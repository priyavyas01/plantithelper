from sqlalchemy import Column, String, DateTime
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from db.database import Base
from datetime import datetime, timezone
import uuid


class User(Base):
    __tablename__ = "users"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    # max 254 per RFC 5321; unique index for fast lookup + duplicate prevention
    email = Column(String(254), unique=True, nullable=False, index=True)
    # bcrypt output is always 60 chars; 255 gives headroom for algorithm changes
    hashed_password = Column(String(255), nullable=False)
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), nullable=False)

    refresh_tokens = relationship("RefreshToken", back_populates="user", cascade="all, delete-orphan")
