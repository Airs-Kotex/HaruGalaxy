#!/usr/bin/env python3
"""Read a user-exported diagnostic JSON without executing or fetching anything."""
import argparse
from collections import Counter
import json
from pathlib import Path


def summarize(bundle):
    if not isinstance(bundle, dict) or bundle.get("schema") != 1 or not isinstance(bundle.get("logs"), dict):
        raise ValueError("Expected diagnostic bundle schema 1 with a logs object")
    environment = bundle.get("environment", {})
    if not isinstance(environment, dict):
        raise ValueError("Invalid environment object")
    records, malformed = [], []
    for filename, raw in bundle["logs"].items():
        if not isinstance(raw, str):
            malformed.append(f"{filename}: not text")
            continue
        for line_number, line in enumerate(raw.splitlines(), 1):
            if not line.strip():
                continue
            try:
                record = json.loads(line)
                if not isinstance(record, dict) or not isinstance(record.get("event"), str) or not isinstance(record.get("fields"), dict):
                    raise ValueError("invalid event")
                if not isinstance(record.get("time"), (int, float)) or not isinstance(record.get("sequence"), int):
                    raise ValueError("invalid ordering")
                records.append(record)
            except (ValueError, TypeError):
                malformed.append(f"{filename}:{line_number}")
    records.sort(key=lambda row: (row["time"], row["sequence"]))
    counts = Counter(row["event"] for row in records)
    important = [row for row in records if any(token in row["event"] for token in
                 ("failed", "exception", "timeout", "invalidated", "unavailable", "gap", "problem_marker", "background.requested", "guard."))]
    input_events = (
        "overlay.interaction_ready", "overlay.hit_test", "input.edge_delivery",
        "edge.touch_begin", "edge.touch_rejected", "edge.touch_end", "edge.touch_cancelled",
        "edge.activate", "edge.move_begin", "edge.move_end", "panel.blocked", "panel.open", "panel.close",
    )
    input_trace = [row for row in records if row["event"] in input_events]
    stages = {"counts": {name: counts[name] for name in input_events if counts[name]},
              "recent_events": input_trace[-80:],
              "interpretation": (
                  "Root hit tests are sampled queries, not delivered touches. input.edge_delivery records only "
                  "app-owned entry touch delivery; edge.touch_begin confirms the UIControl callback ran. "
                  "edge.activate requests the panel; panel.blocked means a presented controller prevented it. "
                  "Missing records alone do not locate a failure: detailed logging, sampling, rotation and "
                  "different sessions can affect this trace. preparationMs is synchronous layout time, not FPS.")}
    search_trace = [row for row in records if row["event"].startswith("search.") or row["event"]=="overlay.search_input"]
    search_stages = {
        "counts": dict(sorted(Counter(row["event"] for row in search_trace).items())),
        "recent_events": search_trace[-80:],
        "interpretation": (
            "application_open.accepted reports LaunchServices request acceptance, not foreground visibility. "
            "main_scene_presented is emitted after the normal scene is foreground and presentation completes. "
            "keyboard_shown.visible checks keyboard intersection with the input window. "
            "Late errors, cancelled generations, external keyboards and missing logs require context; query text is not recorded.")}
    keyboard_trace = [row for row in records if row["event"].startswith("keyboard.")]
    keyboard_stages = {
        "counts": dict(sorted(Counter(row["event"] for row in keyboard_trace).items())),
        "recent_events": keyboard_trace[-100:],
        "interpretation": (
            "environment_registered means an owned PID/environment was recorded; environment_applied means "
            "a matching target call occurred. focus_requested/completed do not prove a focus grant or keyboard "
            "presentation. Compare visibility notifications and selected owner; unavailable selectors and "
            "exceptions identify runtime gaps. No input text or continuous touch coordinates are recorded.")}
    return {"environment": environment, "events": len(records), "sessions": sorted({str(row.get("session", "unknown")) for row in records}),
            "counts": dict(sorted(counts.items())), "malformed_lines": malformed,
            "dropped": bundle.get("dropped"), "storage": bundle.get("storage"), "important_events": important[-80:],
            "export_errors": bundle.get("exportErrors", {}), "raw_files": list(bundle.get("rawFiles", {})),
            "recovered_tail_bytes": bundle.get("recoveredTailBytes", 0),
            "input_pipeline": stages,
            "search_pipeline": search_stages,
            "keyboard_pipeline": keyboard_stages,
            "interpretation": "A heartbeat gap is an observation, not proof of a crash. Assertion valid is not proof of rendering or input."}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("bundle", type=Path)
    args = parser.parse_args()
    if args.bundle.stat().st_size > 64 * 1024 * 1024:
        raise SystemExit("Diagnostic bundle exceeds 64 MiB")
    print(json.dumps(summarize(json.loads(args.bundle.read_text())), ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
