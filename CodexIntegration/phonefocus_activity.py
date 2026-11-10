#!/usr/bin/env python3
"""Signal local Codex turn activity to PhoneFocus without saving chat content."""

import hashlib
import json
import os
import stat
import sys
from pathlib import Path


def digest(value: str) -> str:
    return hashlib.sha256(value.encode("utf-8")).hexdigest()[:20]


def main() -> None:
    event = json.load(sys.stdin)
    name = event.get("hook_event_name", "")
    session_id = event.get("session_id", "")
    turn_id = event.get("turn_id", "")
    if not isinstance(session_id, str) or not isinstance(turn_id, str):
        return

    directory = Path("/private/tmp") / f"phonefocus-codex-{os.getuid()}"
    directory.mkdir(mode=0o700, exist_ok=True)
    info = directory.lstat()
    if not stat.S_ISDIR(info.st_mode) or info.st_uid != os.getuid():
        return
    directory.chmod(0o700)

    prefix = digest(session_id) + "-" if session_id else ""
    if name == "SessionEnd" and prefix:
        for flag in directory.glob(prefix + "*.flag"):
            flag.unlink(missing_ok=True)
    elif session_id and turn_id:
        flag = directory / (prefix + digest(turn_id) + ".flag")
        if name == "UserPromptSubmit":
            flag.touch(mode=0o600, exist_ok=True)
            flag.chmod(0o600)
        elif name in {"Stop", "Interrupt"}:
            flag.unlink(missing_ok=True)


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, TypeError, json.JSONDecodeError):
        pass  # An activity signal must never block a Codex turn.
    # Stop requires JSON output; an empty object leaves the turn untouched.
    if "Stop" in sys.argv:
        print("{}")
