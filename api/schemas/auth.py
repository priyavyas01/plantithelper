from pydantic import BaseModel, EmailStr, field_validator
import uuid


class RegisterRequest(BaseModel):
    email: EmailStr  # Pydantic validates email format automatically
    password: str

    @field_validator("password")
    @classmethod
    def validate_password(cls, v: str) -> str:
        if len(v) < 8:
            raise ValueError("Password must be at least 8 characters")
        # bcrypt silently truncates anything beyond 72 bytes.
        # We enforce this explicitly so the user knows, rather than
        # accepting a 100-char password and only hashing the first 72.
        if len(v.encode("utf-8")) > 72:
            raise ValueError("Password must be 72 characters or fewer")
        return v

    @field_validator("email")
    @classmethod
    def validate_email_length(cls, v: str) -> str:
        # RFC 5321 max email length
        if len(v) > 254:
            raise ValueError("Email must be 254 characters or fewer")
        return v.lower()  # normalize to lowercase before storing


class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"


class RefreshRequest(BaseModel):
    refresh_token: str


class UserResponse(BaseModel):
    id: uuid.UUID
    email: str

    # This tells Pydantic it's okay to read from SQLAlchemy model attributes,
    # not just plain dicts. Without this, response_model won't work with ORM objects.
    model_config = {"from_attributes": True}


class ForgotPasswordRequest(BaseModel):
    email: EmailStr


class ResetPasswordRequest(BaseModel):
    email: EmailStr
    code: str
    new_password: str

    @field_validator("new_password")
    @classmethod
    def validate_password(cls, v: str) -> str:
        if len(v) < 8:
            raise ValueError("Password must be at least 8 characters")
        if len(v.encode("utf-8")) > 72:
            raise ValueError("Password must be 72 characters or fewer")
        return v
