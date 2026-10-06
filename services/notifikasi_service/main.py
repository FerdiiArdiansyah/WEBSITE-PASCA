from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy import Boolean, DateTime, Integer, String
from sqlalchemy.orm import Mapped, Session, mapped_column

from services.common.auth import CurrentUser, get_current_user, internal_only, require_roles
from services.common.config import settings
from services.common.db import Base, make_session_factory
from services.common.http import call
from services.common.utils import Msg, Page, create_service, paginate

engine, SessionLocal, get_db = make_session_factory("notifikasi")


# ------------------------------- Model ---------------------------------- #
class Notifikasi(Base):
    __tablename__ = "notifikasi"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_id: Mapped[int] = mapped_column(Integer, index=True)
    judul: Mapped[str] = mapped_column(String(150))
    isi: Mapped[str] = mapped_column(String(500), default="")
    link: Mapped[str] = mapped_column(String(255), default="")
    dibaca: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.now)


class LogAktivitas(Base):
    __tablename__ = "log_aktivitas"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_id: Mapped[int | None] = mapped_column(Integer, nullable=True, index=True)
    service: Mapped[str] = mapped_column(String(30), default="")
    aksi: Mapped[str] = mapped_column(String(255))
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.now)


# ------------------------------- Schema --------------------------------- #
class NotifOut(BaseModel):
    id: int
    judul: str
    isi: str
    link: str
    dibaca: bool
    created_at: datetime
    model_config = {"from_attributes": True}


class NotifIn(BaseModel):
    user_id: int
    judul: str
    isi: str = ""
    link: str = ""


class NotifRoleIn(BaseModel):
    role: str
    judul: str
    isi: str = ""
    link: str = ""


class LogIn(BaseModel):
    user_id: int | None = None
    aksi: str
    service: str = ""


class LogOut(BaseModel):
    id: int
    user_id: int | None
    service: str
    aksi: str
    created_at: datetime
    model_config = {"from_attributes": True}


# -------------------------------- App ----------------------------------- #
app = create_service("Notifikasi Service", "Notifikasi pengguna dan jejak audit (log aktivitas) lintas service.")
Base.metadata.create_all(engine)
r = APIRouter(prefix="/notifikasi", tags=["Notifikasi"])
logs = APIRouter(prefix="/log", tags=["Log Aktivitas (admin)"])
internal = APIRouter(prefix="/internal", tags=["Internal"], dependencies=[Depends(internal_only)])


@r.get("", response_model=list[NotifOut])
def my_notifications(hanya_belum_dibaca: bool = False, limit: int = 100,
                     cu: CurrentUser = Depends(get_current_user), db: Session = Depends(get_db)):
    q = db.query(Notifikasi).filter(Notifikasi.user_id == cu.id)
    if hanya_belum_dibaca:
        q = q.filter(Notifikasi.dibaca.is_(False))
    return q.order_by(Notifikasi.created_at.desc()).limit(limit).all()


@r.get("/jumlah-belum-dibaca")
def unread_count(cu: CurrentUser = Depends(get_current_user), db: Session = Depends(get_db)):
    return {"jumlah": db.query(Notifikasi).filter(Notifikasi.user_id == cu.id, Notifikasi.dibaca.is_(False)).count()}


@r.post("/baca-semua", response_model=Msg)
def read_all(cu: CurrentUser = Depends(get_current_user), db: Session = Depends(get_db)):
    db.query(Notifikasi).filter(Notifikasi.user_id == cu.id, Notifikasi.dibaca.is_(False)).update({"dibaca": True})
    db.commit()
    return Msg(detail="Semua notifikasi ditandai dibaca")


@r.patch("/{nid}/baca", response_model=NotifOut)
def read_one(nid: int, cu: CurrentUser = Depends(get_current_user), db: Session = Depends(get_db)):
    n = db.get(Notifikasi, nid)
    if not n or n.user_id != cu.id:
        raise HTTPException(404, "Notifikasi tidak ditemukan")
    n.dibaca = True
    db.commit()
    return n


@logs.get("", response_model=Page[LogOut], dependencies=[Depends(require_roles("admin"))])
def list_logs(page: int = 1, per_page: int = 50, user_id: int | None = None, db: Session = Depends(get_db)):
    q = db.query(LogAktivitas)
    if user_id:
        q = q.filter(LogAktivitas.user_id == user_id)
    return paginate(q.order_by(LogAktivitas.created_at.desc()), page, per_page, LogOut)


@internal.post("/notifikasi", status_code=201)
def internal_notify(data: NotifIn, db: Session = Depends(get_db)):
    db.add(Notifikasi(**data.model_dump()))
    db.commit()
    return {"ok": True}


@internal.post("/notifikasi/role", status_code=201)
def internal_notify_role(data: NotifRoleIn, db: Session = Depends(get_db)):
    users = call(settings.AUTH_URL, "GET", "/internal/users", params={"role": data.role}) or []
    for u in users:
        db.add(Notifikasi(user_id=u["id"], judul=data.judul, isi=data.isi, link=data.link))
    db.commit()
    return {"ok": True, "jumlah": len(users)}


@internal.post("/log", status_code=201)
def internal_log(data: LogIn, db: Session = Depends(get_db)):
    db.add(LogAktivitas(**data.model_dump()))
    db.commit()
    return {"ok": True}


@internal.get("/log/terbaru", response_model=list[LogOut])
def internal_recent(limit: int = 10, db: Session = Depends(get_db)):
    return db.query(LogAktivitas).order_by(LogAktivitas.created_at.desc()).limit(limit).all()


app.include_router(r)
app.include_router(logs)
app.include_router(internal)
