from services.common.utils import create_service

from .models import Base, engine
from .routers_internal import internal, laporan
from .routers_master import kal, mk, prodi, ta
from .routers_orang import dosen, mhs
from .routers_perkuliahan import dosen as portal_dosen, kelas, krs, nilai, presensi

app = create_service(
    "Akademik Service",
    "Data master (prodi, tahun akademik, mata kuliah, kalender), profil dosen & mahasiswa, kelas & jadwal, "
    "KRS, penilaian (KHS/transkrip), presensi, perwalian, dan laporan akademik.",
)
Base.metadata.create_all(engine)

for r in (prodi, ta, mk, kal, dosen, portal_dosen, mhs, kelas, krs, nilai, presensi, laporan, internal):
    app.include_router(r)
