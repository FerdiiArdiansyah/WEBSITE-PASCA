import os
from pathlib import Path

from pydantic_settings import BaseSettings

ROOT_DIR = Path(__file__).resolve().parents[2]


class Settings(BaseSettings):
    # Identitas institusi
    NAMA_INSTITUSI: str = "Program Pascasarjana"
    NAMA_UNIVERSITAS: str = "Universitas Muhammadiyah Makassar"
    SINGKATAN_UNIVERSITAS: str = "Unismuh Makassar"
    ALAMAT: str = "Jl. Sultan Alauddin No. 259, Makassar, Sulawesi Selatan 90221"
    EMAIL: str = "pasca@unismuh.ac.id"
    TELEPON: str = "(0411) 866 972"

    # Persuratan (penandatangan & kode klasifikasi nomor surat)
    DIREKTUR_NAMA: str = "Prof. Erwin Akib, M.Pd., Ph.D."
    DIREKTUR_JABATAN: str = "Direktur"
    DIREKTUR_NBM: str = "860 934"
    KODE_SURAT: str = "A.4.II"

    # Keamanan
    SECRET_KEY: str = "ganti-dengan-kunci-rahasia-yang-kuat"
    INTERNAL_KEY: str = "kunci-internal-antar-service"
    JWT_ALGORITHM: str = "HS256"
    JWT_EXPIRE_MINUTES: int = 60 * 12

    # Penyimpanan
    DATA_DIR: Path = ROOT_DIR / "data"
    UPLOAD_DIR: Path = ROOT_DIR / "data" / "uploads"
    MAX_UPLOAD_MB: int = 5
    ALLOWED_EXT: tuple = ("pdf", "png", "jpg", "jpeg")

    # Alamat service (dapat dioverride via environment / docker-compose)
    AUTH_URL: str = "http://127.0.0.1:8001"
    AKADEMIK_URL: str = "http://127.0.0.1:8002"
    TESIS_URL: str = "http://127.0.0.1:8003"
    KEUANGAN_URL: str = "http://127.0.0.1:8004"
    LAYANAN_URL: str = "http://127.0.0.1:8005"
    NOTIFIKASI_URL: str = "http://127.0.0.1:8006"
    GATEWAY_PORT: int = 8000

    # Aturan akademik
    MAKS_SKS: int = 15
    MIN_SKS_TESIS: int = 12

    model_config = {"env_file": str(ROOT_DIR / ".env"), "extra": "ignore"}


settings = Settings()
os.makedirs(settings.DATA_DIR, exist_ok=True)
os.makedirs(settings.UPLOAD_DIR, exist_ok=True)
