from pydantic import BaseModel, Field
from datetime import datetime
from typing import Literal


class ChatMessageResponse(BaseModel):
    id: str
    role: Literal["user", "assistant"]
    content: str
    created_at: datetime

    @classmethod
    def from_orm(cls, msg) -> "ChatMessageResponse":
        return cls(
            id=str(msg.id),
            role=msg.role,
            content=msg.content,
            created_at=msg.created_at,
        )


class ChatHistoryResponse(BaseModel):
    messages: list[ChatMessageResponse]


class ChatRequest(BaseModel):
    message: str = Field(..., min_length=1, description="User's message to Claude")


class ChatResponse(BaseModel):
    reply: str
    message_id: str
    timestamp: datetime
