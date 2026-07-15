import logging
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from db.database import get_db
from models.plant import Plant
from models.user import User
from router.auth import get_current_user
from schemas.plant import PlantCreate, PlantDetail, PlantListItem, PlantResponse

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
    Full details (including care guide) come from GET /plants/{id}.
    """
    logger.info(f"GET /plants | user_id={current_user.id}")

    result = await db.execute(
        select(Plant)
        .where(Plant.user_id == current_user.id)
        .order_by(Plant.created_at.desc())
    )
    plants = result.scalars().all()

    logger.info(f"GET /plants | returning {len(plants)} plants")
    return plants


@router.get("/{plant_id}", response_model=PlantDetail)
async def get_plant(
    plant_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Return full details for a single plant including care_json.

    Returns 404 if the plant does not exist OR belongs to a different user —
    we never reveal whether another user's plant exists.
    """
    logger.info(f"GET /plants/{plant_id} | user_id={current_user.id}")

    result = await db.execute(
        select(Plant).where(Plant.id == plant_id, Plant.user_id == current_user.id)
    )
    plant = result.scalar_one_or_none()

    if not plant:
        logger.warning(f"GET /plants/{plant_id} | not found or wrong user")
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Plant not found")

    logger.info(f"GET /plants/{plant_id} | returning plant name={plant.name!r}")
    return PlantDetail.from_orm(plant)


@router.delete("/{plant_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_plant(
    plant_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Permanently delete a plant from the user's collection.

    Returns 204 on success, 404 if not found or owned by a different user.
    """
    logger.info(f"DELETE /plants/{plant_id} | user_id={current_user.id}")

    result = await db.execute(
        select(Plant).where(Plant.id == plant_id, Plant.user_id == current_user.id)
    )
    plant = result.scalar_one_or_none()

    if not plant:
        logger.warning(f"DELETE /plants/{plant_id} | not found or wrong user")
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Plant not found")

    await db.delete(plant)
    await db.commit()
    logger.info(f"DELETE /plants/{plant_id} | deleted")


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
