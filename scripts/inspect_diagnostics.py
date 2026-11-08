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
    return {"environment": environment, "events": len(records), "sessions": sorted({str(row.get("session", "unknown")) for row in records}),
            "counts": dict(sorted(counts.items())), "malformed_lines": malformed,
            "dropped": bundle.get("dropped"), "storage": bundle.get("storage"), "important_events": important[-80:],
            "export_errors": bundle.get("exportErrors", {}), "raw_files": list(bundle.get("rawFiles", {})),
            "recovered_tail_bytes": bundle.get("recoveredTailBytes", 0),
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
