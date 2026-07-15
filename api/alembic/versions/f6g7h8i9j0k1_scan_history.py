"""scan history — create plant_scans, migrate data, drop scan columns from plants

Revision ID: f6g7h8i9j0k1
Revises: e5f6a7b8c9d0
Create Date: 2026-07-15 00:00:00.000000

What this migration does (all in one transaction — if any step fails, everything rolls back):

  Step 1 — CREATE TABLE plant_scans
  Step 2 — Copy all existing scan data from plants → plant_scans
            Each plant row becomes one plant_scans row (its first/only scan).
            scanned_at = plants.created_at so history timestamps make sense.
  Step 3 — DROP the scan columns from plants
            plants becomes an identity table: id, user_id, name, created_at.

Why one transaction?
  If step 2 fails (bad data, constraint violation), step 3 must not run.
  Losing the source columns before the data is copied would be unrecoverable.
  Alembic wraps each migration in a transaction by default — do not add
  autocommit=True or connection.execute(text('COMMIT')) here.

Why gen_random_uuid()?
  We need a UUID for each new plant_scans row. gen_random_uuid() is a
  Postgres built-in — no Python loop needed, runs entirely in SQL.
  Alternative: uuid_generate_v4() (requires uuid-ossp extension, less portable).
"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import JSONB, UUID

revision: str = 'f6g7h8i9j0k1'
down_revision: Union[str, Sequence[str], None] = 'e5f6a7b8c9d0'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Step 1: create plant_scans table
    op.create_table(
        'plant_scans',
        sa.Column('id', UUID(as_uuid=True), primary_key=True),
        sa.Column(
            'plant_id',
            UUID(as_uuid=True),
            sa.ForeignKey('plants.id', ondelete='CASCADE'),
            nullable=False,
            index=True,
        ),
        sa.Column('common_name', sa.String(100), nullable=False),
        sa.Column('scientific_name', sa.String(150), nullable=False),
        sa.Column('confidence', sa.String(10), nullable=False),
        sa.Column('health', sa.String(20), nullable=False),
        sa.Column('health_observation', sa.Text(), nullable=False),
        sa.Column('care_json', JSONB(), nullable=False),
        sa.Column('fun_fact', sa.Text(), nullable=True),
        sa.Column('scanned_at', sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index('ix_plant_scans_plant_id_scanned_at', 'plant_scans', ['plant_id', 'scanned_at'])

    # Step 2: migrate existing plant data into plant_scans
    # scanned_at = plants.created_at — preserves the original scan timestamp
    op.execute("""
        INSERT INTO plant_scans (
            id, plant_id, common_name, scientific_name,
            confidence, health, health_observation,
            care_json, fun_fact, scanned_at
        )
        SELECT
            gen_random_uuid(),
            id,
            common_name,
            scientific_name,
            confidence,
            health,
            health_observation,
            care_json,
            fun_fact,
            created_at
        FROM plants
    """)

    # Step 3: drop scan columns from plants — it's now an identity table only
    op.drop_column('plants', 'common_name')
    op.drop_column('plants', 'scientific_name')
    op.drop_column('plants', 'confidence')
    op.drop_column('plants', 'health')
    op.drop_column('plants', 'health_observation')
    op.drop_column('plants', 'care_json')
    op.drop_column('plants', 'fun_fact')


def downgrade() -> None:
    # Re-add the columns to plants
    op.add_column('plants', sa.Column('common_name', sa.String(100), nullable=False, server_default=''))
    op.add_column('plants', sa.Column('scientific_name', sa.String(150), nullable=False, server_default=''))
    op.add_column('plants', sa.Column('confidence', sa.String(10), nullable=False, server_default='high'))
    op.add_column('plants', sa.Column('health', sa.String(20), nullable=False, server_default='unknown'))
    op.add_column('plants', sa.Column('health_observation', sa.Text(), nullable=False, server_default=''))
    op.add_column('plants', sa.Column('care_json', JSONB(), nullable=False, server_default='{}'))
    op.add_column('plants', sa.Column('fun_fact', sa.Text(), nullable=True))

    # Restore latest scan data back into plants
    op.execute("""
        UPDATE plants p
        SET
            common_name       = s.common_name,
            scientific_name   = s.scientific_name,
            confidence        = s.confidence,
            health            = s.health,
            health_observation = s.health_observation,
            care_json         = s.care_json,
            fun_fact          = s.fun_fact
        FROM (
            SELECT DISTINCT ON (plant_id)
                plant_id, common_name, scientific_name, confidence,
                health, health_observation, care_json, fun_fact
            FROM plant_scans
            ORDER BY plant_id, scanned_at DESC
        ) s
        WHERE p.id = s.plant_id
    """)

    op.drop_index('ix_plant_scans_plant_id_scanned_at', table_name='plant_scans')
    op.drop_table('plant_scans')
