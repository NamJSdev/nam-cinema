import base64
import hashlib
import hmac
import secrets
import uuid
from datetime import datetime, timedelta, timezone
from typing import Any
from urllib.parse import parse_qsl, urlencode, urlparse, urlunparse

import jwt
from fastapi import Depends
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.exceptions import AuthenticationError
from app.db.session import get_db_session
from app.models.entities import User

try:
    from argon2 import PasswordHasher
    from argon2.exceptions import InvalidHashError, VerifyMismatchError

    _argon2_hasher: PasswordHasher | None = PasswordHasher(
        time_cost=2,
        memory_cost=65536,
        parallelism=2,
        hash_len=32,
        salt_len=16,
    )
except Exception:
    _argon2_hasher = None

bearer_scheme = HTTPBearer(auto_error=False)


def hash_password(plain_password: str) -> str:
    if _argon2_hasher is not None:
        return _argon2_hasher.hash(plain_password)
    # Fallback to stdlib scrypt when Windows Application Control blocks unsigned third-party C extensions
    salt = secrets.token_bytes(16)
    derived = hashlib.scrypt(
        plain_password.encode("utf-8"),
        salt=salt,
        n=16384,
        r=8,
        p=1,
        dklen=32,
    )
    salt_b64 = base64.b64encode(salt).decode("ascii")
    dk_b64 = base64.b64encode(derived).decode("ascii")
    return f"$scrypt$n=16384,r=8,p=1${salt_b64}${dk_b64}"


def verify_password(plain_password: str, password_hash: str) -> bool:
    if password_hash.startswith("$argon2") and _argon2_hasher is not None:
        try:
            return _argon2_hasher.verify(password_hash, plain_password)
        except (VerifyMismatchError, InvalidHashError):
            return False
    if password_hash.startswith("$scrypt$"):
        try:
            parts = password_hash.split("$")
            salt = base64.b64decode(parts[3])
            expected = base64.b64decode(parts[4])
            candidate = hashlib.scrypt(
                plain_password.encode("utf-8"),
                salt=salt,
                n=16384,
                r=8,
                p=1,
                dklen=len(expected),
            )
            return hmac.compare_digest(candidate, expected)
        except Exception:
            return False
    return False


def hash_token(raw_token: str) -> str:
    return hashlib.sha256(raw_token.encode("utf-8")).hexdigest()


def create_access_token(user_id: uuid.UUID, email: str) -> tuple[str, int]:
    settings = get_settings()
    now = datetime.now(timezone.utc)
    expires_delta = timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    expires_at = now + expires_delta
    payload: dict[str, Any] = {
        "sub": str(user_id),
        "email": email,
        "type": "access",
        "jti": secrets.token_hex(16),
        "iat": int(now.timestamp()),
        "exp": int(expires_at.timestamp()),
    }
    token = jwt.encode(payload, settings.JWT_SECRET_KEY, algorithm=settings.JWT_ALGORITHM)
    return token, int(expires_delta.total_seconds())


def create_refresh_token(user_id: uuid.UUID) -> tuple[str, str, datetime]:
    settings = get_settings()
    now = datetime.now(timezone.utc)
    expires_at = now + timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS)
    jti = secrets.token_hex(24)
    payload: dict[str, Any] = {
        "sub": str(user_id),
        "type": "refresh",
        "jti": jti,
        "iat": int(now.timestamp()),
        "exp": int(expires_at.timestamp()),
    }
    token = jwt.encode(payload, settings.JWT_SECRET_KEY, algorithm=settings.JWT_ALGORITHM)
    return token, jti, expires_at


def decode_jwt_token(token: str, expected_type: str) -> dict[str, Any]:
    settings = get_settings()
    try:
        payload = jwt.decode(
            token,
            settings.JWT_SECRET_KEY,
            algorithms=[settings.JWT_ALGORITHM],
        )
    except jwt.ExpiredSignatureError as exc:
        raise AuthenticationError("Token has expired.") from exc
    except jwt.InvalidTokenError as exc:
        raise AuthenticationError("Invalid authentication token.") from exc

    if payload.get("type") != expected_type:
        raise AuthenticationError(f"Expected {expected_type} token.")
    return payload


def sign_manifest_url(
    manifest_url: str,
    session_id: uuid.UUID,
    user_id: uuid.UUID,
    expires_at: datetime,
) -> str:
    """Signs a playback manifest URL with an expiring HMAC-SHA256 signature."""
    settings = get_settings()
    exp_ts = int(expires_at.timestamp())
    message = f"{manifest_url}|{session_id}|{user_id}|{exp_ts}".encode("utf-8")
    signature = hmac.new(
        settings.PLAYBACK_SIGNING_SECRET.encode("utf-8"),
        message,
        hashlib.sha256,
    ).hexdigest()

    parsed = urlparse(manifest_url)
    query_params = dict(parse_qsl(parsed.query))
    query_params.update(
        {
            "nc_sid": str(session_id),
            "nc_exp": str(exp_ts),
            "nc_sig": signature,
        }
    )
    return urlunparse(parsed._replace(query=urlencode(query_params)))


PERSONAL_USER_ID = uuid.UUID("00000000-0000-0000-0000-000000000001")
PERSONAL_USER_EMAIL = "personal@namcinema.vn"


async def get_or_create_personal_user(db: AsyncSession) -> User:
    stmt = select(User).where(User.email == PERSONAL_USER_EMAIL)
    user = (await db.execute(stmt)).scalar_one_or_none()
    if user is not None:
        return user
    user = User(
        id=PERSONAL_USER_ID,
        email=PERSONAL_USER_EMAIL,
        full_name="Nam Cinema Cá Nhân",
        password_hash=hash_password("PersonalMode!2026"),
        preferred_language="vi-VN",
        is_active=True,
    )
    db.add(user)
    await db.commit()
    await db.refresh(user)
    return user


async def get_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
    db: AsyncSession = Depends(get_db_session),
) -> User:
    settings = get_settings()
    if credentials is None or not credentials.credentials:
        if settings.PERSONAL_MODE_ENABLED:
            return await get_or_create_personal_user(db)
        raise AuthenticationError("Missing Bearer authentication token.")
    payload = decode_jwt_token(credentials.credentials, expected_type="access")
    try:
        user_id = uuid.UUID(payload["sub"])
    except (KeyError, ValueError) as exc:
        raise AuthenticationError("Malformed token subject.") from exc

    stmt = select(User).where(User.id == user_id, User.is_active.is_(True))
    result = await db.execute(stmt)
    user = result.scalar_one_or_none()
    if user is None:
        if settings.PERSONAL_MODE_ENABLED:
            return await get_or_create_personal_user(db)
        raise AuthenticationError("User account not found or inactive.")
    return user


async def get_optional_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
    db: AsyncSession = Depends(get_db_session),
) -> User | None:
    settings = get_settings()
    if credentials is None or not credentials.credentials:
        if settings.PERSONAL_MODE_ENABLED:
            return await get_or_create_personal_user(db)
        return None
    try:
        return await get_current_user(credentials=credentials, db=db)
    except AuthenticationError:
        if settings.PERSONAL_MODE_ENABLED:
            return await get_or_create_personal_user(db)
        return None
