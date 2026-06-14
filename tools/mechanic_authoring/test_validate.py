"""Unit tests for the Abyss Dungeon validator (TASK_Q4_01).

Run: python3 -m unittest discover -s tools/mechanic_authoring
"""

import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(__file__))

import validate  # noqa: E402

BOSS_IDS = {"dungeon_warden", "hollow_knight"}


def dungeon(**overrides):
    data = {
        "id": "abyss_d1",
        "rooms": [
            {
                "id": "room_1",
                "boss_id": "dungeon_warden",
                "mechanics": [
                    {"type": "ColorMatch", "trigger_hp": 0.80, "detonation_time": 6},
                    {"type": "DPSCheck", "trigger_hp": 0.50, "threshold": 0.35, "time_limit": 30},
                    {"type": "PillarPhase", "trigger_hp": 0.20, "pillar_count": 4, "time_limit": 45},
                ],
            }
        ],
    }
    data.update(overrides)
    return data


class TestValidateAbyss(unittest.TestCase):
    def test_valid_dungeon_has_no_errors(self):
        self.assertEqual(validate.validate_abyss(dungeon(), BOSS_IDS), [])

    def test_trigger_hp_must_descend(self):
        data = dungeon()
        data["rooms"][0]["mechanics"][1]["trigger_hp"] = 0.90  # higher than the 0.80 before it
        errors = validate.validate_abyss(data, BOSS_IDS)
        self.assertTrue(any("not in descending order" in e for e in errors))

    def test_unknown_boss_id_is_reported(self):
        data = dungeon()
        data["rooms"][0]["boss_id"] = "ghost_boss"
        errors = validate.validate_abyss(data, BOSS_IDS)
        self.assertTrue(any("not found in boss registry" in e for e in errors))

    def test_mechanic_requires_a_type(self):
        data = dungeon()
        del data["rooms"][0]["mechanics"][0]["type"]
        errors = validate.validate_abyss(data, BOSS_IDS)
        self.assertTrue(any("missing required field: type" in e for e in errors))

    def test_empty_rooms_is_rejected(self):
        errors = validate.validate_abyss(dungeon(rooms=[]), BOSS_IDS)
        self.assertTrue(any("rooms must be a non-empty array" in e for e in errors))


class TestValidateFile(unittest.TestCase):
    def test_real_abyss_file_validates(self):
        repo_root = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
        path = os.path.join(
            repo_root, "src", "ReplicatedStorage", "Configs", "AbyssDungeons", "abyss_d1.json"
        )
        self.assertEqual(validate.validate_file(path), [])


if __name__ == "__main__":
    unittest.main()
