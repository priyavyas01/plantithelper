"""
Tests for POST /plants

Never calls the real DB outside of the in-memory SQLite fixture.
Verifies the router correctly:
  1. Creates a plant and returns 201 with id, name, created_at
  2. Rejects unauthenticated requests (401)
  3. Rejects empty name (422)
  4. Rejects names over 100 chars (422)
  5. Accepts null fun_fact and stores it cleanly
"""
import pytest
from httpx import AsyncClient


async def register_and_login(client: AsyncClient, email: str) -> str:
    """Helper: register a new user and return a valid access token."""
    await client.post("/auth/register", json={"email": email, "password": "Password123!"})
    resp = await client.post("/auth/login", json={"email": email, "password": "Password123!"})
    return resp.json()["access_token"]


VALID_PLANT = {
    "name": "My Monstera",
    "common_name": "Monstera",
    "scientific_name": "Monstera deliciosa",
    "confidence": "high",
    "care": {
        "light": "Bright indirect light",
        "water": "Water when top inch of soil is dry",
        "humidity": "Prefers 60% humidity",
        "temperature": "18-27C",
        "tips": ["Wipe leaves with a damp cloth"],
    },
    "fun_fact": "Monstera leaves develop holes as they mature.",
}


@pytest.mark.asyncio
async def test_save_plant_returns_201(client: AsyncClient):
    """AC: valid payload + valid token → 201 with id, name, created_at"""
    token = await register_and_login(client, "plant@example.com")
    resp = await client.post(
        "/plants",
        json=VALID_PLANT,
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 201
    data = resp.json()
    assert data["name"] == "My Monstera"
    assert "id" in data
    assert "created_at" in data


@pytest.mark.asyncio
async def test_save_plant_requires_auth(client: AsyncClient):
    """AC: no token → 401"""
    resp = await client.post("/plants", json=VALID_PLANT)
    assert resp.status_code == 401


@pytest.mark.asyncio
async def test_save_plant_rejects_empty_name(client: AsyncClient):
    """AC: empty name → 422 (Pydantic min_length=1)"""
    token = await register_and_login(client, "plant2@example.com")
    resp = await client.post(
        "/plants",
        json={**VALID_PLANT, "name": ""},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 422


@pytest.mark.asyncio
async def test_save_plant_rejects_name_over_100_chars(client: AsyncClient):
    """AC: name > 100 chars → 422 (Pydantic max_length=100)"""
    token = await register_and_login(client, "plant3@example.com")
    resp = await client.post(
        "/plants",
        json={**VALID_PLANT, "name": "x" * 101},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 422


@pytest.mark.asyncio
async def test_save_plant_null_fun_fact(client: AsyncClient):
    """AC: fun_fact=None → 201, null stored cleanly"""
    token = await register_and_login(client, "plant4@example.com")
    resp = await client.post(
        "/plants",
        json={**VALID_PLANT, "fun_fact": None},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 201


@pytest.mark.asyncio
async def test_same_species_can_be_saved_twice(client: AsyncClient):
    """AC: saving the same species twice is allowed (different pots)"""
    token = await register_and_login(client, "plant5@example.com")
    headers = {"Authorization": f"Bearer {token}"}

    r1 = await client.post("/plants", json=VALID_PLANT, headers=headers)
    r2 = await client.post("/plants", json={**VALID_PLANT, "name": "Second Monstera"}, headers=headers)

    assert r1.status_code == 201
    assert r2.status_code == 201
    # They get different ids
    assert r1.json()["id"] != r2.json()["id"]
