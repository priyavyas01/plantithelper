from fastapi import APIRouter, Depends, File, HTTPException, UploadFile
import logging

from router.auth import get_current_user
from models.user import User
from schemas.scan import ScanResponse
from services.scan_service import identify_plant

router = APIRouter(prefix="/scan", tags=["scan"])
logger = logging.getLogger(__name__)

# 5MB in bytes. Checked before we do any processing.
MAX_IMAGE_BYTES = 5 * 1024 * 1024


@router.post("", response_model=ScanResponse)
async def scan_plant(
    image: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
):
    """
    POST /scan
    Accepts a JPEG/PNG/HEIC image, identifies the plant using Claude Opus,
    and returns structured plant information.
    """
    logger.info(f"POST /scan | filename={image.filename} content_type={image.content_type}")

    # Validate file type.
    # content_type is a hint from the client — Flutter's http package sends
    # image/jpeg when we set it explicitly via MediaType('image', 'jpeg').
    # We still allow None and application/octet-stream as fallbacks so that
    # edge cases (older clients, unusual devices) are not blocked.
    allowed_types = {
        "image/jpeg", "image/jpg", "image/png",
        "image/heic", "image/heif",
        "application/octet-stream",  # Flutter default when contentType not set
    }
    if image.content_type and image.content_type not in allowed_types:
        logger.warning(f"rejected content_type={image.content_type}")
        raise HTTPException(
            status_code=400,
            detail="Only JPEG, PNG, and HEIC images are supported.",
        )

    # Read all bytes into memory.
    image_bytes = await image.read()

    # Validate size after reading (we need the bytes to know the size).
    if len(image_bytes) > MAX_IMAGE_BYTES:
        raise HTTPException(
            status_code=413,
            detail="Image too large. Maximum size is 5MB.",
        )

    # Delegate to the service — router doesn't know about GPT or base64.
    # identify_plant raises HTTPException directly if something goes wrong,
    # which FastAPI catches and converts to the right HTTP response.
    return await identify_plant(image_bytes)
