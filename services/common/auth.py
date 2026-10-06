import hashlib
import hmac
import secrets
from datetime import datetime, timedelta, timezone

import jwt
from fastapi import Depends, Header, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from pydantic import BaseModel

from .config import settings

bearer = HTTPBearer(auto_error=False)

ROLES = ("admin", "dosen", "mahasiswa")


# ----------------------------- Password --------------------------------- #
def hash_password(password: str) -> str:
    salt = secrets.token_hex(16)
    digest = hashlib.pbkdf2_hmac("sha256", password.encode(), salt.encode(), 200_000).hex()
    return f"pbkdf2_sha256$200000${salt}${digest}"


def verify_password(password: str, stored: str) -> bool:
    try:
        _, iters, salt, digest = stored.split("$")
        calc = hashlib.pbkdf2_hmac("sha256", password.encode(), salt.encode(), int(iters)).hex()
        return hmac.compare_digest(calc, digest)
    except ValueError:
        return False


# ------------------------------- JWT ------------------------------------ #
class CurrentUser(BaseModel):
    id: int
    username: str
    nama: str
    role: str
    email: str = ""


def create_token(user: CurrentUser) -> str:
    payload = {
        **user.model_dump(),
        "sub": str(user.id),
        "exp": datetime.now(timezone.utc) + timedelta(minutes=settings.JWT_EXPIRE_MINUTES),
        "iat": datetime.now(timezone.utc),
    }
    return jwt.encode(payload, settings.SECRET_KEY, algorithm=settings.JWT_ALGORITHM)


def decode_token(token: str) -> CurrentUser:
    try:
        data = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.JWT_ALGORITHM])
    except jwt.ExpiredSignatureError:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Token kedaluwarsa")
    except jwt.PyJWTError:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Token tidak valid")
    return CurrentUser(id=int(data["sub"]), username=data["username"], nama=data["nama"],
                       role=data["role"], email=data.get("email", ""))


def get_current_user(cred: HTTPAuthorizationCredentials | None = Depends(bearer)) -> CurrentUser:
    if cred is None:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Autentikasi diperlukan",
                            headers={"WWW-Authenticate": "Bearer"})
    return decode_token(cred.credentials)


def require_roles(*roles: str):
    def dep(user: CurrentUser = Depends(get_current_user)) -> CurrentUser:
        if user.role not in roles:
            raise HTTPException(status.HTTP_403_FORBIDDEN, "Anda tidak memiliki akses")
        return user
    return dep


def internal_only(x_internal_key: str = Header(default="")):
    """Lindungi endpoint komunikasi antar-service."""
    if not hmac.compare_digest(x_internal_key, settings.INTERNAL_KEY):
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Akses internal ditolak")
