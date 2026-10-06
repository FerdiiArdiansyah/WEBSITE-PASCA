"""Dosen & mahasiswa: profil akademik yang terhubung ke akun di auth-service."""
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import or_
from sqlalchemy.orm import Session

from services.common.auth import CurrentUser, get_current_user, require_roles
from services.common.config import settings
from services.common.http import audit, call, safe_call
from services.common.utils import Msg, Page

from . import models as m
from . import schemas as s
from .deps import dosen_saya, get_db, get_or_404, mahasiswa_saya, ta_aktif
from .serializers import dosen_out, krs_out, mahasiswa_out

admin = Depends(require_roles("admin"))
dosen = APIRouter(prefix="/dosen", tags=["Dosen"])
mhs = APIRouter(prefix="/mahasiswa", tags=["Mahasiswa"])


def _buat_akun(username: str, email: str, nama: str, role: str, password: str | None, telepon: str | None):
    return call(settings.AUTH_URL, "POST", "/internal/users", json={
        "username": username, "email": email, "nama": nama, "role": role, "password": password, "telepon": telepon,
    })


def _sinkron_akun(user_id: int, nama: str, email: str):
    safe_call(settings.AUTH_URL, "PUT", f"/internal/users/{user_id}", json={"nama": nama, "email": email})


# ================================ DOSEN ================================= #
@dosen.get("", response_model=list[s.DosenOut], summary="Daftar dosen (publik ringkas, lengkap untuk login)")
def list_dosen(q: str | None = None, prodi_id: int | None = None, db: Session = Depends(get_db)):
    qry = db.query(m.Dosen)
    if q:
        qry = qry.filter(or_(m.Dosen.nama.ilike(f"%{q}%"), m.Dosen.nidn.ilike(f"%{q}%")))
    if prodi_id:
        qry = qry.filter(m.Dosen.prodi_id == prodi_id)
    return [dosen_out(d) for d in qry.order_by(m.Dosen.nama)]


@dosen.get("/me", response_model=s.DosenOut)
def dosen_me(d: m.Dosen = Depends(dosen_saya)):
    return dosen_out(d)


@dosen.get("/{did}", response_model=s.DosenOut)
def get_dosen(did: int, db: Session = Depends(get_db)):
    return dosen_out(get_or_404(db, m.Dosen, did, "Dosen"))


@dosen.post("", response_model=s.DosenOut, status_code=201)
def create_dosen(data: s.DosenCreate, cu: CurrentUser = admin, db: Session = Depends(get_db)):
    if db.query(m.Dosen).filter(m.Dosen.nidn == data.nidn).first():
        raise HTTPException(409, "NIDN sudah terdaftar")
    akun = _buat_akun(data.username or data.nidn, data.email, data.nama, "dosen", data.password, data.telepon)
    d = m.Dosen(user_id=akun["id"], **data.model_dump(exclude={"username", "password", "telepon"}))
    db.add(d)
    db.commit()
    audit(cu.id, f"Menambah dosen {d.nidn}", "akademik")
    return dosen_out(d)


@dosen.put("/me/profil", response_model=s.DosenOut, summary="Dosen memperbarui gelar & keahlian sendiri")
def update_dosen_me(gelar_depan: str | None = None, gelar_belakang: str | None = None,
                    bidang_keahlian: str | None = None, d: m.Dosen = Depends(dosen_saya), db: Session = Depends(get_db)):
    d.gelar_depan, d.gelar_belakang, d.bidang_keahlian = gelar_depan, gelar_belakang, bidang_keahlian
    db.commit()
    return dosen_out(d)


@dosen.put("/{did}", response_model=s.DosenOut)
def update_dosen(did: int, data: s.DosenBase, cu: CurrentUser = admin, db: Session = Depends(get_db)):
    d = get_or_404(db, m.Dosen, did, "Dosen")
    for k, v in data.model_dump(exclude={"telepon"}).items():
        setattr(d, k, v)
    db.commit()
    _sinkron_akun(d.user_id, d.nama, d.email)
    audit(cu.id, f"Mengubah dosen {d.nidn}", "akademik")
    return dosen_out(d)


@dosen.delete("/{did}", response_model=Msg)
def delete_dosen(did: int, cu: CurrentUser = admin, db: Session = Depends(get_db)):
    d = get_or_404(db, m.Dosen, did, "Dosen")
    if d.kelas.count() or d.mahasiswa_pa.count():
        raise HTTPException(400, "Dosen masih memiliki kelas/mahasiswa PA")
    safe_call(settings.AUTH_URL, "DELETE", f"/internal/users/{d.user_id}")
    db.delete(d)
    db.commit()
    audit(cu.id, f"Menghapus dosen {d.nidn}", "akademik")
    return Msg(detail="Dosen dihapus")


# ============================== MAHASISWA =============================== #
@mhs.get("", response_model=Page[s.MahasiswaOut], dependencies=[Depends(require_roles("admin", "dosen"))])
def list_mahasiswa(q: str | None = None, prodi_id: int | None = None, status: str | None = None,
                   angkatan: int | None = None, dosen_pa_id: int | None = None,
                   page: int = Query(1, ge=1), per_page: int = Query(20, ge=1, le=200), db: Session = Depends(get_db)):
    qry = db.query(m.Mahasiswa)
    if q:
        qry = qry.filter(or_(m.Mahasiswa.nama.ilike(f"%{q}%"), m.Mahasiswa.nim.ilike(f"%{q}%")))
    if prodi_id:
        qry = qry.filter(m.Mahasiswa.prodi_id == prodi_id)
    if status:
        qry = qry.filter(m.Mahasiswa.status == status)
    if angkatan:
        qry = qry.filter(m.Mahasiswa.angkatan == angkatan)
    if dosen_pa_id:
        qry = qry.filter(m.Mahasiswa.dosen_pa_id == dosen_pa_id)
    total = qry.count()
    ta = ta_aktif(db)
    items = qry.order_by(m.Mahasiswa.angkatan.desc(), m.Mahasiswa.nim).offset((page - 1) * per_page).limit(per_page).all()
    return Page[s.MahasiswaOut](items=[mahasiswa_out(x, ta) for x in items], total=total, page=page,
                                per_page=per_page, pages=max(1, -(-total // per_page)))


@mhs.get("/me", response_model=s.MahasiswaOut)
def mahasiswa_me(x: m.Mahasiswa = Depends(mahasiswa_saya), db: Session = Depends(get_db)):
    return mahasiswa_out(x, ta_aktif(db))


@mhs.get("/me/ringkasan", summary="Ringkasan dashboard mahasiswa")
def ringkasan_me(x: m.Mahasiswa = Depends(mahasiswa_saya), db: Session = Depends(get_db)):
    from .deps import ta_aktif as _ta
    from datetime import date
    ta = _ta(db)
    krs_aktif = [k for k in x.krs.join(m.Kelas).filter(m.Kelas.tahun_akademik_id == ta.id)] if ta else []
    hari = ["Senin", "Selasa", "Rabu", "Kamis", "Jumat", "Sabtu", "Minggu"][date.today().weekday()]
    jadwal = sorted([krs_out(k) for k in krs_aktif if k.status == "disetujui" and k.kelas.hari == hari],
                    key=lambda k: k.jam_mulai or "")
    semua_ta = {k.kelas.tahun_akademik for k in x.krs_lulus()}
    return {
        "mahasiswa": mahasiswa_out(x, ta),
        "tahun_akademik": ta.nama if ta else None,
        "sks_semester": sum(k.kelas.matakuliah.sks for k in krs_aktif if k.status != "ditolak"),
        "krs_disetujui": sum(1 for k in krs_aktif if k.status == "disetujui"),
        "krs_total": len(krs_aktif),
        "jadwal_hari_ini": jadwal,
        "ips_per_semester": sorted([{"tahun_akademik": t.nama, "ips": x.ips(t.id)} for t in semua_ta],
                                   key=lambda r: r["tahun_akademik"]),
    }


@mhs.get("/{mid}", response_model=s.MahasiswaOut)
def get_mahasiswa(mid: int, cu: CurrentUser = Depends(get_current_user), db: Session = Depends(get_db)):
    x = get_or_404(db, m.Mahasiswa, mid, "Mahasiswa")
    if cu.role == "mahasiswa" and x.user_id != cu.id:
        raise HTTPException(403, "Akses ditolak")
    if cu.role == "dosen":
        d = db.query(m.Dosen).filter(m.Dosen.user_id == cu.id).first()
        diampu = {k.mahasiswa_id for kls in d.kelas for k in kls.peserta} if d else set()
        if not d or (x.dosen_pa_id != d.id and x.id not in diampu):
            raise HTTPException(403, "Mahasiswa bukan bimbingan/peserta kelas Anda")
    return mahasiswa_out(x, ta_aktif(db))


@mhs.get("/{mid}/riwayat", response_model=list[s.KRSOut], summary="Riwayat KRS & nilai (admin/PA/mahasiswa ybs)")
def riwayat(mid: int, cu: CurrentUser = Depends(get_current_user), db: Session = Depends(get_db)):
    get_mahasiswa(mid, cu, db)
    x = db.get(m.Mahasiswa, mid)
    return [krs_out(k) for k in x.krs.join(m.Kelas).join(m.TahunAkademik)
            .order_by(m.TahunAkademik.tahun_mulai, m.TahunAkademik.semester)]


@mhs.post("", response_model=s.MahasiswaOut, status_code=201)
def create_mahasiswa(data: s.MahasiswaCreate, cu: CurrentUser = admin, db: Session = Depends(get_db)):
    if db.query(m.Mahasiswa).filter(m.Mahasiswa.nim == data.nim).first():
        raise HTTPException(409, "NIM sudah terdaftar")
    get_or_404(db, m.ProgramStudi, data.prodi_id, "Prodi")
    akun = _buat_akun(data.nim, data.email, data.nama, "mahasiswa", data.password, data.telepon)
    x = m.Mahasiswa(user_id=akun["id"], **data.model_dump(exclude={"password", "telepon"}))
    db.add(x)
    db.commit()
    audit(cu.id, f"Menambah mahasiswa {x.nim}", "akademik")
    return mahasiswa_out(x, ta_aktif(db))


@mhs.put("/me/biodata", response_model=s.MahasiswaOut, summary="Mahasiswa memperbarui biodata sendiri")
def update_biodata(data: s.MahasiswaUpdate, x: m.Mahasiswa = Depends(mahasiswa_saya), db: Session = Depends(get_db)):
    boleh = {"tempat_lahir", "tanggal_lahir", "alamat", "pekerjaan", "jenis_kelamin"}
    for k, v in data.model_dump(exclude_none=True).items():
        if k in boleh:
            setattr(x, k, v)
    db.commit()
    return mahasiswa_out(x, ta_aktif(db))


@mhs.put("/{mid}", response_model=s.MahasiswaOut)
def update_mahasiswa(mid: int, data: s.MahasiswaUpdate, cu: CurrentUser = admin, db: Session = Depends(get_db)):
    x = get_or_404(db, m.Mahasiswa, mid, "Mahasiswa")
    for k, v in data.model_dump(exclude_none=True).items():
        setattr(x, k, v)
    db.commit()
    _sinkron_akun(x.user_id, x.nama, x.email)
    audit(cu.id, f"Mengubah mahasiswa {x.nim}", "akademik")
    return mahasiswa_out(x, ta_aktif(db))


@mhs.delete("/{mid}", response_model=Msg)
def delete_mahasiswa(mid: int, cu: CurrentUser = admin, db: Session = Depends(get_db)):
    x = get_or_404(db, m.Mahasiswa, mid, "Mahasiswa")
    safe_call(settings.AUTH_URL, "DELETE", f"/internal/users/{x.user_id}")
    db.delete(x)
    db.commit()
    audit(cu.id, f"Menghapus mahasiswa {x.nim}", "akademik")
    return Msg(detail="Mahasiswa dihapus")
