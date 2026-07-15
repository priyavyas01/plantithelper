from fastapi import APIRouter, Depends, File, HTTPException, UploadFile

from core.security import get_current_user
from models.user import User
from schemas.scan import ScanResponse
from services.scan_service import identify_plant

router = APIRouter(prefix="/scan", tags=["scan"])

# 5MB in bytes. Checked before we do any processing.
MAX_IMAGE_BYTES = 5 * 1024 * 1024


@router.post("", response_model=ScanResponse)
async def scan_plant(
    image: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
):
    """
    POST /scan
    Accepts a JPEG image, identifies the plant using GPT-4o Vision,
    and returns structured plant information.
    """

    # Validate file type.
    # content_type is set by the client — it can be spoofed, but it's a
    # reasonable first check.
    if image.content_type not in ("image/jpeg", "image/jpg", "image/png"):
        raise HTTPException(
            status_code=400,
            detail="Only JPEG and PNG images are supported.",
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
