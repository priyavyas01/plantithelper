import logging
from datetime import datetime, timezone
from uuid import UUID

import anthropic
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from db.database import get_db
from models.chat_message import ChatMessage
from models.plant import Plant
from models.plant_scan import PlantScan
from models.user import User
from router.auth import get_current_user
from schemas.chat import ChatRequest, ChatResponse, ChatHistoryResponse, ChatMessageResponse
from services import chat_service

router = APIRouter(prefix="/plants", tags=["chat"])
logger = logging.getLogger(__name__)

# Max messages returned to the Flutter client on history load
_HISTORY_LIMIT = 50


async def _get_plant_for_user(
    plant_id: UUID, current_user: User, db: AsyncSession
) -> Plant:
    """Fetch plant by id, enforcing ownership. Raises 404 if not found or wrong user."""
    result = await db.execute(
        select(Plant).where(Plant.id == plant_id, Plant.user_id == current_user.id)
    )
    plant = result.scalar_one_or_none()
    if plant is None:
        raise HTTPException(status_code=404, detail="Plant not found")
    return plant


@router.get("/{plant_id}/chat", response_model=ChatHistoryResponse)
async def get_chat_history(
    plant_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Return the last 50 chat messages for a plant, oldest first.
    Ownership check: 404 if the plant belongs to another user.
    """
    await _get_plant_for_user(plant_id, current_user, db)
    logger.info(f"GET chat history | plant_id={plant_id} user_id={current_user.id}")

    result = await db.execute(
        select(ChatMessage)
        .where(ChatMessage.plant_id == plant_id)
        .order_by(ChatMessage.created_at.desc())
        .limit(_HISTORY_LIMIT)
    )
    # Reverse so the client receives oldest-first for display
    messages = list(reversed(result.scalars().all()))

    return ChatHistoryResponse(
        messages=[ChatMessageResponse.from_orm(m) for m in messages]
    )


@router.post("/{plant_id}/chat", response_model=ChatResponse)
async def send_chat_message(
    plant_id: UUID,
    body: ChatRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Send a user message and get a Claude reply.

    System prompt is built fresh from the plant's current state on every call
    so health and scan history are always up to date.
    Ownership check: 404 if the plant belongs to another user.
    """
    plant = await _get_plant_for_user(plant_id, current_user, db)
    logger.info(f"POST chat | plant_id={plant_id} user_id={current_user.id}")

    # One query: fetch the last SCAN_SUMMARY_COUNT scans ordered newest-first.
    # First row is the latest scan (for current health); all rows feed the system prompt.
    scans_result = await db.execute(
        select(PlantScan)
        .where(PlantScan.plant_id == plant_id)
        .order_by(PlantScan.scanned_at.desc())
        .limit(chat_service.SCAN_SUMMARY_COUNT)
    )
    recent_scans = scans_result.scalars().all()
    latest_scan = recent_scans[0] if recent_scans else None

    count_result = await db.execute(
        select(func.count()).select_from(PlantScan).where(PlantScan.plant_id == plant_id)
    )
    scan_count = count_result.scalar_one()

    # Load only the last HISTORY_WINDOW messages from DB — no need to load everything.
    # Reverse so they're chronological (oldest first) for the Claude messages array.
    history_result = await db.execute(
        select(ChatMessage)
        .where(ChatMessage.plant_id == plant_id)
        .order_by(ChatMessage.created_at.desc())
        .limit(chat_service.HISTORY_WINDOW)
    )
    history = list(reversed(history_result.scalars().all()))

    # Call Claude
    try:
        reply = await chat_service.send_message(
            plant=plant,
            latest_scan=latest_scan,
            recent_scans=recent_scans,
            scan_count=scan_count,
            history=history,
            user_message=body.message,
        )
    except anthropic.APIError as e:
        logger.error(f"Claude API error | plant_id={plant_id} error={e}")
        raise HTTPException(status_code=502, detail="AI service unavailable. Try again.")
    except ValueError as e:
        logger.error(f"Claude empty response | plant_id={plant_id} error={e}")
        raise HTTPException(status_code=502, detail="AI service returned an empty response. Try again.")

    # Persist both turns atomically
    now = datetime.now(timezone.utc)
    db.add(ChatMessage(plant_id=plant_id, role="user", content=body.message, created_at=now))

    assistant_msg = ChatMessage(plant_id=plant_id, role="assistant", content=reply)
    db.add(assistant_msg)
    await db.commit()
    await db.refresh(assistant_msg)

    return ChatResponse(
        reply=reply,
        message_id=str(assistant_msg.id),
        timestamp=assistant_msg.created_at,
    )