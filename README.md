# 🌿 PlantIt Helper

A mobile app to help you track and care for your plants.

Built with **Flutter** (mobile) + **FastAPI** (backend) + **PostgreSQL** (database).

---

## Project Structure

```
plantithelper/
├── api/        # FastAPI backend
└── app/        # Flutter mobile app
```

---

## Backend Setup (`api/`)

### Prerequisites

- Python 3.9+
- PostgreSQL running locally

### 1. Create and activate a virtual environment

```bash
cd api
python3 -m venv venv
source venv/bin/activate        # Mac/Linux
# venv\Scripts\activate         # Windows
```

### 2. Install dependencies

```bash
pip install -r requirements.txt
```

### 3. Set up environment variables

```bash
cp .env.example .env
```

Open `.env` and fill in:

| Variable | Description |
|---|---|
| `SECRET_KEY` | Random secret — run `python3 -c "import secrets; print(secrets.token_hex(32))"` |
| `DATABASE_URL` | e.g. `postgresql+asyncpg://YOUR_MAC_USERNAME@localhost:5432/plantit` |
| `DATABASE_URL_SYNC` | Same but `postgresql+psycopg2://...` |
| `RESEND_API_KEY` | Get a free key at [resend.com](https://resend.com) |
| `RESEND_FROM_EMAIL` | `PlantIt Helper <onboarding@resend.dev>` (works without a custom domain) |

> **Note on DATABASE_URL:** On Mac, PostgreSQL uses your system username as the default role. Run `whoami` to find it.

### 4. Create the database

```bash
psql postgres -c "CREATE DATABASE plantit;"
```

### 5. Run migrations

```bash
alembic upgrade head
```

### 6. Start the server

```bash
uvicorn main:app --reload
```

API is now running at **http://127.0.0.1:8000**

Interactive docs: **http://127.0.0.1:8000/docs**

---

## Flutter App Setup (`app/`)

### Prerequisites

- Flutter SDK ([install guide](https://docs.flutter.dev/get-started/install))
- iOS Simulator or Android Emulator

### 1. Install dependencies

```bash
cd app
flutter pub get
```

### 2. Configure the API base URL

Open `app/lib/services/auth_service.dart` and update:

```dart
static const String _baseUrl = 'http://localhost:8000';
```

> If running on a **physical device**, replace `localhost` with your Mac's local IP (e.g. `192.168.1.x`). Find it with `ipconfig getifaddr en0`.

### 3. Run the app

```bash
flutter run
```

---

## Features

- [x] User registration & login (JWT auth)
- [x] Token refresh & server-side logout
- [x] Password reset via email code
- [ ] Plant tracking
- [ ] Care reminders

---

## Tech Stack

| Layer | Technology |
|---|---|
| Mobile | Flutter |
| Backend | FastAPI + SQLAlchemy (async) |
| Database | PostgreSQL + Alembic |
| Auth | JWT (access) + rotating refresh tokens |
| Email | Resend |
