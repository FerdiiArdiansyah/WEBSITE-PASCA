"""Perkuliahan: kelas & jadwal, KRS, penilaian, presensi, perwalian."""
from datetime import date

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import true
from sqlalchemy.orm import Session

from services.common.auth import CurrentUser, get_current_user, require_roles
from services.common.config import settings
from services.common.http import audit, notify, safe_call
from services.common.utils import Msg

from . import models as m
from . import schemas as s
from .deps import dosen_saya, get_db, get_or_404, mahasiswa_saya, ta_aktif, ta_aktif_or_400
from .serializers import kelas_out, krs_out, pertemuan_out

admin = Depends(require_roles("admin"))
kelas = APIRouter(prefix="/kelas", tags=["Kelas & Jadwal"])
krs = APIRouter(prefix="/krs", tags=["KRS"])
nilai = APIRouter(prefix="/nilai", tags=["Nilai (KHS / Transkrip)"])
presensi = APIRouter(prefix="/presensi", tags=["Presensi"])
dosen = APIRouter(prefix="/dosen/me", tags=["Portal Dosen"])


def _hari_ini():
    return ["Senin", "Selasa", "Rabu", "Kamis", "Jumat", "Sabtu", "Minggu"][date.today().weekday()]


def _kelas_dosen(kid: int, d: m.Dosen, db: Session) -> m.Kelas:
    k = get_or_404(db, m.Kelas, kid, "Kelas")
    if k.dosen_id != d.id:
        raise HTTPException(403, "Bukan kelas yang Anda ampu")
    return k


# ================================ KELAS ================================= #
@kelas.get("", response_model=list[s.KelasOut])
def list_kelas(tahun_akademik_id: int | None = None, prodi_id: int | None = None, dosen_id: int | None = None,
               db: Session = Depends(get_db)):
    ta_id = tahun_akademik_id or (ta_aktif(db).id if ta_aktif(db) else None)
    q = db.query(m.Kelas).join(m.MataKuliah).filter(m.Kelas.tahun_akademik_id == ta_id)
    if prodi_id:
        q = q.filter(m.MataKuliah.prodi_id == prodi_id)
    if dosen_id:
        q = q.filter(m.Kelas.dosen_id == dosen_id)
    return [kelas_out(k) for k in q.order_by(m.MataKuliah.nama)]


@kelas.get("/{kid}", response_model=s.KelasOut)
def get_kelas(kid: int, db: Session = Depends(get_db)):
    return kelas_out(get_or_404(db, m.Kelas, kid, "Kelas"))


@kelas.get("/{kid}/peserta", response_model=list[s.KRSOut],
           dependencies=[Depends(require_roles("admin", "dosen"))])
def peserta_kelas(kid: int, cu: CurrentUser = Depends(get_current_user), db: Session = Depends(get_db)):
    k = get_or_404(db, m.Kelas, kid, "Kelas")
    if cu.role == "dosen" and k.dosen.user_id != cu.id:
        raise HTTPException(403, "Bukan kelas yang Anda ampu")
    return [krs_out(x, db) for x in k.peserta.filter(m.KRS.status != "ditolak").join(m.Mahasiswa).order_by(m.Mahasiswa.nim)]


@kelas.post("", response_model=s.KelasOut, status_code=201)
def create_kelas(data: s.KelasIn, cu: CurrentUser = admin, db: Session = Depends(get_db)):
    return _simpan_kelas(m.Kelas(), data, cu, db, 201)


@kelas.put("/{kid}", response_model=s.KelasOut)
def update_kelas(kid: int, data: s.KelasIn, cu: CurrentUser = admin, db: Session = Depends(get_db)):
    return _simpan_kelas(get_or_404(db, m.Kelas, kid, "Kelas"), data, cu, db)


def _simpan_kelas(k: m.Kelas, data: s.KelasIn, cu, db, code=200):
    get_or_404(db, m.MataKuliah, data.matakuliah_id, "Mata kuliah")
    get_or_404(db, m.TahunAkademik, data.tahun_akademik_id, "Tahun akademik")
    get_or_404(db, m.Dosen, data.dosen_id, "Dosen")
    bentrok = db.query(m.Kelas).filter(m.Kelas.id != (k.id or 0), m.Kelas.dosen_id == data.dosen_id,
                                       m.Kelas.tahun_akademik_id == data.tahun_akademik_id,
                                       m.Kelas.hari == data.hari, m.Kelas.jam_mulai == data.jam_mulai).first()
    if bentrok and data.hari:
        raise HTTPException(409, f"Jadwal bentrok dengan kelas {bentrok.nama} untuk dosen yang sama")
    for key, v in data.model_dump().items():
        setattr(k, key, v)
    k.nama_kelas = k.nama_kelas.upper()
    if not k.id:
        db.add(k)
    db.commit()
    audit(cu.id, f"Menyimpan kelas {k.nama}", "akademik")
    return kelas_out(k)


@kelas.post("/{kid}/kunci-nilai", response_model=s.KelasOut, dependencies=[admin])
def kunci_nilai(kid: int, db: Session = Depends(get_db)):
    k = get_or_404(db, m.Kelas, kid, "Kelas")
    k.nilai_terkunci = not k.nilai_terkunci
    db.commit()
    return kelas_out(k)


@kelas.delete("/{kid}", response_model=Msg, dependencies=[admin])
def delete_kelas(kid: int, db: Session = Depends(get_db)):
    db.delete(get_or_404(db, m.Kelas, kid, "Kelas"))
    db.commit()
    return Msg(detail="Kelas dihapus")


# ================================= KRS ================================== #
@krs.get("/saya", response_model=list[s.KRSOut], summary="KRS mahasiswa pada TA aktif")
def krs_saya(x: m.Mahasiswa = Depends(mahasiswa_saya), db: Session = Depends(get_db)):
    ta = ta_aktif(db)
    if not ta:
        return []
    return [krs_out(k) for k in x.krs.join(m.Kelas).filter(m.Kelas.tahun_akademik_id == ta.id)]


@krs.get("/tersedia", response_model=list[s.KelasOut], summary="Kelas yang dapat diambil mahasiswa")
def krs_tersedia(x: m.Mahasiswa = Depends(mahasiswa_saya), db: Session = Depends(get_db)):
    ta = ta_aktif(db)
    if not ta:
        return []
    diambil = {k.kelas_id for k in x.krs}
    lulus = {k.kelas.matakuliah_id for k in x.krs_lulus() if k.bobot >= 3.0}
    q = (db.query(m.Kelas).join(m.MataKuliah)
         .filter(m.Kelas.tahun_akademik_id == ta.id, m.MataKuliah.prodi_id == x.prodi_id,
                 m.Kelas.id.notin_(diambil) if diambil else true()))
    return [kelas_out(k) for k in q.order_by(m.MataKuliah.semester_ke, m.MataKuliah.nama) if k.matakuliah_id not in lulus]


@krs.post("", response_model=s.KRSOut, status_code=201, summary="Mahasiswa mengajukan kelas")
def ambil_krs(data: s.KRSAmbil, x: m.Mahasiswa = Depends(mahasiswa_saya), db: Session = Depends(get_db)):
    ta = ta_aktif_or_400(db)
    k = get_or_404(db, m.Kelas, data.kelas_id, "Kelas")
    if k.tahun_akademik_id != ta.id or not ta.krs_dibuka:
        raise HTTPException(400, "Periode KRS tidak dibuka")
    if x.status != "aktif":
        raise HTTPException(400, "Status mahasiswa tidak aktif")
    if k.kuota - k.jumlah_peserta <= 0:
        raise HTTPException(400, "Kuota kelas penuh")
    if db.query(m.KRS).filter_by(mahasiswa_id=x.id, kelas_id=k.id).first():
        raise HTTPException(409, "Kelas sudah diambil")
    aktif = [r for r in x.krs.join(m.Kelas).filter(m.Kelas.tahun_akademik_id == ta.id) if r.status != "ditolak"]
    if sum(r.kelas.matakuliah.sks for r in aktif) + k.matakuliah.sks > settings.MAKS_SKS:
        raise HTTPException(400, f"Melebihi batas maksimal {settings.MAKS_SKS} SKS")
    for r in aktif:
        if r.kelas.hari == k.hari and r.kelas.jam_mulai == k.jam_mulai and k.hari:
            raise HTTPException(409, f"Jadwal bentrok dengan {r.kelas.nama}")
    tunggakan = safe_call(settings.KEUANGAN_URL, "GET", f"/internal/tunggakan/{x.id}")
    if tunggakan and tunggakan.get("jumlah", 0) > 0:
        raise HTTPException(400, "Anda memiliki tagihan belum lunas. Selesaikan pembayaran terlebih dahulu.")
    r = m.KRS(mahasiswa_id=x.id, kelas_id=k.id)
    db.add(r)
    db.commit()
    if x.dosen_pa:
        notify(x.dosen_pa.user_id, "Pengajuan KRS", f"{x.nama} mengajukan {k.nama}.", "/dosen/perwalian")
    audit(x.user_id, f"Mengajukan KRS {k.nama}", "akademik")
    return krs_out(r)


@krs.delete("/{rid}", response_model=Msg, summary="Mahasiswa membatalkan pengajuan")
def batal_krs(rid: int, x: m.Mahasiswa = Depends(mahasiswa_saya), db: Session = Depends(get_db)):
    r = get_or_404(db, m.KRS, rid, "KRS")
    if r.mahasiswa_id != x.id:
        raise HTTPException(403, "Akses ditolak")
    if r.nilai_akhir is not None:
        raise HTTPException(400, "KRS yang sudah dinilai tidak dapat dibatalkan")
    if not r.kelas.tahun_akademik.krs_dibuka:
        raise HTTPException(400, "Periode KRS sudah ditutup")
    db.delete(r)
    db.commit()
    return Msg(detail="Pengajuan dibatalkan")


@krs.get("", response_model=list[s.KRSOut], dependencies=[admin], summary="Daftar KRS untuk verifikasi (admin)")
def list_krs(status: str | None = "diajukan", tahun_akademik_id: int | None = None, db: Session = Depends(get_db)):
    ta_id = tahun_akademik_id or (ta_aktif(db).id if ta_aktif(db) else None)
    q = db.query(m.KRS).join(m.Kelas).filter(m.Kelas.tahun_akademik_id == ta_id)
    if status:
        q = q.filter(m.KRS.status == status)
    return [krs_out(r) for r in q.order_by(m.KRS.created_at.desc())]


@krs.post("/{rid}/{aksi}", response_model=s.KRSOut, summary="Setujui/tolak KRS (admin atau dosen PA)")
def aksi_krs(rid: int, aksi: str, data: s.KRSAksi | None = None,
             cu: CurrentUser = Depends(require_roles("admin", "dosen")), db: Session = Depends(get_db)):
    if aksi not in ("setujui", "tolak"):
        raise HTTPException(400, "Aksi harus 'setujui' atau 'tolak'")
    r = get_or_404(db, m.KRS, rid, "KRS")
    if cu.role == "dosen":
        d = db.query(m.Dosen).filter(m.Dosen.user_id == cu.id).first()
        if not d or r.mahasiswa.dosen_pa_id != d.id:
            raise HTTPException(403, "Anda bukan dosen PA mahasiswa ini")
    r.status = "disetujui" if aksi == "setujui" else "ditolak"
    r.catatan = data.catatan if data else None
    db.commit()
    notify(r.mahasiswa.user_id, f"KRS {r.status}", f"{r.kelas.nama}: {r.status}.", "/mahasiswa/krs")
    audit(cu.id, f"KRS {r.mahasiswa.nim} - {r.kelas.nama}: {r.status}", "akademik")
    return krs_out(r)


@krs.post("/setujui-semua", response_model=Msg, summary="Setujui seluruh KRS diajukan pada TA aktif")
def setujui_semua(cu: CurrentUser = admin, db: Session = Depends(get_db)):
    ta = ta_aktif_or_400(db)
    n = 0
    for r in db.query(m.KRS).join(m.Kelas).filter(m.KRS.status == "diajukan", m.Kelas.tahun_akademik_id == ta.id):
        r.status = "disetujui"
        notify(r.mahasiswa.user_id, "KRS disetujui", f"{r.kelas.nama} disetujui.", "/mahasiswa/krs")
        n += 1
    db.commit()
    audit(cu.id, f"Menyetujui {n} KRS sekaligus", "akademik")
    return Msg(detail=f"{n} KRS disetujui")


# ================================ NILAI ================================= #
@nilai.put("/kelas/{kid}", response_model=list[s.KRSOut], summary="Dosen menginput nilai peserta kelas")
def input_nilai(kid: int, data: list[s.NilaiItem], d: m.Dosen = Depends(dosen_saya), db: Session = Depends(get_db)):
    k = _kelas_dosen(kid, d, db)
    if k.nilai_terkunci:
        raise HTTPException(400, "Nilai kelas ini telah dikunci oleh admin")
    peta = {r.id: r for r in k.peserta.filter(m.KRS.status == "disetujui")}
    for item in data:
        r = peta.get(item.krs_id)
        if not r:
            continue
        sebelum = r.nilai_huruf
        for f in ("nilai_kehadiran", "nilai_tugas", "nilai_uts", "nilai_uas"):
            setattr(r, f, getattr(item, f))
        r.hitung_nilai()
        if r.nilai_huruf and r.nilai_huruf != sebelum:
            notify(r.mahasiswa.user_id, "Nilai telah diinput", f"{k.matakuliah.nama}: {r.nilai_huruf}", "/mahasiswa/khs")
    db.commit()
    audit(d.user_id, f"Input nilai kelas {k.nama}", "akademik")
    return [krs_out(r, db) for r in peta.values()]


@nilai.post("/kelas/{kid}/isi-kehadiran", response_model=list[s.KRSOut],
            summary="Isi komponen kehadiran otomatis dari rekap presensi")
def isi_kehadiran(kid: int, d: m.Dosen = Depends(dosen_saya), db: Session = Depends(get_db)):
    from .serializers import persentase_kehadiran
    k = _kelas_dosen(kid, d, db)
    hasil = []
    for r in k.peserta.filter(m.KRS.status == "disetujui"):
        pct = persentase_kehadiran(r, db)
        if pct is not None:
            r.nilai_kehadiran = pct
            r.hitung_nilai()
        hasil.append(r)
    db.commit()
    return [krs_out(r, db) for r in hasil]


def _khs(x: m.Mahasiswa, ta: m.TahunAkademik) -> s.KHSOut:
    daftar = [k for k in x.krs.filter(m.KRS.status == "disetujui") if k.kelas.tahun_akademik_id == ta.id]
    return s.KHSOut(tahun_akademik_id=ta.id, tahun_akademik=ta.nama, sks=sum(k.kelas.matakuliah.sks for k in daftar),
                    ips=x.ips(ta.id), daftar=[krs_out(k) for k in daftar])


@nilai.get("/khs", response_model=s.KHSOut, summary="KHS mahasiswa per semester")
def khs(tahun_akademik_id: int | None = None, x: m.Mahasiswa = Depends(mahasiswa_saya), db: Session = Depends(get_db)):
    ta = db.get(m.TahunAkademik, tahun_akademik_id) if tahun_akademik_id else ta_aktif(db)
    if not ta:
        raise HTTPException(404, "Tahun akademik tidak ditemukan")
    return _khs(x, ta)


@nilai.get("/transkrip", response_model=s.TranskripOut, summary="Transkrip (mahasiswa sendiri, atau admin/PA via mahasiswa_id)")
def transkrip(mahasiswa_id: int | None = None, cu: CurrentUser = Depends(get_current_user), db: Session = Depends(get_db)):
    from .serializers import mahasiswa_out
    if cu.role == "mahasiswa":
        x = db.query(m.Mahasiswa).filter(m.Mahasiswa.user_id == cu.id).first()
    else:
        if not mahasiswa_id:
            raise HTTPException(400, "mahasiswa_id wajib diisi")
        x = get_or_404(db, m.Mahasiswa, mahasiswa_id, "Mahasiswa")
    ta_ids = sorted({k.kelas.tahun_akademik for k in x.krs.filter(m.KRS.status == "disetujui")},
                    key=lambda t: (t.tahun_mulai, t.semester))
    return s.TranskripOut(mahasiswa=mahasiswa_out(x, ta_aktif(db)), semester=[_khs(x, t) for t in ta_ids],
                          total_sks=x.total_sks, ipk=x.ipk)


# =============================== PRESENSI =============================== #
@presensi.get("/kelas/{kid}/pertemuan", response_model=list[s.PertemuanOut])
def list_pertemuan(kid: int, cu: CurrentUser = Depends(get_current_user), db: Session = Depends(get_db)):
    k = get_or_404(db, m.Kelas, kid, "Kelas")
    return [pertemuan_out(p) for p in k.pertemuan]


@presensi.post("/kelas/{kid}/pertemuan", response_model=s.PertemuanOut, status_code=201,
               summary="Buat pertemuan baru (default semua hadir)")
def buat_pertemuan(kid: int, data: s.PertemuanIn, d: m.Dosen = Depends(dosen_saya), db: Session = Depends(get_db)):
    k = _kelas_dosen(kid, d, db)
    p = m.Pertemuan(kelas_id=k.id, pertemuan_ke=k.pertemuan.count() + 1, tanggal=data.tanggal or date.today(),
                    materi=data.materi, metode=data.metode)
    db.add(p)
    db.flush()
    for r in k.peserta.filter(m.KRS.status == "disetujui"):
        db.add(m.Presensi(pertemuan_id=p.id, mahasiswa_id=r.mahasiswa_id, status="hadir"))
    db.commit()
    return pertemuan_out(p)


@presensi.get("/pertemuan/{pid}", summary="Detail presensi satu pertemuan")
def detail_pertemuan(pid: int, d: m.Dosen = Depends(dosen_saya), db: Session = Depends(get_db)):
    p = get_or_404(db, m.Pertemuan, pid, "Pertemuan")
    _kelas_dosen(p.kelas_id, d, db)
    return {"pertemuan": pertemuan_out(p),
            "presensi": [{"mahasiswa_id": x.mahasiswa_id, "status": x.status} for x in p.presensi]}


@presensi.put("/pertemuan/{pid}", response_model=s.PertemuanOut, summary="Simpan presensi pertemuan")
def set_presensi(pid: int, data: s.PresensiSet, d: m.Dosen = Depends(dosen_saya), db: Session = Depends(get_db)):
    p = get_or_404(db, m.Pertemuan, pid, "Pertemuan")
    k = _kelas_dosen(p.kelas_id, d, db)
    if data.tanggal:
        p.tanggal = data.tanggal
    if data.materi is not None:
        p.materi = data.materi
    peserta = {r.mahasiswa_id for r in k.peserta.filter(m.KRS.status == "disetujui")}
    for item in data.daftar:
        if item.mahasiswa_id not in peserta:
            continue
        pr = db.query(m.Presensi).filter_by(pertemuan_id=p.id, mahasiswa_id=item.mahasiswa_id).first()
        if pr:
            pr.status = item.status
        else:
            db.add(m.Presensi(pertemuan_id=p.id, mahasiswa_id=item.mahasiswa_id, status=item.status))
    db.commit()
    return pertemuan_out(p)


@presensi.delete("/pertemuan/{pid}", response_model=Msg)
def hapus_pertemuan(pid: int, d: m.Dosen = Depends(dosen_saya), db: Session = Depends(get_db)):
    p = get_or_404(db, m.Pertemuan, pid, "Pertemuan")
    _kelas_dosen(p.kelas_id, d, db)
    db.delete(p)
    db.commit()
    return Msg(detail="Pertemuan dihapus")


@presensi.get("/kelas/{kid}/rekap", summary="Matriks rekap kehadiran kelas (dosen)")
def rekap_kelas(kid: int, d: m.Dosen = Depends(dosen_saya), db: Session = Depends(get_db)):
    k = _kelas_dosen(kid, d, db)
    rows = []
    for r in k.peserta.filter(m.KRS.status == "disetujui").join(m.Mahasiswa).order_by(m.Mahasiswa.nim):
        data = {x.pertemuan_id: x.status for x in db.query(m.Presensi).join(m.Pertemuan)
                .filter(m.Pertemuan.kelas_id == k.id, m.Presensi.mahasiswa_id == r.mahasiswa_id)}
        rows.append({"krs": krs_out(r, db), "presensi": data})
    return {"kelas": kelas_out(k), "pertemuan": [pertemuan_out(p) for p in k.pertemuan], "peserta": rows}


@presensi.get("/saya", response_model=list[s.RekapPresensiOut], summary="Rekap presensi mahasiswa semester aktif")
def presensi_saya(x: m.Mahasiswa = Depends(mahasiswa_saya), db: Session = Depends(get_db)):
    from .serializers import persentase_kehadiran
    ta = ta_aktif(db)
    hasil = []
    if not ta:
        return hasil
    for r in x.krs.join(m.Kelas).filter(m.Kelas.tahun_akademik_id == ta.id, m.KRS.status == "disetujui"):
        data = {p.pertemuan_id: p.status for p in db.query(m.Presensi).join(m.Pertemuan)
                .filter(m.Pertemuan.kelas_id == r.kelas_id, m.Presensi.mahasiswa_id == x.id)}
        hasil.append(s.RekapPresensiOut(
            kelas=kelas_out(r.kelas), pertemuan=[pertemuan_out(p) for p in r.kelas.pertemuan], data=data,
            hitung={st: sum(1 for v in data.values() if v == st) for st in m.STATUS_PRESENSI},
            persen=persentase_kehadiran(r, db)))
    return hasil


# ============================= PORTAL DOSEN ============================= #
@dosen.get("/kelas", response_model=list[s.KelasOut], summary="Kelas yang diampu dosen")
def kelas_saya(tahun_akademik_id: int | None = None, d: m.Dosen = Depends(dosen_saya), db: Session = Depends(get_db)):
    ta_id = tahun_akademik_id or (ta_aktif(db).id if ta_aktif(db) else None)
    return [kelas_out(k) for k in d.kelas.filter(m.Kelas.tahun_akademik_id == ta_id)]


@dosen.get("/jadwal", summary="Jadwal mengajar per hari")
def jadwal_dosen(d: m.Dosen = Depends(dosen_saya), db: Session = Depends(get_db)):
    ta = ta_aktif(db)
    daftar = [kelas_out(k) for k in d.kelas.filter(m.Kelas.tahun_akademik_id == ta.id)] if ta else []
    return {h: sorted([k for k in daftar if k.hari == h], key=lambda k: k.jam_mulai or "") for h in m.HARI}


@dosen.get("/perwalian", summary="Mahasiswa PA & KRS menunggu persetujuan")
def perwalian(d: m.Dosen = Depends(dosen_saya), db: Session = Depends(get_db)):
    from .serializers import mahasiswa_out
    ta = ta_aktif(db)
    pending = []
    if ta:
        pending = (db.query(m.KRS).join(m.Mahasiswa).join(m.Kelas)
                   .filter(m.Mahasiswa.dosen_pa_id == d.id, m.KRS.status == "diajukan", m.Kelas.tahun_akademik_id == ta.id))
    return {"mahasiswa": [mahasiswa_out(x, ta) for x in d.mahasiswa_pa.order_by(m.Mahasiswa.nama)],
            "krs_menunggu": [krs_out(r) for r in pending]}


@dosen.get("/ringkasan", summary="Ringkasan dashboard dosen")
def ringkasan_dosen(d: m.Dosen = Depends(dosen_saya), db: Session = Depends(get_db)):
    ta = ta_aktif(db)
    kelas_aktif = list(d.kelas.filter(m.Kelas.tahun_akademik_id == ta.id)) if ta else []
    progres = []
    for k in kelas_aktif:
        peserta = list(k.peserta.filter(m.KRS.status == "disetujui"))
        progres.append({"kelas": kelas_out(k), "total": len(peserta),
                        "dinilai": sum(1 for p in peserta if p.nilai_akhir is not None)})
    krs_pending = (db.query(m.KRS).join(m.Mahasiswa).filter(m.Mahasiswa.dosen_pa_id == d.id, m.KRS.status == "diajukan").count())
    return {
        "dosen": {"id": d.id, "nama_lengkap": d.nama_lengkap, "prodi": d.prodi.nama if d.prodi else None,
                  "jabatan": d.jabatan_fungsional},
        "tahun_akademik": ta.nama if ta else None,
        "jumlah_kelas": len(kelas_aktif),
        "jumlah_mahasiswa": sum(k.jumlah_peserta for k in kelas_aktif),
        "mahasiswa_pa": d.mahasiswa_pa.count(),
        "krs_menunggu": krs_pending,
        "jadwal_hari_ini": sorted([kelas_out(k) for k in kelas_aktif if k.hari == _hari_ini()], key=lambda k: k.jam_mulai or ""),
        "progres_nilai": progres,
    }
