"""
Tests for POST /plants and GET /plants

Never calls the real DB outside of the in-memory SQLite fixture.

  POST /plants:
  1. Creates a plant and returns 201 with id, name, created_at
  2. Rejects unauthenticated requests (401)
  3. Rejects empty name (422)
  4. Rejects names over 100 chars (422)
  5. Accepts null fun_fact
  6. Allows saving the same species twice

  GET /plants:
  7. Returns the current user's plants newest-first
  8. Returns empty list (not 404) when user has no plants
  9. SECURITY: does not return another user's plants
  10. Returns 401 without auth
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


# --- POST /plants ---

@pytest.mark.asyncio
async def test_save_plant_returns_201(client: AsyncClient):
    token = await register_and_login(client, "plant@example.com")
    resp = await client.post("/plants", json=VALID_PLANT, headers={"Authorization": f"Bearer {token}"})
    assert resp.status_code == 201
    data = resp.json()
    assert data["name"] == "My Monstera"
    assert "id" in data
    assert "created_at" in data


@pytest.mark.asyncio
async def test_save_plant_requires_auth(client: AsyncClient):
    resp = await client.post("/plants", json=VALID_PLANT)
    assert resp.status_code == 401


@pytest.mark.asyncio
async def test_save_plant_rejects_empty_name(client: AsyncClient):
    token = await register_and_login(client, "plant2@example.com")
    resp = await client.post("/plants", json={**VALID_PLANT, "name": ""}, headers={"Authorization": f"Bearer {token}"})
    assert resp.status_code == 422


@pytest.mark.asyncio
async def test_save_plant_rejects_name_over_100_chars(client: AsyncClient):
    token = await register_and_login(client, "plant3@example.com")
    resp = await client.post("/plants", json={**VALID_PLANT, "name": "x" * 101}, headers={"Authorization": f"Bearer {token}"})
    assert resp.status_code == 422


@pytest.mark.asyncio
async def test_save_plant_null_fun_fact(client: AsyncClient):
    token = await register_and_login(client, "plant4@example.com")
    resp = await client.post("/plants", json={**VALID_PLANT, "fun_fact": None}, headers={"Authorization": f"Bearer {token}"})
    assert resp.status_code == 201


@pytest.mark.asyncio
async def test_same_species_can_be_saved_twice(client: AsyncClient):
    token = await register_and_login(client, "plant5@example.com")
    headers = {"Authorization": f"Bearer {token}"}
    r1 = await client.post("/plants", json=VALID_PLANT, headers=headers)
    r2 = await client.post("/plants", json={**VALID_PLANT, "name": "Second Monstera"}, headers=headers)
    assert r1.status_code == 201
    assert r2.status_code == 201
    assert r1.json()["id"] != r2.json()["id"]


# --- GET /plants ---

@pytest.mark.asyncio
async def test_list_plants_returns_users_plants(client: AsyncClient):
    """Returns all plants for the current user, newest first."""
    token = await register_and_login(client, "list1@example.com")
    headers = {"Authorization": f"Bearer {token}"}

    await client.post("/plants", json=VALID_PLANT, headers=headers)
    await client.post("/plants", json={**VALID_PLANT, "name": "Snake Plant"}, headers=headers)

    resp = await client.get("/plants", headers=headers)
    assert resp.status_code == 200
    data = resp.json()
    assert len(data) == 2
    # Newest first — Snake Plant was saved second
    assert data[0]["name"] == "Snake Plant"
    assert data[1]["name"] == "My Monstera"


@pytest.mark.asyncio
async def test_list_plants_empty_for_new_user(client: AsyncClient):
    """New user with no plants gets an empty list, not a 404."""
    token = await register_and_login(client, "list2@example.com")
    resp = await client.get("/plants", headers={"Authorization": f"Bearer {token}"})
    assert resp.status_code == 200
    assert resp.json() == []


@pytest.mark.asyncio
async def test_list_plants_only_returns_own_plants(client: AsyncClient):
    """SECURITY: User A cannot see User B's plants."""
    token_a = await register_and_login(client, "usera@example.com")
    token_b = await register_and_login(client, "userb@example.com")

    await client.post("/plants", json=VALID_PLANT, headers={"Authorization": f"Bearer {token_a}"})

    resp = await client.get("/plants", headers={"Authorization": f"Bearer {token_b}"})
    assert resp.status_code == 200
    assert resp.json() == []


@pytest.mark.asyncio
async def test_list_plants_requires_auth(client: AsyncClient):
    resp = await client.get("/plants")
    assert resp.status_code == 401
