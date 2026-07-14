import bcrypt
from jose import JWTError, jwt
from datetime import datetime, timedelta, timezone
from typing import Optional
import hashlib
import secrets
import os

from dotenv import load_dotenv
load_dotenv()

SECRET_KEY = os.getenv("SECRET_KEY")
if not SECRET_KEY:
    raise RuntimeError("SECRET_KEY is not set in .env")

ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 15
REFRESH_TOKEN_EXPIRE_DAYS = 7


# --- Password Hashing ---
# bcrypt is a one-way hashing algorithm designed specifically for passwords.
# It's intentionally slow (work factor), which makes brute-force attacks expensive.
# gensalt() generates a random "salt" — a unique value mixed into each hash so
# two users with the same password get different hashes. This prevents
# "rainbow table" attacks (precomputed lists of common password hashes).

def hash_password(password: str) -> str:
    return bcrypt.hashpw(password.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")


def verify_password(plain: str, hashed: str) -> bool:
    return bcrypt.checkpw(plain.encode("utf-8"), hashed.encode("utf-8"))


# --- JWT Creation ---
# A JWT has three parts: header.payload.signature
# The payload carries claims like user_id and expiry.
# The signature is created with SECRET_KEY — only your server can make valid ones.
# Anyone who intercepts the token can READ the payload (it's base64, not encrypted),
# but they can't FAKE a valid signature without the secret key.
# Never put sensitive data (like passwords) in a JWT payload.

def create_access_token(user_id: str) -> str:
    expire = datetime.now(timezone.utc) + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    payload = {
        "sub": user_id,    # "subject" — who this token belongs to
        "exp": expire,     # expiry — jose rejects tokens past this automatically
        "type": "access",  # prevents a refresh token being used as an access token
    }
    return jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)


def create_refresh_token() -> tuple[str, str, datetime]:
    """
    Returns (raw_token, token_hash, expires_at).

    The refresh token is a random string, NOT a JWT.
    We use random bytes because refresh tokens must be revocable —
    they're stored in the DB so we can cancel them on logout.
    We store only the SHA-256 hash in the DB, not the raw token,
    so a DB breach doesn't hand attackers valid refresh tokens.
    """
    raw_token = secrets.token_urlsafe(32)
    token_hash = hashlib.sha256(raw_token.encode()).hexdigest()
    expires_at = datetime.now(timezone.utc) + timedelta(days=REFRESH_TOKEN_EXPIRE_DAYS)
    return raw_token, token_hash, expires_at


# --- JWT Decoding ---

def decode_access_token(token: str) -> Optional[dict]:
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        if payload.get("type") != "access":
            return None
        return payload
    except JWTError:
        return None

