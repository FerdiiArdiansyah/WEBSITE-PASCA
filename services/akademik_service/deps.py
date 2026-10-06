"""Dependensi bersama: sesi DB, tahun akademik aktif, profil pengguna saat ini."""
from fastapi import Depends, HTTPException
from sqlalchemy.orm import Session

from services.common.auth import CurrentUser, get_current_user

from . import models as m
from .models import get_db


def ta_aktif(db: Session) -> m.TahunAkademik | None:
    return db.query(m.TahunAkademik).filter(m.TahunAkademik.aktif.is_(True)).first()


def ta_aktif_or_400(db: Session) -> m.TahunAkademik:
    ta = ta_aktif(db)
    if not ta:
        raise HTTPException(400, "Tahun akademik aktif belum diatur")
    return ta


def mahasiswa_saya(cu: CurrentUser = Depends(get_current_user), db: Session = Depends(get_db)) -> m.Mahasiswa:
    if cu.role != "mahasiswa":
        raise HTTPException(403, "Hanya untuk mahasiswa")
    mhs = db.query(m.Mahasiswa).filter(m.Mahasiswa.user_id == cu.id).first()
    if not mhs:
        raise HTTPException(404, "Profil mahasiswa tidak ditemukan")
    return mhs


def dosen_saya(cu: CurrentUser = Depends(get_current_user), db: Session = Depends(get_db)) -> m.Dosen:
    if cu.role != "dosen":
        raise HTTPException(403, "Hanya untuk dosen")
    d = db.query(m.Dosen).filter(m.Dosen.user_id == cu.id).first()
    if not d:
        raise HTTPException(404, "Profil dosen tidak ditemukan")
    return d


def get_or_404(db: Session, model, oid: int, nama="Data"):
    obj = db.get(model, oid)
    if not obj:
        raise HTTPException(404, f"{nama} tidak ditemukan")
    return obj
