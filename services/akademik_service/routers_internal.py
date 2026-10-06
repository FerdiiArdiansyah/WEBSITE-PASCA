"""Endpoint internal (antar-service) dan laporan admin."""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import func
from sqlalchemy.orm import Session

from services.common.auth import internal_only, require_roles

from . import models as m
from . import schemas as s
from .deps import get_db, get_or_404, ta_aktif
from .serializers import dosen_out, kelas_out, mahasiswa_out, ta_out

internal = APIRouter(prefix="/internal", tags=["Internal"], dependencies=[Depends(internal_only)])
laporan = APIRouter(prefix="/laporan", tags=["Laporan (admin)"], dependencies=[Depends(require_roles("admin"))])


# ------------------------------ Internal -------------------------------- #
@internal.get("/mahasiswa", response_model=list[s.MahasiswaOut])
def i_list_mahasiswa(status: str | None = None, db: Session = Depends(get_db)):
    q = db.query(m.Mahasiswa)
    if status:
        q = q.filter(m.Mahasiswa.status == status)
    ta = ta_aktif(db)
    return [mahasiswa_out(x, ta) for x in q]


@internal.get("/mahasiswa/by-user/{user_id}", response_model=s.MahasiswaOut)
def i_mhs_by_user(user_id: int, db: Session = Depends(get_db)):
    x = db.query(m.Mahasiswa).filter(m.Mahasiswa.user_id == user_id).first()
    if not x:
        raise HTTPException(404, "Mahasiswa tidak ditemukan")
    return mahasiswa_out(x, ta_aktif(db))


@internal.get("/mahasiswa/{mid}", response_model=s.MahasiswaOut)
def i_get_mahasiswa(mid: int, db: Session = Depends(get_db)):
    return mahasiswa_out(get_or_404(db, m.Mahasiswa, mid, "Mahasiswa"), ta_aktif(db))


@internal.get("/mahasiswa/{mid}/biaya")
def i_biaya(mid: int, db: Session = Depends(get_db)):
    x = get_or_404(db, m.Mahasiswa, mid, "Mahasiswa")
    return {"mahasiswa_id": x.id, "user_id": x.user_id, "biaya_semester": x.prodi.biaya_semester}


@internal.patch("/mahasiswa/{mid}/status", response_model=s.MahasiswaOut)
def i_set_status(mid: int, status: str, db: Session = Depends(get_db)):
    x = get_or_404(db, m.Mahasiswa, mid, "Mahasiswa")
    if status not in m.STATUS_MAHASISWA:
        raise HTTPException(400, "Status tidak valid")
    x.status = status
    db.commit()
    return mahasiswa_out(x, ta_aktif(db))


@internal.post("/mahasiswa", response_model=s.MahasiswaOut, status_code=201,
               summary="Buat mahasiswa (dipakai layanan PMB)")
def i_create_mahasiswa(data: s.MahasiswaCreate, db: Session = Depends(get_db)):
    from .routers_orang import _buat_akun
    if db.query(m.Mahasiswa).filter(m.Mahasiswa.nim == data.nim).first():
        raise HTTPException(409, "NIM sudah terdaftar")
    akun = _buat_akun(data.nim, data.email, data.nama, "mahasiswa", data.password, data.telepon)
    x = m.Mahasiswa(user_id=akun["id"], **data.model_dump(exclude={"password", "telepon"}))
    db.add(x)
    db.commit()
    return mahasiswa_out(x, ta_aktif(db))


@internal.get("/mahasiswa/next-nim/{prodi_id}")
def i_next_nim(prodi_id: int, tahun: int, db: Session = Depends(get_db)):
    p = get_or_404(db, m.ProgramStudi, prodi_id, "Prodi")
    urut = db.query(m.Mahasiswa).filter_by(angkatan=tahun, prodi_id=prodi_id).count() + 1
    return {"nim": f"{tahun % 100:02d}{p.kode[:3].upper()}{urut:04d}"}


@internal.get("/dosen/by-user/{user_id}", response_model=s.DosenOut)
def i_dosen_by_user(user_id: int, db: Session = Depends(get_db)):
    d = db.query(m.Dosen).filter(m.Dosen.user_id == user_id).first()
    if not d:
        raise HTTPException(404, "Dosen tidak ditemukan")
    return dosen_out(d)


@internal.get("/dosen/{did}", response_model=s.DosenOut)
def i_get_dosen(did: int, db: Session = Depends(get_db)):
    return dosen_out(get_or_404(db, m.Dosen, did, "Dosen"))


@internal.get("/tahun-akademik/aktif", response_model=s.TAOut | None)
def i_ta_aktif(db: Session = Depends(get_db)):
    t = ta_aktif(db)
    return ta_out(t) if t else None


@internal.get("/tahun-akademik/{tid}", response_model=s.TAOut)
def i_ta(tid: int, db: Session = Depends(get_db)):
    return ta_out(get_or_404(db, m.TahunAkademik, tid, "Tahun akademik"))


@internal.get("/statistik-publik")
def i_statistik(db: Session = Depends(get_db)):
    return {"prodi": db.query(m.ProgramStudi).count(), "dosen": db.query(m.Dosen).count(),
            "mahasiswa": db.query(m.Mahasiswa).filter_by(status="aktif").count(),
            "alumni": db.query(m.Mahasiswa).filter_by(status="lulus").count()}


# ------------------------------- Laporan -------------------------------- #
@laporan.get("/ringkasan", summary="Statistik untuk dashboard admin")
def ringkasan(db: Session = Depends(get_db)):
    ta = ta_aktif(db)
    per_prodi = db.query(m.ProgramStudi.nama, func.count(m.Mahasiswa.id)) \
        .outerjoin(m.Mahasiswa, (m.Mahasiswa.prodi_id == m.ProgramStudi.id) & (m.Mahasiswa.status == "aktif")) \
        .group_by(m.ProgramStudi.id).all()
    per_angkatan = db.query(m.Mahasiswa.angkatan, func.count(m.Mahasiswa.id)).group_by(m.Mahasiswa.angkatan) \
        .order_by(m.Mahasiswa.angkatan).all()
    return {
        "tahun_akademik": ta_out(ta) if ta else None,
        "mahasiswa_aktif": db.query(m.Mahasiswa).filter_by(status="aktif").count(),
        "dosen": db.query(m.Dosen).count(),
        "kelas_aktif": db.query(m.Kelas).filter_by(tahun_akademik_id=ta.id).count() if ta else 0,
        "krs_menunggu": db.query(m.KRS).filter_by(status="diajukan").count(),
        "mahasiswa_per_prodi": [{"prodi": a, "jumlah": b} for a, b in per_prodi],
        "mahasiswa_per_angkatan": [{"angkatan": a, "jumlah": b} for a, b in per_angkatan],
    }


@laporan.get("/prodi", summary="Kinerja per program studi")
def laporan_prodi(db: Session = Depends(get_db)):
    hasil = []
    for p in db.query(m.ProgramStudi):
        aktif = p.mahasiswa.filter_by(status="aktif").all()
        ipk = [x.ipk for x in aktif if x.ipk > 0]
        hasil.append({"prodi": p.nama, "jenjang": p.jenjang, "aktif": len(aktif),
                      "lulus": p.mahasiswa.filter_by(status="lulus").count(),
                      "rata_ipk": round(sum(ipk) / len(ipk), 2) if ipk else 0})
    return hasil


@laporan.get("/distribusi-nilai")
def distribusi_nilai(db: Session = Depends(get_db)):
    rows = db.query(m.KRS.nilai_huruf, func.count(m.KRS.id)).filter(m.KRS.nilai_huruf.isnot(None)) \
        .group_by(m.KRS.nilai_huruf).all()
    return {h: n for h, n in rows}


@laporan.get("/progres-nilai", summary="Progres penilaian kelas pada TA aktif")
def progres_nilai(db: Session = Depends(get_db)):
    ta = ta_aktif(db)
    hasil = []
    if ta:
        for k in db.query(m.Kelas).filter_by(tahun_akademik_id=ta.id):
            peserta = list(k.peserta.filter(m.KRS.status == "disetujui"))
            nilai = [x.nilai_akhir for x in peserta if x.nilai_akhir is not None]
            hasil.append({"kelas": kelas_out(k), "peserta": len(peserta), "dinilai": len(nilai),
                          "rata": round(sum(nilai) / len(nilai), 2) if nilai else None})
    return hasil
