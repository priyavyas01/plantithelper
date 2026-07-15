"""add plants table

Revision ID: b3c4d5e6f7a8
Revises: a1b2c3d4e5f6
Create Date: 2026-07-15 00:00:00.000000

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import JSONB

revision: str = 'b3c4d5e6f7a8'
down_revision: Union[str, Sequence[str], None] = 'a1b2c3d4e5f6'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        'plants',
        sa.Column('id', sa.UUID(), nullable=False),
        sa.Column('user_id', sa.UUID(), nullable=False),
        sa.Column('name', sa.String(length=100), nullable=False),
        sa.Column('common_name', sa.String(length=100), nullable=False),
        sa.Column('scientific_name', sa.String(length=150), nullable=False),
        sa.Column('confidence', sa.String(length=10), nullable=False),
        # JSONB gives GIN index support and binary storage on Postgres
        sa.Column('care_json', JSONB(), nullable=False),
        sa.Column('fun_fact', sa.Text(), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ondelete='CASCADE'),
        sa.PrimaryKeyConstraint('id'),
    )
    op.create_index('ix_plants_user_id', 'plants', ['user_id'], unique=False)


def downgrade() -> None:
    op.drop_index('ix_plants_user_id', table_name='plants')
    op.drop_table('plants')
