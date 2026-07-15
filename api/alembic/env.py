from logging.config import fileConfig
from sqlalchemy import engine_from_config, pool
from alembic import context
import os
import sys

# Make sure our app modules are importable from alembic
sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))

from dotenv import load_dotenv
load_dotenv()

from db.database import Base

# Import all models so Alembic's autogenerate can see them.
# If you add a new model file, import it here — otherwise Alembic
# won't know the table exists and won't include it in migrations.
import models.user          # noqa: F401
import models.refresh_token # noqa: F401
import models.plant         # noqa: F401
import models.plant_scan    # noqa: F401

config = context.config

if config.config_file_name is not None:
    fileConfig(config.config_file_name)

target_metadata = Base.metadata

# Override the sqlalchemy.url from alembic.ini with DATABASE_URL_SYNC from .env.
# We use the SYNC url here (postgresql://) not the async one (postgresql+asyncpg://)
# because Alembic runs synchronously. The app uses async at runtime.
config.set_main_option("sqlalchemy.url", os.getenv("DATABASE_URL_SYNC"))


def run_migrations_offline() -> None:
    url = config.get_main_option("sqlalchemy.url")
    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
    )
    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    connectable = engine_from_config(
        config.get_section(config.config_ini_section, {}),
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )
    with connectable.connect() as connection:
        context.configure(connection=connection, target_metadata=target_metadata)
        with context.begin_transaction():
            context.run_migrations()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()

