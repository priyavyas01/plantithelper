from db.database import engine, Base

# Import all models so Base.metadata knows about every table.
# This file is called once at app startup to create any tables
# that don't exist yet. In production we use Alembic migrations
# instead, but this is useful for local dev and testing.
import models.user          # noqa: F401
import models.refresh_token # noqa: F401
import models.plant         # noqa: F401
import models.plant_scan    # noqa: F401
import models.chat_message  # noqa: F401


async def init_db():
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
