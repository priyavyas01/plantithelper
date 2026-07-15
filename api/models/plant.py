from sqlalchemy import Column, String, DateTime, Text, ForeignKey, JSON
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
    # From Claude response
    common_name = Column(String(100), nullable=False)
    scientific_name = Column(String(150), nullable=False)
    confidence = Column(String(10), nullable=False)  # low / medium / high — kept for analytics, not shown in UI
    # Health assessment from Claude at scan time
    # health is constrained to: healthy / needs_attention / concerning / unknown
    # health_observation is one sentence describing what Claude saw
    # Both default to safe values so old rows remain valid after migration
    health = Column(String(20), nullable=False, server_default="unknown")
    health_observation = Column(Text, nullable=False, server_default="")
    # Full care guide stored as JSON — structure mirrors CareInfo schema
    # Using generic JSON so the model works with both Postgres (JSONB) and SQLite (tests)
    care_json = Column(JSON, nullable=False)
    fun_fact = Column(Text, nullable=True)
    created_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
    )

    user = relationship("User", back_populates="plants")
