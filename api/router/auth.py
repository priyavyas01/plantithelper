from fastapi import APIRouter, Depends, HTTPException, status, Request
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
import hashlib
import secrets
import random
import string
import uuid
from datetime import datetime, timezone, timedelta

from db.database import get_db
from models.user import User
from models.refresh_token import RefreshToken
from models.password_reset_token import PasswordResetToken
from schemas.auth import (
    RegisterRequest, LoginRequest, TokenResponse, RefreshRequest,
    UserResponse, ForgotPasswordRequest, ResetPasswordRequest,
)
from services.auth_service import (
    hash_password, verify_password,
    create_access_token, create_refresh_token, decode_access_token
)
from services.email_service import send_password_reset_email
from core.limiter import limiter

router = APIRouter(prefix="/auth", tags=["auth"])

# HTTPBearer extracts the token from the "Authorization: Bearer <token>" header.
# auto_error=False means we handle the 401 ourselves with a clear message.
bearer_scheme = HTTPBearer(auto_error=False)


# --- Dependency: get the current authenticated user ---
# Any endpoint that needs auth declares: current_user: User = Depends(get_current_user)

async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(bearer_scheme),
    db: AsyncSession = Depends(get_db),
) -> User:
    if not credentials:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Not authenticated")

    payload = decode_access_token(credentials.credentials)
    if not payload:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid or expired token")

    user_id = payload.get("sub")
    # SQLAlchemy's UUID column expects a uuid.UUID object, not a plain string.
    # The JWT stores user_id as a string — convert it before querying.
    try:
        user_uuid = uuid.UUID(user_id)
    except (TypeError, ValueError):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token payload")
    result = await db.execute(select(User).where(User.id == user_uuid))
    user = result.scalar_one_or_none()

    if not user:
        # Token was valid but user was deleted — force re-login
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User no longer exists")

    return user


# --- POST /auth/register ---

@router.post("/register", response_model=TokenResponse, status_code=status.HTTP_201_CREATED)
@limiter.limit("5/minute")  # prevent automated account creation
async def register(request: Request, body: RegisterRequest, db: AsyncSession = Depends(get_db)):
    # Check for existing email
    result = await db.execute(select(User).where(User.email == body.email))
    if result.scalar_one_or_none():
        # We DO reveal "email already registered" here intentionally.
        # On registration, there's no security risk — the user is trying to create
        # an account. Hiding this just creates bad UX with no security benefit.
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Email already registered")

    user = User(email=body.email, hashed_password=hash_password(body.password))
    db.add(user)
    await db.flush()  # flush to get user.id without committing yet

    raw_token, token_hash, expires_at = create_refresh_token()
    refresh = RefreshToken(user_id=user.id, token_hash=token_hash, expires_at=expires_at)
    db.add(refresh)

    await db.commit()

    return TokenResponse(
        access_token=create_access_token(str(user.id)),
        refresh_token=raw_token,
    )


# --- POST /auth/login ---

@router.post("/login", response_model=TokenResponse)
@limiter.limit("10/minute")  # brute force protection — 10 attempts/min per IP
async def login(request: Request, body: LoginRequest, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).where(User.email == body.email))
    user = result.scalar_one_or_none()

    # SECURITY: same error for wrong email OR wrong password.
    # If we said "email not found" vs "wrong password", an attacker could
    # enumerate which emails are registered in your system.
    if not user or not verify_password(body.password, user.hashed_password):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid credentials")

    raw_token, token_hash, expires_at = create_refresh_token()
    refresh = RefreshToken(user_id=user.id, token_hash=token_hash, expires_at=expires_at)
    db.add(refresh)
    await db.commit()

    return TokenResponse(
        access_token=create_access_token(str(user.id)),
        refresh_token=raw_token,
    )


# --- POST /auth/refresh ---

@router.post("/refresh", response_model=TokenResponse)
async def refresh(body: RefreshRequest, db: AsyncSession = Depends(get_db)):
    token_hash = hashlib.sha256(body.refresh_token.encode()).hexdigest()

    result = await db.execute(
        select(RefreshToken).where(RefreshToken.token_hash == token_hash)
    )
    stored = result.scalar_one_or_none()

    # All failure cases return the same 401 — don't hint why it failed
    if (
        not stored
        or stored.revoked
        or stored.expires_at < datetime.now(timezone.utc)
    ):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid or expired refresh token")

    # TOKEN ROTATION: revoke the old token, issue a new pair.
    # This means a refresh token can only be used once. If it's stolen and
    # used by an attacker first, the real user's next refresh will fail — alerting them.
    stored.revoked = True

    raw_token, new_hash, expires_at = create_refresh_token()
    new_refresh = RefreshToken(user_id=stored.user_id, token_hash=new_hash, expires_at=expires_at)
    db.add(new_refresh)
    await db.commit()

    return TokenResponse(
        access_token=create_access_token(str(stored.user_id)),
        refresh_token=raw_token,
    )


# --- POST /auth/logout ---

@router.post("/logout", status_code=status.HTTP_204_NO_CONTENT)
async def logout(body: RefreshRequest, db: AsyncSession = Depends(get_db)):
    token_hash = hashlib.sha256(body.refresh_token.encode()).hexdigest()
    result = await db.execute(
        select(RefreshToken).where(RefreshToken.token_hash == token_hash)
    )
    stored = result.scalar_one_or_none()
    if stored:
        stored.revoked = True
        await db.commit()
    # Always return 204 even if token wasn't found — don't leak whether it existed


# --- GET /auth/me ---

@router.get("/me", response_model=UserResponse)
async def me(current_user: User = Depends(get_current_user)):
    # get_current_user already did all the work — just return the user
    return current_user


# --- POST /auth/forgot-password ---

@router.post("/forgot-password", status_code=status.HTTP_204_NO_CONTENT)
@limiter.limit("3/minute")
async def forgot_password(request: Request, body: ForgotPasswordRequest, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).where(User.email == body.email.lower()))
    user = result.scalar_one_or_none()

    # Always return 204 even if email not found — don't reveal whether it's registered
    if not user:
        return

    # Generate a 6-digit numeric code
    code = ''.join(random.choices(string.digits, k=6))
    code_hash = hashlib.sha256(code.encode()).hexdigest()
    expires_at = datetime.now(timezone.utc) + timedelta(minutes=15)

    reset_token = PasswordResetToken(
        user_id=user.id,
        code_hash=code_hash,
        expires_at=expires_at,
    )
    db.add(reset_token)
    await db.commit()

    send_password_reset_email(to_email=user.email, code=code)


# --- POST /auth/reset-password ---

@router.post("/reset-password", status_code=status.HTTP_204_NO_CONTENT)
@limiter.limit("5/minute")
async def reset_password(request: Request, body: ResetPasswordRequest, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).where(User.email == body.email.lower()))
    user = result.scalar_one_or_none()

    code_hash = hashlib.sha256(body.code.encode()).hexdigest()

    token_result = await db.execute(
        select(PasswordResetToken).where(
            PasswordResetToken.user_id == user.id if user else PasswordResetToken.code_hash == code_hash,
            PasswordResetToken.code_hash == code_hash,
        )
    )
    token = token_result.scalar_one_or_none()

    # Same error for all failure cases — don't hint at what went wrong
    if (
        not user
        or not token
        or token.used
        or token.expires_at.replace(tzinfo=timezone.utc) < datetime.now(timezone.utc)
    ):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid or expired code")

    user.hashed_password = hash_password(body.new_password)
    token.used = True
    await db.commit()
