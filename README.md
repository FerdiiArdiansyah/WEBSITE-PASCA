# SIAKAD Pascasarjana — Arsitektur Microservice

Sistem Informasi Akademik **Program Pascasarjana Universitas Muhammadiyah Makassar** berbasis **microservice REST/JSON** (Python FastAPI). Tidak ada template HTML di sisi server: seluruh fungsi tersedia sebagai API berdokumentasi (Swagger/OpenAPI) yang siap dikonsumsi aplikasi web SPA (React/Vue), aplikasi mobile (Flutter/Android), atau sistem lain.

```
                         ┌──────────────────────────┐
  Klien (SPA / Mobile) ─▶│  API Gateway  :8000      │─▶ /api/auth, /api/users      ─▶ auth-service       :8001
                         │  proxy, agregasi,        │─▶ /api/akademik              ─▶ akademik-service   :8002
                         │  health, dashboard       │─▶ /api/tesis                 ─▶ tesis-service      :8003
                         └──────────────────────────┘─▶ /api/keuangan              ─▶ keuangan-service   :8004
                                                     ─▶ /api/layanan               ─▶ layanan-service    :8005
                                                     ─▶ /api/notifikasi, /api/log  ─▶ notifikasi-service :8006
```

Setiap service memiliki **database sendiri** (SQLite di `data/<service>.db`; ganti ke PostgreSQL/MySQL via `make_session_factory`), berkomunikasi lewat HTTP internal yang dilindungi header `X-Internal-Key`, dan mengirim notifikasi/log audit ke notifikasi-service secara *fire-and-forget*.

## 1. Menjalankan

```powershell
python -m pip install -r requirements.txt
python seed.py          # reset + isi data demo untuk semua service
python run_all.py       # jalankan 6 service + gateway (Ctrl+C untuk berhenti)
python smoke_test.py    # 88 uji end-to-end melalui gateway
```

### Aplikasi mobile (Flutter) — folder `mobile/`

```powershell
cd mobile
flutter pub get
flutter run                      # Android/iOS/emulator (Android emulator otomatis memakai http://10.0.2.2:8000)
flutter run -d chrome            # pratinjau di browser
flutter build apk --release      # APK Android siap distribusi
flutter build web --release      # bundel web statis (build/web)
```

Alamat server API dapat diubah dari layar login (ikon server) atau menu Profil → Server API. Tombol akun demo di layar login dikendalikan konstanta `kDemoMode` di `lib/screens/auth_screens.dart` (set `false` untuk produksi).

Fitur aplikasi: login JWT per peran; **Mahasiswa** (dashboard, KRS, jadwal, presensi, KHS, transkrip, tesis + unggah proposal/bimbingan, keuangan + unggah bukti, surat + pratinjau, pengumuman, notifikasi); **Dosen** (dashboard, kelas → input nilai & presensi, bimbingan tesis, perwalian/PA); **Admin** (dashboard grafik, mahasiswa, dosen, kelas, verifikasi KRS, keuangan & generate SPP, tesis, surat, PMB, pengumuman, pengguna, master, laporan); **Publik** (profil institusi, prodi & kurikulum, pengumuman, kalender, formulir PMB).

Dokumentasi interaktif: **http://127.0.0.1:8000/docs** (gateway) dan `/docs` di tiap service (8001–8006).

Docker: `docker compose up --build` (konfigurasi di [.env.docker](.env.docker)).

### Akun demo

| Peran | Username | Password |
|---|---|---|
| Admin/Staf | `admin`, `keuangan` | `admin123` |
| Dosen | `0001017001` … `0008087008` (NIDN) | `dosen123` |
| Mahasiswa | `25MPD001`, `25MKM001`, `26MKM002`, … (NIM) | `mhs123` |

### Contoh pemakaian

```http
POST /api/auth/auth/login            {"username":"25MKM001","password":"mhs123"}
→ {"access_token":"...", "user":{...}}

GET  /api/dashboard/mahasiswa         Authorization: Bearer <token>
GET  /api/akademik/krs/tersedia
POST /api/akademik/krs                {"kelas_id": 33}
GET  /api/akademik/nilai/transkrip
POST /api/keuangan/saya/12/bayar      multipart: bukti=<pdf>, catatan=...
POST /api/tesis/saya                  multipart: judul, abstrak, bidang, file_proposal
```

## 2. Struktur

```
services/
  common/              pustaka bersama: config (pydantic-settings), db, auth (JWT, PBKDF2, RBAC),
                       http (klien antar-service, notify/audit), files (upload aman), utils
  gateway/             reverse-proxy + endpoint komposit (/api/dashboard/*, /api/publik/beranda, /health)
  auth_service/        login JWT, /auth/me, ganti password, manajemen pengguna (admin), internal user API
  akademik_service/    prodi, tahun akademik, mata kuliah, kalender, dosen, mahasiswa, kelas/jadwal,
                       KRS (validasi kuota/SKS/bentrok/tunggakan), nilai (KHS/transkrip), presensi,
                       perwalian, laporan
  tesis_service/       pengajuan judul + proposal, penetapan pembimbing, tahapan, log bimbingan
  keuangan_service/    tagihan, generate SPP massal, unggah bukti, verifikasi, rekap
  layanan_service/     persuratan berbasis templat (draf → edit → ajukan → admin tinjau/setujui + penomoran), pengumuman, PMB (→ otomatis buat akun)
  notifikasi_service/  notifikasi per pengguna/peran, log audit
run_all.py             orkestrasi lokal          seed.py  data demo          smoke_test.py  uji E2E
Dockerfile, docker-compose.yml, .env.docker, .env.example
```

## 3. Ringkasan Endpoint per Peran (melalui gateway `/api/...`)

**Publik** — `publik/beranda`, `akademik/prodi`, `akademik/prodi/{id}/kurikulum`, `akademik/kalender`, `layanan/pengumuman`, `layanan/pmb/daftar`, `layanan/pmb/cek/{nomor}`.

**Mahasiswa** — `dashboard/mahasiswa`; `akademik/mahasiswa/me[/ringkasan|/biodata]`; `akademik/krs/saya|tersedia`, `POST akademik/krs`, `DELETE akademik/krs/{id}`; `akademik/nilai/khs|transkrip`; `akademik/presensi/saya`; `tesis/saya` (+`/bimbingan`); `keuangan/saya` (+`/ringkasan`, `/{id}/bayar`); `layanan/persuratan/templat`; `layanan/persuratan/saya` (`POST` buat draf dari data akademik, `GET|PUT|DELETE /{id}`, `POST /{id}/ajukan`, `GET /{id}/dokumen`); `layanan/pengumuman/untuk-saya`; `notifikasi`.

**Dosen** — `dashboard/dosen`; `akademik/dosen/me[/kelas|/jadwal|/perwalian|/ringkasan]`; `akademik/kelas/{id}/peserta`; `PUT akademik/nilai/kelas/{id}`, `POST .../isi-kehadiran`; `akademik/presensi/kelas/{id}/pertemuan|rekap`, `PUT akademik/presensi/pertemuan/{id}`; `akademik/krs/{id}/setujui|tolak` (PA); `tesis/bimbingan` (+`/{id}`, `/{id}/log`, `/log/{id}`, `/{id}/status`, `/log-menunggu`).

**Admin/Staf** — `dashboard/admin`; CRUD `akademik/prodi|tahun-akademik|matakuliah|kalender|dosen|mahasiswa|kelas`; `akademik/krs` + `setujui-semua`; `akademik/laporan/*`; `tesis` (+`PUT /{id}` pembimbing/status/nilai); `keuangan` (+`generate`, `/{id}/verifikasi|tolak`, `ringkasan`); `layanan/persuratan?status=` (+`GET /{id}`, `/{id}/dokumen`, `/{id}/nomor-usulan`, `PATCH /{id}/tinjau` aksi `setujui|revisi|tolak`), `layanan/pengumuman` CRUD, `layanan/pmb` (+`PATCH /{id}` dengan `buat_akun`); `users`; `log`.

## 4. Keamanan
JWT (HS256, 12 jam) via `Authorization: Bearer`; password PBKDF2-SHA256 200k iterasi; RBAC per endpoint + pemeriksaan kepemilikan (dosen hanya kelas/bimbingannya, mahasiswa hanya datanya); endpoint `/internal/*` hanya menerima `X-Internal-Key` dan **diblokir di gateway**; validasi skema Pydantic; unggahan dibatasi tipe (pdf/jpg/png) & ukuran (5 MB) dengan nama acak; CORS dapat dibatasi di `create_service`. Untuk produksi: set `SECRET_KEY`/`INTERNAL_KEY` via environment, HTTPS di depan gateway, dan DB server.
