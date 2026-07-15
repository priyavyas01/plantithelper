import base64
import json
import logging

from openai import AsyncOpenAI
from fastapi import HTTPException

from schemas.scan import ScanResponse, CareInfo

logger = logging.getLogger(__name__)

_client = AsyncOpenAI()

# The prompt tells GPT exactly what we want.
# "Respond ONLY with valid JSON" is the key instruction — without it,
# GPT might write "Sure! Here's the plant info: {...}" which breaks json.loads().
_SYSTEM_PROMPT = """You are an expert botanist. Identify the plant in the image provided.

Respond ONLY with valid JSON. No explanation, no markdown, no code fences. Just JSON.

If you can identify a plant, use this format:
{
  "identified": true,
  "common_name": "...",
  "scientific_name": "...",
  "confidence": "high" or "medium" or "low",
  "care": {
    "light": "...",
    "water": "...",
    "humidity": "...",
    "temperature": "...",
    "tips": ["...", "..."]
  },
  "fun_fact": "..."
}

If no plant is visible or the image is too blurry to identify, use this format:
{
  "identified": false,
  "reason": "..."
}"""


async def identify_plant(image_bytes: bytes) -> ScanResponse:
    logger.info(f"🔍 Scan request received — image size: {len(image_bytes) / 1024:.1f}KB")

    image_b64 = base64.b64encode(image_bytes).decode("utf-8")

    logger.info("📡 Sending image to GPT-4o Vision...")
    try:
        response = await _client.chat.completions.create(
            model="gpt-4o",
            messages=[
                {"role": "system", "content": _SYSTEM_PROMPT},
                {
                    "role": "user",
                    "content": [
                        {
                            "type": "image_url",
                            "image_url": {
                                "url": f"data:image/jpeg;base64,{image_b64}",
                                # "auto" lets GPT decide the detail level.
                                # "low" is cheaper but misses fine details.
                                # "high" is more accurate but costs more tokens.
                                "detail": "auto",
                            },
                        },
                        {
                            "type": "text",
                            "text": "Identify this plant.",
                        },
                    ],
                },
            ],
            # max_tokens caps the response length.
            # Our JSON response is ~300 tokens max — 500 gives comfortable headroom.
            max_tokens=500,
        )
    except Exception as e:
        logger.error(f"❌ OpenAI API error: {e}")
        raise HTTPException(status_code=500, detail=f"OpenAI API error: {str(e)}")

    raw_text = response.choices[0].message.content
    logger.info(f"📥 GPT response received: {raw_text[:120]}...")

    try:
        data = json.loads(raw_text)
    except (ValueError, TypeError):
        raise HTTPException(
            status_code=500,
            detail="GPT returned an unexpected response format.",
        )

    if not data.get("identified", False):
        reason = data.get("reason", "No plant detected in the image.")
        logger.warning(f"🌿 Plant not identified: {reason}")
        raise HTTPException(status_code=422, detail=reason)

    logger.info(f"✅ Plant identified: {data.get('common_name')} ({data.get('confidence')} confidence)")

    # Step 6: build and return the ScanResponse.
    # Pydantic validates the fields here — if GPT returned a confidence value
    # we didn't expect (e.g. "very high"), Pydantic raises a ValidationError.
    try:
        return ScanResponse(
            common_name=data["common_name"],
            scientific_name=data["scientific_name"],
            confidence=data["confidence"],
            care=CareInfo(**data["care"]),  # ** unpacks the dict into keyword args
            fun_fact=data["fun_fact"],
        )
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Could not parse plant data: {str(e)}",
        )
