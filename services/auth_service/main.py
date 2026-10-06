from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import or_
from sqlalchemy.orm import Session

from services.common.auth import (
    CurrentUser, create_token, get_current_user, hash_password, internal_only, require_roles, verify_password,
)
from services.common.http import audit
from services.common.utils import Msg, create_service

from .models import Base, User, engine, get_db
from .schemas import LoginIn, PasswordChange, TokenOut, UserCreate, UserOut, UserPatch, UserUpdateMe

app = create_service("Auth Service", "Autentikasi JWT, akun pengguna, dan peran (admin/dosen/mahasiswa).")
Base.metadata.create_all(engine)

auth = APIRouter(prefix="/auth", tags=["Autentikasi"])
users = APIRouter(prefix="/users", tags=["Pengguna (admin)"])
internal = APIRouter(prefix="/internal", tags=["Internal"], dependencies=[Depends(internal_only)])


def _to_current(u: User) -> CurrentUser:
    return CurrentUser(id=u.id, username=u.username, nama=u.nama, role=u.role, email=u.email)


def _create_user(db: Session, data: UserCreate) -> User:
    if db.query(User).filter(or_(User.username == data.username, User.email == data.email)).first():
        raise HTTPException(409, "Username atau email sudah digunakan")
    u = User(username=data.username, email=data.email, nama=data.nama, role=data.role, telepon=data.telepon,
             password_hash=hash_password(data.password or data.username))
    db.add(u)
    db.commit()
    db.refresh(u)
    return u


# =============================== AUTH =================================== #
@auth.post("/login", response_model=TokenOut)
def login(data: LoginIn, db: Session = Depends(get_db)):
    u = db.query(User).filter(or_(User.username == data.username, User.email == data.username)).first()
    if not u or not verify_password(data.password, u.password_hash):
        raise HTTPException(401, "Username atau password salah")
    if not u.aktif:
        raise HTTPException(403, "Akun dinonaktifkan. Hubungi bagian akademik.")
    u.last_login = datetime.now()
    db.commit()
    audit(u.id, "Login ke sistem", "auth")
    return TokenOut(access_token=create_token(_to_current(u)), user=UserOut.model_validate(u))


@auth.get("/me", response_model=UserOut)
def me(cu: CurrentUser = Depends(get_current_user), db: Session = Depends(get_db)):
    return db.get(User, cu.id)


@auth.put("/me", response_model=UserOut)
def update_me(data: UserUpdateMe, cu: CurrentUser = Depends(get_current_user), db: Session = Depends(get_db)):
    u = db.get(User, cu.id)
    if data.email and data.email != u.email and db.query(User).filter(User.email == data.email).first():
        raise HTTPException(409, "Email sudah digunakan")
    for k, v in data.model_dump(exclude_none=True).items():
        setattr(u, k, v)
    db.commit()
    audit(u.id, "Memperbarui profil", "auth")
    return u


@auth.put("/me/password", response_model=Msg)
def change_password(data: PasswordChange, cu: CurrentUser = Depends(get_current_user), db: Session = Depends(get_db)):
    u = db.get(User, cu.id)
    if not verify_password(data.password_lama, u.password_hash):
        raise HTTPException(400, "Password lama salah")
    u.password_hash = hash_password(data.password_baru)
    db.commit()
    audit(u.id, "Mengganti password", "auth")
    return Msg(detail="Password berhasil diganti")


@auth.post("/refresh", response_model=TokenOut)
def refresh(cu: CurrentUser = Depends(get_current_user), db: Session = Depends(get_db)):
    u = db.get(User, cu.id)
    if not u or not u.aktif:
        raise HTTPException(401, "Akun tidak aktif")
    return TokenOut(access_token=create_token(_to_current(u)), user=UserOut.model_validate(u))


# =============================== USERS ================================== #
@users.get("", response_model=list[UserOut], dependencies=[Depends(require_roles("admin"))])
def list_users(role: str | None = None, q: str | None = None, db: Session = Depends(get_db)):
    qry = db.query(User)
    if role:
        qry = qry.filter(User.role == role)
    if q:
        qry = qry.filter(or_(User.nama.ilike(f"%{q}%"), User.username.ilike(f"%{q}%"), User.email.ilike(f"%{q}%")))
    return qry.order_by(User.role, User.nama).all()


@users.post("", response_model=UserOut, status_code=201)
def create_user(data: UserCreate, cu: CurrentUser = Depends(require_roles("admin")), db: Session = Depends(get_db)):
    u = _create_user(db, data)
    audit(cu.id, f"Menambah pengguna {u.username} ({u.role})", "auth")
    return u


@users.patch("/{uid}", response_model=UserOut)
def patch_user(uid: int, data: UserPatch, cu: CurrentUser = Depends(require_roles("admin")), db: Session = Depends(get_db)):
    u = db.get(User, uid)
    if not u:
        raise HTTPException(404, "Pengguna tidak ditemukan")
    if u.id == cu.id and data.aktif is False:
        raise HTTPException(400, "Tidak dapat menonaktifkan akun sendiri")
    if data.aktif is not None:
        u.aktif = data.aktif
    if data.reset_password:
        u.password_hash = hash_password(u.username)
    if data.nama:
        u.nama = data.nama
    if data.email:
        u.email = data.email
    db.commit()
    audit(cu.id, f"Mengubah pengguna {u.username}", "auth")
    return u


@users.delete("/{uid}", response_model=Msg)
def delete_user(uid: int, cu: CurrentUser = Depends(require_roles("admin")), db: Session = Depends(get_db)):
    u = db.get(User, uid)
    if not u:
        raise HTTPException(404, "Pengguna tidak ditemukan")
    if u.id == cu.id:
        raise HTTPException(400, "Tidak dapat menghapus akun sendiri")
    db.delete(u)
    db.commit()
    audit(cu.id, f"Menghapus pengguna {u.username}", "auth")
    return Msg(detail="Pengguna dihapus")


# ============================== INTERNAL ================================ #
@internal.post("/users", response_model=UserOut, status_code=201)
def internal_create(data: UserCreate, db: Session = Depends(get_db)):
    return _create_user(db, data)


@internal.get("/users/{uid}", response_model=UserOut)
def internal_get(uid: int, db: Session = Depends(get_db)):
    u = db.get(User, uid)
    if not u:
        raise HTTPException(404, "Pengguna tidak ditemukan")
    return u


@internal.put("/users/{uid}", response_model=UserOut)
def internal_update(uid: int, data: UserUpdateMe, db: Session = Depends(get_db)):
    u = db.get(User, uid)
    if not u:
        raise HTTPException(404, "Pengguna tidak ditemukan")
    for k, v in data.model_dump(exclude_none=True).items():
        setattr(u, k, v)
    db.commit()
    return u


@internal.delete("/users/{uid}", status_code=204)
def internal_delete(uid: int, db: Session = Depends(get_db)):
    u = db.get(User, uid)
    if u:
        db.delete(u)
        db.commit()


@internal.get("/users", response_model=list[UserOut])
def internal_list(ids: str | None = Query(default=None, description="daftar id dipisah koma"),
                  role: str | None = None, db: Session = Depends(get_db)):
    qry = db.query(User)
    if ids:
        qry = qry.filter(User.id.in_([int(i) for i in ids.split(",") if i.strip().isdigit()]))
    if role:
        qry = qry.filter(User.role == role, User.aktif.is_(True))
    return qry.all()


app.include_router(auth)
app.include_router(users)
app.include_router(internal)
