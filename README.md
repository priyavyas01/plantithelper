# PlantIt Helper

A mobile app to identify plants from photos, get personalised care guides, and track your collection over time.

Built by Priya Vyas as a full-stack learning project.

**Stack:** Flutter (iOS/Android) — FastAPI — PostgreSQL — Claude AI (Anthropic)

---

## Architecture

```
                Flutter app (iOS / Android)
                         |
                   HTTPS + JWT
                         |
                  FastAPI backend
                  /      |      \
           Postgres   Anthropic  Resend
           (data)     (Claude AI) (email)
```

The backend is a single FastAPI process. Flutter talks to it over HTTP using a JWT
access token (15 min) and a rotating refresh token (30 days). No data is stored on
device beyond the token pair in secure storage.

---

## Request flow — plant scan

```
User taps "Scan This Plant"
        |
        | POST /scan  (multipart image)
        v
FastAPI validates image type + size
        |
        v
image bytes → base64 → Anthropic Claude Opus
        |
        v
Claude returns JSON: name, care guide, confidence, health
        |
        v
FastAPI validates + returns ScanResponse
        |
        v
Flutter shows ResultScreen (name, care grid, save button)
        |
        | POST /plants  (on save)
        v
Plant stored in Postgres → collection updated
```

---

## Auth flow

```
Register / Login
        |
        v
   access_token (15 min JWT)    <-- stored in memory
   refresh_token (30 day hash)  <-- stored in secure storage
        |
        | access token expires
        v
POST /auth/refresh
   old refresh token → revoked
   new refresh token → issued   (token rotation)
   new access token → returned
        |
        | both tokens expired / invalid
        v
   clear secure storage → redirect to login
```

Token rotation means a stolen refresh token can only be used once. If an attacker
uses it first, the real user's next refresh fails and they are forced to log back in.

---

## Project structure

```
plantit-helper/
├── api/                  FastAPI backend
│   ├── models/           SQLAlchemy ORM models
│   ├── schemas/          Pydantic request/response schemas
│   ├── router/           Route handlers (auth, scan, plants)
│   ├── services/         Business logic (scan, auth, email)
│   ├── db/               Database connection + init
│   ├── alembic/          Migration scripts
│   └── tests/            pytest test suite
│
└── app/                  Flutter mobile app
    └── lib/
        ├── config/       AppConfig (base URL)
        ├── models/       Dart data classes (fromJson/toJson)
        ├── services/     HTTP service layer (AuthService, PlantService, ScanService)
        ├── screens/
        │   ├── auth/     Login, Register, ForgotPassword, ResetPassword
        │   ├── scan/     CaptureScreen, PreviewScreen, ResultScreen
        │   ├── plants/   MyPlantsScreen
        │   └── home/     HomeScreen (shell)
        └── test/         Widget and unit tests
```

---

## Database schema

```
users
  id               UUID PK
  email            VARCHAR unique
  hashed_password  VARCHAR
  created_at       TIMESTAMPTZ

refresh_tokens
  id               UUID PK
  user_id          UUID FK → users
  token_hash       VARCHAR   (SHA-256 of the raw token)
  expires_at       TIMESTAMPTZ
  revoked          BOOLEAN

password_reset_tokens
  id               UUID PK
  user_id          UUID FK → users
  code_hash        VARCHAR   (SHA-256 of the 6-digit code)
  expires_at       TIMESTAMPTZ
  used             BOOLEAN

plants
  id               UUID PK
  user_id          UUID FK → users
  name             VARCHAR   (user's display name)
  common_name      VARCHAR   (from Claude)
  scientific_name  VARCHAR
  confidence       VARCHAR   (high / medium / low)
  care_json        JSONB
  fun_fact         TEXT nullable
  created_at       TIMESTAMPTZ
```

---

## API endpoints

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | `/auth/register` | — | Create account, returns token pair |
| POST | `/auth/login` | — | Login, returns token pair |
| POST | `/auth/refresh` | — | Rotate refresh token |
| POST | `/auth/logout` | — | Revoke refresh token |
| GET | `/auth/me` | JWT | Get current user |
| POST | `/auth/forgot-password` | — | Send 6-digit reset code by email |
| POST | `/auth/reset-password` | — | Reset password with code |
| POST | `/scan` | JWT | Identify a plant from an image |
| POST | `/plants` | JWT | Save plant to collection |
| GET | `/plants` | JWT | List saved plants (newest first) |

---

## Feature status

| Feature | Status |
|---------|--------|
| Registration and login | Done |
| Token refresh and server-side logout | Done |
| Password reset by email | Done |
| Auth persistence (auto-login, silent refresh) | Done |
| Camera and gallery capture | Done |
| Plant identification via Claude AI | Done |
| Care guide (light, water, humidity, temperature) | Done |
| Save plant to collection | Done |
| My Plants collection screen | Done |
| Plant detail view | Planned (E4) |
| Chat with Claude about a specific plant | Planned (E5) |
| Care schedule and reminders | Planned (E6) |
| Plant journal notes | Planned (E7) |
| Plant health tracking | Planned (E8) |

---

## Backend setup

**Prerequisites:** Python 3.9+, PostgreSQL running locally

```bash
cd api
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

Copy the example env file and fill in the values:

```bash
cp .env.example .env
```

| Variable | Description |
|----------|-------------|
| `SECRET_KEY` | Run `python3 -c "import secrets; print(secrets.token_hex(32))"` |
| `DATABASE_URL` | `postgresql+asyncpg://YOUR_USERNAME@localhost:5432/plantit` |
| `DATABASE_URL_SYNC` | `postgresql+psycopg2://YOUR_USERNAME@localhost:5432/plantit` |
| `ANTHROPIC_API_KEY` | From [console.anthropic.com](https://console.anthropic.com) |
| `RESEND_API_KEY` | From [resend.com](https://resend.com) (free tier works) |
| `RESEND_FROM_EMAIL` | `PlantIt Helper <onboarding@resend.dev>` |

On Mac, PostgreSQL uses your system username as the default role. Run `whoami` to find it.

```bash
psql postgres -c "CREATE DATABASE plantit;"
alembic upgrade head
uvicorn main:app --reload
```

API runs at `http://127.0.0.1:8000` — interactive docs at `http://127.0.0.1:8000/docs`.

---

## Flutter setup

**Prerequisites:** Flutter SDK ([install guide](https://docs.flutter.dev/get-started/install))

```bash
cd app
flutter pub get
```

Open `app/lib/config/app_config.dart` and set `baseUrl`:

```dart
// Simulator
static const String baseUrl = 'http://localhost:8000';

// Physical device — find your Mac's IP with: ipconfig getifaddr en0
static const String baseUrl = 'http://192.168.1.x:8000';
```

```bash
flutter run
```

---

## Running tests

**Backend:**
```bash
cd api
source venv/bin/activate
pytest tests/ -v
```

**Flutter:**
```bash
cd app
flutter test
```

