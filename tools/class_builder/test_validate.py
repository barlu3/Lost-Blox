"""Unit tests for the class-definition validator (TASK_Q2_01).

Run: python3 -m unittest discover -s tools/class_builder
"""

import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(__file__))

import validate  # noqa: E402


def base_class(**overrides):
    data = {
        "id": "ironclad",
        "display_name": "Ironclad",
        "resource_type": "fury",
        "resource_max": 100,
        "identity": {"skill_id": "heavy_strike", "resource_threshold": 100},
        "skills": [
            {
                "id": "heavy_strike",
                "key": "Q",
                "cooldown": 4.0,
                "range": 8,
                "damage_multiplier": 1.8,
                "resource_cost": 10,
                "target_type": "single",
            },
            {
                "id": "shield_bash",
                "key": "W",
                "cooldown": 6.0,
                "range": 6,
                "damage_multiplier": 1.4,
                "resource_cost": 20,
                "target_type": "single",
            },
        ],
    }
    data.update(overrides)
    return data


class TestValidateClass(unittest.TestCase):
    def test_valid_class_has_no_errors(self):
        self.assertEqual(validate.validate_class(base_class()), [])

    def test_duplicate_key_binding_is_reported(self):
        data = base_class()
        data["skills"][1]["key"] = "Q"  # same as skills[0]
        errors = validate.validate_class(data)
        self.assertTrue(any("duplicate key binding 'Q'" in e for e in errors))

    def test_cooldown_must_be_positive(self):
        data = base_class()
        data["skills"][0]["cooldown"] = 0
        errors = validate.validate_class(data)
        self.assertTrue(any("cooldown must be > 0" in e for e in errors))

    def test_resource_cost_cannot_exceed_resource_max(self):
        data = base_class()
        data["skills"][0]["resource_cost"] = 150  # max is 100
        errors = validate.validate_class(data)
        self.assertTrue(any("exceeds resource_max" in e for e in errors))

    def test_target_type_must_be_known(self):
        data = base_class()
        data["skills"][0]["target_type"] = "everyone"
        errors = validate.validate_class(data)
        self.assertTrue(any("target_type 'everyone'" in e for e in errors))

    def test_identity_skill_must_exist(self):
        data = base_class()
        data["identity"]["skill_id"] = "nonexistent"
        errors = validate.validate_class(data)
        self.assertTrue(any("identity.skill_id 'nonexistent'" in e for e in errors))

    def test_missing_required_top_field(self):
        data = base_class()
        del data["resource_max"]
        errors = validate.validate_class(data)
        self.assertTrue(any("missing required field: resource_max" in e for e in errors))

    def test_empty_skills_is_rejected(self):
        data = base_class(skills=[])
        errors = validate.validate_class(data)
        self.assertTrue(any("skills must be a non-empty array" in e for e in errors))

    def test_tripod_options_must_be_complete(self):
        data = base_class()
        data["skills"][0]["tripod"] = {"options": [{"id": "x"}]}  # missing type/value
        errors = validate.validate_class(data)
        self.assertTrue(any("missing required field: type" in e for e in errors))


class TestValidateFile(unittest.TestCase):
    def test_real_ironclad_file_validates(self):
        repo_root = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
        path = os.path.join(
            repo_root, "src", "ReplicatedStorage", "Configs", "Classes", "Ironclad.json"
        )
        self.assertEqual(validate.validate_file(path), [])

    def test_missing_file_is_reported(self):
        errors = validate.validate_file("/no/such/class.json")
        self.assertTrue(any("file not found" in e for e in errors))


if __name__ == "__main__":
    unittest.main()
