import base64
import json
import logging
import time

from openai import AsyncOpenAI
from fastapi import HTTPException

from schemas.scan import ScanResponse, CareInfo

logger = logging.getLogger(__name__)

_client = AsyncOpenAI()

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
    size_kb = len(image_bytes) / 1024
    logger.info(f"scan started | size_kb={size_kb:.1f}")

    # Convert raw bytes to base64 string for OpenAI API
    image_b64 = base64.b64encode(image_bytes).decode("utf-8")
    logger.debug(f"base64 encoded | original_bytes={len(image_bytes)} encoded_chars={len(image_b64)}")

    logger.info("openai request | model=gpt-4o detail=auto max_tokens=500")
    t0 = time.monotonic()
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
                                "detail": "auto",
                            },
                        },
                        {"type": "text", "text": "Identify this plant."},
                    ],
                },
            ],
            max_tokens=500,
        )
    except Exception as e:
        logger.error(f"openai request failed | error={e}")
        raise HTTPException(status_code=500, detail=f"OpenAI API error: {str(e)}")

    elapsed = time.monotonic() - t0
    usage = response.usage
    logger.info(
        f"openai response received | duration_s={elapsed:.2f} "
        f"prompt_tokens={usage.prompt_tokens} "
        f"completion_tokens={usage.completion_tokens} "
        f"total_tokens={usage.total_tokens}"
    )

    raw_text = response.choices[0].message.content
    logger.debug(f"raw gpt output | content={raw_text}")

    # Parse JSON — GPT should return clean JSON per our prompt instructions
    try:
        data = json.loads(raw_text)
        logger.info(f"json parsed | identified={data.get('identified')}")
    except (ValueError, TypeError) as e:
        logger.error(f"json parse failed | error={e} raw_preview={raw_text[:200]}")
        raise HTTPException(status_code=500, detail="GPT returned an unexpected response format.")

    if not data.get("identified", False):
        reason = data.get("reason", "No plant detected in the image.")
        logger.warning(f"plant not identified | reason={reason}")
        raise HTTPException(status_code=422, detail=reason)

    # Build typed response — Pydantic validates all fields here
    try:
        result = ScanResponse(
            common_name=data["common_name"],
            scientific_name=data["scientific_name"],
            confidence=data["confidence"],
            care=CareInfo(**data["care"]),
            fun_fact=data["fun_fact"],
        )
        logger.info(
            f"scan complete | name={result.common_name} "
            f"scientific={result.scientific_name} "
            f"confidence={result.confidence}"
        )
        return result
    except Exception as e:
        logger.error(f"response build failed | error={e} raw_data={data}")
        raise HTTPException(status_code=500, detail=f"Could not parse plant data: {str(e)}")
