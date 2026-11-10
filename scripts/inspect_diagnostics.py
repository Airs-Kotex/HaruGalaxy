#!/usr/bin/env python3
"""Read a user-exported diagnostic JSON without executing or fetching anything."""
import argparse
from collections import Counter
import json
from pathlib import Path


def summarize(bundle, session=None):
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
    all_records = records
    sessions = {}
    for row in all_records:
        key = str(row.get("session", "unknown"))
        entry = sessions.setdefault(key, {"events": 0})
        entry["events"] += 1
        if row["event"] == "session.start":
            entry.update({k: row["fields"].get(k) for k in ("version", "build", "model", "systemVersion")})
    selected = None
    if session and session != "all":
        selected = session
        if session == "latest":
            selected = environment.get("session") or (str(records[-1].get("session", "unknown")) if records else None)
        if selected is not None:
            if str(selected) not in sessions:
                raise ValueError("Requested session is absent from this diagnostic bundle")
            records = [row for row in records if str(row.get("session", "unknown")) == str(selected)]
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
            "presentation. presentation_prepared records a paired hosted-window preparation attempt; "
            "guest_input_state.systemInputActive is the guest-reported request. focus_observed samples "
            "the state after the request without asserting success. Compare visibility notifications and selected owner; unavailable selectors and "
            "exceptions identify runtime gaps. No input text or continuous touch coordinates are recorded.")}
    capture_events = [row for row in keyboard_trace if row["event"] in
                      ("keyboard.capture_begin", "keyboard.capture_end", "keyboard.diagnostic_sample")]
    capture_stages = {
        "counts": dict(sorted(Counter(row["event"] for row in capture_events).items())),
        "recent_events": capture_events[-24:],
        "interpretation": (
            "Timed captures sample at most 21 times over 20 seconds; marker/export snapshots are separate. "
            "systemInputActive is a guest request and focus.visible is a runtime report, not proof of usable input. "
            "deliveredTouchStarts counts only host-delivered guest touch starts; WindowServer may route guest "
            "touches without a host callback, so zero is not proof of no touch. Missing/unsupported getters "
            "remain unavailable, never false. Compare capability encodings, selected owner, environment mapping "
            "and keyboard window visibility/level. No text, keycodes or clipboard content is sampled.")}
    touch_trace = [row for row in records if row["event"] in
                   ("input.window_touch", "window.resize_contact", "window.resize_begin", "window.resize_finished")]
    bottom_samples = []
    for row in capture_events:
        if row["event"] != "keyboard.diagnostic_sample":
            continue
        guests = row["fields"].get("guests", [])
        if not isinstance(guests, list):
            continue
        for guest in guests:
            if not isinstance(guest, dict) or "bottomHitProbes" not in guest:
                continue
            bottom_samples.append({"session": row.get("session"), "sequence": row["sequence"], "time": row["time"],
                "bundle": guest.get("bundle"), "railVisible": guest.get("railVisible"),
                "railOverlapsContent": guest.get("railOverlapsContent"),
                "contentFrame": guest.get("contentFrame"), "railFrame": guest.get("railFrame"),
                "bottomHitProbes": guest.get("bottomHitProbes")})
    touch_stages = {
        "counts": dict(sorted(Counter(row["event"] for row in touch_trace).items())),
        "recent_events": touch_trace[-80:], "bottom_samples": bottom_samples[-24:],
        "interpretation": (
            "input.window_touch is a host-delivered touch start with a region, without tap coordinates or text. "
            "bottomHitProbes are synthetic host-window queries, not injected or delivered touches; they cannot "
            "prove guest or WindowServer routing. railOverlapsContent checks model rectangles. Absent delivery "
            "does not prove a blocked tap. Compare selected-window safeInsets and guest safeAreaRequested; "
            "zero safe area can expose controls to system edge gestures. Never mix separate sessions when attributing a symptom.")}
    render_events = [row for row in records if row["event"] in
                     ("guest.application_profile", "guest.render_probe", "guest.presenter_ready", "workspace.compatibility_reopen")]
    render_stages = {
        "counts": dict(sorted(Counter(row["event"] for row in render_events).items())),
        "recent_events": render_events[-80:],
        "interpretation": (
            "presenter_ready establishes a presenter object, not a rendered frame. render_probe records scene "
            "connection observations and registered layers, never pixel contents. layerCount=0 differs from "
            "unavailable; a positive count does not prove correct images or media loading. Missing client-connect "
            "callbacks may reflect observer timing. application_profile describes the installed app's declared "
            "scene manifest/version; absent multiple-scene declarations are not proof that hosting is impossible. "
            "Compatibility mode keeps system canvas dimensions and restarts only the selected hosted window.")}
    board_trace = [row for row in records if row["event"].startswith("input_board.")]
    board_stages = {
        "counts": dict(sorted(Counter(row["event"] for row in board_trace).items())),
        "recent_events": board_trace[-80:],
        "interpretation": (
            "focus.accepted is first-responder acceptance, not keyboard visibility. keyboard.overlap records "
            "the keyboard frame intersection in the normal app. finished.copied means an explicit clipboard "
            "write, not insertion into the guest. original_open.accepted is request acceptance, not proof "
            "of foreground visibility or transfer of the guest's form. Draft text is not recorded.")}
    native_trace = [row for row in records if row["event"].startswith("native_handoff.")]
    native_stages = {
        "counts": dict(sorted(Counter(row["event"] for row in native_trace).items())),
        "recent_events": native_trace[-80:],
        "interpretation": (
            "capabilities.route selects deactivation or settings-update fallback; an unsupported preflight preserves the window. "
            "deactivated follows a deactivation callback or a background-settings callback with foreground=false; released.localReleaseConfirmed requires presenter "
            "cleanup, input cleanup and absence from the local scene manager. open_requested.accepted means "
            "LaunchServices accepted the request, not that the ordinary app rendered or has a usable keyboard. "
            "The target hosted session ends and is not automatically recreated. cancelled and timeouts must "
            "not be interpreted as successful handoffs.")}
    execution_trace = [row for row in records if row["event"].startswith(("guest.keepalive", "guest.user_close", "orientation."))]
    return {"environment": environment, "events": len(records), "selected_session": selected,
            "available_sessions": sessions, "total_events": len(all_records),
            "sessions": sorted({str(row.get("session", "unknown")) for row in records}),
            "counts": dict(sorted(counts.items())), "malformed_lines": malformed,
            "dropped": bundle.get("dropped"), "storage": bundle.get("storage"), "important_events": important[-80:],
            "export_errors": bundle.get("exportErrors", {}), "raw_files": list(bundle.get("rawFiles", {})),
            "recovered_tail_bytes": bundle.get("recoveredTailBytes", 0),
            "input_pipeline": stages,
            "search_pipeline": search_stages,
            "keyboard_pipeline": keyboard_stages,
            "keyboard_capture": capture_stages,
            "window_touch_pipeline": touch_stages,
            "render_pipeline": render_stages,
            "input_board_pipeline": board_stages,
            "native_handoff_pipeline": native_stages,
            "execution_pipeline": {"counts":dict(sorted(Counter(r["event"] for r in execution_trace).items())),
                "recent_events":execution_trace[-80:],
                "interpretation":"Keepalive requested is not a grant. Termination accepted is not process exit; require guest.user_close_exited. Orientation requests are not proof that a guest honors the requested layout."},
            "interpretation": "A heartbeat gap is an observation, not proof of a crash. Assertion valid is not proof of rendering or input."}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("bundle", type=Path)
    parser.add_argument("--session", default="latest", help="latest (default), all, or exact session identifier")
    args = parser.parse_args()
    if args.bundle.stat().st_size > 64 * 1024 * 1024:
        raise SystemExit("Diagnostic bundle exceeds 64 MiB")
    print(json.dumps(summarize(json.loads(args.bundle.read_text()),args.session), ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
