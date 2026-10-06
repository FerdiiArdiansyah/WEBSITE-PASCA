from datetime import date, datetime

from pydantic import BaseModel, EmailStr, Field, computed_field


class ORM(BaseModel):
    model_config = {"from_attributes": True}


# ------------------------------ Prodi ----------------------------------- #
class ProdiIn(BaseModel):
    kode: str = Field(max_length=10)
    nama: str
    jenjang: str = Field(pattern="^(S2|S3)$")
    gelar: str | None = None
    akreditasi: str | None = None
    deskripsi: str | None = None
    biaya_semester: int = 0
    kaprodi_id: int | None = None


class ProdiOut(ProdiIn, ORM):
    id: int
    jumlah_mahasiswa: int = 0
    jumlah_matakuliah: int = 0
    kaprodi_nama: str | None = None


# ------------------------------ Dosen ----------------------------------- #
class DosenBase(BaseModel):
    nidn: str
    nama: str
    email: EmailStr
    telepon: str | None = None
    gelar_depan: str | None = None
    gelar_belakang: str | None = None
    prodi_id: int | None = None
    jabatan_fungsional: str | None = None
    bidang_keahlian: str | None = None
    pendidikan_terakhir: str = "S3"


class DosenCreate(DosenBase):
    username: str | None = None
    password: str | None = None


class DosenOut(ORM):
    id: int
    user_id: int
    nidn: str
    nama: str
    nama_lengkap: str
    email: str
    gelar_depan: str | None
    gelar_belakang: str | None
    prodi_id: int | None
    prodi_nama: str | None = None
    jabatan_fungsional: str | None
    bidang_keahlian: str | None
    pendidikan_terakhir: str
    jumlah_kelas: int = 0
    jumlah_mahasiswa_pa: int = 0


# ---------------------------- Mahasiswa --------------------------------- #
class MahasiswaBase(BaseModel):
    nim: str
    nama: str
    email: EmailStr
    telepon: str | None = None
    prodi_id: int
    angkatan: int
    status: str = "aktif"
    dosen_pa_id: int | None = None
    jenis_kelamin: str | None = None
    tempat_lahir: str | None = None
    tanggal_lahir: date | None = None
    alamat: str | None = None
    pendidikan_s1: str | None = None
    konsentrasi: str | None = None
    pekerjaan: str | None = None


class MahasiswaCreate(MahasiswaBase):
    password: str | None = None


class MahasiswaUpdate(BaseModel):
    nama: str | None = None
    email: EmailStr | None = None
    prodi_id: int | None = None
    angkatan: int | None = None
    status: str | None = None
    dosen_pa_id: int | None = None
    jenis_kelamin: str | None = None
    tempat_lahir: str | None = None
    tanggal_lahir: date | None = None
    alamat: str | None = None
    pendidikan_s1: str | None = None
    konsentrasi: str | None = None
    pekerjaan: str | None = None


class MahasiswaOut(ORM):
    id: int
    user_id: int
    nim: str
    nama: str
    email: str
    prodi_id: int
    prodi_nama: str | None = None
    prodi_jenjang: str | None = None
    angkatan: int
    status: str
    dosen_pa_id: int | None
    dosen_pa_nama: str | None = None
    jenis_kelamin: str | None
    tempat_lahir: str | None
    tanggal_lahir: date | None
    alamat: str | None
    pendidikan_s1: str | None
    konsentrasi: str | None
    pekerjaan: str | None
    ipk: float = 0.0
    total_sks: int = 0
    semester_ke: int = 1


# ---------------------------- Tahun Akademik ----------------------------- #
class TAIn(BaseModel):
    tahun_mulai: int
    semester: str = Field(pattern="^(Ganjil|Genap)$")
    tanggal_mulai: date | None = None
    tanggal_selesai: date | None = None


class TAOut(TAIn, ORM):
    id: int
    nama: str
    aktif: bool
    krs_dibuka: bool


# ---------------------------- Mata Kuliah -------------------------------- #
class MKIn(BaseModel):
    kode: str
    nama: str
    sks: int = Field(ge=1, le=12, default=3)
    semester_ke: int = Field(ge=1, le=8, default=1)
    jenis: str = Field(pattern="^(wajib|pilihan)$", default="wajib")
    prodi_id: int
    deskripsi: str | None = None


class MKOut(MKIn, ORM):
    id: int
    prodi_nama: str | None = None


# ------------------------------- Kelas ----------------------------------- #
class KelasIn(BaseModel):
    matakuliah_id: int
    tahun_akademik_id: int
    dosen_id: int
    nama_kelas: str = "A"
    hari: str | None = None
    jam_mulai: str | None = None
    jam_selesai: str | None = None
    ruangan: str | None = None
    kuota: int = Field(ge=1, default=30)


class KelasOut(ORM):
    id: int
    matakuliah_id: int
    kode_mk: str
    nama_mk: str
    sks: int
    nama: str
    nama_kelas: str
    tahun_akademik_id: int
    tahun_akademik: str
    dosen_id: int
    dosen_nama: str
    prodi_id: int
    prodi_nama: str
    hari: str | None
    jam_mulai: str | None
    jam_selesai: str | None
    ruangan: str | None
    kuota: int
    jumlah_peserta: int
    sisa_kuota: int
    nilai_terkunci: bool
    jumlah_pertemuan: int = 0


# -------------------------------- KRS ------------------------------------ #
class KRSAmbil(BaseModel):
    kelas_id: int


class KRSAksi(BaseModel):
    catatan: str | None = None


class KRSOut(ORM):
    id: int
    mahasiswa_id: int
    nim: str
    mahasiswa_nama: str
    prodi_kode: str
    kelas_id: int
    kode_mk: str
    nama_mk: str
    nama_kelas: str
    sks: int
    dosen_nama: str
    hari: str | None
    jam_mulai: str | None
    jam_selesai: str | None
    tahun_akademik_id: int
    tahun_akademik: str
    status: str
    catatan: str | None
    created_at: datetime
    nilai_kehadiran: float | None
    nilai_tugas: float | None
    nilai_uts: float | None
    nilai_uas: float | None
    nilai_akhir: float | None
    nilai_huruf: str | None
    bobot: float | None
    persentase_kehadiran: float | None = None


class NilaiItem(BaseModel):
    krs_id: int
    nilai_kehadiran: float | None = Field(default=None, ge=0, le=100)
    nilai_tugas: float | None = Field(default=None, ge=0, le=100)
    nilai_uts: float | None = Field(default=None, ge=0, le=100)
    nilai_uas: float | None = Field(default=None, ge=0, le=100)


class KHSOut(BaseModel):
    tahun_akademik_id: int
    tahun_akademik: str
    sks: int
    ips: float
    daftar: list[KRSOut]


class TranskripOut(BaseModel):
    mahasiswa: MahasiswaOut
    semester: list[KHSOut]
    total_sks: int
    ipk: float


# ------------------------------ Presensi --------------------------------- #
class PertemuanIn(BaseModel):
    tanggal: date | None = None
    materi: str | None = None
    metode: str = "Tatap Muka"


class PertemuanOut(ORM):
    id: int
    kelas_id: int
    pertemuan_ke: int
    tanggal: date
    materi: str | None
    metode: str
    jumlah_hadir: int = 0


class PresensiItem(BaseModel):
    mahasiswa_id: int
    status: str = Field(pattern="^(hadir|izin|sakit|alpa)$")


class PresensiSet(BaseModel):
    tanggal: date | None = None
    materi: str | None = None
    daftar: list[PresensiItem]


class RekapPresensiOut(BaseModel):
    kelas: KelasOut
    pertemuan: list[PertemuanOut]
    data: dict[int, str]  # pertemuan_id -> status
    hitung: dict[str, int]
    persen: float | None


# ------------------------------ Kalender --------------------------------- #
class KalenderIn(BaseModel):
    tahun_akademik_id: int
    kegiatan: str
    tanggal_mulai: date
    tanggal_selesai: date | None = None
    keterangan: str | None = None


class KalenderOut(KalenderIn, ORM):
    id: int
