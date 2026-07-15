"""
Tests for POST /scan

We never call the real OpenAI API in tests — that would be slow, cost money,
and make tests flaky (what if OpenAI is down?). Instead we mock identify_plant
at the service level and test that the router:
  1. Accepts valid images and returns the service's response
  2. Rejects missing images (400)
  3. Rejects oversized images (413)
  4. Rejects unauthenticated requests (401)
  5. Passes through 422 when service says no plant found
"""
import pytest
from httpx import AsyncClient
from unittest.mock import AsyncMock, patch

from schemas.scan import ScanResponse, CareInfo


# A minimal valid JPEG — just the magic bytes that identify it as a JPEG file.
# Real image content doesn't matter since we mock the service.
FAKE_JPEG = bytes([0xFF, 0xD8, 0xFF, 0xE0]) + b"\x00" * 100


# Helper: register a user and return a valid JWT access token.
async def get_token(client: AsyncClient) -> str:
    await client.post("/auth/register", json={
        "email": "scan@example.com",
        "password": "Password123!",
    })
    resp = await client.post("/auth/login", json={
        "email": "scan@example.com",
        "password": "Password123!",
    })
    return resp.json()["access_token"]


# A pre-built ScanResponse we return from the mock so every success test
# gets a consistent, valid response without re-building it each time.
MOCK_RESPONSE = ScanResponse(
    common_name="Monstera",
    scientific_name="Monstera deliciosa",
    confidence="high",
    health="healthy",
    health_observation="Leaves look vibrant and full with no visible signs of stress.",
    care=CareInfo(
        light="Bright indirect light",
        water="Water when top inch of soil is dry",
        humidity="Prefers 60% humidity",
        temperature="18–27°C",
        tips=["Wipe leaves with damp cloth", "Mist occasionally"],
    ),
    fun_fact="Monstera leaves develop holes as they mature — a process called fenestration.",
)


@pytest.mark.asyncio
async def test_scan_returns_plant_data(client: AsyncClient):
    """AC-1: valid JPEG + valid token → 200 with plant info"""
    token = await get_token(client)

    # patch("router.scan.identify_plant") replaces the real function
    # with a mock for the duration of this test only.
    # new_callable=AsyncMock makes it an async function (since the real one is async).
    with patch("router.scan.identify_plant", new_callable=AsyncMock) as mock_identify:
        mock_identify.return_value = MOCK_RESPONSE

        resp = await client.post(
            "/scan",
            files={"image": ("plant.jpg", FAKE_JPEG, "image/jpeg")},
            headers={"Authorization": f"Bearer {token}"},
        )

    assert resp.status_code == 200
    data = resp.json()
    assert data["common_name"] == "Monstera"
    assert data["scientific_name"] == "Monstera deliciosa"
    assert data["confidence"] == "high"
    assert "light" in data["care"]
    assert isinstance(data["care"]["tips"], list)
    assert "fun_fact" in data


@pytest.mark.asyncio
async def test_scan_requires_auth(client: AsyncClient):
    """AC-5: no token → 401"""
    resp = await client.post(
        "/scan",
        files={"image": ("plant.jpg", FAKE_JPEG, "image/jpeg")},
        # No Authorization header
    )
    assert resp.status_code == 401


@pytest.mark.asyncio
async def test_scan_rejects_missing_image(client: AsyncClient):
    """AC-2: no image field → 422 (FastAPI validates required fields)"""
    token = await get_token(client)
    resp = await client.post(
        "/scan",
        headers={"Authorization": f"Bearer {token}"},
        # No files
    )
    assert resp.status_code == 422


@pytest.mark.asyncio
async def test_scan_rejects_oversized_image(client: AsyncClient):
    """AC-3: image > 5MB → 413"""
    token = await get_token(client)

    # 6MB of zeros — over our 5MB limit
    big_image = b"\x00" * (6 * 1024 * 1024)

    resp = await client.post(
        "/scan",
        files={"image": ("big.jpg", big_image, "image/jpeg")},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 413


@pytest.mark.asyncio
async def test_scan_rejects_wrong_file_type(client: AsyncClient):
    """AC-2 extension: non-image content type → 400"""
    token = await get_token(client)

    resp = await client.post(
        "/scan",
        files={"image": ("doc.pdf", b"%PDF-1.4", "application/pdf")},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 400


@pytest.mark.asyncio
async def test_scan_returns_422_when_no_plant(client: AsyncClient):
    """AC-4: service raises 422 (no plant) → router passes it through"""
    from fastapi import HTTPException

    token = await get_token(client)

    with patch("router.scan.identify_plant", new_callable=AsyncMock) as mock_identify:
        mock_identify.side_effect = HTTPException(
            status_code=422,
            detail="No plant detected in the image.",
        )

        resp = await client.post(
            "/scan",
            files={"image": ("dog.jpg", FAKE_JPEG, "image/jpeg")},
            headers={"Authorization": f"Bearer {token}"},
        )

    assert resp.status_code == 422
    assert "No plant" in resp.json()["detail"]
