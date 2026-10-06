"""Data master: program studi, tahun akademik, mata kuliah, kalender akademik."""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from services.common.auth import CurrentUser, require_roles
from services.common.http import audit
from services.common.utils import Msg

from . import models as m
from . import schemas as s
from .deps import get_db, get_or_404, ta_aktif
from .serializers import kalender_out, mk_out, prodi_out, ta_out

admin = Depends(require_roles("admin"))

prodi = APIRouter(prefix="/prodi", tags=["Program Studi"])
ta = APIRouter(prefix="/tahun-akademik", tags=["Tahun Akademik"])
mk = APIRouter(prefix="/matakuliah", tags=["Mata Kuliah"])
kal = APIRouter(prefix="/kalender", tags=["Kalender Akademik"])


# ------------------------------ Prodi ----------------------------------- #
@prodi.get("", response_model=list[s.ProdiOut], summary="Daftar prodi (publik)")
def list_prodi(db: Session = Depends(get_db)):
    return [prodi_out(p, db) for p in db.query(m.ProgramStudi).order_by(m.ProgramStudi.jenjang, m.ProgramStudi.nama)]


@prodi.get("/{pid}", response_model=s.ProdiOut)
def get_prodi(pid: int, db: Session = Depends(get_db)):
    return prodi_out(get_or_404(db, m.ProgramStudi, pid, "Prodi"), db)


@prodi.get("/{pid}/kurikulum", response_model=list[s.MKOut], summary="Kurikulum prodi (publik)")
def kurikulum(pid: int, db: Session = Depends(get_db)):
    p = get_or_404(db, m.ProgramStudi, pid, "Prodi")
    return [mk_out(x) for x in p.matakuliah.order_by(m.MataKuliah.semester_ke, m.MataKuliah.kode)]


@prodi.post("", response_model=s.ProdiOut, status_code=201)
def create_prodi(data: s.ProdiIn, cu: CurrentUser = admin, db: Session = Depends(get_db)):
    if db.query(m.ProgramStudi).filter(m.ProgramStudi.kode == data.kode.upper()).first():
        raise HTTPException(409, "Kode prodi sudah ada")
    p = m.ProgramStudi(**data.model_dump())
    p.kode = p.kode.upper()
    db.add(p)
    db.commit()
    audit(cu.id, f"Menambah prodi {p.kode}", "akademik")
    return prodi_out(p, db)


@prodi.put("/{pid}", response_model=s.ProdiOut)
def update_prodi(pid: int, data: s.ProdiIn, cu: CurrentUser = admin, db: Session = Depends(get_db)):
    p = get_or_404(db, m.ProgramStudi, pid, "Prodi")
    for k, v in data.model_dump().items():
        setattr(p, k, v)
    p.kode = p.kode.upper()
    db.commit()
    audit(cu.id, f"Mengubah prodi {p.kode}", "akademik")
    return prodi_out(p, db)


@prodi.delete("/{pid}", response_model=Msg)
def delete_prodi(pid: int, cu: CurrentUser = admin, db: Session = Depends(get_db)):
    p = get_or_404(db, m.ProgramStudi, pid, "Prodi")
    if p.mahasiswa.count() or p.matakuliah.count():
        raise HTTPException(400, "Prodi masih memiliki mahasiswa/mata kuliah")
    db.delete(p)
    db.commit()
    return Msg(detail="Prodi dihapus")


# -------------------------- Tahun Akademik ------------------------------ #
@ta.get("", response_model=list[s.TAOut])
def list_ta(db: Session = Depends(get_db)):
    return [ta_out(t) for t in db.query(m.TahunAkademik).order_by(m.TahunAkademik.tahun_mulai.desc(), m.TahunAkademik.semester)]


@ta.get("/aktif", response_model=s.TAOut | None)
def get_aktif(db: Session = Depends(get_db)):
    t = ta_aktif(db)
    return ta_out(t) if t else None


@ta.post("", response_model=s.TAOut, status_code=201, dependencies=[admin])
def create_ta(data: s.TAIn, db: Session = Depends(get_db)):
    if db.query(m.TahunAkademik).filter_by(tahun_mulai=data.tahun_mulai, semester=data.semester).first():
        raise HTTPException(409, "Tahun akademik sudah ada")
    t = m.TahunAkademik(**data.model_dump())
    db.add(t)
    db.commit()
    return ta_out(t)


@ta.post("/{tid}/aktifkan", response_model=s.TAOut)
def aktifkan(tid: int, cu: CurrentUser = admin, db: Session = Depends(get_db)):
    t = get_or_404(db, m.TahunAkademik, tid, "Tahun akademik")
    db.query(m.TahunAkademik).update({"aktif": False})
    t.aktif = True
    db.commit()
    audit(cu.id, f"Mengaktifkan TA {t.nama}", "akademik")
    return ta_out(t)


@ta.post("/{tid}/toggle-krs", response_model=s.TAOut, dependencies=[admin])
def toggle_krs(tid: int, db: Session = Depends(get_db)):
    t = get_or_404(db, m.TahunAkademik, tid, "Tahun akademik")
    t.krs_dibuka = not t.krs_dibuka
    db.commit()
    return ta_out(t)


# ---------------------------- Mata Kuliah ------------------------------- #
@mk.get("", response_model=list[s.MKOut])
def list_mk(prodi_id: int | None = None, db: Session = Depends(get_db)):
    q = db.query(m.MataKuliah)
    if prodi_id:
        q = q.filter(m.MataKuliah.prodi_id == prodi_id)
    return [mk_out(x) for x in q.order_by(m.MataKuliah.prodi_id, m.MataKuliah.semester_ke, m.MataKuliah.kode)]


@mk.post("", response_model=s.MKOut, status_code=201, dependencies=[admin])
def create_mk(data: s.MKIn, db: Session = Depends(get_db)):
    if db.query(m.MataKuliah).filter(m.MataKuliah.kode == data.kode.upper()).first():
        raise HTTPException(409, "Kode mata kuliah sudah ada")
    get_or_404(db, m.ProgramStudi, data.prodi_id, "Prodi")
    x = m.MataKuliah(**data.model_dump())
    x.kode = x.kode.upper()
    db.add(x)
    db.commit()
    return mk_out(x)


@mk.put("/{mid}", response_model=s.MKOut, dependencies=[admin])
def update_mk(mid: int, data: s.MKIn, db: Session = Depends(get_db)):
    x = get_or_404(db, m.MataKuliah, mid, "Mata kuliah")
    for k, v in data.model_dump().items():
        setattr(x, k, v)
    db.commit()
    return mk_out(x)


@mk.delete("/{mid}", response_model=Msg, dependencies=[admin])
def delete_mk(mid: int, db: Session = Depends(get_db)):
    x = get_or_404(db, m.MataKuliah, mid, "Mata kuliah")
    if x.kelas.count():
        raise HTTPException(400, "Mata kuliah sudah memiliki kelas")
    db.delete(x)
    db.commit()
    return Msg(detail="Mata kuliah dihapus")


# ------------------------------ Kalender -------------------------------- #
@kal.get("", response_model=list[s.KalenderOut], summary="Kalender akademik (publik)")
def list_kalender(tahun_akademik_id: int | None = None, mendatang: bool = False, db: Session = Depends(get_db)):
    from datetime import date
    ta_id = tahun_akademik_id or (ta_aktif(db).id if ta_aktif(db) else None)
    q = db.query(m.KalenderAkademik).filter(m.KalenderAkademik.tahun_akademik_id == ta_id)
    if mendatang:
        q = q.filter(m.KalenderAkademik.tanggal_mulai >= date.today())
    return [kalender_out(k) for k in q.order_by(m.KalenderAkademik.tanggal_mulai)]


@kal.post("", response_model=s.KalenderOut, status_code=201, dependencies=[admin])
def create_kalender(data: s.KalenderIn, db: Session = Depends(get_db)):
    get_or_404(db, m.TahunAkademik, data.tahun_akademik_id, "Tahun akademik")
    k = m.KalenderAkademik(**data.model_dump())
    db.add(k)
    db.commit()
    return kalender_out(k)


@kal.delete("/{kid}", response_model=Msg, dependencies=[admin])
def delete_kalender(kid: int, db: Session = Depends(get_db)):
    db.delete(get_or_404(db, m.KalenderAkademik, kid, "Kegiatan"))
    db.commit()
    return Msg(detail="Kegiatan dihapus")
