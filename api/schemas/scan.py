from pydantic import BaseModel
from typing import Literal, Optional


# CareInfo is a nested model — it lives inside ScanResponse.
# Breaking it out as its own class keeps things readable and
# lets us reuse it later (e.g. in a plant detail endpoint).
class CareInfo(BaseModel):
    light: str
    water: str
    humidity: str
    temperature: str
    tips: list[str]


# ScanResponse is what we return to the Flutter app on success (HTTP 200).
# Literal["low", "medium", "high"] means Pydantic will reject any other string —
# it's like an enum but simpler.
# fun_fact is optional — Claude doesn't always include it.
class ScanResponse(BaseModel):
    common_name: str
    scientific_name: str
    confidence: Literal["low", "medium", "high"]
    care: CareInfo
    fun_fact: Optional[str] = None
