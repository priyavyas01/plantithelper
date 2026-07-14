# PlantIt Helper API

Python FastAPI backend for the PlantIt Helper plant identification app.

## Stack
- **FastAPI** — REST API framework
- **PostgreSQL** — primary database (SQLAlchemy ORM + Alembic migrations)
- **OpenAI GPT-4 Vision** — plant identification + AI chat
- **C++ / pybind11** — image preprocessing module (<50ms target)
- **AWS S3** — plant photo storage
- **JWT** — stateless auth (python-jose)
- **bcrypt** — password hashing (passlib)

## Project Structure

```
plantithelper-api/
├── main.py                   # FastAPI app entry point
├── requirements.txt          # Python dependencies
├── .env                      # Secrets (never committed)
├── docs/
│   └── architecture.md       # System diagrams (Mermaid)
├── db/
│   ├── database.py           # SQLAlchemy engine + session
│   └── __init__.py
├── models/                   # SQLAlchemy ORM models
│   ├── user.py
│   ├── plant.py
│   ├── scan.py
│   ├── chat.py
│   └── schedule.py
├── router/                   # FastAPI route handlers
│   ├── auth.py               # POST /auth/register, /auth/login, GET /auth/me
│   ├── plants.py             # CRUD /plants
│   ├── scan.py               # POST /scan
│   ├── chat.py               # POST /chat/{plant_id}/message
│   └── schedule.py           # GET/POST /schedule
├── services/                 # Business logic
│   ├── auth_service.py       # JWT + bcrypt helpers
│   ├── llm_service.py        # OpenAI Vision calls
│   ├── plant_service.py      # Plant + scan DB operations
│   ├── chat_service.py       # Chat history + context building
│   └── schedule_service.py   # Care schedule generation
└── cpp/
    ├── preprocess.cpp        # Image resize/normalize/feature extract
    ├── preprocess.hpp
    └── CMakeLists.txt
```

## Setup

### Prerequisites
- Python 3.11+
- PostgreSQL running locally
- cmake + OpenCV (for C++ module)
- OpenAI API key

### Install Python dependencies
```bash
pip install -r requirements.txt
```

### Environment variables
Create a `.env` file in the project root:
```env
DATABASE_URL=postgresql://user:password@localhost:5432/plantithelper
SECRET_KEY=your-secret-key-min-32-chars
OPENAI_API_KEY=sk-...
AWS_ACCESS_KEY_ID=...
AWS_SECRET_ACCESS_KEY=...
AWS_S3_BUCKET=plantithelper-images
AWS_REGION=us-east-1
```

### Build the C++ module
```bash
cd cpp
mkdir build && cd build
cmake ..
make
# Module will be importable as plantit_preprocess
```

**Note for Apple Silicon:** OpenCV may need `export OpenCV_DIR=$(brew --prefix opencv)/lib/cmake/opencv4` before cmake.

### Run the API
```bash
uvicorn main:app --reload --port 8000
```

## API Endpoints

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/health` | No | Health check |
| POST | `/auth/register` | No | Create account |
| POST | `/auth/login` | No | Login, get JWT |
| GET | `/auth/me` | JWT | Get current user |
| GET | `/plants` | JWT | List my plants |
| POST | `/plants` | JWT | Save a plant |
| GET | `/plants/{id}` | JWT | Plant detail |
| POST | `/scan` | JWT | Scan a plant image |
| GET | `/plants/{id}/scans` | JWT | Scan history |
| POST | `/chat/{plant_id}/message` | JWT | Send chat message |
| GET | `/chat/{plant_id}/history` | JWT | Chat history |
| GET | `/schedule` | JWT | View care schedule |
| POST | `/schedule/generate/{plant_id}` | JWT | Generate schedule from scan |
| GET | `/plants/{id}/journal` | JWT | Get journal entries |
| POST | `/plants/{id}/journal` | JWT | Add journal entry |

Full interactive docs available at `http://localhost:8000/docs` when running.

## Architecture

See [docs/architecture.md](docs/architecture.md) for:
- System overview diagram
- Authentication flow
- Plant scan pipeline
- Chat flow
- Care schedule generation
- Database entity-relationship diagram

## Story Progress

See [stories.md](stories.md) for full story definitions, acceptance criteria, and edge cases.  
See [TRACKER.md](TRACKER.md) for session-by-session progress log.
