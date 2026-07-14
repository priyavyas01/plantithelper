from unittest.mock import patch


# --- POST /auth/forgot-password ---

async def test_forgot_password_unknown_email_returns_204(client):
    """Returns 204 even when email isn't registered — never reveal if an account exists."""
    response = await client.post(
        "/auth/forgot-password",
        json={"email": "nobody@example.com"},
    )
    assert response.status_code == 204


async def test_forgot_password_known_email_sends_code(client):
    """Sends email with 6-digit numeric code when user exists."""
    await client.post(
        "/auth/register",
        json={"email": "user@example.com", "password": "password123"},
    )

    with patch("router.auth.send_password_reset_email") as mock_send:
        response = await client.post(
            "/auth/forgot-password",
            json={"email": "user@example.com"},
        )

    assert response.status_code == 204
    mock_send.assert_called_once()
    _, kwargs = mock_send.call_args
    assert kwargs["to_email"] == "user@example.com"
    assert len(kwargs["code"]) == 6
    assert kwargs["code"].isdigit()


# --- POST /auth/reset-password ---

async def test_reset_password_wrong_code_returns_400(client):
    """Wrong code should return 400."""
    await client.post(
        "/auth/register",
        json={"email": "user2@example.com", "password": "password123"},
    )
    with patch("router.auth.send_password_reset_email"):
        await client.post("/auth/forgot-password", json={"email": "user2@example.com"})

    response = await client.post(
        "/auth/reset-password",
        json={"email": "user2@example.com", "code": "000000", "new_password": "newpassword1"},
    )
    assert response.status_code == 400


async def test_reset_password_success_updates_password(client):
    """Valid code resets password — user can log in with new password."""
    email = "user3@example.com"
    await client.post("/auth/register", json={"email": email, "password": "oldpassword"})

    with patch("router.auth.send_password_reset_email") as mock_send:
        await client.post("/auth/forgot-password", json={"email": email})
        code = mock_send.call_args[1]["code"]

    response = await client.post(
        "/auth/reset-password",
        json={"email": email, "code": code, "new_password": "newpassword1"},
    )
    assert response.status_code == 204

    # Old password should no longer work
    old_login = await client.post("/auth/login", json={"email": email, "password": "oldpassword"})
    assert old_login.status_code == 401

    # New password should work
    new_login = await client.post("/auth/login", json={"email": email, "password": "newpassword1"})
    assert new_login.status_code == 200


async def test_reset_password_code_is_single_use(client):
    """Reset code should be rejected after it's been used once."""
    email = "user4@example.com"
    await client.post("/auth/register", json={"email": email, "password": "oldpassword"})

    with patch("router.auth.send_password_reset_email") as mock_send:
        await client.post("/auth/forgot-password", json={"email": email})
        code = mock_send.call_args[1]["code"]

    await client.post(
        "/auth/reset-password",
        json={"email": email, "code": code, "new_password": "newpassword1"},
    )

    # Second use of the same code
    second_use = await client.post(
        "/auth/reset-password",
        json={"email": email, "code": code, "new_password": "anotherpassword"},
    )
    assert second_use.status_code == 400


async def test_reset_password_unknown_email_returns_400(client):
    """Should return 400 for an email that has no account (no token exists)."""
    response = await client.post(
        "/auth/reset-password",
        json={"email": "ghost@example.com", "code": "123456", "new_password": "newpassword1"},
    )
    assert response.status_code == 400
