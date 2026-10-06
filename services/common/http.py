"""Klien HTTP antar-service + helper notifikasi/log (fire-and-forget)."""
import logging
from typing import Any

import httpx
from fastapi import HTTPException

from .config import settings

log = logging.getLogger("siakad.http")
HEADERS = {"X-Internal-Key": settings.INTERNAL_KEY}


def call(base_url: str, method: str, path: str, *, json: Any = None, params: dict | None = None,
         timeout: float = 10.0, raise_for_status: bool = True) -> Any:
    """Panggil service lain secara sinkron. Mengembalikan JSON respons."""
    try:
        r = httpx.request(method, f"{base_url}{path}", json=json, params=params, headers=HEADERS, timeout=timeout)
    except httpx.HTTPError as e:
        log.error("Gagal menghubungi %s%s: %s", base_url, path, e)
        raise HTTPException(503, f"Service tidak tersedia: {base_url}")
    if raise_for_status and r.status_code >= 400:
        detail = r.json().get("detail") if r.headers.get("content-type", "").startswith("application/json") else r.text
        raise HTTPException(r.status_code, detail)
    if r.status_code == 204 or not r.content:
        return None
    return r.json()


def safe_call(base_url: str, method: str, path: str, **kw) -> Any:
    """Seperti call(), tetapi kegagalan hanya dicatat (untuk notifikasi/log)."""
    try:
        return call(base_url, method, path, timeout=3.0, **kw)
    except HTTPException as e:
        log.warning("Panggilan non-kritis gagal %s%s: %s", base_url, path, e.detail)
        return None


# ------------------------------ Shortcut -------------------------------- #
def notify(user_id: int | None, judul: str, isi: str = "", link: str = ""):
    if user_id:
        safe_call(settings.NOTIFIKASI_URL, "POST", "/internal/notifikasi",
                  json={"user_id": user_id, "judul": judul, "isi": isi, "link": link})


def notify_role(role: str, judul: str, isi: str = "", link: str = ""):
    safe_call(settings.NOTIFIKASI_URL, "POST", "/internal/notifikasi/role",
              json={"role": role, "judul": judul, "isi": isi, "link": link})


def audit(user_id: int | None, aksi: str, service: str = ""):
    safe_call(settings.NOTIFIKASI_URL, "POST", "/internal/log",
              json={"user_id": user_id, "aksi": aksi, "service": service})
