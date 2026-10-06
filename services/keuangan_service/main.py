from datetime import date, datetime, timedelta

from fastapi import APIRouter, Depends, File, Form, HTTPException, Query, UploadFile
from pydantic import BaseModel, Field
from sqlalchemy import Date, DateTime, Integer, String, func, or_
from sqlalchemy.orm import Mapped, Session, mapped_column

from services.common.auth import CurrentUser, get_current_user, internal_only, require_roles
from services.common.config import settings
from services.common.db import Base, make_session_factory
from services.common.files import mount_files, save_upload
from services.common.http import audit, call, notify, notify_role
from services.common.utils import Msg, Page, create_service

engine, SessionLocal, get_db = make_session_factory("keuangan")
STATUS = ("belum bayar", "menunggu verifikasi", "lunas", "ditolak")
JENIS = ("SPP", "Biaya Ujian Tesis", "Biaya Seminar Proposal", "Biaya Wisuda", "Denda", "Lainnya")


class Tagihan(Base):
    __tablename__ = "tagihan"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    mahasiswa_id: Mapped[int] = mapped_column(Integer, index=True)
    mahasiswa_user_id: Mapped[int] = mapped_column(Integer, index=True)
    mahasiswa_nama: Mapped[str] = mapped_column(String(150))
    nim: Mapped[str] = mapped_column(String(20), index=True)
    tahun_akademik_id: Mapped[int | None] = mapped_column(Integer, nullable=True)
    tahun_akademik: Mapped[str | None] = mapped_column(String(30), nullable=True)
    jenis: Mapped[str] = mapped_column(String(60), default="SPP")
    jumlah: Mapped[int] = mapped_column(Integer)
    jatuh_tempo: Mapped[date | None] = mapped_column(Date, nullable=True)
    status: Mapped[str] = mapped_column(String(25), default="belum bayar", index=True)
    bukti_bayar: Mapped[str | None] = mapped_column(String(255), nullable=True)
    tanggal_bayar: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    diverifikasi_oleh: Mapped[int | None] = mapped_column(Integer, nullable=True)
    catatan: Mapped[str | None] = mapped_column(String(255), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.now)


class TagihanOut(BaseModel):
    id: int
    mahasiswa_id: int
    mahasiswa_nama: str
    nim: str
    tahun_akademik_id: int | None
    tahun_akademik: str | None
    jenis: str
    jumlah: int
    jatuh_tempo: date | None
    status: str
    bukti_bayar: str | None
    tanggal_bayar: datetime | None
    catatan: str | None
    created_at: datetime
    terlambat: bool = False
    model_config = {"from_attributes": True}


class TagihanIn(BaseModel):
    mahasiswa_id: int
    tahun_akademik_id: int | None = None
    jenis: str = "SPP"
    jumlah: int = Field(ge=0)
    jatuh_tempo: date | None = None
    catatan: str | None = None


class GenerateIn(BaseModel):
    tahun_akademik_id: int
    jatuh_tempo: date | None = None


class TolakIn(BaseModel):
    catatan: str = "Bukti pembayaran tidak valid"


def _out(t: Tagihan) -> TagihanOut:
    o = TagihanOut.model_validate(t)
    o.terlambat = bool(t.jatuh_tempo and t.jatuh_tempo < date.today() and t.status != "lunas")
    return o


app = create_service("Keuangan Service", "Tagihan SPP & biaya lain, unggah bukti pembayaran, verifikasi, dan rekap keuangan.")
Base.metadata.create_all(engine)
mount_files(app)

mhs = APIRouter(prefix="/keuangan/saya", tags=["Mahasiswa"])
adm = APIRouter(prefix="/keuangan", tags=["Admin"])
internal = APIRouter(prefix="/internal", tags=["Internal"], dependencies=[Depends(internal_only)])
admin = Depends(require_roles("admin"))


def _mhs(cu: CurrentUser = Depends(require_roles("mahasiswa"))):
    return call(settings.AKADEMIK_URL, "GET", f"/internal/mahasiswa/by-user/{cu.id}")


# ------------------------------ Mahasiswa ------------------------------- #
@mhs.get("", response_model=list[TagihanOut])
def tagihan_saya(x: dict = Depends(_mhs), db: Session = Depends(get_db)):
    return [_out(t) for t in db.query(Tagihan).filter_by(mahasiswa_id=x["id"]).order_by(Tagihan.created_at.desc())]


@mhs.get("/ringkasan")
def ringkasan_saya(x: dict = Depends(_mhs), db: Session = Depends(get_db)):
    rows = db.query(Tagihan).filter_by(mahasiswa_id=x["id"]).all()
    return {"lunas": sum(t.jumlah for t in rows if t.status == "lunas"),
            "belum": sum(t.jumlah for t in rows if t.status != "lunas"),
            "jumlah_belum": sum(1 for t in rows if t.status in ("belum bayar", "ditolak")),
            "rekening": "Bank Syariah Indonesia 7000-123-456 a.n. Program Pascasarjana Unismuh Makassar"}


@mhs.post("/{tid}/bayar", response_model=TagihanOut, summary="Unggah bukti pembayaran (multipart)")
def bayar(tid: int, bukti: UploadFile = File(...), catatan: str = Form(""), x: dict = Depends(_mhs),
          db: Session = Depends(get_db)):
    t = db.get(Tagihan, tid)
    if not t or t.mahasiswa_id != x["id"]:
        raise HTTPException(404, "Tagihan tidak ditemukan")
    if t.status == "lunas":
        raise HTTPException(400, "Tagihan sudah lunas")
    t.bukti_bayar = save_upload(bukti, "bukti_bayar")
    t.tanggal_bayar, t.status, t.catatan = datetime.now(), "menunggu verifikasi", catatan
    db.commit()
    notify_role("admin", "Konfirmasi pembayaran", f"{t.mahasiswa_nama} mengunggah bukti {t.jenis}.",
                "/admin/keuangan?status=menunggu verifikasi")
    audit(x["user_id"], f"Mengunggah bukti pembayaran tagihan #{t.id}", "keuangan")
    return _out(t)


# -------------------------------- Admin --------------------------------- #
@adm.get("", response_model=Page[TagihanOut], dependencies=[admin])
def list_tagihan(status: str | None = None, q: str | None = None, tahun_akademik_id: int | None = None,
                 page: int = Query(1, ge=1), per_page: int = Query(25, ge=1, le=200), db: Session = Depends(get_db)):
    qry = db.query(Tagihan)
    if status:
        qry = qry.filter(Tagihan.status == status)
    if tahun_akademik_id:
        qry = qry.filter(Tagihan.tahun_akademik_id == tahun_akademik_id)
    if q:
        qry = qry.filter(or_(Tagihan.mahasiswa_nama.ilike(f"%{q}%"), Tagihan.nim.ilike(f"%{q}%")))
    total = qry.count()
    items = qry.order_by(Tagihan.created_at.desc()).offset((page - 1) * per_page).limit(per_page).all()
    return Page[TagihanOut](items=[_out(t) for t in items], total=total, page=page, per_page=per_page,
                            pages=max(1, -(-total // per_page)))


@adm.get("/ringkasan", dependencies=[admin], summary="Total per status")
def ringkasan(db: Session = Depends(get_db)):
    rows = db.query(Tagihan.status, func.coalesce(func.sum(Tagihan.jumlah), 0), func.count(Tagihan.id)) \
        .group_by(Tagihan.status).all()
    return {s: {"total": int(j), "jumlah": n} for s, j, n in rows}


@adm.post("", response_model=TagihanOut, status_code=201, summary="Tagihan manual")
def tambah(data: TagihanIn, cu: CurrentUser = admin, db: Session = Depends(get_db)):
    x = call(settings.AKADEMIK_URL, "GET", f"/internal/mahasiswa/{data.mahasiswa_id}")
    ta = call(settings.AKADEMIK_URL, "GET", f"/internal/tahun-akademik/{data.tahun_akademik_id}") if data.tahun_akademik_id else None
    t = Tagihan(mahasiswa_id=x["id"], mahasiswa_user_id=x["user_id"], mahasiswa_nama=x["nama"], nim=x["nim"],
                tahun_akademik_id=ta["id"] if ta else None, tahun_akademik=ta["nama"] if ta else None,
                jenis=data.jenis, jumlah=data.jumlah, jatuh_tempo=data.jatuh_tempo, catatan=data.catatan)
    db.add(t)
    db.commit()
    notify(x["user_id"], "Tagihan baru", f"Tagihan {t.jenis} telah diterbitkan.", "/mahasiswa/keuangan")
    audit(cu.id, f"Menambah tagihan {t.jenis} untuk {t.nim}", "keuangan")
    return _out(t)


@adm.post("/generate", response_model=Msg, summary="Generate SPP massal untuk mahasiswa aktif")
def generate(data: GenerateIn, cu: CurrentUser = admin, db: Session = Depends(get_db)):
    ta = call(settings.AKADEMIK_URL, "GET", f"/internal/tahun-akademik/{data.tahun_akademik_id}")
    jatuh_tempo = data.jatuh_tempo or (date.today() + timedelta(days=30))
    n = 0
    for x in call(settings.AKADEMIK_URL, "GET", "/internal/mahasiswa", params={"status": "aktif"}):
        if db.query(Tagihan).filter_by(mahasiswa_id=x["id"], tahun_akademik_id=ta["id"], jenis="SPP").first():
            continue
        biaya = call(settings.AKADEMIK_URL, "GET", f"/internal/mahasiswa/{x['id']}/biaya")["biaya_semester"]
        db.add(Tagihan(mahasiswa_id=x["id"], mahasiswa_user_id=x["user_id"], mahasiswa_nama=x["nama"], nim=x["nim"],
                       tahun_akademik_id=ta["id"], tahun_akademik=ta["nama"], jenis="SPP", jumlah=biaya,
                       jatuh_tempo=jatuh_tempo))
        notify(x["user_id"], "Tagihan SPP baru", f"Tagihan SPP {ta['nama']} telah diterbitkan.", "/mahasiswa/keuangan")
        n += 1
    db.commit()
    audit(cu.id, f"Generate {n} tagihan SPP {ta['nama']}", "keuangan")
    return Msg(detail=f"{n} tagihan SPP diterbitkan")


@adm.post("/{tid}/verifikasi", response_model=TagihanOut)
def verifikasi(tid: int, cu: CurrentUser = admin, db: Session = Depends(get_db)):
    t = db.get(Tagihan, tid)
    if not t:
        raise HTTPException(404, "Tagihan tidak ditemukan")
    t.status, t.diverifikasi_oleh = "lunas", cu.id
    if not t.tanggal_bayar:
        t.tanggal_bayar = datetime.now()
    db.commit()
    notify(t.mahasiswa_user_id, "Pembayaran diverifikasi", f"Pembayaran {t.jenis} sebesar Rp {t.jumlah:,} telah lunas.",
           "/mahasiswa/keuangan")
    audit(cu.id, f"Verifikasi tagihan #{t.id} {t.nim}", "keuangan")
    return _out(t)


@adm.post("/{tid}/tolak", response_model=TagihanOut)
def tolak(tid: int, data: TolakIn, cu: CurrentUser = admin, db: Session = Depends(get_db)):
    t = db.get(Tagihan, tid)
    if not t:
        raise HTTPException(404, "Tagihan tidak ditemukan")
    t.status, t.catatan = "ditolak", data.catatan
    db.commit()
    notify(t.mahasiswa_user_id, "Pembayaran ditolak", f"{t.jenis}: {t.catatan}", "/mahasiswa/keuangan")
    audit(cu.id, f"Menolak pembayaran tagihan #{t.id} {t.nim}", "keuangan")
    return _out(t)


@adm.delete("/{tid}", response_model=Msg, dependencies=[admin])
def hapus(tid: int, db: Session = Depends(get_db)):
    t = db.get(Tagihan, tid)
    if not t:
        raise HTTPException(404, "Tagihan tidak ditemukan")
    if t.status == "lunas":
        raise HTTPException(400, "Tagihan lunas tidak dapat dihapus")
    db.delete(t)
    db.commit()
    return Msg(detail="Tagihan dihapus")


# ------------------------------- Internal ------------------------------- #
@internal.get("/tunggakan/{mid}")
def tunggakan(mid: int, db: Session = Depends(get_db)):
    rows = db.query(Tagihan).filter(Tagihan.mahasiswa_id == mid, Tagihan.status.in_(["belum bayar", "ditolak"])).all()
    return {"mahasiswa_id": mid, "jumlah": sum(t.jumlah for t in rows), "item": len(rows)}


@internal.get("/ringkasan")
def i_ringkasan(db: Session = Depends(get_db)):
    return ringkasan(db)


for r in (mhs, adm, internal):
    app.include_router(r)
