#!/usr/bin/env python3
"""Validate a Lost Blox class-definition JSON against the schema.

Designers author classes as JSON in ReplicatedStorage/Configs/Classes/. This tool
checks structural and semantic rules so CI can block an invalid class before it
reaches the game. Exits 0 when valid, 1 with messages when not.

Usage:
    python validate.py path/to/Class.json [more.json ...]
"""

from __future__ import annotations

import json
import sys
from typing import Any

VALID_TARGET_TYPES = {"single", "aoe", "self"}
REQUIRED_TOP = ("id", "display_name", "resource_type", "resource_max", "skills")
REQUIRED_SKILL = (
    "id",
    "key",
    "cooldown",
    "range",
    "damage_multiplier",
    "resource_cost",
    "target_type",
)


def _is_number(value: Any) -> bool:
    return isinstance(value, (int, float)) and not isinstance(value, bool)


def validate_class(data: Any) -> list[str]:
    """Return a list of error messages. An empty list means the class is valid."""
    errors: list[str] = []

    if not isinstance(data, dict):
        return ["root must be a JSON object"]

    for key in REQUIRED_TOP:
        if key not in data:
            errors.append(f"missing required field: {key}")

    if "resource_max" in data and not _is_number(data["resource_max"]):
        errors.append("resource_max must be a number")

    skills = data.get("skills")
    if not isinstance(skills, list) or not skills:
        errors.append("skills must be a non-empty array")
        return errors  # nothing more we can check without skills

    resource_max = data.get("resource_max")
    seen_keys: dict[str, int] = {}
    skill_ids: set[str] = set()

    for index, skill in enumerate(skills):
        where = f"skills[{index}]"
        if not isinstance(skill, dict):
            errors.append(f"{where} must be an object")
            continue

        for field in REQUIRED_SKILL:
            if field not in skill:
                errors.append(f"{where} missing required field: {field}")

        sid = skill.get("id")
        if isinstance(sid, str):
            skill_ids.add(sid)

        cooldown = skill.get("cooldown")
        if _is_number(cooldown) and cooldown <= 0:
            errors.append(f"{where} cooldown must be > 0 (got {cooldown})")

        cost = skill.get("resource_cost")
        if _is_number(cost) and _is_number(resource_max) and cost > resource_max:
            errors.append(
                f"{where} resource_cost {cost} exceeds resource_max {resource_max}"
            )

        target = skill.get("target_type")
        if target is not None and target not in VALID_TARGET_TYPES:
            errors.append(
                f"{where} target_type '{target}' must be one of "
                f"{sorted(VALID_TARGET_TYPES)}"
            )

        key = skill.get("key")
        if isinstance(key, str):
            if key in seen_keys:
                errors.append(
                    f"duplicate key binding '{key}' used by skills "
                    f"[{seen_keys[key]}] and [{index}]"
                )
            else:
                seen_keys[key] = index

        _validate_tripod(skill, where, errors)

    identity = data.get("identity")
    if isinstance(identity, dict):
        ident_skill = identity.get("skill_id")
        if ident_skill is not None and ident_skill not in skill_ids:
            errors.append(
                f"identity.skill_id '{ident_skill}' does not match any skill id"
            )

    return errors


def _validate_tripod(skill: dict, where: str, errors: list[str]) -> None:
    """Tripods are optional (added in TASK_Q4_03); validate lightly when present."""
    tripod = skill.get("tripod")
    if tripod is None:
        return
    options = tripod.get("options") if isinstance(tripod, dict) else None
    if not isinstance(options, list) or not options:
        errors.append(f"{where}.tripod.options must be a non-empty array")
        return
    for opt_index, option in enumerate(options):
        opt_where = f"{where}.tripod.options[{opt_index}]"
        if not isinstance(option, dict):
            errors.append(f"{opt_where} must be an object")
            continue
        for field in ("id", "type", "value"):
            if field not in option:
                errors.append(f"{opt_where} missing required field: {field}")


def validate_file(path: str) -> list[str]:
    try:
        with open(path, "r", encoding="utf-8") as handle:
            data = json.load(handle)
    except FileNotFoundError:
        return [f"file not found: {path}"]
    except json.JSONDecodeError as exc:
        return [f"invalid JSON in {path}: {exc}"]
    return validate_class(data)


def main(argv: list[str]) -> int:
    if not argv:
        print("usage: validate.py <class.json> [...]", file=sys.stderr)
        return 2

    had_errors = False
    for path in argv:
        errors = validate_file(path)
        if errors:
            had_errors = True
            print(f"FAIL {path}")
            for message in errors:
                print(f"  - {message}")
        else:
            print(f"OK   {path}")
    return 1 if had_errors else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
