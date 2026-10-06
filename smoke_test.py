"""Uji asap end-to-end melalui API Gateway. Jalankan setelah `python run_all.py` aktif.

    python smoke_test.py
"""
import io
import sys

import httpx

from services.common.config import settings

G = f"http://127.0.0.1:{settings.GATEWAY_PORT}"
c = httpx.Client(base_url=G, timeout=30)
gagal = []


def cek(label, r, ok=(200, 201)):
    status = "ok" if r.status_code in ok else "GAGAL"
    if status == "GAGAL":
        gagal.append((label, r.status_code, r.text[:200]))
    print(f"  [{status}] {label} -> {r.status_code}")
    return r


def login(username, password):
    r = cek(f"login {username}", c.post("/api/auth/auth/login", json={"username": username, "password": password}))
    return {"Authorization": f"Bearer {r.json()['access_token']}"} if r.status_code == 200 else {}


print("== Gateway & publik")
cek("health", c.get("/health"))
cek("beranda publik", c.get("/api/publik/beranda"))
cek("prodi", c.get("/api/akademik/prodi"))
cek("kurikulum prodi 1", c.get("/api/akademik/prodi/1/kurikulum"))
cek("pengumuman publik", c.get("/api/layanan/pengumuman"))
cek("kalender", c.get("/api/akademik/kalender"))
cek("jenis surat", c.get("/api/layanan/surat/jenis"))
cek("internal diblokir", c.get("/api/akademik/internal/mahasiswa"), ok=(403,))
cek("tanpa token ditolak", c.get("/api/akademik/mahasiswa/me"), ok=(401,))
r = cek("PMB daftar", c.post("/api/layanan/pmb/daftar", json={
    "nama": "Calon Uji", "email": "calon.uji@mail.com", "telepon": "08123456789", "prodi_id": 2,
    "pendidikan_terakhir": "S1 Informatika, Unismuh", "ipk_terakhir": 3.6}))
nomor = r.json().get("nomor_pendaftaran")
cek("PMB cek status", c.get(f"/api/layanan/pmb/cek/{nomor}"))

print("== Admin")
h = login("admin", "admin123")
cek("me", c.get("/api/auth/auth/me", headers=h))
cek("dashboard admin", c.get("/api/dashboard/admin", headers=h))
cek("users", c.get("/api/users", headers=h))
cek("mahasiswa list", c.get("/api/akademik/mahasiswa", headers=h, params={"per_page": 5}))
cek("mahasiswa detail", c.get("/api/akademik/mahasiswa/1", headers=h))
cek("mahasiswa riwayat", c.get("/api/akademik/mahasiswa/1/riwayat", headers=h))
cek("dosen list", c.get("/api/akademik/dosen", headers=h))
cek("tahun akademik", c.get("/api/akademik/tahun-akademik", headers=h))
cek("matakuliah", c.get("/api/akademik/matakuliah", headers=h))
cek("kelas", c.get("/api/akademik/kelas", headers=h))
cek("kelas peserta", c.get("/api/akademik/kelas/1/peserta", headers=h))
cek("krs diajukan", c.get("/api/akademik/krs", headers=h))
cek("laporan ringkasan", c.get("/api/akademik/laporan/ringkasan", headers=h))
cek("laporan prodi", c.get("/api/akademik/laporan/prodi", headers=h))
cek("laporan distribusi", c.get("/api/akademik/laporan/distribusi-nilai", headers=h))
cek("laporan progres", c.get("/api/akademik/laporan/progres-nilai", headers=h))
cek("tesis list", c.get("/api/tesis", headers=h))
cek("tesis detail", c.get("/api/tesis/1", headers=h))
cek("keuangan list", c.get("/api/keuangan", headers=h))
cek("keuangan ringkasan", c.get("/api/keuangan/ringkasan", headers=h))
cek("surat list", c.get("/api/layanan/surat", headers=h))
cek("pmb list", c.get("/api/layanan/pmb", headers=h))
cek("log", c.get("/api/log", headers=h))
# tulis
r = cek("tambah prodi", c.post("/api/akademik/prodi", headers=h, json={"kode": "MTI", "nama": "Teknologi Informasi", "jenjang": "S2", "biaya_semester": 9500000}))
pid_baru = r.json().get("id")
cek("hapus prodi", c.delete(f"/api/akademik/prodi/{pid_baru}", headers=h))
r = cek("tambah mahasiswa", c.post("/api/akademik/mahasiswa", headers=h, json={
    "nim": "26TST001", "nama": "Mahasiswa Uji", "email": "uji@student.unismuh.ac.id", "prodi_id": 2, "angkatan": 2026}))
mid_baru = r.json().get("id")
cek("pengumuman buat", c.post("/api/layanan/pengumuman", headers=h, json={"judul": "Uji", "isi": "Isi pengumuman uji", "target": "semua"}))
krs_pending = c.get("/api/akademik/krs", headers=h).json()
if krs_pending:
    cek("krs setujui", c.post(f"/api/akademik/krs/{krs_pending[0]['id']}/setujui", headers=h, json={"catatan": "ok"}))
menunggu = c.get("/api/keuangan", headers=h, params={"status": "menunggu verifikasi"}).json()["items"]
if menunggu:
    cek("keuangan verifikasi", c.post(f"/api/keuangan/{menunggu[0]['id']}/verifikasi", headers=h))
cek("keuangan generate", c.post("/api/keuangan/generate", headers=h, json={"tahun_akademik_id": 3}))
tp = [t for t in c.get("/api/tesis", headers=h, params={"status": "pengajuan"}).json()]
if tp:
    cek("tesis tetapkan pembimbing", c.put(f"/api/tesis/{tp[0]['id']}", headers=h, json={"pembimbing1_id": 1, "pembimbing2_id": 2}))
surat_p = c.get("/api/layanan/surat", headers=h, params={"status": "diajukan"}).json()
if surat_p:
    cek("surat proses", c.patch(f"/api/layanan/surat/{surat_p[0]['id']}", headers=h, json={"status": "selesai"}))
pend = c.get("/api/layanan/pmb", headers=h, params={"status": "baru"}).json()
if pend:
    cek("pmb terima + buat akun", c.patch(f"/api/layanan/pmb/{pend[0]['id']}", headers=h, json={"status": "diterima", "buat_akun": True}))
cek("akses dosen ditolak", c.get("/api/akademik/dosen/me/ringkasan", headers=h), ok=(403,))

print("== Dosen")
h = login("0003037003", "dosen123")
cek("dashboard dosen", c.get("/api/dashboard/dosen", headers=h))
cek("dosen me", c.get("/api/akademik/dosen/me", headers=h))
r = cek("kelas saya", c.get("/api/akademik/dosen/me/kelas", headers=h))
kelas = r.json()
cek("jadwal", c.get("/api/akademik/dosen/me/jadwal", headers=h))
cek("perwalian", c.get("/api/akademik/dosen/me/perwalian", headers=h))
if kelas:
    kid = kelas[0]["id"]
    peserta = cek("peserta kelas", c.get(f"/api/akademik/kelas/{kid}/peserta", headers=h)).json()
    cek("input nilai", c.put(f"/api/akademik/nilai/kelas/{kid}", headers=h, json=[
        {"krs_id": p["id"], "nilai_kehadiran": 90, "nilai_tugas": 85, "nilai_uts": 80, "nilai_uas": 88} for p in peserta]))
    cek("rekap presensi", c.get(f"/api/akademik/presensi/kelas/{kid}/rekap", headers=h))
    r = cek("buat pertemuan", c.post(f"/api/akademik/presensi/kelas/{kid}/pertemuan", headers=h, json={"materi": "Uji", "metode": "Daring"}))
    pid = r.json().get("id")
    cek("set presensi", c.put(f"/api/akademik/presensi/pertemuan/{pid}", headers=h, json={
        "daftar": [{"mahasiswa_id": p["mahasiswa_id"], "status": "izin"} for p in peserta[:1]]}))
    cek("isi kehadiran otomatis", c.post(f"/api/akademik/nilai/kelas/{kid}/isi-kehadiran", headers=h))
bimb = cek("bimbingan saya", c.get("/api/tesis/bimbingan", headers=h)).json()
cek("log menunggu", c.get("/api/tesis/bimbingan/log-menunggu", headers=h))
if bimb:
    tid = bimb[0]["id"]
    cek("detail bimbingan", c.get(f"/api/tesis/bimbingan/{tid}", headers=h))
    cek("catat log", c.post(f"/api/tesis/bimbingan/{tid}/log", headers=h, json={"topik": "Uji", "catatan_dosen": "Lanjutkan"}))
cek("akses admin ditolak", c.get("/api/akademik/laporan/ringkasan", headers=h), ok=(403,))

print("== Mahasiswa")
h = login("25MKM001", "mhs123")
cek("dashboard mahasiswa", c.get("/api/dashboard/mahasiswa", headers=h))
cek("mahasiswa me", c.get("/api/akademik/mahasiswa/me", headers=h))
cek("ringkasan", c.get("/api/akademik/mahasiswa/me/ringkasan", headers=h))
cek("krs saya", c.get("/api/akademik/krs/saya", headers=h))
tersedia = cek("krs tersedia", c.get("/api/akademik/krs/tersedia", headers=h)).json()
cek("khs", c.get("/api/akademik/nilai/khs", headers=h))
cek("transkrip", c.get("/api/akademik/nilai/transkrip", headers=h))
cek("presensi saya", c.get("/api/akademik/presensi/saya", headers=h))
cek("tesis saya", c.get("/api/tesis/saya", headers=h))
cek("keuangan saya", c.get("/api/keuangan/saya", headers=h))
cek("keuangan ringkasan", c.get("/api/keuangan/saya/ringkasan", headers=h))
cek("surat saya", c.get("/api/layanan/surat/saya", headers=h))
cek("ajukan surat", c.post("/api/layanan/surat/saya", headers=h, json={"jenis": "Surat Keterangan Aktif Kuliah", "keperluan": "Keperluan uji coba"}))
cek("pengumuman untuk saya", c.get("/api/layanan/pengumuman/untuk-saya", headers=h))
cek("notifikasi", c.get("/api/notifikasi", headers=h))
cek("notifikasi baca semua", c.post("/api/notifikasi/baca-semua", headers=h))
cek("ubah biodata", c.put("/api/akademik/mahasiswa/me/biodata", headers=h, json={"alamat": "Jl. Uji No. 1"}))
belum = [t for t in c.get("/api/keuangan/saya", headers=h).json() if t["status"] in ("belum bayar", "ditolak")]
if belum:
    cek("upload bukti bayar", c.post(f"/api/keuangan/saya/{belum[0]['id']}/bayar", headers=h,
                                     files={"bukti": ("bukti.pdf", io.BytesIO(b"%PDF-1.4 uji"), "application/pdf")},
                                     data={"catatan": "transfer BSI"}))
    cek("upload tipe salah ditolak", c.post(f"/api/keuangan/saya/{belum[0]['id']}/bayar", headers=h,
                                           files={"bukti": ("x.exe", io.BytesIO(b"MZ"), "application/octet-stream")}), ok=(400,))
if tersedia:
    r = c.post("/api/akademik/krs", headers=h, json={"kelas_id": tersedia[0]["id"]})
    cek("ambil krs (boleh 400 jika ada tunggakan)", r, ok=(201, 400, 409))
cek("ganti password salah", c.put("/api/auth/auth/me/password", headers=h, json={"password_lama": "salah", "password_baru": "password123"}), ok=(400,))
cek("akses admin ditolak", c.get("/api/users", headers=h), ok=(403,))

# Mahasiswa baru dari PMB (akun otomatis)
if pend:
    p = c.get("/api/layanan/pmb", headers=login("admin", "admin123"), params={"status": "diterima"}).json()
    if p and p[0].get("mahasiswa_id"):
        nim_baru = p[0]["catatan"].split("NIM ")[1].split(",")[0]
        h2 = login(nim_baru, nim_baru)
        cek("mahasiswa PMB login & me", c.get("/api/akademik/mahasiswa/me", headers=h2))

print("\nHasil:", "SEMUA LOLOS" if not gagal else f"{len(gagal)} GAGAL")
for g in gagal:
    print("   ", g)
sys.exit(1 if gagal else 0)
