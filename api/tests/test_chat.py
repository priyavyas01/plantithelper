"""
Tests for GET /plants/{id}/chat and POST /plants/{id}/chat

Never calls the real DB or Claude outside of mocks.

  GET /plants/{id}/chat:
  1. Returns empty list when no messages exist
  2. Returns messages oldest-first
  3. Returns 404 for another user's plant (SECURITY)
  4. Returns 401 without auth

  POST /plants/{id}/chat:
  5. Returns Claude's reply with message_id and timestamp
  6. User message and assistant reply are persisted in DB
  7. Returns 404 for another user's plant (SECURITY)
  8. Returns 401 without auth

  System prompt:
  9. Contains plant common_name
  10. Contains health and health_observation from latest scan
  11. Contains last 3 scans in history
  12. History window: last 20 messages are passed to Claude
"""
import pytest
from unittest.mock import AsyncMock, patch, MagicMock
from httpx import AsyncClient


async def register_and_login(client: AsyncClient, email: str) -> str:
    await client.post("/auth/register", json={"email": email, "password": "Password123!"})
    resp = await client.post("/auth/login", json={"email": email, "password": "Password123!"})
    return resp.json()["access_token"]


VALID_PLANT = {
    "name": "My Monstera",
    "common_name": "Monstera",
    "scientific_name": "Monstera deliciosa",
    "confidence": "high",
    "health": "needs_attention",
    "health_observation": "Some yellowing on lower leaves.",
    "care": {
        "light": "Bright indirect light",
        "water": "Water when top inch is dry",
        "humidity": "60%",
        "temperature": "18-27C",
        "tips": ["Wipe leaves monthly"],
    },
    "fun_fact": "Leaves develop holes as they mature.",
}


def _mock_claude(reply: str = "Claude's helpful reply"):
    """Return a patch context that makes chat_service._client.messages.create return reply."""
    mock_response = MagicMock()
    mock_response.content = [MagicMock(text=reply)]
    mock_create = AsyncMock(return_value=mock_response)
    return patch("services.chat_service._client.messages.create", mock_create)


async def _save_plant(client: AsyncClient, token: str) -> str:
    resp = await client.post(
        "/plants",
        json=VALID_PLANT,
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 201
    return resp.json()["id"]


# --- GET /plants/{id}/chat ---

@pytest.mark.asyncio
async def test_get_chat_history_empty(client: AsyncClient):
    token = await register_and_login(client, "chat1@example.com")
    plant_id = await _save_plant(client, token)

    resp = await client.get(
        f"/plants/{plant_id}/chat",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 200
    assert resp.json()["messages"] == []


@pytest.mark.asyncio
async def test_get_chat_history_oldest_first(client: AsyncClient):
    token = await register_and_login(client, "chat2@example.com")
    plant_id = await _save_plant(client, token)

    with _mock_claude("First reply"):
        await client.post(
            f"/plants/{plant_id}/chat",
            json={"message": "First question"},
            headers={"Authorization": f"Bearer {token}"},
        )
    with _mock_claude("Second reply"):
        await client.post(
            f"/plants/{plant_id}/chat",
            json={"message": "Second question"},
            headers={"Authorization": f"Bearer {token}"},
        )

    resp = await client.get(
        f"/plants/{plant_id}/chat",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 200
    messages = resp.json()["messages"]
    # 4 messages: user1, assistant1, user2, assistant2
    assert len(messages) == 4
    assert messages[0]["content"] == "First question"
    assert messages[0]["role"] == "user"
    assert messages[1]["role"] == "assistant"
    assert messages[2]["content"] == "Second question"


@pytest.mark.asyncio
async def test_get_chat_history_security_other_user(client: AsyncClient):
    token_a = await register_and_login(client, "chata@example.com")
    token_b = await register_and_login(client, "chatb@example.com")
    plant_id = await _save_plant(client, token_a)

    resp = await client.get(
        f"/plants/{plant_id}/chat",
        headers={"Authorization": f"Bearer {token_b}"},
    )
    assert resp.status_code == 404


@pytest.mark.asyncio
async def test_get_chat_history_requires_auth(client: AsyncClient):
    token = await register_and_login(client, "chat3@example.com")
    plant_id = await _save_plant(client, token)

    resp = await client.get(f"/plants/{plant_id}/chat")
    assert resp.status_code == 401


# --- POST /plants/{id}/chat ---

@pytest.mark.asyncio
async def test_send_message_returns_reply(client: AsyncClient):
    token = await register_and_login(client, "chat4@example.com")
    plant_id = await _save_plant(client, token)

    with _mock_claude("Water less frequently — the yellowing suggests overwatering."):
        resp = await client.post(
            f"/plants/{plant_id}/chat",
            json={"message": "Why are my leaves turning yellow?"},
            headers={"Authorization": f"Bearer {token}"},
        )

    assert resp.status_code == 200
    data = resp.json()
    assert data["reply"] == "Water less frequently — the yellowing suggests overwatering."
    assert "message_id" in data
    assert "timestamp" in data


@pytest.mark.asyncio
async def test_send_message_persisted_in_db(client: AsyncClient):
    token = await register_and_login(client, "chat5@example.com")
    plant_id = await _save_plant(client, token)

    with _mock_claude("Try misting the leaves daily."):
        await client.post(
            f"/plants/{plant_id}/chat",
            json={"message": "How do I raise humidity?"},
            headers={"Authorization": f"Bearer {token}"},
        )

    # Check the history endpoint to confirm both turns were saved
    resp = await client.get(
        f"/plants/{plant_id}/chat",
        headers={"Authorization": f"Bearer {token}"},
    )
    messages = resp.json()["messages"]
    assert len(messages) == 2
    assert messages[0]["role"] == "user"
    assert messages[0]["content"] == "How do I raise humidity?"
    assert messages[1]["role"] == "assistant"
    assert messages[1]["content"] == "Try misting the leaves daily."


@pytest.mark.asyncio
async def test_send_message_security_other_user(client: AsyncClient):
    token_a = await register_and_login(client, "chatc@example.com")
    token_b = await register_and_login(client, "chatd@example.com")
    plant_id = await _save_plant(client, token_a)

    resp = await client.post(
        f"/plants/{plant_id}/chat",
        json={"message": "Can I see this plant?"},
        headers={"Authorization": f"Bearer {token_b}"},
    )
    assert resp.status_code == 404


@pytest.mark.asyncio
async def test_send_message_requires_auth(client: AsyncClient):
    token = await register_and_login(client, "chat6@example.com")
    plant_id = await _save_plant(client, token)

    resp = await client.post(
        f"/plants/{plant_id}/chat",
        json={"message": "Hello"},
    )
    assert resp.status_code == 401


# --- System prompt content ---

@pytest.mark.asyncio
async def test_system_prompt_contains_plant_name(client: AsyncClient):
    token = await register_and_login(client, "chat7@example.com")
    plant_id = await _save_plant(client, token)

    captured_system = {}

    async def mock_create(**kwargs):
        captured_system["prompt"] = kwargs.get("system", "")
        mock_response = MagicMock()
        mock_response.content = [MagicMock(text="reply")]
        return mock_response

    with patch("services.chat_service._client.messages.create", AsyncMock(side_effect=mock_create)):
        await client.post(
            f"/plants/{plant_id}/chat",
            json={"message": "hi"},
            headers={"Authorization": f"Bearer {token}"},
        )

    assert "Monstera" in captured_system["prompt"]
    assert "My Monstera" in captured_system["prompt"]


@pytest.mark.asyncio
async def test_system_prompt_contains_health(client: AsyncClient):
    token = await register_and_login(client, "chat8@example.com")
    plant_id = await _save_plant(client, token)

    captured_system = {}

    async def mock_create(**kwargs):
        captured_system["prompt"] = kwargs.get("system", "")
        mock_response = MagicMock()
        mock_response.content = [MagicMock(text="reply")]
        return mock_response

    with patch("services.chat_service._client.messages.create", AsyncMock(side_effect=mock_create)):
        await client.post(
            f"/plants/{plant_id}/chat",
            json={"message": "hi"},
            headers={"Authorization": f"Bearer {token}"},
        )

    assert "needs_attention" in captured_system["prompt"]
    assert "Some yellowing on lower leaves." in captured_system["prompt"]


@pytest.mark.asyncio
async def test_history_window_capped_at_20(client: AsyncClient):
    """Claude should only receive the last 20 messages even if more exist in DB."""
    token = await register_and_login(client, "chat9@example.com")
    plant_id = await _save_plant(client, token)

    # Send 12 messages → 24 turns in DB (12 user + 12 assistant)
    for i in range(12):
        with _mock_claude(f"reply {i}"):
            await client.post(
                f"/plants/{plant_id}/chat",
                json={"message": f"question {i}"},
                headers={"Authorization": f"Bearer {token}"},
            )

    captured_messages = {}

    async def mock_create(**kwargs):
        captured_messages["messages"] = kwargs.get("messages", [])
        mock_response = MagicMock()
        mock_response.content = [MagicMock(text="final reply")]
        return mock_response

    with patch("services.chat_service._client.messages.create", AsyncMock(side_effect=mock_create)):
        await client.post(
            f"/plants/{plant_id}/chat",
            json={"message": "final question"},
            headers={"Authorization": f"Bearer {token}"},
        )

    # 20 history + 1 new user message = 21 total messages sent to Claude
    assert len(captured_messages["messages"]) == 21


@pytest.mark.asyncio
async def test_send_empty_message_rejected(client: AsyncClient):
    token = await register_and_login(client, "chat10@example.com")
    plant_id = await _save_plant(client, token)

    resp = await client.post(
        f"/plants/{plant_id}/chat",
        json={"message": ""},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 422


@pytest.mark.asyncio
async def test_system_prompt_contains_scan_history(client: AsyncClient):
    """System prompt should include previous scans when more than one exists."""
    token = await register_and_login(client, "chat11@example.com")
    plant_id = await _save_plant(client, token)

    # Add a second scan with different health
    second_scan = {
        "common_name": "Monstera",
        "scientific_name": "Monstera deliciosa",
        "confidence": "high",
        "health": "concerning",
        "health_observation": "Heavy browning on most leaves.",
        "care": {
            "light": "Bright indirect light",
            "water": "Water when top inch is dry",
            "humidity": "60%",
            "temperature": "18-27C",
            "tips": [],
        },
    }
    await client.post(
        f"/plants/{plant_id}/scans",
        json=second_scan,
        headers={"Authorization": f"Bearer {token}"},
    )

    captured_system = {}

    async def mock_create(**kwargs):
        captured_system["prompt"] = kwargs.get("system", "")
        mock_response = MagicMock()
        mock_response.content = [MagicMock(text="reply")]
        return mock_response

    with patch("services.chat_service._client.messages.create", AsyncMock(side_effect=mock_create)):
        await client.post(
            f"/plants/{plant_id}/chat",
            json={"message": "my plant looks bad"},
            headers={"Authorization": f"Bearer {token}"},
        )

    prompt = captured_system["prompt"]
    # Latest scan should be in current health section
    assert "concerning" in prompt
    assert "Heavy browning on most leaves." in prompt
    # Scan count should show 2 total scans
    assert "2 total scans" in prompt
