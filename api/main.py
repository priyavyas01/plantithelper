from contextlib import asynccontextmanager
import logging
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded

from core.limiter import limiter
from db.init_db import init_db
from router import auth, scan, plants

# Configure logging format for the whole app.
# %(asctime)s  — timestamp
# %(name)s     — which module logged it (e.g. "router.scan")
# %(levelname)s — INFO, WARNING, ERROR
# %(message)s  — the actual message
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s  %(name)s  %(levelname)s  %(message)s",
    datefmt="%H:%M:%S",
)

logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("startup complete")
    await init_db()
    logger.info("database ready")
    yield
    logger.info("shutdown")


app = FastAPI(title="PlantIt Helper API", version="0.1.0", lifespan=lifespan)

app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# CORS: list every origin that's allowed to call this API.
# In dev this is localhost. In production, replace with your real domains.
# Never use allow_origins=["*"] when allow_credentials=True —
# that's a security vulnerability that lets any site make authenticated requests.
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:5173",  # React (Vite dev server)
        "http://localhost:3000",  # React (fallback)
    ],
    allow_credentials=True,  # needed so cookies are sent cross-origin (React httpOnly cookie auth)
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router)
app.include_router(scan.router)
app.include_router(plants.router)


@app.get("/health")
def health():
    return {"status": "ok", "service": "plantithelper-api"}
