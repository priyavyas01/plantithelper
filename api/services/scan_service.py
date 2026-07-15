import base64
import json

from openai import AsyncOpenAI
from fastapi import HTTPException

from schemas.scan import ScanResponse, CareInfo

# AsyncOpenAI reads OPENAI_API_KEY from the environment automatically.
# We create one client at module load time and reuse it — creating a new
# HTTP connection on every request would be slow.
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
    """
    Send image_bytes to GPT-4o Vision and parse the response into a ScanResponse.

    Raises:
        HTTPException 422 — GPT could not identify a plant
        HTTPException 500 — OpenAI API error or unexpected response format
    """

    # Step 1: encode bytes to base64 string.
    # base64.b64encode() returns bytes like b"abc123==".
    # .decode() converts those bytes to a plain Python string "abc123==".
    # We need a string because JSON can't contain raw bytes.
    image_b64 = base64.b64encode(image_bytes).decode("utf-8")

    # Step 2: call GPT-4o Vision.
    # The messages list is how you talk to GPT:
    #   - "system" message sets the rules / persona
    #   - "user" message is the actual request
    # We send the image as a "image_url" content block.
    # The URL format "data:image/jpeg;base64,..." is a data URL —
    # it embeds the image directly in the request instead of linking to it.
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
        # Any network error, invalid API key, quota exceeded etc.
        raise HTTPException(status_code=500, detail=f"OpenAI API error: {str(e)}")

    # Step 3: extract the text content from GPT's response.
    # response.choices is a list — we always take [0] (we only asked for one response).
    # .message.content is the raw string GPT returned.
    raw_text = response.choices[0].message.content

    # Step 4: parse the JSON string into a Python dict.
    # json.loads() converts '{"key": "value"}' → {"key": "value"}
    # If GPT ignored our instructions and returned prose, this will raise ValueError.
    try:
        data = json.loads(raw_text)
    except (ValueError, TypeError):
        raise HTTPException(
            status_code=500,
            detail="GPT returned an unexpected response format.",
        )

    # Step 5: check if GPT identified a plant.
    if not data.get("identified", False):
        reason = data.get("reason", "No plant detected in the image.")
        raise HTTPException(status_code=422, detail=reason)

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
