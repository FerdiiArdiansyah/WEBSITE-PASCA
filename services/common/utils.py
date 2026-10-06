from typing import Generic, TypeVar

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

from .config import settings

T = TypeVar("T")


class Msg(BaseModel):
    detail: str


class Page(BaseModel, Generic[T]):
    items: list[T]
    total: int
    page: int
    per_page: int
    pages: int


def paginate(query, page: int, per_page: int, schema):
    total = query.count()
    items = query.offset((page - 1) * per_page).limit(per_page).all()
    return Page[schema](items=[schema.model_validate(i) for i in items], total=total, page=page,
                        per_page=per_page, pages=max(1, -(-total // per_page)))


def create_service(name: str, description: str, version: str = "1.0.0") -> FastAPI:
    app = FastAPI(
        title=f"SIAKAD Pascasarjana — {name}",
        description=description + f"\n\n**{settings.NAMA_INSTITUSI} {settings.NAMA_UNIVERSITAS}**",
        version=version,
        docs_url="/docs", redoc_url="/redoc",
    )
    app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])

    @app.get("/health", tags=["Sistem"])
    def health():
        return {"service": name, "status": "ok"}

    return app


def konversi_nilai(angka: float | None):
    if angka is None:
        return None, None
    for batas, huruf, bobot in ((85, "A", 4.0), (80, "A-", 3.75), (75, "B+", 3.5), (70, "B", 3.0),
                                (65, "B-", 2.75), (60, "C+", 2.5), (55, "C", 2.0), (40, "D", 1.0)):
        if angka >= batas:
            return huruf, bobot
    return "E", 0.0
