from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime
from uuid import UUID

from schemas.plant import CareDetail, HealthStatus, ConfidenceLevel, _parse_care


class PlantScanCreate(BaseModel):
    """Request body for POST /plants/{id}/scans — add a scan to an existing plant.
    Same fields as PlantCreate minus name (the plant already has a name).
    """
    common_name: str
    scientific_name: str
    confidence: ConfidenceLevel
    health: HealthStatus
    health_observation: str = Field(..., max_length=300)
    care: CareDetail
    fun_fact: Optional[str] = None


class PlantScanResponse(BaseModel):
    """One scan record — returned by POST /plants/{id}/scans and inside GET /plants/{id}/scans."""
    id: UUID
    plant_id: UUID
    common_name: str
    scientific_name: str
    confidence: ConfidenceLevel
    health: HealthStatus
    health_observation: str
    care: CareDetail
    fun_fact: Optional[str] = None
    scanned_at: datetime

    model_config = {"from_attributes": False}

    @classmethod
    def from_orm(cls, scan) -> "PlantScanResponse":
        return cls(
            id=scan.id,
            plant_id=scan.plant_id,
            common_name=scan.common_name,
            scientific_name=scan.scientific_name,
            confidence=scan.confidence,
            health=scan.health,
            health_observation=scan.health_observation,
            care=_parse_care(scan.care_json),
            fun_fact=scan.fun_fact,
            scanned_at=scan.scanned_at,
        )


class PlantScanHistoryResponse(BaseModel):
    """Paginated scan history returned by GET /plants/{id}/scans."""
    scans: list[PlantScanResponse]
    total: int
    page: int
    page_size: int
