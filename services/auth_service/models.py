from datetime import datetime

from sqlalchemy import Boolean, DateTime, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from services.common.db import Base, make_session_factory

engine, SessionLocal, get_db = make_session_factory("auth")


class User(Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    username: Mapped[str] = mapped_column(String(50), unique=True, index=True)
    email: Mapped[str] = mapped_column(String(120), unique=True)
    password_hash: Mapped[str] = mapped_column(String(255))
    nama: Mapped[str] = mapped_column(String(150))
    role: Mapped[str] = mapped_column(String(20), index=True)
    aktif: Mapped[bool] = mapped_column(Boolean, default=True)
    telepon: Mapped[str | None] = mapped_column(String(30), nullable=True)
    foto: Mapped[str | None] = mapped_column(String(255), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.now)
    last_login: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
