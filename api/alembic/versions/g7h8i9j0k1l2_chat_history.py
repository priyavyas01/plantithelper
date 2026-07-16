"""chat history — create chat_messages table

Revision ID: g7h8i9j0k1l2
Revises: f6g7h8i9j0k1
Create Date: 2026-07-15

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID

revision = 'g7h8i9j0k1l2'
down_revision = 'f6g7h8i9j0k1'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        'chat_messages',
        sa.Column('id', UUID(as_uuid=True), primary_key=True),
        sa.Column(
            'plant_id',
            UUID(as_uuid=True),
            sa.ForeignKey('plants.id', ondelete='CASCADE'),
            nullable=False,
        ),
        sa.Column('role', sa.String(20), nullable=False),
        sa.Column('content', sa.Text, nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index(
        'ix_chat_messages_plant_id_created_at',
        'chat_messages',
        ['plant_id', 'created_at'],
    )
    op.create_index(
        'ix_chat_messages_plant_id',
        'chat_messages',
        ['plant_id'],
    )


def downgrade() -> None:
    op.drop_index('ix_chat_messages_plant_id', table_name='chat_messages')
    op.drop_index('ix_chat_messages_plant_id_created_at', table_name='chat_messages')
    op.drop_table('chat_messages')
