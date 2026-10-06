"""API Gateway — satu pintu masuk untuk seluruh microservice SIAKAD Pascasarjana.

Meneruskan permintaan /api/<service>/... ke service terkait, memblokir rute /internal,
mengagregasi health-check, dan menyediakan endpoint dashboard komposit.
"""
import asyncio

import httpx
from fastapi import Depends, FastAPI, Request, Response
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from services.common.auth import CurrentUser, get_current_user, require_roles
from services.common.config import settings

ROUTES = {
    # prefix publik          -> (base_url service, prefix di service)
    "auth": (settings.AUTH_URL, ""),
    "users": (settings.AUTH_URL, "/users"),
    "akademik": (settings.AKADEMIK_URL, ""),
    "tesis": (settings.TESIS_URL, "/tesis"),
    "keuangan": (settings.KEUANGAN_URL, "/keuangan"),
    "layanan": (settings.LAYANAN_URL, ""),
    "notifikasi": (settings.NOTIFIKASI_URL, "/notifikasi"),
    "log": (settings.NOTIFIKASI_URL, "/log"),
}
SERVICES = {
    "auth": settings.AUTH_URL, "akademik": settings.AKADEMIK_URL, "tesis": settings.TESIS_URL,
    "keuangan": settings.KEUANGAN_URL, "layanan": settings.LAYANAN_URL, "notifikasi": settings.NOTIFIKASI_URL,
}
HOP_HEADERS = {"host", "content-length", "transfer-encoding", "connection", "x-internal-key"}

app = FastAPI(
    title="SIAKAD Pascasarjana — API Gateway",
    description=(
        f"Gerbang API **{settings.NAMA_INSTITUSI} {settings.NAMA_UNIVERSITAS}**.\n\n"
        "Semua permintaan klien (web SPA / mobile) masuk melalui gateway ini:\n\n"
        "| Prefix | Service | Dokumentasi |\n|---|---|---|\n"
        f"| `/api/auth`, `/api/users` | Auth | {settings.AUTH_URL}/docs |\n"
        f"| `/api/akademik` | Akademik | {settings.AKADEMIK_URL}/docs |\n"
        f"| `/api/tesis` | Tesis | {settings.TESIS_URL}/docs |\n"
        f"| `/api/keuangan` | Keuangan | {settings.KEUANGAN_URL}/docs |\n"
        f"| `/api/layanan` | Layanan (surat, pengumuman, PMB) | {settings.LAYANAN_URL}/docs |\n"
        f"| `/api/notifikasi`, `/api/log` | Notifikasi & Audit | {settings.NOTIFIKASI_URL}/docs |\n\n"
        "Autentikasi: `Authorization: Bearer <token>` dari `POST /api/auth/auth/login`."
    ),
    version="1.0.0",
)
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])
client = httpx.AsyncClient(timeout=30.0)


@app.get("/", tags=["Sistem"])
def root():
    return {"nama": f"SIAKAD {settings.NAMA_INSTITUSI} {settings.NAMA_UNIVERSITAS}", "gateway": "ok",
            "docs": "/docs", "services": {k: f"{v}/docs" for k, v in SERVICES.items()}}


@app.get("/health", tags=["Sistem"], summary="Status seluruh service")
async def health():
    async def cek(nama, url):
        try:
            r = await client.get(f"{url}/health", timeout=3.0)
            return nama, {"status": "ok" if r.status_code == 200 else "error", "url": url}
        except httpx.HTTPError:
            return nama, {"status": "down", "url": url}
    hasil = dict(await asyncio.gather(*(cek(n, u) for n, u in SERVICES.items())))
    semua_ok = all(v["status"] == "ok" for v in hasil.values())
    return JSONResponse({"gateway": "ok", "semua_service_ok": semua_ok, "services": hasil}, status_code=200 if semua_ok else 503)


# ------------------------- Endpoint komposit ---------------------------- #
async def _get(url: str, path: str, token: str | None = None, params: dict | None = None):
    headers = {"Authorization": token} if token else {}
    headers["X-Internal-Key"] = settings.INTERNAL_KEY
    try:
        r = await client.get(f"{url}{path}", headers=headers, params=params)
        return r.json() if r.status_code < 400 else None
    except httpx.HTTPError:
        return None


@app.get("/api/dashboard/admin", tags=["Dashboard Komposit"], summary="Agregasi statistik seluruh service untuk admin")
async def dashboard_admin(request: Request, cu: CurrentUser = Depends(require_roles("admin"))):
    tok = request.headers.get("authorization")
    akademik, tesis, keuangan, layanan, log = await asyncio.gather(
        _get(settings.AKADEMIK_URL, "/laporan/ringkasan", tok),
        _get(settings.TESIS_URL, "/internal/statistik"),
        _get(settings.KEUANGAN_URL, "/internal/ringkasan"),
        _get(settings.LAYANAN_URL, "/internal/statistik"),
        _get(settings.NOTIFIKASI_URL, "/internal/log/terbaru", params={"limit": 10}),
    )
    keuangan = keuangan or {}
    return {
        "akademik": akademik, "tesis_per_status": tesis or {}, "keuangan_per_status": keuangan,
        "layanan": layanan or {},
        "tunggakan": sum(v["total"] for k, v in keuangan.items() if k != "lunas"),
        "bayar_menunggu": keuangan.get("menunggu verifikasi", {}).get("jumlah", 0),
        "log_terbaru": log or [],
    }


@app.get("/api/dashboard/mahasiswa", tags=["Dashboard Komposit"])
async def dashboard_mahasiswa(request: Request, cu: CurrentUser = Depends(require_roles("mahasiswa"))):
    tok = request.headers.get("authorization")
    ringkasan, keuangan, tesis, pengumuman, kalender, notif = await asyncio.gather(
        _get(settings.AKADEMIK_URL, "/mahasiswa/me/ringkasan", tok),
        _get(settings.KEUANGAN_URL, "/keuangan/saya/ringkasan", tok),
        _get(settings.TESIS_URL, "/tesis/saya", tok),
        _get(settings.LAYANAN_URL, "/pengumuman/untuk-saya", tok, {"limit": 5}),
        _get(settings.AKADEMIK_URL, "/kalender", None, {"mendatang": "true"}),
        _get(settings.NOTIFIKASI_URL, "/notifikasi/jumlah-belum-dibaca", tok),
    )
    return {"akademik": ringkasan, "keuangan": keuangan, "tesis": tesis, "pengumuman": pengumuman or [],
            "agenda": (kalender or [])[:5], "notifikasi_belum_dibaca": (notif or {}).get("jumlah", 0)}


@app.get("/api/dashboard/dosen", tags=["Dashboard Komposit"])
async def dashboard_dosen(request: Request, cu: CurrentUser = Depends(require_roles("dosen"))):
    tok = request.headers.get("authorization")
    ringkasan, bimbingan, log_menunggu, pengumuman, notif = await asyncio.gather(
        _get(settings.AKADEMIK_URL, "/dosen/me/ringkasan", tok),
        _get(settings.TESIS_URL, "/tesis/bimbingan", tok),
        _get(settings.TESIS_URL, "/tesis/bimbingan/log-menunggu", tok),
        _get(settings.LAYANAN_URL, "/pengumuman/untuk-saya", tok, {"limit": 5}),
        _get(settings.NOTIFIKASI_URL, "/notifikasi/jumlah-belum-dibaca", tok),
    )
    aktif = [t for t in (bimbingan or []) if t["status"] not in ("selesai", "ditolak")]
    return {"akademik": ringkasan, "bimbingan_aktif": aktif, "log_menunggu": log_menunggu or [],
            "pengumuman": pengumuman or [], "notifikasi_belum_dibaca": (notif or {}).get("jumlah", 0)}


@app.get("/api/publik/beranda", tags=["Publik"], summary="Data landing page (statistik, prodi, pengumuman)")
async def beranda():
    stat, prodi, peng, kal = await asyncio.gather(
        _get(settings.AKADEMIK_URL, "/internal/statistik-publik"),
        _get(settings.AKADEMIK_URL, "/prodi"),
        _get(settings.LAYANAN_URL, "/pengumuman", params={"limit": 4}),
        _get(settings.AKADEMIK_URL, "/kalender"),
    )
    return {"institusi": {"nama": settings.NAMA_INSTITUSI, "universitas": settings.NAMA_UNIVERSITAS,
                          "singkatan": settings.SINGKATAN_UNIVERSITAS, "alamat": settings.ALAMAT,
                          "email": settings.EMAIL, "telepon": settings.TELEPON},
            "statistik": stat, "prodi": prodi or [], "pengumuman": peng or [], "kalender": kal or []}


# ------------------------------ Proxy ----------------------------------- #
@app.api_route("/api/{service}", methods=["GET", "POST", "PUT", "PATCH", "DELETE"], include_in_schema=False)
@app.api_route("/api/{service}/{path:path}", methods=["GET", "POST", "PUT", "PATCH", "DELETE"],
               tags=["Proxy"], summary="Teruskan ke service", include_in_schema=False)
async def proxy(service: str, request: Request, path: str = ""):
    if service not in ROUTES:
        return JSONResponse({"detail": f"Service '{service}' tidak dikenal"}, status_code=404)
    if path.startswith("internal"):
        return JSONResponse({"detail": "Rute internal tidak dapat diakses melalui gateway"}, status_code=403)
    base, prefix = ROUTES[service]
    url = f"{base}{prefix}/{path}".rstrip("/")
    headers = {k: v for k, v in request.headers.items() if k.lower() not in HOP_HEADERS}
    body = await request.body()
    try:
        r = await client.request(request.method, url, content=body, headers=headers, params=request.query_params)
    except httpx.HTTPError:
        return JSONResponse({"detail": f"Service '{service}' tidak tersedia"}, status_code=503)
    resp_headers = {k: v for k, v in r.headers.items() if k.lower() not in HOP_HEADERS | {"content-encoding"}}
    return Response(content=r.content, status_code=r.status_code, headers=resp_headers)


@app.api_route("/files/{path:path}", methods=["GET"], include_in_schema=False)
async def files(path: str, request: Request):
    """Berkas unggahan (bukti bayar, proposal) dilayani oleh service pemiliknya."""
    folder = path.split("/", 1)[0]
    base = settings.KEUANGAN_URL if folder == "bukti_bayar" else settings.TESIS_URL
    try:
        r = await client.get(f"{base}/files/{path}")
    except httpx.HTTPError:
        return JSONResponse({"detail": "Berkas tidak tersedia"}, status_code=503)
    return Response(content=r.content, status_code=r.status_code, media_type=r.headers.get("content-type"))
