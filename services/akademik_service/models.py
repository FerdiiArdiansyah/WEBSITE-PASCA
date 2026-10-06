from datetime import date, datetime

from sqlalchemy import Boolean, Date, DateTime, Float, ForeignKey, Integer, String, Text, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from services.common.db import Base, make_session_factory

engine, SessionLocal, get_db = make_session_factory("akademik")

HARI = ("Senin", "Selasa", "Rabu", "Kamis", "Jumat", "Sabtu")
STATUS_MAHASISWA = ("aktif", "cuti", "lulus", "drop out", "nonaktif")
STATUS_KRS = ("diajukan", "disetujui", "ditolak")
STATUS_PRESENSI = ("hadir", "izin", "sakit", "alpa")


class ProgramStudi(Base):
    __tablename__ = "program_studi"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    kode: Mapped[str] = mapped_column(String(10), unique=True)
    nama: Mapped[str] = mapped_column(String(150))
    jenjang: Mapped[str] = mapped_column(String(5))
    gelar: Mapped[str | None] = mapped_column(String(20), nullable=True)
    akreditasi: Mapped[str | None] = mapped_column(String(20), nullable=True)
    deskripsi: Mapped[str | None] = mapped_column(Text, nullable=True)
    biaya_semester: Mapped[int] = mapped_column(Integer, default=0)
    kaprodi_id: Mapped[int | None] = mapped_column(Integer, nullable=True)

    mahasiswa = relationship("Mahasiswa", back_populates="prodi", lazy="dynamic")
    matakuliah = relationship("MataKuliah", back_populates="prodi", lazy="dynamic")


class Dosen(Base):
    """Profil dosen; identitas login ada di auth-service (user_id). Nama/email di-cache."""
    __tablename__ = "dosen"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_id: Mapped[int] = mapped_column(Integer, unique=True, index=True)
    nama: Mapped[str] = mapped_column(String(150))
    email: Mapped[str] = mapped_column(String(120))
    nidn: Mapped[str] = mapped_column(String(20), unique=True)
    gelar_depan: Mapped[str | None] = mapped_column(String(30), nullable=True)
    gelar_belakang: Mapped[str | None] = mapped_column(String(60), nullable=True)
    prodi_id: Mapped[int | None] = mapped_column(ForeignKey("program_studi.id"), nullable=True)
    jabatan_fungsional: Mapped[str | None] = mapped_column(String(50), nullable=True)
    bidang_keahlian: Mapped[str | None] = mapped_column(String(200), nullable=True)
    pendidikan_terakhir: Mapped[str] = mapped_column(String(10), default="S3")

    prodi = relationship("ProgramStudi")
    kelas = relationship("Kelas", back_populates="dosen", lazy="dynamic")
    mahasiswa_pa = relationship("Mahasiswa", back_populates="dosen_pa", lazy="dynamic")

    @property
    def nama_lengkap(self) -> str:
        nama = " ".join(b for b in (self.gelar_depan, self.nama) if b)
        return f"{nama}, {self.gelar_belakang}" if self.gelar_belakang else nama


class Mahasiswa(Base):
    __tablename__ = "mahasiswa"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_id: Mapped[int] = mapped_column(Integer, unique=True, index=True)
    nama: Mapped[str] = mapped_column(String(150))
    email: Mapped[str] = mapped_column(String(120))
    nim: Mapped[str] = mapped_column(String(20), unique=True, index=True)
    prodi_id: Mapped[int] = mapped_column(ForeignKey("program_studi.id"))
    angkatan: Mapped[int] = mapped_column(Integer)
    status: Mapped[str] = mapped_column(String(20), default="aktif")
    dosen_pa_id: Mapped[int | None] = mapped_column(ForeignKey("dosen.id"), nullable=True)
    jenis_kelamin: Mapped[str | None] = mapped_column(String(1), nullable=True)
    tempat_lahir: Mapped[str | None] = mapped_column(String(60), nullable=True)
    tanggal_lahir: Mapped[date | None] = mapped_column(Date, nullable=True)
    alamat: Mapped[str | None] = mapped_column(Text, nullable=True)
    pendidikan_s1: Mapped[str | None] = mapped_column(String(150), nullable=True)
    konsentrasi: Mapped[str | None] = mapped_column(String(100), nullable=True)
    pekerjaan: Mapped[str | None] = mapped_column(String(100), nullable=True)

    prodi = relationship("ProgramStudi", back_populates="mahasiswa")
    dosen_pa = relationship("Dosen", back_populates="mahasiswa_pa")
    krs = relationship("KRS", back_populates="mahasiswa", lazy="dynamic", cascade="all, delete-orphan")

    # ---- Perhitungan akademik ------------------------------------------ #
    def krs_lulus(self):
        return [k for k in self.krs.filter(KRS.status == "disetujui") if k.bobot is not None]

    @property
    def total_sks(self) -> int:
        return sum(k.kelas.matakuliah.sks for k in self.krs_lulus())

    @property
    def ipk(self) -> float:
        data = self.krs_lulus()
        sks = sum(k.kelas.matakuliah.sks for k in data)
        return round(sum(k.bobot * k.kelas.matakuliah.sks for k in data) / sks, 2) if sks else 0.0

    def ips(self, ta_id: int) -> float:
        data = [k for k in self.krs_lulus() if k.kelas.tahun_akademik_id == ta_id]
        sks = sum(k.kelas.matakuliah.sks for k in data)
        return round(sum(k.bobot * k.kelas.matakuliah.sks for k in data) / sks, 2) if sks else 0.0

    def semester_ke(self, ta) -> int:
        if not ta:
            return 1
        return max(1, (ta.tahun_mulai - self.angkatan) * 2 + (2 if ta.semester == "Genap" else 1))


class TahunAkademik(Base):
    __tablename__ = "tahun_akademik"
    __table_args__ = (UniqueConstraint("tahun_mulai", "semester"),)
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    tahun_mulai: Mapped[int] = mapped_column(Integer)
    semester: Mapped[str] = mapped_column(String(10))
    aktif: Mapped[bool] = mapped_column(Boolean, default=False)
    krs_dibuka: Mapped[bool] = mapped_column(Boolean, default=True)
    tanggal_mulai: Mapped[date | None] = mapped_column(Date, nullable=True)
    tanggal_selesai: Mapped[date | None] = mapped_column(Date, nullable=True)

    kelas = relationship("Kelas", back_populates="tahun_akademik", lazy="dynamic")
    kalender = relationship("KalenderAkademik", back_populates="tahun_akademik", lazy="dynamic",
                            cascade="all, delete-orphan")

    @property
    def nama(self) -> str:
        return f"{self.tahun_mulai}/{self.tahun_mulai + 1} {self.semester}"


class MataKuliah(Base):
    __tablename__ = "mata_kuliah"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    kode: Mapped[str] = mapped_column(String(15), unique=True)
    nama: Mapped[str] = mapped_column(String(150))
    sks: Mapped[int] = mapped_column(Integer, default=3)
    semester_ke: Mapped[int] = mapped_column(Integer, default=1)
    jenis: Mapped[str] = mapped_column(String(20), default="wajib")
    prodi_id: Mapped[int] = mapped_column(ForeignKey("program_studi.id"))
    deskripsi: Mapped[str | None] = mapped_column(Text, nullable=True)

    prodi = relationship("ProgramStudi", back_populates="matakuliah")
    kelas = relationship("Kelas", back_populates="matakuliah", lazy="dynamic")


class Kelas(Base):
    __tablename__ = "kelas"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    matakuliah_id: Mapped[int] = mapped_column(ForeignKey("mata_kuliah.id"))
    tahun_akademik_id: Mapped[int] = mapped_column(ForeignKey("tahun_akademik.id"))
    dosen_id: Mapped[int] = mapped_column(ForeignKey("dosen.id"))
    nama_kelas: Mapped[str] = mapped_column(String(10), default="A")
    hari: Mapped[str | None] = mapped_column(String(10), nullable=True)
    jam_mulai: Mapped[str | None] = mapped_column(String(5), nullable=True)
    jam_selesai: Mapped[str | None] = mapped_column(String(5), nullable=True)
    ruangan: Mapped[str | None] = mapped_column(String(50), nullable=True)
    kuota: Mapped[int] = mapped_column(Integer, default=30)
    nilai_terkunci: Mapped[bool] = mapped_column(Boolean, default=False)

    matakuliah = relationship("MataKuliah", back_populates="kelas")
    tahun_akademik = relationship("TahunAkademik", back_populates="kelas")
    dosen = relationship("Dosen", back_populates="kelas")
    peserta = relationship("KRS", back_populates="kelas", lazy="dynamic", cascade="all, delete-orphan")
    pertemuan = relationship("Pertemuan", back_populates="kelas", lazy="dynamic", cascade="all, delete-orphan",
                             order_by="Pertemuan.pertemuan_ke")

    @property
    def nama(self) -> str:
        return f"{self.matakuliah.nama} ({self.nama_kelas})"

    @property
    def jumlah_peserta(self) -> int:
        return self.peserta.filter(KRS.status != "ditolak").count()


class KRS(Base):
    __tablename__ = "krs"
    __table_args__ = (UniqueConstraint("mahasiswa_id", "kelas_id"),)
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    mahasiswa_id: Mapped[int] = mapped_column(ForeignKey("mahasiswa.id"))
    kelas_id: Mapped[int] = mapped_column(ForeignKey("kelas.id"))
    status: Mapped[str] = mapped_column(String(20), default="diajukan")
    catatan: Mapped[str | None] = mapped_column(String(255), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.now)
    nilai_kehadiran: Mapped[float | None] = mapped_column(Float, nullable=True)
    nilai_tugas: Mapped[float | None] = mapped_column(Float, nullable=True)
    nilai_uts: Mapped[float | None] = mapped_column(Float, nullable=True)
    nilai_uas: Mapped[float | None] = mapped_column(Float, nullable=True)
    nilai_akhir: Mapped[float | None] = mapped_column(Float, nullable=True)
    nilai_huruf: Mapped[str | None] = mapped_column(String(2), nullable=True)
    bobot: Mapped[float | None] = mapped_column(Float, nullable=True)

    mahasiswa = relationship("Mahasiswa", back_populates="krs")
    kelas = relationship("Kelas", back_populates="peserta")

    def hitung_nilai(self):
        from services.common.utils import konversi_nilai
        komp = (self.nilai_kehadiran, self.nilai_tugas, self.nilai_uts, self.nilai_uas)
        if any(k is None for k in komp):
            self.nilai_akhir = self.nilai_huruf = self.bobot = None
            return
        self.nilai_akhir = round(0.10 * komp[0] + 0.20 * komp[1] + 0.30 * komp[2] + 0.40 * komp[3], 2)
        self.nilai_huruf, self.bobot = konversi_nilai(self.nilai_akhir)


class Pertemuan(Base):
    __tablename__ = "pertemuan"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    kelas_id: Mapped[int] = mapped_column(ForeignKey("kelas.id"))
    pertemuan_ke: Mapped[int] = mapped_column(Integer)
    tanggal: Mapped[date] = mapped_column(Date, default=date.today)
    materi: Mapped[str | None] = mapped_column(String(255), nullable=True)
    metode: Mapped[str] = mapped_column(String(30), default="Tatap Muka")

    kelas = relationship("Kelas", back_populates="pertemuan")
    presensi = relationship("Presensi", back_populates="pertemuan", lazy="dynamic", cascade="all, delete-orphan")


class Presensi(Base):
    __tablename__ = "presensi"
    __table_args__ = (UniqueConstraint("pertemuan_id", "mahasiswa_id"),)
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    pertemuan_id: Mapped[int] = mapped_column(ForeignKey("pertemuan.id"))
    mahasiswa_id: Mapped[int] = mapped_column(ForeignKey("mahasiswa.id"))
    status: Mapped[str] = mapped_column(String(10), default="hadir")

    pertemuan = relationship("Pertemuan", back_populates="presensi")


class KalenderAkademik(Base):
    __tablename__ = "kalender_akademik"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    tahun_akademik_id: Mapped[int] = mapped_column(ForeignKey("tahun_akademik.id"))
    kegiatan: Mapped[str] = mapped_column(String(200))
    tanggal_mulai: Mapped[date] = mapped_column(Date)
    tanggal_selesai: Mapped[date | None] = mapped_column(Date, nullable=True)
    keterangan: Mapped[str | None] = mapped_column(String(255), nullable=True)

    tahun_akademik = relationship("TahunAkademik", back_populates="kalender")
