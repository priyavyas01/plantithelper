from sqlalchemy import Column, String, DateTime, Text, ForeignKey, JSON
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from db.database import Base
from datetime import datetime, timezone
import uuid


class PlantScan(Base):
    __tablename__ = "plant_scans"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    # Cascade: deleting a plant removes all its scan history
    plant_id = Column(
        UUID(as_uuid=True),
        ForeignKey("plants.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    common_name = Column(String(100), nullable=False)
    scientific_name = Column(String(150), nullable=False)
    confidence = Column(String(10), nullable=False)   # low / medium / high — kept for analytics
    health = Column(String(20), nullable=False)       # healthy / needs_attention / concerning / unknown
    health_observation = Column(Text, nullable=False)
    care_json = Column(JSON, nullable=False)
    fun_fact = Column(Text, nullable=True)
    scanned_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        nullable=False,
        index=True,  # indexed — lateral join orders by scanned_at DESC
    )

    plant = relationship("Plant", back_populates="scans", lazy="raise")
