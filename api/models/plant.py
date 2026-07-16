from sqlalchemy import Column, String, DateTime, ForeignKey
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from db.database import Base
from datetime import datetime, timezone
import uuid


class Plant(Base):
    __tablename__ = "plants"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    # Cascade delete: removing a user removes all their plants
    user_id = Column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    # User-editable name (e.g. "My Bedroom Monstera")
    name = Column(String(100), nullable=False)
    created_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
    )

    user = relationship("User", back_populates="plants")
    # All scan data lives in plant_scans — Plant is just identity + name.
    # lazy="raise" prevents accidental sync lazy loads on an async session.
    # Any access to plant.scans outside an explicit joinedload/selectinload will raise
    # InvalidRequestError immediately, rather than silently causing a MissingGreenlet
    # crash at serialization time in production.
    scans = relationship(
        "PlantScan",
        back_populates="plant",
        order_by="PlantScan.scanned_at.desc()",
        cascade="all, delete-orphan",
        lazy="raise",
    )
    chat_messages = relationship(
        "ChatMessage",
        back_populates="plant",
        order_by="ChatMessage.created_at.asc()",
        cascade="all, delete-orphan",
        lazy="raise",
    )
