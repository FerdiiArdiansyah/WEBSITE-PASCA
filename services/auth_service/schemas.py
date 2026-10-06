from datetime import datetime

from pydantic import BaseModel, EmailStr, Field


class LoginIn(BaseModel):
    username: str
    password: str


class UserOut(BaseModel):
    id: int
    username: str
    email: str
    nama: str
    role: str
    aktif: bool
    telepon: str | None = None
    foto: str | None = None
    created_at: datetime | None = None
    last_login: datetime | None = None
    model_config = {"from_attributes": True}


class TokenOut(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserOut


class UserCreate(BaseModel):
    username: str = Field(min_length=3, max_length=50)
    email: EmailStr
    nama: str = Field(min_length=2)
    role: str = Field(pattern="^(admin|dosen|mahasiswa)$")
    password: str | None = None
    telepon: str | None = None


class UserUpdateMe(BaseModel):
    nama: str | None = None
    email: EmailStr | None = None
    telepon: str | None = None
    foto: str | None = None


class PasswordChange(BaseModel):
    password_lama: str
    password_baru: str = Field(min_length=8)


class UserPatch(BaseModel):
    aktif: bool | None = None
    reset_password: bool = False
    nama: str | None = None
    email: EmailStr | None = None
