import uuid
from pathlib import Path

from fastapi import HTTPException, UploadFile
from fastapi.staticfiles import StaticFiles

from .config import settings


def save_upload(file: UploadFile | None, subfolder: str) -> str | None:
    """Simpan unggahan dengan validasi tipe & ukuran; kembalikan path relatif untuk URL /files/..."""
    if file is None or not file.filename:
        return None
    ext = file.filename.rsplit(".", 1)[-1].lower() if "." in file.filename else ""
    if ext not in settings.ALLOWED_EXT:
        raise HTTPException(400, f"Tipe berkas harus salah satu dari: {', '.join(settings.ALLOWED_EXT)}")
    data = file.file.read()
    if len(data) > settings.MAX_UPLOAD_MB * 1024 * 1024:
        raise HTTPException(413, f"Ukuran berkas melebihi {settings.MAX_UPLOAD_MB} MB")
    folder: Path = settings.UPLOAD_DIR / subfolder
    folder.mkdir(parents=True, exist_ok=True)
    name = f"{uuid.uuid4().hex}.{ext}"
    (folder / name).write_bytes(data)
    return f"/files/{subfolder}/{name}"


def mount_files(app):
    app.mount("/files", StaticFiles(directory=str(settings.UPLOAD_DIR)), name="files")
