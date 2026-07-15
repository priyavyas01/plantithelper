from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime
from uuid import UUID


class CareInput(BaseModel):
    light: str
    water: str
    humidity: str
    temperature: str
    tips: list[str]


class PlantCreate(BaseModel):
    # min_length=1 rejects empty strings; max_length=100 matches DB column
    name: str = Field(..., min_length=1, max_length=100, description="User's custom name for the plant")
    common_name: str
    scientific_name: str
    confidence: str
    care: CareInput
    fun_fact: Optional[str] = None


class PlantResponse(BaseModel):
    id: UUID
    name: str
    created_at: datetime

    model_config = {"from_attributes": True}
