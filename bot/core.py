"""Pure bot logic for the Lost Blox community bot (TASK_Q6_03).

Kept free of any discord.py import so the rate limiting, permission checks, bug
report formatting, and player lookup are unit-testable with stdlib only. The
discord wiring in lostblox_bot.py calls into these.
"""

from __future__ import annotations

import time
from typing import Callable, Optional

SUPPORT_ROLE = "Support"
BUG_TRIAGE_CHANNEL = "bug-triage"


class RateLimiter:
    """Sliding-window limiter: at most `limit` calls per `window` seconds, per key.

    In-memory; resets on bot restart (acceptable for soft abuse protection).
    """

    def __init__(self, limit: int = 5, window: float = 60.0) -> None:
        self.limit = limit
        self.window = window
        self._calls: dict[int, list[float]] = {}

    def _recent(self, key: int, now: float) -> list[float]:
        return [t for t in self._calls.get(key, []) if now - t < self.window]

    def allow(self, key: int, now: Optional[float] = None) -> bool:
        now = time.time() if now is None else now
        recent = self._recent(key, now)
        if len(recent) >= self.limit:
            self._calls[key] = recent
            return False
        recent.append(now)
        self._calls[key] = recent
        return True

    def retry_after(self, key: int, now: Optional[float] = None) -> float:
        now = time.time() if now is None else now
        recent = self._recent(key, now)
        if len(recent) < self.limit:
            return 0.0
        oldest = min(recent)
        return max(0.0, self.window - (now - oldest))


def has_support_role(role_names: list[str], support_role: str = SUPPORT_ROLE) -> bool:
    return support_role in role_names


def build_bug_report(
    title: str,
    reporter_tag: str,
    ingame_name: str,
    description: str,
    place_version: str,
) -> dict:
    """Builds the thread name + templated fields for a bug report."""
    return {
        "channel": BUG_TRIAGE_CHANNEL,
        "thread_name": f"[BUG] {title}",
        "fields": {
            "Reporter": reporter_tag,
            "In-game name": ingame_name,
            "Description": description,
            "Reproduction steps": "1. \n2. \n3. ",
            "Place version": place_version,
        },
    }


def lookup_embed(username: str, fetch_fn: Callable[[str], Optional[dict]]) -> Optional[dict]:
    """Returns an embed dict for a player, or None if not found.

    fetch_fn queries the analytics endpoint (TASK_Q6_01 Exporter cache) — injected
    so this stays testable without a network call.
    """
    data = fetch_fn(username)
    if data is None:
        return None
    return {
        "title": f"Player: {username}",
        "fields": {
            "Character level": data.get("level", "?"),
            "iLvl": data.get("ilvl", "?"),
            "Last online": data.get("last_online", "unknown"),
            "Guild": data.get("guild", "none"),
        },
    }


# Reply strings, centralized so tests and the bot agree on exact wording.
MSG_NOT_FOUND = "Player not found."
MSG_NO_PERMISSION = "You don't have permission to use this command."


def rate_limit_message(retry_after: float) -> str:
    return f"Rate limit exceeded. Try again in {int(retry_after) + 1} seconds."
