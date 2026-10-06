"""Setiap service memiliki database sendiri (database-per-service)."""
from sqlalchemy import create_engine
from sqlalchemy.orm import DeclarativeBase, sessionmaker

from .config import settings


class Base(DeclarativeBase):
    pass


def make_session_factory(service_name: str):
    url = f"sqlite:///{settings.DATA_DIR / (service_name + '.db')}"
    engine = create_engine(url, connect_args={"check_same_thread": False})
    SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False)

    def get_db():
        db = SessionLocal()
        try:
            yield db
        finally:
            db.close()

    return engine, SessionLocal, get_db
