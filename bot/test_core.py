"""Unit tests for the community bot logic (TASK_Q6_03).

Run: python3 -m unittest discover -s bot
"""

import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(__file__))

import core  # noqa: E402


class TestRateLimiter(unittest.TestCase):
    def test_allows_up_to_the_limit(self):
        limiter = core.RateLimiter(limit=5, window=60)
        for i in range(5):
            self.assertTrue(limiter.allow(42, now=1000 + i))

    def test_blocks_the_sixth_call_within_the_window(self):
        limiter = core.RateLimiter(limit=5, window=60)
        for i in range(5):
            limiter.allow(42, now=1000 + i)
        self.assertFalse(limiter.allow(42, now=1005))

    def test_window_resets_after_expiry(self):
        limiter = core.RateLimiter(limit=5, window=60)
        for i in range(5):
            limiter.allow(42, now=1000 + i)
        # 61s after the first call, the window has rolled over.
        self.assertTrue(limiter.allow(42, now=1061))

    def test_retry_after_is_positive_when_blocked(self):
        limiter = core.RateLimiter(limit=5, window=60)
        for i in range(5):
            limiter.allow(7, now=1000)
        self.assertGreater(limiter.retry_after(7, now=1000), 0)


class TestPermissions(unittest.TestCase):
    def test_support_role_required(self):
        self.assertTrue(core.has_support_role(["Member", "Support"]))
        self.assertFalse(core.has_support_role(["Member"]))


class TestBugReport(unittest.TestCase):
    def test_thread_and_template_fields_present(self):
        report = core.build_bug_report(
            title="Stuck in wall",
            reporter_tag="player#1234",
            ingame_name="barlu3",
            description="fell through the floor",
            place_version="v1.0.3",
        )
        self.assertEqual(report["channel"], "bug-triage")
        self.assertEqual(report["thread_name"], "[BUG] Stuck in wall")
        for field in ("Reporter", "In-game name", "Description", "Reproduction steps", "Place version"):
            self.assertIn(field, report["fields"])


class TestLookup(unittest.TestCase):
    def test_returns_embed_for_existing_player(self):
        def fetch(_name):
            return {"level": 50, "ilvl": 1100, "last_online": "2026-06-10", "guild": "Hollow"}

        embed = core.lookup_embed("barlu3", fetch)
        self.assertIsNotNone(embed)
        self.assertEqual(embed["title"], "Player: barlu3")
        self.assertEqual(embed["fields"]["iLvl"], 1100)

    def test_returns_none_for_missing_player(self):
        embed = core.lookup_embed("ghost", lambda _name: None)
        self.assertIsNone(embed)


if __name__ == "__main__":
    unittest.main()
