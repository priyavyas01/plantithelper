from pydantic import BaseModel, Field
from typing import Literal, Optional
from datetime import datetime
from uuid import UUID

# confidence is kept in the DB and schema for debugging/analytics but
# is no longer shown in the UI. HealthStatus is what users see.
ConfidenceLevel = Literal["high", "medium", "low"]

# HealthStatus mirrors the Literal in scan.py — duplicated intentionally so
# each schema module is self-contained and doesn't create a circular import.
HealthStatus = Literal["healthy", "needs_attention", "concerning", "unknown"]


class CareInput(BaseModel):
    """Care guide fields sent by the client when saving a plant."""
    light: str
    water: str
    humidity: str
    temperature: str
    tips: list[str]


# CareDetail is identical in shape to CareInput — both carry the same four
# fields plus tips. We alias rather than duplicate so a field addition only
# needs to happen once.
CareDetail = CareInput


class PlantCreate(BaseModel):
    """Request body for POST /plants."""
    # min_length=1 rejects empty strings; max_length=100 matches DB column
    name: str = Field(..., min_length=1, max_length=100, description="User's custom name for the plant")
    common_name: str
    scientific_name: str
    confidence: ConfidenceLevel
    health: HealthStatus
    # max_length=300 matches the truncation applied in scan_service.py.
    # Enforcing it here means a rogue client sending a huge observation on
    # POST /plants still gets a 422, not a silent DB bloat.
    health_observation: str = Field(..., max_length=300)
    care: CareInput
    fun_fact: Optional[str] = None


class PlantResponse(BaseModel):
    """Returned after POST /plants — just enough to confirm the save."""
    id: UUID
    name: str
    created_at: datetime

    model_config = {"from_attributes": True}


class PlantDetail(BaseModel):
    """Full plant data returned by GET /plants/{id}. Includes care guide."""
    id: UUID
    name: str
    common_name: str
    scientific_name: str
    confidence: ConfidenceLevel
    health: HealthStatus
    health_observation: str
    care: CareDetail
    fun_fact: Optional[str] = None
    created_at: datetime

    model_config = {"from_attributes": False}

    @classmethod
    def from_orm(cls, plant) -> "PlantDetail":
        # care_json is stored as a raw dict in Postgres (JSONB column).
        # SQLAlchemy's from_attributes mode cannot automatically convert a
        # plain dict to a nested Pydantic model, so we build it manually.
        return cls(
            id=plant.id,
            name=plant.name,
            common_name=plant.common_name,
            scientific_name=plant.scientific_name,
            confidence=plant.confidence,
            health=plant.health,
            health_observation=plant.health_observation,
            care=CareDetail(**plant.care_json),
            fun_fact=plant.fun_fact,
            created_at=plant.created_at,
        )


class PlantListItem(BaseModel):
    """One item in GET /plants — summary only, no care JSON.
    The full care guide comes from GET /plants/{id} when the user opens detail.
    """
    id: UUID
    name: str
    common_name: str
    scientific_name: str
    confidence: ConfidenceLevel
    health: HealthStatus
    health_observation: str
    created_at: datetime

    model_config = {"from_attributes": True}
