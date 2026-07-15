import logging
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select, func, and_
from sqlalchemy.ext.asyncio import AsyncSession

from db.database import get_db
from models.plant import Plant
from models.plant_scan import PlantScan
from models.user import User
from router.auth import get_current_user
from schemas.plant import PlantCreate, PlantDetail, PlantListItem, PlantResponse
from schemas.plant_scan import PlantScanCreate, PlantScanResponse, PlantScanHistoryResponse

router = APIRouter(prefix="/plants", tags=["plants"])
logger = logging.getLogger(__name__)

PAGE_SIZE = 20


@router.get("", response_model=list[PlantListItem])
async def list_plants(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Return all plants belonging to the current user, newest first.

    Uses a correlated scalar subquery to find the max scanned_at per plant,
    then joins to plant_scans on that timestamp. This avoids LATERAL JOIN,
    which is PostgreSQL-only and breaks SQLite in tests.

    The subquery is O(1) per plant row — the composite index on
    (plant_id, scanned_at) makes the MAX lookup a single index seek.
    """
    logger.info(f"GET /plants | user_id={current_user.id}")

    # Correlated subquery: for each Plant row, find its latest scanned_at.
    # SQLAlchemy emits: WHERE plant_scans.scanned_at = (SELECT MAX(...) WHERE plant_id = plants.id)
    max_scanned_at = (
        select(func.max(PlantScan.scanned_at))
        .where(PlantScan.plant_id == Plant.id)
        .correlate(Plant)
        .scalar_subquery()
    )

    result = await db.execute(
        select(Plant, PlantScan)
        .outerjoin(
            PlantScan,
            and_(PlantScan.plant_id == Plant.id, PlantScan.scanned_at == max_scanned_at),
        )
        .where(Plant.user_id == current_user.id)
        .order_by(Plant.created_at.desc())
    )
    rows = result.all()

    plants = []
    for plant, scan in rows:
        if scan is None:
            logger.error(f"GET /plants | plant_id={plant.id} has no scans — skipping")
            continue
        plants.append(PlantListItem.from_row(plant, scan))

    logger.info(f"GET /plants | returning {len(plants)} plants")
    return plants


@router.get("/{plant_id}", response_model=PlantDetail)
async def get_plant(
    plant_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Full plant detail — latest scan data + care guide + scan_count."""
    logger.info(f"GET /plants/{plant_id} | user_id={current_user.id}")

    result = await db.execute(
        select(Plant).where(Plant.id == plant_id, Plant.user_id == current_user.id)
    )
    plant = result.scalar_one_or_none()
    if not plant:
        logger.warning(f"GET /plants/{plant_id} | not found or wrong user")
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Plant not found")

    scan_result = await db.execute(
        select(PlantScan)
        .where(PlantScan.plant_id == plant_id)
        .order_by(PlantScan.scanned_at.desc())
        .limit(1)
    )
    latest_scan = scan_result.scalar_one_or_none()
    if not latest_scan:
        logger.error(f"GET /plants/{plant_id} | plant has no scans — data integrity issue")
        raise HTTPException(status_code=500, detail="Plant data is incomplete.")

    count_result = await db.execute(
        select(func.count()).where(PlantScan.plant_id == plant_id)
    )
    scan_count = count_result.scalar_one()

    logger.info(f"GET /plants/{plant_id} | name={plant.name!r} scan_count={scan_count}")
    return PlantDetail.from_orm(plant, latest_scan, scan_count)


@router.post("", response_model=PlantResponse, status_code=status.HTTP_201_CREATED)
async def create_plant(
    body: PlantCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Save a scanned plant — creates plants + plant_scans rows atomically.
    flush() gives plant.id to the scan FK before commit.
    If the scan insert fails, the plant insert also rolls back.
    """
    logger.info(f"POST /plants | user_id={current_user.id} name={body.name!r}")

    plant = Plant(user_id=current_user.id, name=body.name)
    db.add(plant)
    await db.flush()  # need plant.id for the scan FK; still inside same transaction

    scan = PlantScan(
        plant_id=plant.id,
        common_name=body.common_name,
        scientific_name=body.scientific_name,
        confidence=body.confidence,
        health=body.health,
        health_observation=body.health_observation,
        care_json=body.care.model_dump(),
        fun_fact=body.fun_fact,
    )
    db.add(scan)
    await db.commit()
    await db.refresh(plant)

    logger.info(f"plant saved | plant_id={plant.id} scan_id={scan.id}")
    return plant


@router.post("/{plant_id}/scans", response_model=PlantScanResponse, status_code=status.HTTP_201_CREATED)
async def add_scan(
    plant_id: UUID,
    body: PlantScanCreate,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Add a scan to an existing plant — never replaces, always appends.
    Returns 404 if the plant does not exist or belongs to another user.
    Same 404 for both cases — never reveal existence to non-owners.
    """
    logger.info(f"POST /plants/{plant_id}/scans | user_id={current_user.id}")

    result = await db.execute(
        select(Plant).where(Plant.id == plant_id, Plant.user_id == current_user.id)
    )
    if not result.scalar_one_or_none():
        logger.warning(f"POST /plants/{plant_id}/scans | not found or wrong user")
        raise HTTPException(status_code=404, detail="Plant not found")

    scan = PlantScan(
        plant_id=plant_id,
        common_name=body.common_name,
        scientific_name=body.scientific_name,
        confidence=body.confidence,
        health=body.health,
        health_observation=body.health_observation,
        care_json=body.care.model_dump(),
        fun_fact=body.fun_fact,
    )
    db.add(scan)
    await db.commit()
    await db.refresh(scan)

    logger.info(f"scan added | plant_id={plant_id} scan_id={scan.id} health={scan.health}")
    return PlantScanResponse.from_orm(scan)


@router.get("/{plant_id}/scans", response_model=PlantScanHistoryResponse)
async def list_scans(
    plant_id: UUID,
    page: int = Query(default=1, ge=1),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Paginated scan history, newest first. Page size fixed at 20."""
    logger.info(f"GET /plants/{plant_id}/scans | user_id={current_user.id} page={page}")

    # Ownership check first — same 404 for not-found and wrong-user
    result = await db.execute(
        select(Plant).where(Plant.id == plant_id, Plant.user_id == current_user.id)
    )
    if not result.scalar_one_or_none():
        raise HTTPException(status_code=404, detail="Plant not found")

    total = (await db.execute(
        select(func.count()).where(PlantScan.plant_id == plant_id)
    )).scalar_one()

    scans = (await db.execute(
        select(PlantScan)
        .where(PlantScan.plant_id == plant_id)
        .order_by(PlantScan.scanned_at.desc())
        .offset((page - 1) * PAGE_SIZE)
        .limit(PAGE_SIZE)
    )).scalars().all()

    logger.info(f"GET /plants/{plant_id}/scans | total={total} returning={len(scans)}")
    return PlantScanHistoryResponse(
        scans=[PlantScanResponse.from_orm(s) for s in scans],
        total=total,
        page=page,
        page_size=PAGE_SIZE,
    )


@router.delete("/{plant_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_plant(
    plant_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Delete a plant and all its scan history.
    CASCADE on plant_scans FK handles scan cleanup automatically.
    """
    logger.info(f"DELETE /plants/{plant_id} | user_id={current_user.id}")

    result = await db.execute(
        select(Plant).where(Plant.id == plant_id, Plant.user_id == current_user.id)
    )
    plant = result.scalar_one_or_none()
    if not plant:
        logger.warning(f"DELETE /plants/{plant_id} | not found or wrong user")
        raise HTTPException(status_code=404, detail="Plant not found")

    await db.delete(plant)
    await db.commit()
    logger.info(f"DELETE /plants/{plant_id} | deleted (cascade removes all scans)")
