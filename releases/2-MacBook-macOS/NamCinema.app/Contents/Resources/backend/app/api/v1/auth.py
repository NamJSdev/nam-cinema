from datetime import datetime, timezone
from fastapi import APIRouter, Depends, Request, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.cache import cache_backend
from app.core.config import get_settings
from app.core.exceptions import (
    AuthenticationError,
    ConflictError,
    RateLimitExceededError,
)
from app.db.session import get_db_session
from app.models.entities import RefreshToken, User
from app.schemas.api import (
    AuthTokenResponse,
    LoginRequest,
    LogoutRequest,
    RefreshTokenRequest,
    RegisterRequest,
    UserResponse,
)
from app.security.auth import (
    create_access_token,
    create_refresh_token,
    decode_jwt_token,
    get_current_user,
    hash_password,
    hash_token,
    verify_password,
)

router = APIRouter(prefix="/auth", tags=["Authentication"])


async def _issue_token_pair(
    db: AsyncSession,
    user: User,
    device_info: str | None = None,
) -> AuthTokenResponse:
    access_token, expires_in = create_access_token(user.id, user.email)
    refresh_raw, jti, expires_at = create_refresh_token(user.id)

    token_row = RefreshToken(
        user_id=user.id,
        token_hash=hash_token(refresh_raw),
        jti=jti,
        expires_at=expires_at,
        device_info=device_info,
    )
    db.add(token_row)
    await db.commit()
    await db.refresh(user)

    return AuthTokenResponse(
        access_token=access_token,
        refresh_token=refresh_raw,
        token_type="Bearer",
        expires_in=expires_in,
        user=UserResponse.model_validate(user),
    )


@router.post("/register", response_model=AuthTokenResponse, status_code=status.HTTP_201_CREATED)
async def register_user(
    payload: RegisterRequest,
    db: AsyncSession = Depends(get_db_session),
) -> AuthTokenResponse:
    normalized_email = payload.email.strip().lower()
    existing_stmt = select(User).where(User.email == normalized_email)
    existing = (await db.execute(existing_stmt)).scalar_one_or_none()
    if existing is not None:
        raise ConflictError("An account with this email address already exists.")

    user = User(
        email=normalized_email,
        full_name=payload.full_name.strip(),
        password_hash=hash_password(payload.password),
        preferred_language=payload.preferred_language,
        is_active=True,
    )
    db.add(user)
    await db.flush()
    return await _issue_token_pair(db, user)


@router.post("/login", response_model=AuthTokenResponse)
async def login_user(
    payload: LoginRequest,
    request: Request,
    db: AsyncSession = Depends(get_db_session),
) -> AuthTokenResponse:
    settings = get_settings()
    client_ip = request.client.host if request.client else "local"
    normalized_email = payload.email.strip().lower()
    rate_key = f"login:{client_ip}:{normalized_email}"

    allowed = await cache_backend.check_rate_limit(
        rate_key,
        max_requests=settings.LOGIN_RATE_LIMIT_REQUESTS,
        window_seconds=settings.LOGIN_RATE_LIMIT_WINDOW_SECONDS,
    )
    if not allowed:
        raise RateLimitExceededError(retry_after_seconds=settings.LOGIN_RATE_LIMIT_WINDOW_SECONDS)

    stmt = select(User).where(User.email == normalized_email)
    user = (await db.execute(stmt)).scalar_one_or_none()
    if user is None or not user.is_active:
        raise AuthenticationError("Invalid email or password.")

    if not verify_password(payload.password, user.password_hash):
        raise AuthenticationError("Invalid email or password.")

    return await _issue_token_pair(db, user, device_info=payload.device_info)


@router.post("/refresh", response_model=AuthTokenResponse)
async def refresh_access_token(
    payload: RefreshTokenRequest,
    db: AsyncSession = Depends(get_db_session),
) -> AuthTokenResponse:
    claims = decode_jwt_token(payload.refresh_token, expected_type="refresh")
    token_hash_val = hash_token(payload.refresh_token)
    jti = claims.get("jti", "")

    stmt = select(RefreshToken).where(
        RefreshToken.token_hash == token_hash_val,
        RefreshToken.jti == jti,
    )
    stored_token = (await db.execute(stmt)).scalar_one_or_none()
    now = datetime.now(timezone.utc)

    if stored_token is None or stored_token.revoked_at is not None:
        raise AuthenticationError("Refresh token has been revoked or is invalid.")

    expires_at = stored_token.expires_at
    if expires_at.tzinfo is None:
        expires_at = expires_at.replace(tzinfo=timezone.utc)
    if expires_at <= now:
        raise AuthenticationError("Refresh token has expired.")

    user_stmt = select(User).where(User.id == stored_token.user_id, User.is_active.is_(True))
    user = (await db.execute(user_stmt)).scalar_one_or_none()
    if user is None:
        raise AuthenticationError("User account is inactive or missing.")

    # Rotate refresh token on use
    stored_token.revoked_at = now
    return await _issue_token_pair(db, user, device_info=stored_token.device_info)


@router.post("/logout", status_code=status.HTTP_200_OK)
async def logout_user(
    payload: LogoutRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db_session),
) -> dict[str, str]:
    now = datetime.now(timezone.utc)
    if payload.refresh_token:
        target_hash = hash_token(payload.refresh_token)
        stmt = select(RefreshToken).where(
            RefreshToken.user_id == current_user.id,
            RefreshToken.token_hash == target_hash,
            RefreshToken.revoked_at.is_(None),
        )
        token_row = (await db.execute(stmt)).scalar_one_or_none()
        if token_row is not None:
            token_row.revoked_at = now
    else:
        stmt = select(RefreshToken).where(
            RefreshToken.user_id == current_user.id,
            RefreshToken.revoked_at.is_(None),
        )
        for row in (await db.execute(stmt)).scalars().all():
            row.revoked_at = now

    await db.commit()
    return {"status": "logged_out"}


@router.get("/me", response_model=UserResponse)
async def get_me(current_user: User = Depends(get_current_user)) -> UserResponse:
    return UserResponse.model_validate(current_user)
