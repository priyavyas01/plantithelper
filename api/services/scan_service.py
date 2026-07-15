import base64
import json
import logging
import time

import anthropic
from fastapi import HTTPException

from schemas.scan import ScanResponse, CareInfo

logger = logging.getLogger(__name__)

# AsyncAnthropic reads ANTHROPIC_API_KEY from the environment automatically.
_client = anthropic.AsyncAnthropic()

# Claude differs from OpenAI in one key way:
# the system prompt is a separate parameter, not a message in the array.
# This gives Claude clearer separation between instructions and user input.
_SYSTEM_PROMPT = """You are an expert botanist with deep knowledge of plant identification including bulbs, tubers, corms, rhizomes, and all growth stages.

Respond ONLY with valid JSON. No explanation, no markdown, no code fences. Just JSON.

If you can identify a plant, use this format:
{
  "identified": true,
  "common_name": "...",
  "scientific_name": "...",
  "confidence": "high" or "medium" or "low",
  "health": "healthy" or "needs_attention" or "concerning" or "unknown",
  "health_observation": "One sentence describing what you observe about this plant's health, e.g. 'Leaves look vibrant and full with no visible signs of stress.' or 'Some yellowing on lower leaves — could indicate overwatering or insufficient light.' If health cannot be assessed (e.g. a bare bulb or unclear image), use 'unknown' for health and explain briefly.",
  "care": {
    "light": "...",
    "water": "...",
    "humidity": "...",
    "temperature": "...",
    "tips": ["...", "..."]
  },
  "fun_fact": "..."
}

Health assessment guide:
- "healthy": Plant looks vigorous, leaves are full and colourful, no visible damage or stress
- "needs_attention": Minor issues visible — slight yellowing, some leaf curl, small spots, or dry soil cues
- "concerning": Significant issues — heavy yellowing/browning, wilting, visible pests or rot
- "unknown": Cannot assess from this image (bare bulb/corm, soil only, image too blurry, no leaves visible)

If no plant is visible or the image is too unclear to identify, use this format:
{
  "identified": false,
  "reason": "..."
}"""


async def identify_plant(image_bytes: bytes) -> ScanResponse:
    size_kb = len(image_bytes) / 1024
    logger.info(f"scan started | size_kb={size_kb:.1f}")

    # Convert raw bytes to base64 — Anthropic requires this for image input
    image_b64 = base64.b64encode(image_bytes).decode("utf-8")
    logger.debug(f"base64 encoded | original_bytes={len(image_bytes)} encoded_chars={len(image_b64)}")

    # Anthropic's message format differs from OpenAI:
    # - image is sent as type "image" with a "source" block (not "image_url")
    # - media_type is declared explicitly ("image/jpeg")
    # - system prompt is a top-level parameter, not a message role
    logger.info("anthropic request | model=claude-opus-4-5 max_tokens=1024")
    t0 = time.monotonic()
    try:
        response = await _client.messages.create(
            model="claude-opus-4-5",
            max_tokens=1024,
            system=_SYSTEM_PROMPT,
            messages=[
                {
                    "role": "user",
                    "content": [
                        {
                            "type": "image",
                            "source": {
                                "type": "base64",
                                "media_type": "image/jpeg",
                                "data": image_b64,
                            },
                        },
                        {
                            "type": "text",
                            "text": "Identify this plant. If it is a bulb, tuber, or corm, identify it from its shape, colour, and any visible features.",
                        },
                    ],
                }
            ],
        )
    except Exception as e:
        logger.error(f"anthropic request failed | error={e}")
        raise HTTPException(status_code=500, detail=f"Claude API error: {str(e)}")

    elapsed = time.monotonic() - t0
    logger.info(
        f"anthropic response received | duration_s={elapsed:.2f} "
        f"input_tokens={response.usage.input_tokens} "
        f"output_tokens={response.usage.output_tokens} "
        f"stop_reason={response.stop_reason}"
    )

    # Claude's response is in response.content — a list of content blocks.
    # We always take [0] since we asked for one response and it's text.
    raw_text = response.content[0].text
    logger.info(f"claude raw response | preview={raw_text[:300]}")

    try:
        data = json.loads(raw_text)
        logger.info(f"json parsed | identified={data.get('identified')}")
    except (ValueError, TypeError) as e:
        logger.error(f"json parse failed | error={e} raw_preview={raw_text[:200]}")
        raise HTTPException(status_code=500, detail="Claude returned an unexpected response format.")

    if not data.get("identified", False):
        reason = data.get("reason", "No plant detected in the image.")
        logger.warning(f"plant not identified | reason={reason}")
        raise HTTPException(status_code=422, detail=reason)

    try:
        # Truncate health_observation to 300 chars — Claude tends to be verbose.
        # Python slice [:300] handles strings shorter than 300 chars correctly
        # (returns the full string), so no conditional needed.
        raw_observation = data.get("health_observation", "")
        health_observation = raw_observation[:300]

        # Log the raw health value BEFORE Pydantic validation so that if Claude
        # returns an unexpected value (e.g. "great"), the 500 error log shows
        # exactly what came back instead of just a generic validation error.
        health = data.get("health", "unknown")
        logger.info(f"health parsed | health={health!r} observation_len={len(health_observation)}")
        result = ScanResponse(
            common_name=data["common_name"],
            scientific_name=data["scientific_name"],
            confidence=data["confidence"],
            health=health,
            health_observation=health_observation,
            care=CareInfo(**data["care"]),
            fun_fact=data.get("fun_fact"),  # .get() — Claude sometimes omits this field
        )
        logger.info(
            f"scan complete | name={result.common_name} "
            f"scientific={result.scientific_name} "
            f"health={result.health}"
        )
        return result
    except Exception as e:
        logger.error(f"response build failed | error={e} raw_data={data}")
        raise HTTPException(status_code=500, detail=f"Could not parse plant data: {str(e)}")
