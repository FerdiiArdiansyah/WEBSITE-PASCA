from datetime import date

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile
from pydantic import BaseModel, Field
from sqlalchemy import Date, Float, ForeignKey, Integer, String, Text, or_
from sqlalchemy.orm import Mapped, Session, mapped_column, relationship

from services.common.auth import CurrentUser, get_current_user, internal_only, require_roles
from services.common.config import settings
from services.common.db import Base, make_session_factory
from services.common.files import mount_files, save_upload
from services.common.http import audit, call, notify, notify_role, safe_call
from services.common.utils import Msg, create_service

engine, SessionLocal, get_db = make_session_factory("tesis")

STATUS = ("pengajuan", "disetujui", "proposal", "penelitian", "seminar hasil", "ujian", "selesai", "ditolak")
URUTAN = STATUS[:-1]


# -------------------------------- Model --------------------------------- #
class Tesis(Base):
    __tablename__ = "tesis"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    mahasiswa_id: Mapped[int] = mapped_column(Integer, unique=True, index=True)
    mahasiswa_user_id: Mapped[int] = mapped_column(Integer, index=True)
    mahasiswa_nama: Mapped[str] = mapped_column(String(150))
    nim: Mapped[str] = mapped_column(String(20))
    prodi: Mapped[str] = mapped_column(String(150), default="")
    judul: Mapped[str] = mapped_column(String(300))
    abstrak: Mapped[str | None] = mapped_column(Text, nullable=True)
    bidang: Mapped[str | None] = mapped_column(String(100), nullable=True)
    pembimbing1_id: Mapped[int | None] = mapped_column(Integer, nullable=True, index=True)
    pembimbing1_user_id: Mapped[int | None] = mapped_column(Integer, nullable=True)
    pembimbing1_nama: Mapped[str | None] = mapped_column(String(150), nullable=True)
    pembimbing2_id: Mapped[int | None] = mapped_column(Integer, nullable=True, index=True)
    pembimbing2_user_id: Mapped[int | None] = mapped_column(Integer, nullable=True)
    pembimbing2_nama: Mapped[str | None] = mapped_column(String(150), nullable=True)
    status: Mapped[str] = mapped_column(String(20), default="pengajuan")
    catatan: Mapped[str | None] = mapped_column(Text, nullable=True)
    nilai_akhir: Mapped[float | None] = mapped_column(Float, nullable=True)
    tanggal_pengajuan: Mapped[date] = mapped_column(Date, default=date.today)
    tanggal_ujian: Mapped[date | None] = mapped_column(Date, nullable=True)
    file_proposal: Mapped[str | None] = mapped_column(String(255), nullable=True)

    bimbingan = relationship("Bimbingan", back_populates="tesis", lazy="dynamic", cascade="all, delete-orphan",
                             order_by="Bimbingan.tanggal.desc()")

    @property
    def progres(self) -> int:
        return 0 if self.status == "ditolak" else int(URUTAN.index(self.status) / (len(URUTAN) - 1) * 100)


class Bimbingan(Base):
    __tablename__ = "bimbingan"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    tesis_id: Mapped[int] = mapped_column(ForeignKey("tesis.id"))
    dosen_id: Mapped[int] = mapped_column(Integer)
    dosen_nama: Mapped[str] = mapped_column(String(150))
    tanggal: Mapped[date] = mapped_column(Date, default=date.today)
    topik: Mapped[str] = mapped_column(String(200))
    catatan_mahasiswa: Mapped[str | None] = mapped_column(Text, nullable=True)
    catatan_dosen: Mapped[str | None] = mapped_column(Text, nullable=True)
    status: Mapped[str] = mapped_column(String(20), default="menunggu")
    file_lampiran: Mapped[str | None] = mapped_column(String(255), nullable=True)

    tesis = relationship("Tesis", back_populates="bimbingan")


# -------------------------------- Schema -------------------------------- #
class BimbinganOut(BaseModel):
    id: int
    tesis_id: int
    dosen_id: int
    dosen_nama: str
    tanggal: date
    topik: str
    catatan_mahasiswa: str | None
    catatan_dosen: str | None
    status: str
    file_lampiran: str | None
    model_config = {"from_attributes": True}


class TesisOut(BaseModel):
    id: int
    mahasiswa_id: int
    mahasiswa_nama: str
    nim: str
    prodi: str
    judul: str
    abstrak: str | None
    bidang: str | None
    pembimbing1_id: int | None
    pembimbing1_nama: str | None
    pembimbing2_id: int | None
    pembimbing2_nama: str | None
    status: str
    catatan: str | None
    nilai_akhir: float | None
    tanggal_pengajuan: date
    tanggal_ujian: date | None
    file_proposal: str | None
    progres: int
    jumlah_bimbingan_disetujui: int = 0
    model_config = {"from_attributes": True}


class TesisDetail(TesisOut):
    bimbingan: list[BimbinganOut] = []


class TesisAdminUpdate(BaseModel):
    pembimbing1_id: int | None = None
    pembimbing2_id: int | None = None
    status: str | None = Field(default=None, pattern="^(" + "|".join(STATUS).replace(" ", r"\s") + ")$")
    catatan: str | None = None
    tanggal_ujian: date | None = None
    nilai_akhir: float | None = Field(default=None, ge=0, le=100)


class TesisStatusDosen(BaseModel):
    status: str
    catatan: str | None = None


class LogDosenIn(BaseModel):
    tanggal: date | None = None
    topik: str
    catatan_dosen: str


class LogReview(BaseModel):
    status: str = Field(pattern="^(disetujui|revisi)$")
    catatan_dosen: str


def _out(t: Tesis) -> TesisOut:
    o = TesisOut.model_validate(t)
    o.jumlah_bimbingan_disetujui = t.bimbingan.filter(Bimbingan.status == "disetujui").count()
    return o


def _detail(t: Tesis) -> TesisDetail:
    d = TesisDetail(**_out(t).model_dump(), bimbingan=[BimbinganOut.model_validate(b) for b in t.bimbingan])
    return d


# --------------------------------- App ---------------------------------- #
app = create_service("Tesis Service", "Pengajuan judul tesis/disertasi, penetapan pembimbing, tahapan, dan log bimbingan.")
Base.metadata.create_all(engine)
mount_files(app)

mhs = APIRouter(prefix="/tesis/saya", tags=["Mahasiswa"])
dsn = APIRouter(prefix="/tesis/bimbingan", tags=["Dosen Pembimbing"])
adm = APIRouter(prefix="/tesis", tags=["Admin"])
internal = APIRouter(prefix="/internal", tags=["Internal"], dependencies=[Depends(internal_only)])


def _mhs(cu: CurrentUser = Depends(require_roles("mahasiswa"))):
    return call(settings.AKADEMIK_URL, "GET", f"/internal/mahasiswa/by-user/{cu.id}")


def _dosen(cu: CurrentUser = Depends(require_roles("dosen"))):
    return call(settings.AKADEMIK_URL, "GET", f"/internal/dosen/by-user/{cu.id}")


def _tesis_dosen(tid: int, d: dict, db: Session) -> Tesis:
    t = db.get(Tesis, tid)
    if not t:
        raise HTTPException(404, "Tesis tidak ditemukan")
    if d["id"] not in (t.pembimbing1_id, t.pembimbing2_id):
        raise HTTPException(403, "Anda bukan pembimbing tesis ini")
    return t


# ------------------------------ Mahasiswa ------------------------------- #
@mhs.get("", response_model=TesisDetail | None)
def tesis_saya(x: dict = Depends(_mhs), db: Session = Depends(get_db)):
    t = db.query(Tesis).filter_by(mahasiswa_id=x["id"]).first()
    return _detail(t) if t else None


@mhs.post("", response_model=TesisOut, status_code=201, summary="Ajukan judul (multipart, proposal PDF opsional)")
def ajukan(judul: str = Form(...), abstrak: str = Form(""), bidang: str = Form(""),
           file_proposal: UploadFile | None = File(default=None), x: dict = Depends(_mhs), db: Session = Depends(get_db)):
    t = db.query(Tesis).filter_by(mahasiswa_id=x["id"]).first()
    if t and t.status != "ditolak":
        raise HTTPException(409, "Anda sudah memiliki pengajuan tesis")
    if x["total_sks"] < settings.MIN_SKS_TESIS:
        raise HTTPException(400, f"Pengajuan tesis memerlukan minimal {settings.MIN_SKS_TESIS} SKS lulus")
    if not t:
        t = Tesis(mahasiswa_id=x["id"], mahasiswa_user_id=x["user_id"], mahasiswa_nama=x["nama"], nim=x["nim"],
                  prodi=f"{x['prodi_jenjang']} {x['prodi_nama']}", judul=judul)
        db.add(t)
    t.judul, t.abstrak, t.bidang = judul, abstrak, bidang
    t.status, t.catatan, t.tanggal_pengajuan = "pengajuan", None, date.today()
    berkas = save_upload(file_proposal, "proposal")
    if berkas:
        t.file_proposal = berkas
    db.commit()
    notify_role("admin", "Pengajuan judul tesis", f"{t.mahasiswa_nama}: {t.judul}", "/admin/tesis")
    audit(x["user_id"], "Mengajukan judul tesis", "tesis")
    return _out(t)


@mhs.post("/bimbingan", response_model=BimbinganOut, status_code=201, summary="Ajukan log bimbingan (multipart)")
def ajukan_bimbingan(dosen_id: int = Form(...), topik: str = Form(...), catatan_mahasiswa: str = Form(""),
                     tanggal: date | None = Form(default=None), lampiran: UploadFile | None = File(default=None),
                     x: dict = Depends(_mhs), db: Session = Depends(get_db)):
    t = db.query(Tesis).filter_by(mahasiswa_id=x["id"]).first()
    if not t or t.status in ("pengajuan", "ditolak", "selesai"):
        raise HTTPException(400, "Bimbingan belum dapat diajukan pada tahapan ini")
    if dosen_id not in (t.pembimbing1_id, t.pembimbing2_id):
        raise HTTPException(400, "Dosen bukan pembimbing Anda")
    nama = t.pembimbing1_nama if dosen_id == t.pembimbing1_id else t.pembimbing2_nama
    uid = t.pembimbing1_user_id if dosen_id == t.pembimbing1_id else t.pembimbing2_user_id
    b = Bimbingan(tesis_id=t.id, dosen_id=dosen_id, dosen_nama=nama or "", tanggal=tanggal or date.today(), topik=topik,
                  catatan_mahasiswa=catatan_mahasiswa, file_lampiran=save_upload(lampiran, "bimbingan"))
    db.add(b)
    db.commit()
    notify(uid, "Pengajuan bimbingan", f"{t.mahasiswa_nama}: {topik}", f"/dosen/bimbingan/{t.id}")
    audit(x["user_id"], "Mengajukan bimbingan tesis", "tesis")
    return b


# -------------------------------- Dosen --------------------------------- #
@dsn.get("", response_model=list[TesisOut], summary="Tesis yang dibimbing dosen")
def bimbingan_saya(status: str | None = None, d: dict = Depends(_dosen), db: Session = Depends(get_db)):
    q = db.query(Tesis).filter(or_(Tesis.pembimbing1_id == d["id"], Tesis.pembimbing2_id == d["id"]))
    if status:
        q = q.filter(Tesis.status == status)
    return [_out(t) for t in q.order_by(Tesis.tanggal_pengajuan.desc())]


@dsn.get("/log-menunggu", response_model=list[BimbinganOut], summary="Log bimbingan menunggu persetujuan dosen")
def log_menunggu(d: dict = Depends(_dosen), db: Session = Depends(get_db)):
    return db.query(Bimbingan).filter(Bimbingan.dosen_id == d["id"], Bimbingan.status == "menunggu") \
        .order_by(Bimbingan.tanggal.desc()).all()


@dsn.get("/{tid}", response_model=TesisDetail)
def detail_bimbingan(tid: int, d: dict = Depends(_dosen), db: Session = Depends(get_db)):
    return _detail(_tesis_dosen(tid, d, db))


@dsn.post("/{tid}/log", response_model=BimbinganOut, status_code=201, summary="Dosen mencatat bimbingan")
def catat_log(tid: int, data: LogDosenIn, d: dict = Depends(_dosen), db: Session = Depends(get_db)):
    t = _tesis_dosen(tid, d, db)
    b = Bimbingan(tesis_id=t.id, dosen_id=d["id"], dosen_nama=d["nama_lengkap"], tanggal=data.tanggal or date.today(),
                  topik=data.topik, catatan_dosen=data.catatan_dosen, status="disetujui")
    db.add(b)
    db.commit()
    notify(t.mahasiswa_user_id, "Catatan bimbingan baru", data.topik, "/mahasiswa/tesis")
    return b


@dsn.patch("/log/{bid}", response_model=BimbinganOut, summary="Setujui / minta revisi log mahasiswa")
def review_log(bid: int, data: LogReview, d: dict = Depends(_dosen), db: Session = Depends(get_db)):
    b = db.get(Bimbingan, bid)
    if not b:
        raise HTTPException(404, "Log tidak ditemukan")
    t = _tesis_dosen(b.tesis_id, d, db)
    b.status, b.catatan_dosen = data.status, data.catatan_dosen
    db.commit()
    notify(t.mahasiswa_user_id, f"Bimbingan {b.status}", f"{b.topik}: {b.catatan_dosen}", "/mahasiswa/tesis")
    return b


@dsn.patch("/{tid}/status", response_model=TesisOut, summary="Pembimbing 1 memperbarui tahapan")
def ubah_tahapan(tid: int, data: TesisStatusDosen, d: dict = Depends(_dosen), db: Session = Depends(get_db)):
    t = _tesis_dosen(tid, d, db)
    if t.pembimbing1_id != d["id"]:
        raise HTTPException(403, "Hanya Pembimbing 1 yang dapat mengubah tahapan")
    if data.status not in STATUS or data.status in ("selesai", "pengajuan"):
        raise HTTPException(400, "Tahapan tidak valid untuk dosen")
    t.status, t.catatan = data.status, data.catatan
    db.commit()
    notify(t.mahasiswa_user_id, "Status tesis diperbarui", f"Tahapan kini: {t.status}.", "/mahasiswa/tesis")
    audit(d["user_id"], f"Update tahapan tesis {t.nim}: {t.status}", "tesis")
    return _out(t)


# -------------------------------- Admin --------------------------------- #
@adm.get("", response_model=list[TesisOut], dependencies=[Depends(require_roles("admin"))])
def list_tesis(status: str | None = None, db: Session = Depends(get_db)):
    q = db.query(Tesis)
    if status:
        q = q.filter(Tesis.status == status)
    return [_out(t) for t in q.order_by(Tesis.tanggal_pengajuan.desc())]


@adm.get("/statistik", dependencies=[Depends(require_roles("admin"))])
def statistik(db: Session = Depends(get_db)):
    from sqlalchemy import func
    return {s: n for s, n in db.query(Tesis.status, func.count(Tesis.id)).group_by(Tesis.status)}


@adm.get("/{tid}", response_model=TesisDetail, dependencies=[Depends(require_roles("admin"))])
def detail_admin(tid: int, db: Session = Depends(get_db)):
    t = db.get(Tesis, tid)
    if not t:
        raise HTTPException(404, "Tesis tidak ditemukan")
    return _detail(t)


@adm.put("/{tid}", response_model=TesisOut, summary="Tetapkan pembimbing / ubah status / nilai")
def update_admin(tid: int, data: TesisAdminUpdate, cu: CurrentUser = Depends(require_roles("admin")),
                 db: Session = Depends(get_db)):
    t = db.get(Tesis, tid)
    if not t:
        raise HTTPException(404, "Tesis tidak ditemukan")
    lama = {t.pembimbing1_id, t.pembimbing2_id}
    for n, did in ((1, data.pembimbing1_id), (2, data.pembimbing2_id)):
        if did is not None:
            d = call(settings.AKADEMIK_URL, "GET", f"/internal/dosen/{did}")
            setattr(t, f"pembimbing{n}_id", d["id"])
            setattr(t, f"pembimbing{n}_user_id", d["user_id"])
            setattr(t, f"pembimbing{n}_nama", d["nama_lengkap"])
    if data.status:
        t.status = data.status
    if data.catatan is not None:
        t.catatan = data.catatan
    if data.tanggal_ujian:
        t.tanggal_ujian = data.tanggal_ujian
    if data.nilai_akhir is not None:
        t.nilai_akhir = data.nilai_akhir
    if t.status == "pengajuan" and t.pembimbing1_id:
        t.status = "disetujui"
    db.commit()
    for did, uid in ((t.pembimbing1_id, t.pembimbing1_user_id), (t.pembimbing2_id, t.pembimbing2_user_id)):
        if did and did not in lama:
            notify(uid, "Penugasan pembimbing", f"Anda ditetapkan sebagai pembimbing tesis {t.mahasiswa_nama}.",
                   f"/dosen/bimbingan/{t.id}")
    notify(t.mahasiswa_user_id, "Pembaruan tesis", f"Status tesis Anda: {t.status}.", "/mahasiswa/tesis")
    if t.status == "selesai":
        safe_call(settings.AKADEMIK_URL, "PATCH", f"/internal/mahasiswa/{t.mahasiswa_id}/status", params={"status": "lulus"})
    audit(cu.id, f"Memperbarui tesis {t.nim}: {t.status}", "tesis")
    return _out(t)


@adm.delete("/{tid}", response_model=Msg, dependencies=[Depends(require_roles("admin"))])
def hapus_tesis(tid: int, db: Session = Depends(get_db)):
    t = db.get(Tesis, tid)
    if not t:
        raise HTTPException(404, "Tesis tidak ditemukan")
    db.delete(t)
    db.commit()
    return Msg(detail="Tesis dihapus")


@internal.get("/tesis/by-mahasiswa/{mid}", response_model=TesisOut | None)
def i_by_mhs(mid: int, db: Session = Depends(get_db)):
    t = db.query(Tesis).filter_by(mahasiswa_id=mid).first()
    return _out(t) if t else None


@internal.get("/statistik")
def i_statistik(db: Session = Depends(get_db)):
    from sqlalchemy import func
    return {s: n for s, n in db.query(Tesis.status, func.count(Tesis.id)).group_by(Tesis.status)}


for r in (mhs, dsn, adm, internal):
    app.include_router(r)
