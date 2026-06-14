#!/usr/bin/env python3
"""Validate an Abyss Dungeon definition JSON.

Checks structural rules plus two semantic rules from TASK_Q4_01:
  * each room's mechanic trigger_hp values are in descending order (mechanics
    cannot trigger out of sequence as the boss loses HP);
  * every referenced boss_id exists in the boss registry CSV.

Exits 0 when valid, 1 with messages when not.

Usage:
    python validate.py abyss_d1.json [--registry boss_registry.csv]
"""

from __future__ import annotations

import argparse
import csv
import json
import os
import sys
from typing import Any

DEFAULT_REGISTRY = os.path.join(os.path.dirname(__file__), "boss_registry.csv")


def load_boss_ids(registry_path: str) -> set[str]:
    ids: set[str] = set()
    with open(registry_path, newline="", encoding="utf-8") as handle:
        for row in csv.DictReader(handle):
            boss_id = row.get("boss_id", "").strip()
            if boss_id:
                ids.add(boss_id)
    return ids


def validate_abyss(data: Any, boss_ids: set[str]) -> list[str]:
    """Return a list of error messages. Empty means the dungeon is valid."""
    errors: list[str] = []

    if not isinstance(data, dict):
        return ["root must be a JSON object"]
    if "id" not in data:
        errors.append("missing required field: id")

    rooms = data.get("rooms")
    if not isinstance(rooms, list) or not rooms:
        errors.append("rooms must be a non-empty array")
        return errors

    for room_index, room in enumerate(rooms):
        where = f"rooms[{room_index}]"
        if not isinstance(room, dict):
            errors.append(f"{where} must be an object")
            continue

        boss_id = room.get("boss_id")
        if boss_id is None:
            errors.append(f"{where} missing required field: boss_id")
        elif boss_id not in boss_ids:
            errors.append(f"{where} boss_id '{boss_id}' not found in boss registry")

        mechanics = room.get("mechanics")
        if not isinstance(mechanics, list) or not mechanics:
            errors.append(f"{where}.mechanics must be a non-empty array")
            continue

        previous_hp = None
        for mech_index, mechanic in enumerate(mechanics):
            mwhere = f"{where}.mechanics[{mech_index}]"
            if not isinstance(mechanic, dict):
                errors.append(f"{mwhere} must be an object")
                continue
            if not mechanic.get("type"):
                errors.append(f"{mwhere} missing required field: type")

            trigger_hp = mechanic.get("trigger_hp")
            if not isinstance(trigger_hp, (int, float)) or isinstance(trigger_hp, bool):
                errors.append(f"{mwhere} trigger_hp must be a number")
            else:
                if previous_hp is not None and trigger_hp > previous_hp:
                    errors.append(
                        f"{mwhere} trigger_hp {trigger_hp} is not in descending "
                        f"order (previous was {previous_hp})"
                    )
                previous_hp = trigger_hp

    return errors


def validate_file(path: str, registry_path: str = DEFAULT_REGISTRY) -> list[str]:
    try:
        boss_ids = load_boss_ids(registry_path)
    except FileNotFoundError:
        return [f"boss registry not found: {registry_path}"]
    try:
        with open(path, "r", encoding="utf-8") as handle:
            data = json.load(handle)
    except FileNotFoundError:
        return [f"file not found: {path}"]
    except json.JSONDecodeError as exc:
        return [f"invalid JSON in {path}: {exc}"]
    return validate_abyss(data, boss_ids)


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="Validate Abyss Dungeon JSON")
    parser.add_argument("files", nargs="+")
    parser.add_argument("--registry", default=DEFAULT_REGISTRY)
    args = parser.parse_args(argv)

    had_errors = False
    for path in args.files:
        errors = validate_file(path, args.registry)
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
