#!/usr/bin/env python3
"""Install or remove the PhoneFocus lifecycle hooks in local Codex."""

import argparse
import json
import os
import shlex
import shutil
import tempfile
from pathlib import Path


EVENTS = ("UserPromptSubmit", "Stop", "Interrupt", "SessionEnd")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--remove", action="store_true")
    parser.add_argument("--config-dir", type=Path, help=argparse.SUPPRESS)
    args = parser.parse_args()
    remove = args.remove
    codex = args.config_dir or Path.home() / ".codex"
    config_path = codex / "hooks.json"
    script_path = codex / "hooks" / "phonefocus_activity.py"
    codex.mkdir(mode=0o700, exist_ok=True)

    if config_path.exists():
        config = json.loads(config_path.read_text(encoding="utf-8"))
    else:
        config = {"hooks": {}}
    hooks = config.setdefault("hooks", {})
    if not isinstance(hooks, dict):
        raise ValueError("Expected hooks.json to contain a 'hooks' object")

    for event in EVENTS:
        groups = hooks.get(event, [])
        if not isinstance(groups, list):
            raise ValueError(f"Expected {event} to be a list")
        kept = []
        for group in groups:
            if not isinstance(group, dict):
                kept.append(group)
                continue
            handlers = group.get("hooks", [])
            if not isinstance(handlers, list):
                kept.append(group)
                continue
            remaining = [
                handler for handler in handlers
                if not (isinstance(handler, dict) and
                        "phonefocus_activity.py" in str(handler.get("command", "")))
            ]
            if remaining:
                updated = dict(group)
                updated["hooks"] = remaining
                kept.append(updated)
        if not remove:
            kept.append({"hooks": [{
                "type": "command",
                "command": f"/usr/bin/python3 {shlex.quote(str(script_path))} {event}",
                "timeout": 3,
            }]})
        if kept:
            hooks[event] = kept
        else:
            hooks.pop(event, None)

    if not remove:
        script_path.parent.mkdir(mode=0o700, exist_ok=True)
        shutil.copy2(Path(__file__).with_name("phonefocus_activity.py"), script_path)
        script_path.chmod(0o700)
    elif script_path.exists():
        script_path.unlink()

    if config_path.exists():
        shutil.copy2(config_path, config_path.with_name("hooks.json.phonefocus-backup"))
    script_path.parent.mkdir(mode=0o700, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix="hooks.json.", dir=script_path.parent)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as stream:
            json.dump(config, stream, indent=2)
            stream.write("\n")
        os.chmod(temporary, 0o600)
        os.replace(temporary, config_path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)
    print("Removed PhoneFocus Codex hooks." if remove else "Installed PhoneFocus Codex hooks. Review and trust them with /hooks in a new local Codex chat.")


if __name__ == "__main__":
    main()
