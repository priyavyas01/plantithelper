import logging

from fastapi import APIRouter, Depends, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from db.database import get_db
from models.plant import Plant
from models.user import User
from router.auth import get_current_user
from schemas.plant import PlantCreate, PlantListItem, PlantResponse

router = APIRouter(prefix="/plants", tags=["plants"])
logger = logging.getLogger(__name__)


@router.get("", response_model=list[PlantListItem])
async def list_plants(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Return all plants belonging to the current user, newest first.

    Does not include care_json — the list screen only needs summary data.
    Full details (including care guide) come from GET /plants/{id} (E4-S1).
    """
    logger.info(f"GET /plants | user_id={current_user.id}")

    # select(Plant) builds a SQL query: SELECT * FROM plants
    # .where(...) adds: WHERE user_id = <current user's id>
    # .order_by(...) adds: ORDER BY created_at DESC  (newest first)
    result = await db.execute(
        select(Plant)
        .where(Plant.user_id == current_user.id)
        .order_by(Plant.created_at.desc())
    )
    plants = result.scalars().all()

    logger.info(f"GET /plants | returning {len(plants)} plants")
    return plants


@router.post("", response_model=PlantResponse, status_code=status.HTTP_201_CREATED)
async def create_plant(
    body: PlantCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Save a scanned plant to the current user's collection.

    Accepts the full scan result (name, common name, scientific name,
    confidence, care guide, optional fun fact). Returns the created
    plant's id, display name, and creation timestamp.
    """
    logger.info(f"POST /plants | user_id={current_user.id} name={body.name!r}")

    plant = Plant(
        user_id=current_user.id,
        name=body.name,
        common_name=body.common_name,
        scientific_name=body.scientific_name,
        confidence=body.confidence,
        care_json=body.care.model_dump(),
        fun_fact=body.fun_fact,
    )
    db.add(plant)
    await db.commit()
    await db.refresh(plant)

    logger.info(f"plant saved | plant_id={plant.id}")
    return plant
