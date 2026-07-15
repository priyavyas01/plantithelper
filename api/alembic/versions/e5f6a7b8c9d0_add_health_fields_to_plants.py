"""add health fields to plants

Revision ID: e5f6a7b8c9d0
Revises: b3c4d5e6f7a8
Create Date: 2026-07-15 00:00:00.000000

Two new columns on the plants table:
  - health: VARCHAR(20) — one of healthy / needs_attention / concerning / unknown
  - health_observation: TEXT — one sentence from Claude describing what it saw

Both columns are NOT NULL with server defaults so existing rows survive the
migration without a data-fill step:
  - health defaults to 'unknown'  (safest value — we don't know old plants' health)
  - health_observation defaults to '' (empty string — UI shows nothing for old rows)

Why server_default not Python default?
  server_default is applied by Postgres itself when the column is added, so
  all existing rows are updated atomically inside the ALTER TABLE transaction.
  A Python default (SQLAlchemy's default=) only fires on INSERT, not on
  column addition.
"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa

revision: str = 'e5f6a7b8c9d0'
down_revision: Union[str, Sequence[str], None] = 'b3c4d5e6f7a8'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        'plants',
        sa.Column(
            'health',
            sa.String(length=20),
            nullable=False,
            server_default='unknown',
        ),
    )
    op.add_column(
        'plants',
        sa.Column(
            'health_observation',
            sa.Text(),
            nullable=False,
            server_default='',
        ),
    )


def downgrade() -> None:
    op.drop_column('plants', 'health_observation')
    op.drop_column('plants', 'health')
