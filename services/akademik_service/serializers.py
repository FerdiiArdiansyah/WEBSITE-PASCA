"""Konversi ORM -> skema keluaran dengan field turunan."""
from . import models as m
from . import schemas as s


def prodi_out(p: m.ProgramStudi, db) -> s.ProdiOut:
    kaprodi = db.get(m.Dosen, p.kaprodi_id) if p.kaprodi_id else None
    return s.ProdiOut(id=p.id, kode=p.kode, nama=p.nama, jenjang=p.jenjang, gelar=p.gelar, akreditasi=p.akreditasi,
                      deskripsi=p.deskripsi, biaya_semester=p.biaya_semester, kaprodi_id=p.kaprodi_id,
                      kaprodi_nama=kaprodi.nama_lengkap if kaprodi else None,
                      jumlah_mahasiswa=p.mahasiswa.count(), jumlah_matakuliah=p.matakuliah.count())


def dosen_out(d: m.Dosen) -> s.DosenOut:
    return s.DosenOut(id=d.id, user_id=d.user_id, nidn=d.nidn, nama=d.nama, nama_lengkap=d.nama_lengkap, email=d.email,
                      gelar_depan=d.gelar_depan, gelar_belakang=d.gelar_belakang, prodi_id=d.prodi_id,
                      prodi_nama=d.prodi.nama if d.prodi else None, jabatan_fungsional=d.jabatan_fungsional,
                      bidang_keahlian=d.bidang_keahlian, pendidikan_terakhir=d.pendidikan_terakhir,
                      jumlah_kelas=d.kelas.count(), jumlah_mahasiswa_pa=d.mahasiswa_pa.count())


def mahasiswa_out(mhs: m.Mahasiswa, ta: m.TahunAkademik | None) -> s.MahasiswaOut:
    return s.MahasiswaOut(
        id=mhs.id, user_id=mhs.user_id, nim=mhs.nim, nama=mhs.nama, email=mhs.email, prodi_id=mhs.prodi_id,
        prodi_nama=mhs.prodi.nama, prodi_jenjang=mhs.prodi.jenjang, angkatan=mhs.angkatan, status=mhs.status,
        dosen_pa_id=mhs.dosen_pa_id, dosen_pa_nama=mhs.dosen_pa.nama_lengkap if mhs.dosen_pa else None,
        jenis_kelamin=mhs.jenis_kelamin, tempat_lahir=mhs.tempat_lahir, tanggal_lahir=mhs.tanggal_lahir,
        alamat=mhs.alamat, pendidikan_s1=mhs.pendidikan_s1, konsentrasi=mhs.konsentrasi, pekerjaan=mhs.pekerjaan,
        ipk=mhs.ipk, total_sks=mhs.total_sks, semester_ke=mhs.semester_ke(ta),
    )


def ta_out(t: m.TahunAkademik) -> s.TAOut:
    return s.TAOut(id=t.id, nama=t.nama, tahun_mulai=t.tahun_mulai, semester=t.semester, aktif=t.aktif,
                   krs_dibuka=t.krs_dibuka, tanggal_mulai=t.tanggal_mulai, tanggal_selesai=t.tanggal_selesai)


def mk_out(mk: m.MataKuliah) -> s.MKOut:
    return s.MKOut(id=mk.id, kode=mk.kode, nama=mk.nama, sks=mk.sks, semester_ke=mk.semester_ke, jenis=mk.jenis,
                   prodi_id=mk.prodi_id, deskripsi=mk.deskripsi, prodi_nama=mk.prodi.nama)


def kelas_out(k: m.Kelas) -> s.KelasOut:
    peserta = k.jumlah_peserta
    return s.KelasOut(
        id=k.id, matakuliah_id=k.matakuliah_id, kode_mk=k.matakuliah.kode, nama_mk=k.matakuliah.nama,
        sks=k.matakuliah.sks, nama=k.nama, nama_kelas=k.nama_kelas, tahun_akademik_id=k.tahun_akademik_id,
        tahun_akademik=k.tahun_akademik.nama, dosen_id=k.dosen_id, dosen_nama=k.dosen.nama_lengkap,
        prodi_id=k.matakuliah.prodi_id, prodi_nama=k.matakuliah.prodi.nama, hari=k.hari, jam_mulai=k.jam_mulai,
        jam_selesai=k.jam_selesai, ruangan=k.ruangan, kuota=k.kuota, jumlah_peserta=peserta,
        sisa_kuota=k.kuota - peserta, nilai_terkunci=k.nilai_terkunci, jumlah_pertemuan=k.pertemuan.count(),
    )


def persentase_kehadiran(krs: m.KRS, db) -> float | None:
    total = krs.kelas.pertemuan.count()
    if not total:
        return None
    hadir = (db.query(m.Presensi).join(m.Pertemuan)
             .filter(m.Pertemuan.kelas_id == krs.kelas_id, m.Presensi.mahasiswa_id == krs.mahasiswa_id,
                     m.Presensi.status == "hadir").count())
    return round(hadir / total * 100, 1)


def krs_out(k: m.KRS, db=None) -> s.KRSOut:
    kl = k.kelas
    return s.KRSOut(
        id=k.id, mahasiswa_id=k.mahasiswa_id, nim=k.mahasiswa.nim, mahasiswa_nama=k.mahasiswa.nama,
        prodi_kode=k.mahasiswa.prodi.kode, kelas_id=k.kelas_id, kode_mk=kl.matakuliah.kode, nama_mk=kl.matakuliah.nama,
        nama_kelas=kl.nama_kelas, sks=kl.matakuliah.sks, dosen_nama=kl.dosen.nama_lengkap, hari=kl.hari,
        jam_mulai=kl.jam_mulai, jam_selesai=kl.jam_selesai, tahun_akademik_id=kl.tahun_akademik_id,
        tahun_akademik=kl.tahun_akademik.nama, status=k.status, catatan=k.catatan, created_at=k.created_at,
        nilai_kehadiran=k.nilai_kehadiran, nilai_tugas=k.nilai_tugas, nilai_uts=k.nilai_uts, nilai_uas=k.nilai_uas,
        nilai_akhir=k.nilai_akhir, nilai_huruf=k.nilai_huruf, bobot=k.bobot,
        persentase_kehadiran=persentase_kehadiran(k, db) if db is not None else None,
    )


def pertemuan_out(p: m.Pertemuan) -> s.PertemuanOut:
    return s.PertemuanOut(id=p.id, kelas_id=p.kelas_id, pertemuan_ke=p.pertemuan_ke, tanggal=p.tanggal,
                          materi=p.materi, metode=p.metode,
                          jumlah_hadir=p.presensi.filter(m.Presensi.status == "hadir").count())


def kalender_out(k: m.KalenderAkademik) -> s.KalenderOut:
    return s.KalenderOut.model_validate(k)
