"""Seed data demo untuk seluruh microservice (menulis langsung ke DB tiap service).

    python seed.py
"""
import random
from datetime import date, datetime, timedelta

from services.common.auth import hash_password
from services.common.config import settings
from services.akademik_service import models as ak
from services.auth_service.models import Base as AuthBase, User, engine as auth_engine, SessionLocal as AuthSession
from services.keuangan_service.main import Base as KeuBase, Tagihan, engine as keu_engine, SessionLocal as KeuSession
from services.layanan_service.main import (
    Base as LayBase, Pendaftar, Pengumuman, PengajuanSurat, engine as lay_engine, SessionLocal as LaySession,
)
from services.notifikasi_service.main import Base as NotBase, engine as not_engine
from services.tesis_service.main import Base as TesBase, Bimbingan, Tesis, engine as tes_engine, SessionLocal as TesSession

random.seed(42)

# ------------------------------------------------------------ reset semua DB
for base, eng in ((AuthBase, auth_engine), (ak.Base, ak.engine), (TesBase, tes_engine), (KeuBase, keu_engine),
                  (LayBase, lay_engine), (NotBase, not_engine)):
    base.metadata.drop_all(eng)
    base.metadata.create_all(eng)

auth, db, tes, keu, lay = AuthSession(), ak.SessionLocal(), TesSession(), KeuSession(), LaySession()


def user(username, nama, role, email, password):
    u = User(username=username, nama=nama, role=role, email=email, password_hash=hash_password(password))
    auth.add(u)
    auth.flush()
    return u


# ------------------------------------------------------------------ Admin
admin = user("admin", "Staf Akademik", "admin", "admin@unismuh.ac.id", "admin123")
user("keuangan", "Staf Keuangan", "admin", "keuangan@unismuh.ac.id", "admin123")

# --------------------------------------------------------- Tahun Akademik
ta_list = []
for th, sem, aktif, mulai, selesai in [(2025, "Ganjil", False, date(2025, 9, 1), date(2026, 1, 31)),
                                        (2025, "Genap", False, date(2026, 2, 9), date(2026, 7, 10)),
                                        (2026, "Ganjil", True, date(2026, 9, 7), date(2027, 1, 29))]:
    t = ak.TahunAkademik(tahun_mulai=th, semester=sem, aktif=aktif, tanggal_mulai=mulai, tanggal_selesai=selesai)
    db.add(t)
    ta_list.append(t)
db.flush()
ta1, ta2, ta_aktif = ta_list

# ------------------------------------------------------------------ Dosen
data_dosen = [
    ("0001017001", "Prof. Dr.", "Ahmad Fauzi", "M.Pd.", "Guru Besar", "Pendidikan Matematika, Asesmen Pembelajaran"),
    ("0002027002", "Dr.", "Siti Rahmawati", "M.Si.", "Lektor Kepala", "Psikologi Pendidikan, Motivasi Belajar"),
    ("0003037003", "Dr.", "Budi Santoso", "M.Kom.", "Lektor Kepala", "Kecerdasan Buatan, NLP, Deep Learning"),
    ("0004047004", "Dr.", "Dewi Lestari", "M.M.", "Lektor", "Manajemen Strategik, Kepemimpinan"),
    ("0005057005", "Prof. Dr.", "Hendra Wijaya", "M.T.", "Guru Besar", "Sistem Cerdas, Graph Neural Network"),
    ("0006067006", "Dr.", "Nur Aisyah", "M.Pd.", "Lektor", "Teknologi Pendidikan, Kurikulum"),
    ("0007077007", "Dr.", "Rizky Pratama", "M.Si.", "Lektor", "Statistika, Metodologi Penelitian"),
    ("0008087008", "Dr.", "Maya Kusuma", "M.M.", "Lektor Kepala", "Manajemen SDM, Perilaku Organisasi"),
]
dosen = []
for nidn, gd, nama, gb, jab, bidang in data_dosen:
    email = f"{nama.split()[0].lower()}.{nama.split()[-1].lower()}@unismuh.ac.id"
    u = user(nidn, nama, "dosen", email, "dosen123")
    d = ak.Dosen(user_id=u.id, nama=nama, email=email, nidn=nidn, gelar_depan=gd, gelar_belakang=gb,
                 jabatan_fungsional=jab, bidang_keahlian=bidang)
    db.add(d)
    dosen.append(d)
db.flush()

# ----------------------------------------------------------- Program Studi
prodi_data = [
    ("MPD", "Pendidikan", "S2", "M.Pd.", "Unggul", 7_500_000, dosen[0], "Program Magister Pendidikan berfokus pada pengembangan kurikulum, asesmen, dan teknologi pembelajaran berbasis riset."),
    ("MKM", "Ilmu Komputer", "S2", "M.Kom.", "A", 9_000_000, dosen[2], "Program Magister Ilmu Komputer dengan konsentrasi kecerdasan buatan, sains data, dan rekayasa perangkat lunak."),
    ("MMJ", "Manajemen", "S2", "M.M.", "Unggul", 8_500_000, dosen[3], "Program Magister Manajemen yang mencetak pemimpin bisnis adaptif, Islami, dan berdaya saing."),
    ("DPD", "Ilmu Pendidikan", "S3", "Dr.", "A", 12_500_000, dosen[1], "Program Doktor Ilmu Pendidikan menghasilkan peneliti dan pemikir kebijakan pendidikan berkelas internasional."),
]
prodi = []
for kode, nama, jenjang, gelar, akr, biaya, kaprodi, desk in prodi_data:
    p = ak.ProgramStudi(kode=kode, nama=nama, jenjang=jenjang, gelar=gelar, akreditasi=akr, biaya_semester=biaya,
                        kaprodi_id=kaprodi.id, deskripsi=desk)
    db.add(p)
    prodi.append(p)
db.flush()
mpd, mkm, mmj, dpd = prodi
for d, p in zip(dosen, [mpd, dpd, mkm, mmj, mkm, mpd, mpd, mmj]):
    d.prodi_id = p.id

# ------------------------------------------------------------ Mata Kuliah
mk_data = {
    mpd: [("MPD501", "Filsafat Ilmu Pendidikan", 3, 1), ("MPD502", "Metodologi Penelitian Pendidikan", 3, 1),
          ("MPD503", "Statistika Pendidikan Lanjut", 3, 1), ("MPD504", "Psikologi Belajar", 3, 1),
          ("MPD511", "Pengembangan Kurikulum", 3, 2), ("MPD512", "Asesmen & Evaluasi Pembelajaran", 3, 2),
          ("MPD513", "Teknologi Pembelajaran Digital", 3, 2), ("MPD521", "Seminar Proposal Tesis", 2, 3), ("MPD599", "Tesis", 6, 4)],
    mkm: [("MKM501", "Algoritma Lanjut", 3, 1), ("MKM502", "Metodologi Penelitian Komputasi", 3, 1),
          ("MKM503", "Pembelajaran Mesin", 3, 1), ("MKM504", "Statistika Komputasi", 3, 1),
          ("MKM511", "Deep Learning", 3, 2), ("MKM512", "Pemrosesan Bahasa Alami", 3, 2),
          ("MKM513", "Sistem Terdistribusi", 3, 2), ("MKM521", "Seminar Proposal Tesis", 2, 3), ("MKM599", "Tesis", 6, 4)],
    mmj: [("MMJ501", "Manajemen Strategik", 3, 1), ("MMJ502", "Metodologi Penelitian Bisnis", 3, 1),
          ("MMJ503", "Ekonomi Manajerial", 3, 1), ("MMJ504", "Perilaku Organisasi", 3, 1),
          ("MMJ511", "Manajemen Keuangan Lanjut", 3, 2), ("MMJ512", "Manajemen SDM Strategik", 3, 2),
          ("MMJ513", "Kepemimpinan & Perubahan", 3, 2), ("MMJ521", "Seminar Proposal Tesis", 2, 3), ("MMJ599", "Tesis", 6, 4)],
    dpd: [("DPD701", "Filsafat Ilmu & Epistemologi", 3, 1), ("DPD702", "Metodologi Penelitian Lanjut", 3, 1),
          ("DPD703", "Analisis Kebijakan Pendidikan", 3, 1), ("DPD711", "Teori Belajar Kontemporer", 3, 2),
          ("DPD712", "Statistika Multivariat", 3, 2), ("DPD799", "Disertasi", 12, 4)],
}
mk_map = {}
for p, items in mk_data.items():
    for kode, nama, sks, smt in items:
        mk = ak.MataKuliah(kode=kode, nama=nama, sks=sks, semester_ke=smt, prodi_id=p.id,
                           jenis="pilihan" if kode.endswith("13") else "wajib",
                           deskripsi=f"Mata kuliah {nama} untuk program {p.jenjang} {p.nama}.")
        db.add(mk)
        mk_map[kode] = mk
db.flush()

# ------------------------------------------------------------- Mahasiswa
nama_mhs = ["Andi Saputra", "Rina Marlina", "Fajar Nugroho", "Dian Permata", "Yusuf Hidayat", "Lina Kartika",
            "Bagus Prakoso", "Sri Wahyuni", "Arif Rahman", "Nadia Putri", "Teguh Setiawan", "Mega Anjani",
            "Rudi Hartono", "Fitri Handayani", "Ilham Maulana", "Citra Dewi", "Doni Kurniawan", "Ayu Lestari",
            "Galih Pratama", "Wulan Sari", "Hafiz Ramadhan", "Intan Permatasari", "Joko Susilo", "Kartika Sari"]
mahasiswa = []
siklus = [mpd, mkm, mmj, dpd, mpd, mkm, mmj]
for i, nama in enumerate(nama_mhs):
    p = siklus[i % len(siklus)]
    angkatan = 2025 if i < 14 else 2026
    urut = sum(1 for m in mahasiswa if m.prodi_id == p.id and m.angkatan == angkatan) + 1
    nim = f"{angkatan % 100}{p.kode}{urut:03d}"
    email = f"{nama.split()[0].lower()}{i}@student.unismuh.ac.id"
    u = user(nim, nama, "mahasiswa", email, "mhs123")
    pa = [d for d in dosen if d.prodi_id == p.id]
    m = ak.Mahasiswa(user_id=u.id, nama=nama, email=email, nim=nim, prodi_id=p.id, angkatan=angkatan,
                     dosen_pa_id=random.choice(pa).id, jenis_kelamin=random.choice("LP"),
                     tempat_lahir=random.choice(["Makassar", "Gowa", "Maros", "Parepare", "Bone"]),
                     tanggal_lahir=date(random.randint(1985, 2000), random.randint(1, 12), random.randint(1, 28)),
                     alamat=f"Jl. Contoh No. {i + 1}, Makassar",
                     pendidikan_s1=f"S1 {random.choice(['Pendidikan', 'Informatika', 'Manajemen', 'Psikologi'])}, {random.choice(['Unismuh Makassar', 'Universitas Hasanuddin', 'UNM', 'UIN Alauddin'])}",
                     pekerjaan=random.choice(["Guru", "ASN", "Karyawan Swasta", "Wiraswasta", "Dosen"]))
    db.add(m)
    mahasiswa.append(m)
db.flush()

# ------------------------------------------------------------------ Kelas
jam = [("08:00", "10:30"), ("10:30", "13:00"), ("13:30", "16:00"), ("16:00", "18:30")]
kelas_map = {}


def buat_kelas(ta, kode, idx):
    mk = mk_map[kode]
    pengampu = [d for d in dosen if d.prodi_id == mk.prodi_id] or dosen
    k = ak.Kelas(matakuliah_id=mk.id, tahun_akademik_id=ta.id, dosen_id=pengampu[idx % len(pengampu)].id,
                 hari=ak.HARI[idx % 6], jam_mulai=jam[(idx // 6) % 4][0], jam_selesai=jam[(idx // 6) % 4][1],
                 ruangan=f"R-{201 + idx % 8}", kuota=25)
    db.add(k)
    kelas_map[(ta.id, kode)] = k


idx = 0
for items in mk_data.values():
    for kode, _, _, smt in items:
        if smt == 1:
            buat_kelas(ta1, kode, idx); idx += 1
        if smt == 2:
            buat_kelas(ta2, kode, idx); idx += 1
idx = 0
for items in mk_data.values():
    for kode, _, _, smt in items:
        if smt in (1, 3):
            buat_kelas(ta_aktif, kode, idx); idx += 1
db.flush()


# ----------------------------------------------------------- KRS & Nilai
def isi_nilai(k):
    k.nilai_kehadiran = random.choice([80, 85, 90, 95, 100])
    k.nilai_tugas, k.nilai_uts, k.nilai_uas = random.randint(70, 95), random.randint(65, 95), random.randint(65, 97)
    k.hitung_nilai()


for m in mahasiswa:
    items = mk_data[next(p for p in prodi if p.id == m.prodi_id)]
    for kode, _, _, smt in items:
        if m.angkatan == 2025:
            if smt in (1, 2):
                k = ak.KRS(mahasiswa_id=m.id, kelas_id=kelas_map[((ta1 if smt == 1 else ta2).id, kode)].id, status="disetujui")
                isi_nilai(k)
                db.add(k)
            elif smt == 3:
                db.add(ak.KRS(mahasiswa_id=m.id, kelas_id=kelas_map[(ta_aktif.id, kode)].id,
                              status=random.choice(["disetujui", "disetujui", "diajukan"])))
        elif smt == 1:
            db.add(ak.KRS(mahasiswa_id=m.id, kelas_id=kelas_map[(ta_aktif.id, kode)].id,
                          status=random.choice(["disetujui", "disetujui", "disetujui", "diajukan"])))
db.flush()

# ------------------------------------------------------ Pertemuan/Presensi
for (ta_id, kode), k in kelas_map.items():
    if ta_id != ta_aktif.id:
        continue
    peserta = k.peserta.filter(ak.KRS.status == "disetujui").all()
    for ke in range(1, 5):
        p = ak.Pertemuan(kelas_id=k.id, pertemuan_ke=ke, tanggal=ta_aktif.tanggal_mulai + timedelta(weeks=ke - 1),
                         materi=f"Pertemuan {ke}: {k.matakuliah.nama} — topik {ke}")
        db.add(p)
        db.flush()
        for r in peserta:
            db.add(ak.Presensi(pertemuan_id=p.id, mahasiswa_id=r.mahasiswa_id,
                               status=random.choices(["hadir", "izin", "sakit", "alpa"], [85, 5, 5, 5])[0]))

# ----------------------------------------------------------------- Kalender
for keg, mulai, selesai, ket in [("Pengisian KRS", date(2026, 9, 1), date(2026, 9, 14), "Melalui portal akademik"),
                                 ("Awal Perkuliahan", date(2026, 9, 7), None, ""),
                                 ("Ujian Tengah Semester", date(2026, 10, 26), date(2026, 11, 6), ""),
                                 ("Seminar Proposal Periode I", date(2026, 11, 16), date(2026, 11, 20), ""),
                                 ("Ujian Akhir Semester", date(2027, 1, 4), date(2027, 1, 15), ""),
                                 ("Batas Input Nilai", date(2027, 1, 22), None, "Dosen pengampu"),
                                 ("Yudisium & Wisuda", date(2027, 2, 20), None, "Balai Sidang Unismuh")]:
    db.add(ak.KalenderAkademik(tahun_akademik_id=ta_aktif.id, kegiatan=keg, tanggal_mulai=mulai, tanggal_selesai=selesai, keterangan=ket))

auth.commit()
db.commit()

# ------------------------------------------------------------------ Tesis
judul = ["Pengaruh Pembelajaran Berbasis Proyek terhadap Kemampuan Berpikir Kritis Siswa SMA",
         "Deteksi Stres Akademik Mahasiswa Menggunakan Transformer pada Data Teks Media Sosial",
         "Pengaruh Kepemimpinan Transformasional terhadap Kinerja Karyawan Perbankan Syariah",
         "Model Kebijakan Pendidikan Inklusif Berbasis Komunitas di Kawasan Timur Indonesia",
         "Implementasi Asesmen Autentik pada Kurikulum Merdeka di Sekolah Dasar",
         "Prediksi Kepadatan Lalu Lintas Kota Makassar dengan Spatio-Temporal Graph Neural Network",
         "Analisis Strategi Diversifikasi Produk UMKM Pascapandemi"]
status_tesis = ["penelitian", "proposal", "disetujui", "pengajuan", "seminar hasil", "penelitian", "pengajuan"]
for i, m in enumerate(mahasiswa[:7]):
    pb = [d for d in dosen if d.prodi_id == m.prodi_id]
    st = status_tesis[i]
    t = Tesis(mahasiswa_id=m.id, mahasiswa_user_id=m.user_id, mahasiswa_nama=m.nama, nim=m.nim,
              prodi=f"{m.prodi.jenjang} {m.prodi.nama}", judul=judul[i], bidang=m.prodi.nama, status=st,
              abstrak="Penelitian ini bertujuan menganalisis dan mengembangkan model yang relevan dengan konteks pendidikan "
                      "dan praktik profesional di Indonesia menggunakan pendekatan metode campuran.",
              tanggal_pengajuan=date(2026, 3, 1) + timedelta(days=i * 7))
    if st != "pengajuan":
        t.pembimbing1_id, t.pembimbing1_user_id, t.pembimbing1_nama = pb[0].id, pb[0].user_id, pb[0].nama_lengkap
        if len(pb) > 1:
            t.pembimbing2_id, t.pembimbing2_user_id, t.pembimbing2_nama = pb[1].id, pb[1].user_id, pb[1].nama_lengkap
    tes.add(t)
    tes.flush()
    if st != "pengajuan":
        for j in range(random.randint(2, 5)):
            tes.add(Bimbingan(tesis_id=t.id, dosen_id=pb[0].id, dosen_nama=pb[0].nama_lengkap,
                              tanggal=t.tanggal_pengajuan + timedelta(days=14 * (j + 1)),
                              topik=["Pendahuluan & rumusan masalah", "Kajian pustaka", "Metodologi", "Instrumen penelitian", "Analisis data awal"][j],
                              catatan_mahasiswa="Telah merevisi sesuai arahan sebelumnya.",
                              catatan_dosen="Perbaiki konsistensi sitasi dan perkuat argumen kebaruan." if j % 2 else "Lanjutkan ke tahap berikutnya.",
                              status="disetujui" if j < 3 else random.choice(["menunggu", "revisi", "disetujui"])))
tes.commit()

# --------------------------------------------------------------- Tagihan
for m in mahasiswa:
    for ta in ta_list:
        if m.angkatan == 2026 and ta.id != ta_aktif.id:
            continue
        status = random.choices(["lunas", "belum bayar", "menunggu verifikasi"], [55, 30, 15])[0] if ta.id == ta_aktif.id else "lunas"
        t = Tagihan(mahasiswa_id=m.id, mahasiswa_user_id=m.user_id, mahasiswa_nama=m.nama, nim=m.nim,
                    tahun_akademik_id=ta.id, tahun_akademik=ta.nama, jenis="SPP", jumlah=m.prodi.biaya_semester,
                    jatuh_tempo=ta.tanggal_mulai + timedelta(days=30), status=status)
        if status != "belum bayar":
            t.tanggal_bayar = datetime.combine(ta.tanggal_mulai + timedelta(days=random.randint(1, 25)), datetime.min.time())
        keu.add(t)
keu.commit()

# -------------------------------------------------- Surat, Pengumuman, PMB
for m in random.sample(mahasiswa, 6):
    lay.add(PengajuanSurat(mahasiswa_id=m.id, mahasiswa_user_id=m.user_id, mahasiswa_nama=m.nama, nim=m.nim,
                           prodi=f"{m.prodi.jenjang} {m.prodi.nama}",
                           jenis=random.choice(["Surat Keterangan Aktif Kuliah", "Surat Izin Penelitian", "Surat Pengantar Observasi"]),
                           keperluan=random.choice(["Pengajuan beasiswa instansi", "Izin penelitian di sekolah mitra", "Keperluan tugas belajar"]),
                           status=random.choice(["diajukan", "diproses", "selesai"])))
for judul_p, isi, kat, target, penting in [
    ("Jadwal Pengisian KRS Semester Ganjil 2026/2027", "Pengisian KRS dibuka 1–14 September 2026 melalui portal akademik. Pastikan tagihan SPP telah lunas sebelum mengajukan KRS.", "Akademik", "semua", True),
    ("Pendaftaran Seminar Proposal Tesis Periode Oktober", "Mahasiswa dengan minimal 3 bimbingan disetujui dapat mendaftar seminar proposal paling lambat 20 Oktober 2026.", "Tesis", "mahasiswa", False),
    ("Batas Input Nilai UTS", "Dosen pengampu dimohon menginput nilai UTS paling lambat 2 minggu setelah pelaksanaan UTS.", "Akademik", "dosen", False),
    ("Kuliah Umum: AI untuk Pendidikan Masa Depan", "Kuliah umum bersama pakar AI nasional, 15 Oktober 2026 pukul 09.00 WITA di Balai Sidang Unismuh Makassar.", "Kegiatan", "semua", False),
    ("Beasiswa Penelitian Tesis 2026", "Tersedia 10 kuota beasiswa penelitian tesis senilai Rp 5.000.000. Syarat IPK ≥ 3,50.", "Beasiswa", "mahasiswa", True),
]:
    lay.add(Pengumuman(judul=judul_p, isi=isi, kategori=kat, target=target, penting=penting, penulis_id=admin.id, penulis_nama=admin.nama))
for i, (nama, p) in enumerate([("Calon Mahasiswa A", mkm), ("Calon Mahasiswa B", mpd), ("Calon Mahasiswa C", mmj)]):
    lay.add(Pendaftar(nomor_pendaftaran=f"PMB2026100{i + 1}", nama=nama, email=f"calon{i}@mail.com", telepon="08123456789",
                      prodi_id=p.id, prodi_nama=f"{p.jenjang} {p.nama}", pendidikan_terakhir="S1 Terkait, Universitas X",
                      ipk_terakhir=round(random.uniform(3.0, 3.9), 2), rencana_penelitian="Rencana penelitian terkait topik unggulan prodi.",
                      status=["baru", "diverifikasi", "baru"][i]))
lay.commit()

print(f"Seed selesai -> {settings.DATA_DIR}\n")
print("Akun demo (password):")
print("  Admin     : admin / admin123   |  keuangan / admin123")
print("  Dosen     : 0001017001 / dosen123 (Prof. Ahmad Fauzi), 0003037003 / dosen123 (Dr. Budi Santoso), ...")
print(f"  Mahasiswa : {mahasiswa[0].nim} / mhs123 ({mahasiswa[0].nama}), {mahasiswa[1].nim} / mhs123 ({mahasiswa[1].nama}), ...")
