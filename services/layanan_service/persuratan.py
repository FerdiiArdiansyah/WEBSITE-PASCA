"""Persuratan berbasis templat: mahasiswa menyusun & mengedit isi surat sendiri, mengajukan ke admin,
admin meninjau (setujui / minta revisi / tolak). Templat pertama: Surat Keterangan Kuliah."""
from datetime import date, datetime

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy import Date, DateTime, Integer, String, Text, func
from sqlalchemy.orm import Mapped, Session, mapped_column

from services.common.auth import CurrentUser, require_roles
from services.common.config import settings
from services.common.db import Base
from services.common.http import audit, call, notify, notify_role, safe_call

STATUS = ("draft", "diajukan", "revisi", "disetujui", "ditolak")
BOLEH_EDIT = ("draft", "revisi")

# Templat surat yang tersedia. Kolom = field yang boleh diisi/diubah mahasiswa.
TEMPLAT = {
    "Surat Keterangan Kuliah": {
        "kode": "SKK",
        "deskripsi": "Menerangkan bahwa mahasiswa benar terdaftar dan aktif kuliah pada semester berjalan.",
        "kolom": [
            {"key": "nama", "label": "Nama", "wajib": True},
            {"key": "nim", "label": "No. Induk Mahasiswa", "wajib": True, "readonly": True},
            {"key": "tempat_lahir", "label": "Tempat Lahir", "wajib": True},
            {"key": "tanggal_lahir", "label": "Tanggal Lahir", "wajib": True, "tipe": "date"},
            {"key": "asal_sekolah", "label": "Asal Sekolah / Instansi", "wajib": True},
            {"key": "program_pendidikan", "label": "Program Pendidikan", "wajib": True},
            {"key": "program_studi", "label": "Program Studi", "wajib": True},
            {"key": "semester", "label": "Semester", "wajib": True, "pilihan": ["Ganjil", "Genap"]},
            {"key": "tahun_ajaran", "label": "Tahun Ajaran", "wajib": True},
            {"key": "keperluan", "label": "Keperluan (untuk catatan admin, tidak dicetak)", "wajib": False, "multiline": True},
        ],
    },
}

BULAN_ID = ["", "Januari", "Februari", "Maret", "April", "Mei", "Juni", "Juli", "Agustus", "September", "Oktober",
            "November", "Desember"]
BULAN_HIJRIAH = ["", "Muharram", "Safar", "Rabiul Awal", "Rabiul Akhir", "Jumadil Awal", "Jumadil Akhir", "Rajab",
                 "Sya'ban", "Ramadhan", "Syawal", "Dzulkaidah", "Dzulhijjah"]
ROMAWI = ["", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI", "XII"]


# -------------------------------- Model --------------------------------- #
class Persuratan(Base):
    __tablename__ = "persuratan"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    mahasiswa_id: Mapped[int] = mapped_column(Integer, index=True)
    mahasiswa_user_id: Mapped[int] = mapped_column(Integer, index=True)
    jenis: Mapped[str] = mapped_column(String(80))
    status: Mapped[str] = mapped_column(String(20), default="draft", index=True)
    # Isi surat (diedit mahasiswa)
    nama: Mapped[str] = mapped_column(String(150))
    nim: Mapped[str] = mapped_column(String(20))
    tempat_lahir: Mapped[str | None] = mapped_column(String(80), nullable=True)
    tanggal_lahir: Mapped[date | None] = mapped_column(Date, nullable=True)
    asal_sekolah: Mapped[str | None] = mapped_column(String(150), nullable=True)
    program_pendidikan: Mapped[str] = mapped_column(String(60), default="")
    program_studi: Mapped[str] = mapped_column(String(150), default="")
    semester: Mapped[str] = mapped_column(String(10), default="")
    tahun_ajaran: Mapped[str] = mapped_column(String(12), default="")
    keperluan: Mapped[str | None] = mapped_column(Text, nullable=True)
    # Penomoran & pengesahan (diisi admin)
    nomor_urut: Mapped[int | None] = mapped_column(Integer, nullable=True)
    nomor_surat: Mapped[str | None] = mapped_column(String(60), nullable=True)
    tanggal_surat: Mapped[date | None] = mapped_column(Date, nullable=True)
    tanggal_hijriah: Mapped[str | None] = mapped_column(String(40), nullable=True)
    penandatangan_nama: Mapped[str | None] = mapped_column(String(150), nullable=True)
    penandatangan_jabatan: Mapped[str | None] = mapped_column(String(80), nullable=True)
    penandatangan_nbm: Mapped[str | None] = mapped_column(String(30), nullable=True)
    catatan_admin: Mapped[str | None] = mapped_column(String(500), nullable=True)
    ditinjau_oleh: Mapped[str | None] = mapped_column(String(150), nullable=True)
    # Jejak waktu
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.now)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.now, onupdate=datetime.now)
    diajukan_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    ditinjau_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)


# -------------------------------- Schema -------------------------------- #
class ORM(BaseModel):
    model_config = {"from_attributes": True}


class PersuratanBuat(BaseModel):
    jenis: str = "Surat Keterangan Kuliah"
    keperluan: str | None = None


class PersuratanEdit(BaseModel):
    nama: str = Field(min_length=3, max_length=150)
    tempat_lahir: str = Field(min_length=2, max_length=80)
    tanggal_lahir: date
    asal_sekolah: str = Field(min_length=2, max_length=150)
    program_pendidikan: str = Field(min_length=3, max_length=60)
    program_studi: str = Field(min_length=3, max_length=150)
    semester: str = Field(pattern="^(Ganjil|Genap)$")
    tahun_ajaran: str = Field(pattern=r"^\d{4}-\d{4}$")
    keperluan: str | None = Field(default=None, max_length=500)


class PersuratanOut(ORM):
    id: int
    mahasiswa_id: int
    jenis: str
    status: str
    nama: str
    nim: str
    tempat_lahir: str | None
    tanggal_lahir: date | None
    asal_sekolah: str | None
    program_pendidikan: str
    program_studi: str
    semester: str
    tahun_ajaran: str
    keperluan: str | None
    nomor_surat: str | None
    tanggal_surat: date | None
    tanggal_hijriah: str | None
    penandatangan_nama: str | None
    penandatangan_jabatan: str | None
    penandatangan_nbm: str | None
    catatan_admin: str | None
    ditinjau_oleh: str | None
    created_at: datetime
    updated_at: datetime
    diajukan_at: datetime | None
    ditinjau_at: datetime | None


class Tinjau(BaseModel):
    aksi: str = Field(pattern="^(setujui|revisi|tolak)$")
    catatan: str | None = Field(default=None, max_length=500)
    nomor_surat: str | None = Field(default=None, max_length=60)
    tanggal_surat: date | None = None
    tanggal_hijriah: str | None = Field(default=None, max_length=40)


# -------------------------------- Helper -------------------------------- #
def ke_hijriah(d: date) -> tuple[int, int, int]:
    """Konversi Masehi -> Hijriah (kalender tabular/aritmetika; selisih maks. 1 hari dari rukyat)."""
    jd = d.toordinal() + 1721425
    l = jd - 1948440 + 10632
    n = (l - 1) // 10631
    l = l - 10631 * n + 354
    j = ((10985 - l) // 5316) * ((50 * l) // 17719) + (l // 5670) * ((43 * l) // 15238)
    l = l - ((30 - j) // 15) * ((17719 * j) // 50) - (j // 16) * ((15238 * j) // 43) + 29
    bulan = (24 * l) // 709
    hari = l - (709 * bulan) // 24
    tahun = 30 * n + j - 30
    return tahun, bulan, hari


def teks_hijriah(d: date) -> str:
    t, b, h = ke_hijriah(d)
    return f"{h:02d} {BULAN_HIJRIAH[b]} {t} H"


def teks_masehi(d: date) -> str:
    return f"{d.day:02d} {BULAN_ID[d.month]} {d.year} M"


def teks_tanggal(d: date | None) -> str:
    return "-" if d is None else f"{d.day:02d} {BULAN_ID[d.month]} {d.year}"


def program_pendidikan(jenjang: str | None) -> str:
    return {"S2": "Strata Dua (S.2)", "S3": "Strata Tiga (S.3)"}.get(jenjang or "", jenjang or "")


def program_studi(jenjang: str | None, nama: str | None) -> str:
    nama = nama or ""
    if nama.lower().startswith(("magister", "doktor")):
        return nama
    return f"{ {'S2': 'Magister', 'S3': 'Doktor'}.get(jenjang or '', '') } {nama}".strip()


def nomor_berikutnya(db: Session, tgl: date) -> tuple[int, str]:
    awal, akhir = date(tgl.year, 1, 1), date(tgl.year, 12, 31)
    maks = db.query(func.max(Persuratan.nomor_urut)).filter(
        Persuratan.tanggal_surat >= awal, Persuratan.tanggal_surat <= akhir).scalar() or 0
    urut = maks + 1
    th_h, _, _ = ke_hijriah(tgl)
    return urut, f"{urut}/{settings.KODE_SURAT}/{ROMAWI[tgl.month]}/{th_h}/{tgl.year}"


def cek_lengkap(s: Persuratan):
    kosong = [k["label"] for k in TEMPLAT[s.jenis]["kolom"] if k["wajib"] and not getattr(s, k["key"])]
    if kosong:
        raise HTTPException(400, "Kolom wajib belum diisi: " + ", ".join(kosong))


def render(s: Persuratan) -> dict:
    """Susun dokumen final (semua teks berasal dari server agar klien tidak merakit isi surat sendiri)."""
    tgl = s.tanggal_surat or date.today()
    return {
        "id": s.id, "status": s.status, "jenis": s.jenis,
        "kop": {"institusi": settings.NAMA_INSTITUSI, "universitas": settings.NAMA_UNIVERSITAS,
                "alamat": settings.ALAMAT, "email": settings.EMAIL, "telepon": settings.TELEPON},
        "judul": s.jenis.upper(),
        "nomor": f"Nomor : {s.nomor_surat}" if s.nomor_surat else "Nomor : ........ /" + settings.KODE_SURAT + "/..../..../....",
        "pembuka": f"{settings.DIREKTUR_JABATAN} {settings.NAMA_INSTITUSI} {settings.NAMA_UNIVERSITAS}, "
                   "dengan ini menerangkan bahwa :",
        "data": [
            ["Nama", s.nama],
            ["No. Induk Mahasiswa", s.nim],
            ["Tempat, Tgl Lahir", f"{s.tempat_lahir or '-'}, {teks_tanggal(s.tanggal_lahir)}"],
            ["Asal Sekolah", s.asal_sekolah or "-"],
            ["Program Pendidikan", s.program_pendidikan],
            ["Program Studi", s.program_studi],
        ],
        "isi": [
            f"adalah benar mahasiswa aktif pada {settings.NAMA_INSTITUSI} {settings.NAMA_UNIVERSITAS} "
            f"pada semester {s.semester} Tahun Ajaran {s.tahun_ajaran}.",
            "Demikian surat keterangan ini diberikan kepada yang bersangkutan untuk dipergunakan sebagaimana mestinya.",
        ],
        "tanggal_hijriah": s.tanggal_hijriah or teks_hijriah(tgl),
        "tanggal_masehi": teks_masehi(tgl),
        "penandatangan": {"jabatan": (s.penandatangan_jabatan or settings.DIREKTUR_JABATAN) + ",",
                          "nama": s.penandatangan_nama or settings.DIREKTUR_NAMA,
                          "nbm": "NBM: " + (s.penandatangan_nbm or settings.DIREKTUR_NBM)},
        "final": s.status == "disetujui",
    }


# -------------------------------- Router -------------------------------- #
def buat_router(get_db) -> APIRouter:
    r = APIRouter(prefix="/persuratan", tags=["Persuratan (templat)"])
    admin = Depends(require_roles("admin"))

    def _mhs(cu: CurrentUser = Depends(require_roles("mahasiswa"))):
        return call(settings.AKADEMIK_URL, "GET", f"/internal/mahasiswa/by-user/{cu.id}")

    def _milik(db: Session, sid: int, x: dict) -> Persuratan:
        s = db.get(Persuratan, sid)
        if not s or s.mahasiswa_id != x["id"]:
            raise HTTPException(404, "Surat tidak ditemukan")
        return s

    def _ada(db: Session, sid: int) -> Persuratan:
        s = db.get(Persuratan, sid)
        if not s:
            raise HTTPException(404, "Surat tidak ditemukan")
        return s

    @r.get("/templat", summary="Daftar templat surat beserta kolom yang dapat diedit mahasiswa")
    def templat():
        return [{"jenis": k, **v} for k, v in TEMPLAT.items()]

    # ------------------------------ Mahasiswa ------------------------------ #
    @r.get("/saya", response_model=list[PersuratanOut])
    def saya(x: dict = Depends(_mhs), db: Session = Depends(get_db)):
        return db.query(Persuratan).filter_by(mahasiswa_id=x["id"]).order_by(Persuratan.updated_at.desc()).all()

    @r.post("/saya", response_model=PersuratanOut, status_code=201,
            summary="Buat draf surat; isi awal diambil dari data akademik mahasiswa & tahun akademik aktif")
    def buat(data: PersuratanBuat, x: dict = Depends(_mhs), db: Session = Depends(get_db)):
        if data.jenis not in TEMPLAT:
            raise HTTPException(400, "Jenis surat tidak tersedia")
        if x.get("status") != "aktif":
            raise HTTPException(400, "Hanya mahasiswa berstatus aktif yang dapat mengajukan surat keterangan kuliah")
        ta = safe_call(settings.AKADEMIK_URL, "GET", "/internal/tahun-akademik/aktif") or {}
        th = ta.get("tahun_mulai") or date.today().year
        s = Persuratan(
            mahasiswa_id=x["id"], mahasiswa_user_id=x["user_id"], jenis=data.jenis,
            nama=x["nama"], nim=x["nim"], tempat_lahir=x.get("tempat_lahir"),
            tanggal_lahir=date.fromisoformat(x["tanggal_lahir"]) if x.get("tanggal_lahir") else None,
            asal_sekolah=None,  # tidak ada padanan di data akademik; wajib diisi mahasiswa
            program_pendidikan=program_pendidikan(x.get("prodi_jenjang")),
            program_studi=program_studi(x.get("prodi_jenjang"), x.get("prodi_nama")),
            semester=ta.get("semester") or "Ganjil", tahun_ajaran=f"{th}-{int(th) + 1}", keperluan=data.keperluan)
        db.add(s)
        db.commit()
        return s

    @r.get("/saya/{sid}", response_model=PersuratanOut)
    def detail_saya(sid: int, x: dict = Depends(_mhs), db: Session = Depends(get_db)):
        return _milik(db, sid, x)

    @r.put("/saya/{sid}", response_model=PersuratanOut, summary="Mahasiswa mengedit isi surat (draf / revisi)")
    def edit(sid: int, data: PersuratanEdit, x: dict = Depends(_mhs), db: Session = Depends(get_db)):
        s = _milik(db, sid, x)
        if s.status not in BOLEH_EDIT:
            raise HTTPException(400, f"Surat berstatus '{s.status}' tidak dapat diedit")
        for k, v in data.model_dump().items():
            setattr(s, k, v.strip() if isinstance(v, str) else v)
        db.commit()
        return s

    @r.post("/saya/{sid}/ajukan", response_model=PersuratanOut, summary="Ajukan draf ke admin untuk ditinjau")
    def ajukan(sid: int, x: dict = Depends(_mhs), db: Session = Depends(get_db)):
        s = _milik(db, sid, x)
        if s.status not in BOLEH_EDIT:
            raise HTTPException(400, f"Surat berstatus '{s.status}' tidak dapat diajukan")
        cek_lengkap(s)
        s.status, s.diajukan_at, s.catatan_admin = "diajukan", datetime.now(), None
        db.commit()
        notify_role("admin", "Pengajuan surat baru", f"{s.nama} ({s.nim}): {s.jenis}", "/admin/persuratan")
        audit(x["user_id"], f"Mengajukan {s.jenis} #{s.id}", "layanan")
        return s

    @r.delete("/saya/{sid}", status_code=204, summary="Hapus draf (hanya status draft)")
    def hapus(sid: int, x: dict = Depends(_mhs), db: Session = Depends(get_db)):
        s = _milik(db, sid, x)
        if s.status != "draft":
            raise HTTPException(400, "Hanya draf yang dapat dihapus")
        db.delete(s)
        db.commit()

    @r.get("/saya/{sid}/dokumen", summary="Dokumen surat (pratinjau; final bila sudah disetujui)")
    def dokumen_saya(sid: int, x: dict = Depends(_mhs), db: Session = Depends(get_db)):
        return render(_milik(db, sid, x))

    # -------------------------------- Admin -------------------------------- #
    @r.get("", response_model=list[PersuratanOut], dependencies=[admin])
    def daftar(status: str | None = None, db: Session = Depends(get_db)):
        q = db.query(Persuratan)
        if status:
            q = q.filter(Persuratan.status == status)
        else:
            q = q.filter(Persuratan.status != "draft")
        return q.order_by(Persuratan.updated_at.desc()).all()

    @r.get("/{sid}", response_model=PersuratanOut, dependencies=[admin])
    def detail(sid: int, db: Session = Depends(get_db)):
        return _ada(db, sid)

    @r.get("/{sid}/dokumen", dependencies=[admin], summary="Pratinjau dokumen untuk peninjauan admin")
    def dokumen(sid: int, db: Session = Depends(get_db)):
        return render(_ada(db, sid))

    @r.get("/{sid}/nomor-usulan", dependencies=[admin], summary="Usulan nomor surat & tanggal (dapat diubah admin)")
    def nomor_usulan(sid: int, tanggal: date | None = None, db: Session = Depends(get_db)):
        _ada(db, sid)
        tgl = tanggal or date.today()
        _, nomor = nomor_berikutnya(db, tgl)
        return {"nomor_surat": nomor, "tanggal_surat": tgl, "tanggal_hijriah": teks_hijriah(tgl)}

    @r.patch("/{sid}/tinjau", response_model=PersuratanOut, summary="Admin menyetujui / meminta revisi / menolak")
    def tinjau(sid: int, data: Tinjau, cu: CurrentUser = admin, db: Session = Depends(get_db)):
        s = _ada(db, sid)
        if s.status not in ("diajukan", "revisi"):
            raise HTTPException(400, f"Surat berstatus '{s.status}' tidak dapat ditinjau")
        if data.aksi in ("revisi", "tolak") and not (data.catatan or "").strip():
            raise HTTPException(400, "Catatan wajib diisi untuk revisi/penolakan")
        if data.aksi == "setujui":
            cek_lengkap(s)
            tgl = data.tanggal_surat or date.today()
            urut, nomor = nomor_berikutnya(db, tgl)
            s.nomor_urut, s.nomor_surat = urut, (data.nomor_surat or "").strip() or nomor
            if db.query(Persuratan).filter(Persuratan.nomor_surat == s.nomor_surat, Persuratan.id != s.id).first():
                raise HTTPException(409, "Nomor surat sudah dipakai")
            s.tanggal_surat = tgl
            s.tanggal_hijriah = (data.tanggal_hijriah or "").strip() or teks_hijriah(tgl)
            s.penandatangan_nama, s.penandatangan_jabatan, s.penandatangan_nbm = \
                settings.DIREKTUR_NAMA, settings.DIREKTUR_JABATAN, settings.DIREKTUR_NBM
            s.status = "disetujui"
        else:
            s.status = "revisi" if data.aksi == "revisi" else "ditolak"
        s.catatan_admin = (data.catatan or "").strip() or None
        s.ditinjau_oleh, s.ditinjau_at = cu.nama, datetime.now()
        db.commit()
        pesan = {"disetujui": f"{s.jenis} Anda telah disetujui. Nomor: {s.nomor_surat}.",
                 "revisi": f"{s.jenis} perlu direvisi: {s.catatan_admin}",
                 "ditolak": f"{s.jenis} ditolak: {s.catatan_admin}"}[s.status]
        notify(s.mahasiswa_user_id, f"Surat {s.status}", pesan, "/mahasiswa/persuratan")
        audit(cu.id, f"Persuratan #{s.id} {s.nim}: {s.status}", "layanan")
        return s

    return r
