import logging
from datetime import datetime, timezone, timedelta

import anthropic

from models.plant import Plant
from models.plant_scan import PlantScan
from models.chat_message import ChatMessage

logger = logging.getLogger(__name__)

_client = anthropic.AsyncAnthropic()

# Model and token limit as named constants — easy to change in one place.
_MODEL = "claude-opus-4-5"
_MAX_TOKENS = 2048  # 1024 was tight for detailed care responses

# How many past messages to send to Claude as conversation history.
# Public so the router can use it to limit the DB query.
HISTORY_WINDOW = 20

# How many recent scans to include in the system prompt.
SCAN_SUMMARY_COUNT = 3


def _relative_time(dt: datetime) -> str:
    """Return a human-readable relative timestamp, e.g. '2 days ago'."""
    now = datetime.now(timezone.utc)
    diff = now - dt
    if diff < timedelta(minutes=1):
        return "just now"
    if diff < timedelta(hours=1):
        mins = int(diff.total_seconds() / 60)
        return f"{mins} minute{'s' if mins != 1 else ''} ago"
    if diff < timedelta(days=1):
        hours = int(diff.total_seconds() / 3600)
        return f"{hours} hour{'s' if hours != 1 else ''} ago"
    days = diff.days
    if days == 1:
        return "yesterday"
    if days < 30:
        return f"{days} days ago"
    months = days // 30
    return f"{months} month{'s' if months != 1 else ''} ago"


def build_system_prompt(
    plant: Plant,
    latest_scan: PlantScan | None,
    recent_scans: list[PlantScan],
    scan_count: int,
) -> str:
    """
    Build a plant-aware system prompt for Claude.
    Called fresh on every request so the context is always current.
    """
    if latest_scan is None:
        return (
            f"You are a plant care expert helping a user look after their plant "
            f"nicknamed '{plant.name}'. No scan data is available yet. "
            "Give general plant care advice and encourage the user to scan their plant "
            "for personalised guidance."
        )

    care = latest_scan.care_json
    tips = care.get("tips", [])
    tips_text = "\n".join(f"- {t}" for t in tips) if tips else "- No specific tips."

    fun_fact_line = (
        f"\nFun fact: {latest_scan.fun_fact}" if latest_scan.fun_fact else ""
    )

    health_obs_line = (
        latest_scan.health_observation
        if latest_scan.health_observation and latest_scan.health != "unknown"
        else "Not yet assessed."
    )

    scan_history_lines: list[str] = []
    for scan in recent_scans:
        obs = scan.health_observation or "No observation recorded."
        scan_history_lines.append(
            f"  - {_relative_time(scan.scanned_at)}: {scan.health} — {obs}"
        )
    scan_history_text = (
        "\n".join(scan_history_lines)
        if scan_history_lines
        else "  - Only one scan on record."
    )

    return f"""You are a plant care expert helping a user look after their plant.

Plant: {latest_scan.common_name} ({latest_scan.scientific_name})
Nickname: {plant.name}
Care needs:
  Light: {care.get("light", "unknown")}
  Water: {care.get("water", "unknown")}
  Humidity: {care.get("humidity", "unknown")}
  Temperature: {care.get("temperature", "unknown")}
Tips:
{tips_text}{fun_fact_line}

Current health: {latest_scan.health}
Health observation: {health_obs_line}

Scan history ({scan_count} total scan{"s" if scan_count != 1 else ""}):
{scan_history_text}

Keep your responses conversational and concise. Be direct about problems.
If the user describes new symptoms, address them specifically.
Do not repeat the plant's full care guide unless asked — the user has already seen it."""


async def send_message(
    plant: Plant,
    latest_scan: PlantScan | None,
    recent_scans: list[PlantScan],
    scan_count: int,
    history: list[ChatMessage],
    user_message: str,
) -> str:
    """
    Send a user message to Claude with full plant context and conversation history.
    Returns Claude's reply as a plain string.
    """
    system_prompt = build_system_prompt(plant, latest_scan, recent_scans, scan_count)

    # Router already caps history at HISTORY_WINDOW rows, but slice defensively.
    messages = [{"role": m.role, "content": m.content} for m in history]
    messages.append({"role": "user", "content": user_message})

    logger.info(
        f"chat request | plant_id={plant.id} scan_count={scan_count} "
        f"history_len={len(history)} user_msg_len={len(user_message)}"
    )
    logger.debug(f"system_prompt | plant_id={plant.id}\n{system_prompt}")

    response = await _client.messages.create(
        model=_MODEL,
        max_tokens=_MAX_TOKENS,
        system=system_prompt,
        messages=messages,
    )

    if not response.content:
        logger.error(f"Claude returned empty content | plant_id={plant.id}")
        raise ValueError("Claude returned an empty response")

    reply = response.content[0].text
    logger.info(f"chat response | plant_id={plant.id} reply_len={len(reply)}")
    return reply