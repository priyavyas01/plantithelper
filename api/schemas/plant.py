from pydantic import BaseModel, Field
from typing import Literal, Optional
from datetime import datetime
from uuid import UUID

# confidence is constrained to three values Claude can return.
# Pydantic will reject any other string at parse time so bad data
# never reaches the DB or the UI.
ConfidenceLevel = Literal["high", "medium", "low"]


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
    created_at: datetime

    model_config = {"from_attributes": True}
