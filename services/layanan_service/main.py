from datetime import date, datetime

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, EmailStr, Field
from sqlalchemy import Boolean, DateTime, Float, Integer, String, Text
from sqlalchemy.orm import Mapped, Session, mapped_column

from services.common.auth import CurrentUser, get_current_user, internal_only, require_roles
from services.common.config import settings
from services.common.db import Base, make_session_factory
from services.common.http import audit, call, notify, notify_role, safe_call
from services.common.utils import Msg, create_service

engine, SessionLocal, get_db = make_session_factory("layanan")

JENIS_SURAT = ("Surat Keterangan Aktif Kuliah", "Surat Izin Penelitian", "Surat Pengantar Observasi",
               "Surat Keterangan Lulus", "Transkrip Sementara", "Surat Cuti Akademik")
STATUS_SURAT = ("diajukan", "diproses", "selesai", "ditolak")
STATUS_PENDAFTAR = ("baru", "diverifikasi", "lulus seleksi", "tidak lulus", "diterima")


# -------------------------------- Model --------------------------------- #
class PengajuanSurat(Base):
    __tablename__ = "pengajuan_surat"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    mahasiswa_id: Mapped[int] = mapped_column(Integer, index=True)
    mahasiswa_user_id: Mapped[int] = mapped_column(Integer, index=True)
    mahasiswa_nama: Mapped[str] = mapped_column(String(150))
    nim: Mapped[str] = mapped_column(String(20))
    prodi: Mapped[str] = mapped_column(String(150), default="")
    jenis: Mapped[str] = mapped_column(String(80))
    keperluan: Mapped[str] = mapped_column(Text)
    status: Mapped[str] = mapped_column(String(20), default="diajukan")
    nomor_surat: Mapped[str | None] = mapped_column(String(60), nullable=True)
    catatan: Mapped[str | None] = mapped_column(String(255), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.now)
    selesai_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)


class Pengumuman(Base):
    __tablename__ = "pengumuman"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    judul: Mapped[str] = mapped_column(String(200))
    isi: Mapped[str] = mapped_column(Text)
    kategori: Mapped[str] = mapped_column(String(30), default="Umum")
    target: Mapped[str] = mapped_column(String(20), default="semua")
    penting: Mapped[bool] = mapped_column(Boolean, default=False)
    penulis_id: Mapped[int | None] = mapped_column(Integer, nullable=True)
    penulis_nama: Mapped[str | None] = mapped_column(String(150), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.now)


class Pendaftar(Base):
    __tablename__ = "pendaftar"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    nomor_pendaftaran: Mapped[str] = mapped_column(String(20), unique=True)
    nama: Mapped[str] = mapped_column(String(150))
    email: Mapped[str] = mapped_column(String(120))
    telepon: Mapped[str] = mapped_column(String(30))
    prodi_id: Mapped[int] = mapped_column(Integer)
    prodi_nama: Mapped[str] = mapped_column(String(150), default="")
    pendidikan_terakhir: Mapped[str] = mapped_column(String(150))
    ipk_terakhir: Mapped[float | None] = mapped_column(Float, nullable=True)
    rencana_penelitian: Mapped[str | None] = mapped_column(Text, nullable=True)
    status: Mapped[str] = mapped_column(String(20), default="baru")
    catatan: Mapped[str | None] = mapped_column(String(255), nullable=True)
    mahasiswa_id: Mapped[int | None] = mapped_column(Integer, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.now)


# -------------------------------- Schema -------------------------------- #
class ORM(BaseModel):
    model_config = {"from_attributes": True}


class SuratIn(BaseModel):
    jenis: str
    keperluan: str = Field(min_length=5)


class SuratOut(ORM):
    id: int
    mahasiswa_id: int
    mahasiswa_nama: str
    nim: str
    prodi: str
    jenis: str
    keperluan: str
    status: str
    nomor_surat: str | None
    catatan: str | None
    created_at: datetime
    selesai_at: datetime | None


class SuratProses(BaseModel):
    status: str = Field(pattern="^(diajukan|diproses|selesai|ditolak)$")
    nomor_surat: str | None = None
    catatan: str | None = None


class PengumumanIn(BaseModel):
    judul: str
    isi: str
    kategori: str = "Umum"
    target: str = Field(default="semua", pattern="^(semua|mahasiswa|dosen|publik)$")
    penting: bool = False


class PengumumanOut(PengumumanIn, ORM):
    id: int
    penulis_nama: str | None
    created_at: datetime


class PendaftarIn(BaseModel):
    nama: str = Field(min_length=3)
    email: EmailStr
    telepon: str = Field(min_length=6)
    prodi_id: int
    pendidikan_terakhir: str = Field(min_length=3)
    ipk_terakhir: float | None = Field(default=None, ge=0, le=4)
    rencana_penelitian: str | None = None


class PendaftarOut(ORM):
    id: int
    nomor_pendaftaran: str
    nama: str
    email: str
    telepon: str
    prodi_id: int
    prodi_nama: str
    pendidikan_terakhir: str
    ipk_terakhir: float | None
    rencana_penelitian: str | None
    status: str
    catatan: str | None
    mahasiswa_id: int | None
    created_at: datetime


class PendaftarProses(BaseModel):
    status: str
    catatan: str | None = None
    buat_akun: bool = False


# --------------------------------- App ---------------------------------- #
app = create_service("Layanan Service", "Pengajuan surat, pengumuman, dan Penerimaan Mahasiswa Baru (PMB).")
Base.metadata.create_all(engine)

surat = APIRouter(prefix="/surat", tags=["Pengajuan Surat"])
peng = APIRouter(prefix="/pengumuman", tags=["Pengumuman"])
pmb = APIRouter(prefix="/pmb", tags=["PMB"])
internal = APIRouter(prefix="/internal", tags=["Internal"], dependencies=[Depends(internal_only)])
admin = Depends(require_roles("admin"))


def _mhs(cu: CurrentUser = Depends(require_roles("mahasiswa"))):
    return call(settings.AKADEMIK_URL, "GET", f"/internal/mahasiswa/by-user/{cu.id}")


# -------------------------------- Surat --------------------------------- #
@surat.get("/jenis", summary="Daftar jenis surat yang dapat diajukan")
def jenis_surat():
    return list(JENIS_SURAT)


@surat.get("/saya", response_model=list[SuratOut])
def surat_saya(x: dict = Depends(_mhs), db: Session = Depends(get_db)):
    return db.query(PengajuanSurat).filter_by(mahasiswa_id=x["id"]).order_by(PengajuanSurat.created_at.desc()).all()


@surat.post("/saya", response_model=SuratOut, status_code=201)
def ajukan_surat(data: SuratIn, x: dict = Depends(_mhs), db: Session = Depends(get_db)):
    if data.jenis not in JENIS_SURAT:
        raise HTTPException(400, "Jenis surat tidak valid")
    s = PengajuanSurat(mahasiswa_id=x["id"], mahasiswa_user_id=x["user_id"], mahasiswa_nama=x["nama"], nim=x["nim"],
                       prodi=f"{x['prodi_jenjang']} {x['prodi_nama']}", jenis=data.jenis, keperluan=data.keperluan)
    db.add(s)
    db.commit()
    notify_role("admin", "Pengajuan surat baru", f"{x['nama']}: {data.jenis}", "/admin/surat")
    audit(x["user_id"], f"Mengajukan {data.jenis}", "layanan")
    return s


@surat.get("/saya/{sid}/dokumen", summary="Data untuk mencetak surat yang telah selesai (JSON)")
def dokumen_surat(sid: int, x: dict = Depends(_mhs), db: Session = Depends(get_db)):
    s = db.get(PengajuanSurat, sid)
    if not s or s.mahasiswa_id != x["id"]:
        raise HTTPException(404, "Surat tidak ditemukan")
    if s.status != "selesai":
        raise HTTPException(400, "Surat belum selesai diproses")
    return {"surat": SuratOut.model_validate(s), "mahasiswa": x,
            "institusi": {"nama": settings.NAMA_INSTITUSI, "universitas": settings.NAMA_UNIVERSITAS,
                          "alamat": settings.ALAMAT, "email": settings.EMAIL, "telepon": settings.TELEPON},
            "tanggal_terbit": (s.selesai_at or s.created_at).date()}


@surat.get("", response_model=list[SuratOut], dependencies=[admin])
def list_surat(status: str | None = None, db: Session = Depends(get_db)):
    q = db.query(PengajuanSurat)
    if status:
        q = q.filter(PengajuanSurat.status == status)
    return q.order_by(PengajuanSurat.created_at.desc()).all()


@surat.patch("/{sid}", response_model=SuratOut, summary="Admin memproses surat")
def proses_surat(sid: int, data: SuratProses, cu: CurrentUser = admin, db: Session = Depends(get_db)):
    s = db.get(PengajuanSurat, sid)
    if not s:
        raise HTTPException(404, "Surat tidak ditemukan")
    s.status = data.status
    s.catatan = data.catatan
    if data.nomor_surat:
        s.nomor_surat = data.nomor_surat
    if s.status == "selesai":
        s.selesai_at = datetime.now()
        s.nomor_surat = s.nomor_surat or f"{s.id:04d}/PPs-UNISMUH/{date.today().strftime('%m/%Y')}"
    db.commit()
    notify(s.mahasiswa_user_id, f"Pengajuan surat {s.status}", f"{s.jenis}: {s.status}. {s.catatan or ''}", "/mahasiswa/surat")
    audit(cu.id, f"Surat #{s.id} {s.nim}: {s.status}", "layanan")
    return s


# ------------------------------ Pengumuman ------------------------------ #
@peng.get("", response_model=list[PengumumanOut], summary="Pengumuman publik (tanpa login)")
def list_pengumuman(limit: int = 50, db: Session = Depends(get_db)):
    q = db.query(Pengumuman).filter(Pengumuman.target.in_(["semua", "publik"]))
    return q.order_by(Pengumuman.penting.desc(), Pengumuman.created_at.desc()).limit(limit).all()


@peng.get("/untuk-saya", response_model=list[PengumumanOut])
def pengumuman_saya(limit: int = 50, cu: CurrentUser = Depends(get_current_user), db: Session = Depends(get_db)):
    target = ["semua", "publik"] + ([cu.role] if cu.role in ("mahasiswa", "dosen") else ["mahasiswa", "dosen"])
    return db.query(Pengumuman).filter(Pengumuman.target.in_(target)) \
        .order_by(Pengumuman.penting.desc(), Pengumuman.created_at.desc()).limit(limit).all()


@peng.get("/{pid}", response_model=PengumumanOut)
def get_pengumuman(pid: int, db: Session = Depends(get_db)):
    p = db.get(Pengumuman, pid)
    if not p:
        raise HTTPException(404, "Pengumuman tidak ditemukan")
    return p


@peng.post("", response_model=PengumumanOut, status_code=201)
def buat_pengumuman(data: PengumumanIn, cu: CurrentUser = admin, db: Session = Depends(get_db)):
    p = Pengumuman(**data.model_dump(), penulis_id=cu.id, penulis_nama=cu.nama)
    db.add(p)
    db.commit()
    for role in ("mahasiswa", "dosen"):
        if p.target in ("semua", role):
            notify_role(role, f"Pengumuman: {p.judul}", p.isi[:120], f"/pengumuman/{p.id}")
    audit(cu.id, f"Membuat pengumuman '{p.judul}'", "layanan")
    return p


@peng.put("/{pid}", response_model=PengumumanOut)
def ubah_pengumuman(pid: int, data: PengumumanIn, cu: CurrentUser = admin, db: Session = Depends(get_db)):
    p = db.get(Pengumuman, pid)
    if not p:
        raise HTTPException(404, "Pengumuman tidak ditemukan")
    for k, v in data.model_dump().items():
        setattr(p, k, v)
    db.commit()
    return p


@peng.delete("/{pid}", response_model=Msg, dependencies=[admin])
def hapus_pengumuman(pid: int, db: Session = Depends(get_db)):
    p = db.get(Pengumuman, pid)
    if not p:
        raise HTTPException(404, "Pengumuman tidak ditemukan")
    db.delete(p)
    db.commit()
    return Msg(detail="Pengumuman dihapus")


# --------------------------------- PMB ---------------------------------- #
@pmb.post("/daftar", response_model=PendaftarOut, status_code=201, summary="Formulir pendaftaran publik")
def daftar(data: PendaftarIn, db: Session = Depends(get_db)):
    prodi = call(settings.AKADEMIK_URL, "GET", f"/prodi/{data.prodi_id}")
    p = Pendaftar(**data.model_dump(), prodi_nama=f"{prodi['jenjang']} {prodi['nama']}",
                  nomor_pendaftaran="PMB" + datetime.now().strftime("%Y%m%d%H%M%S%f")[:17])
    db.add(p)
    db.commit()
    notify_role("admin", "Pendaftar baru PMB", f"{p.nama} mendaftar ke {p.prodi_nama}.", "/admin/pmb")
    return p


@pmb.get("/cek/{nomor}", response_model=PendaftarOut, summary="Cek status pendaftaran (publik)")
def cek(nomor: str, db: Session = Depends(get_db)):
    p = db.query(Pendaftar).filter_by(nomor_pendaftaran=nomor).first()
    if not p:
        raise HTTPException(404, "Nomor pendaftaran tidak ditemukan")
    return p


@pmb.get("", response_model=list[PendaftarOut], dependencies=[admin])
def list_pendaftar(status: str | None = None, db: Session = Depends(get_db)):
    q = db.query(Pendaftar)
    if status:
        q = q.filter(Pendaftar.status == status)
    return q.order_by(Pendaftar.created_at.desc()).all()


@pmb.patch("/{pid}", response_model=PendaftarOut, summary="Proses seleksi; opsional buat akun mahasiswa")
def proses_pendaftar(pid: int, data: PendaftarProses, cu: CurrentUser = admin, db: Session = Depends(get_db)):
    p = db.get(Pendaftar, pid)
    if not p:
        raise HTTPException(404, "Pendaftar tidak ditemukan")
    if data.status not in STATUS_PENDAFTAR:
        raise HTTPException(400, "Status tidak valid")
    p.status, p.catatan = data.status, data.catatan
    if data.status == "diterima" and data.buat_akun and not p.mahasiswa_id:
        tahun = date.today().year
        nim = call(settings.AKADEMIK_URL, "GET", f"/internal/mahasiswa/next-nim/{p.prodi_id}", params={"tahun": tahun})["nim"]
        mhs = call(settings.AKADEMIK_URL, "POST", "/internal/mahasiswa", json={
            "nim": nim, "nama": p.nama, "email": p.email, "telepon": p.telepon, "prodi_id": p.prodi_id,
            "angkatan": tahun, "pendidikan_s1": p.pendidikan_terakhir})
        p.mahasiswa_id = mhs["id"]
        p.catatan = (p.catatan or "") + f" | Akun dibuat: NIM {nim}, password awal = NIM"
    db.commit()
    audit(cu.id, f"Pendaftar {p.nomor_pendaftaran}: {p.status}", "layanan")
    return p


@internal.get("/statistik")
def i_statistik(db: Session = Depends(get_db)):
    from sqlalchemy import func
    return {"pendaftar_baru": db.query(Pendaftar).filter_by(status="baru").count(),
            "surat_pending": db.query(PengajuanSurat).filter(PengajuanSurat.status.in_(["diajukan", "diproses"])).count(),
            "pengumuman": db.query(Pengumuman).count()}


for r in (surat, peng, pmb, internal):
    app.include_router(r)
