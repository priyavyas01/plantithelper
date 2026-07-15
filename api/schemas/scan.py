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


# HealthStatus constrains the four values Claude is allowed to return.
# "unknown" is the safe fallback — used when Claude can't assess health
# from the image (e.g. a bare bulb, a blurry photo, or just soil).
HealthStatus = Literal["healthy", "needs_attention", "concerning", "unknown"]


# ScanResponse is what we return to the Flutter app on success (HTTP 200).
# confidence is kept for debugging/analytics but not shown in the UI.
# health + health_observation are the user-facing signals.
class ScanResponse(BaseModel):
    common_name: str
    scientific_name: str
    confidence: Literal["low", "medium", "high"]
    health: HealthStatus
    health_observation: str
    care: CareInfo
    fun_fact: Optional[str] = None
