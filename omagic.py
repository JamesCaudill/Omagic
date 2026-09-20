#!/usr/bin/env python3
"""Omagic's JSON CLI; uses only the Python standard library."""

import argparse
import json
import re
import subprocess

import omagic_lib as om


def apply_trackpad(settings=None):
    if {om.PLUS_ID, om.PULSE_ID} & om.enabled_plugin_ids():
        raise ValueError("Disable Trackpad Plus/Pulse before applying Omagic trackpad settings.")
    names = om.hypr_devices()["trackpad"]
    if not names:
        raise ValueError("Connect a Magic Trackpad before applying its settings.")
    previous = om.PROFILE_PATH.read_text() if om.PROFILE_PATH.exists() else None
    om.atomic_write(om.PROFILE_PATH, om.render_profile(names, settings or om.load_settings()))
    ok, error = om.hypr_reload()
    if not ok:
        if previous is None:
            om.PROFILE_PATH.unlink(missing_ok=True)
        else:
            om.atomic_write(om.PROFILE_PATH, previous)
        restored, restore_error = om.hypr_reload()
        raise RuntimeError(error + (" (profile restored)" if restored else f"; restore reload failed: {restore_error}"))
    return {"path": str(om.PROFILE_PATH), "hyprNames": names}


def revert_trackpad():
    previous = om.PROFILE_PATH.read_text() if om.PROFILE_PATH.exists() else None
    om.PROFILE_PATH.unlink(missing_ok=True)
    ok, error = om.hypr_reload()
    if not ok:
        if previous is not None:
            om.atomic_write(om.PROFILE_PATH, previous)
            om.hypr_reload()
        raise RuntimeError(error)
    return {"removed": previous is not None}


def set_settings(raw):
    patch = json.loads(raw)
    if not isinstance(patch, dict) or not patch:
        raise ValueError("Expected a nonempty settings object.")
    om.validate_settings(patch)
    settings = {**om.load_settings(), **patch}
    # Keep privileged keyboard settings independent of trackpad availability.
    if "macFnKeys" in patch and len(patch) != 1:
        raise ValueError("Change macFnKeys separately from trackpad settings.")
    if "macFnKeys" in patch:
        ok, error = om.apply_fnmode(settings["macFnKeys"])
        if not ok:
            raise RuntimeError(error)
    else:
        apply_trackpad(settings)
    om.save_settings(settings)
    return {"settings": settings}


def connect(mac):
    if not re.fullmatch(r"(?:[0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}", mac):
        raise ValueError("Invalid Bluetooth address.")
    om.run(["omarchy", "bluetooth", "device", "connect", mac], timeout=25)
    info = om.bt_info(mac)
    if not info["connected"]:
        raise RuntimeError(f"Could not connect {mac}. Check power and Bluetooth pairing.")
    if info["kind"]:
        om.remember_address(info["kind"], mac)
    return {"address": mac, "connected": True}


def setup_wireless(kind):
    om.run(["omarchy", "bluetooth", "power", "on"], timeout=8)
    for mac in om.known_addresses(kind):
        try:
            return connect(mac)
        except (OSError, RuntimeError, subprocess.TimeoutExpired):
            continue
    found = om.discover_magic(kind, 28 if kind == "trackpad" else 22)
    if not found:
        raise RuntimeError("No Magic device found. Power it on" + (" and tap the pad." if kind == "trackpad" else "."))
    if len(found) > 1:
        raise RuntimeError("Multiple Magic devices found. Pair the intended device in Omarchy Bluetooth settings.")
    mac = found[0]["address"]
    om.run(["omarchy", "bluetooth", "device", "pair", mac], timeout=45)
    # Pairing alone is not a successful connection.
    info = om.bt_info(mac)
    if not info["connected"]:
        raise RuntimeError("Pairing did not connect the device. Try again or use Omarchy Bluetooth settings.")
    om.remember_address(kind, mac)
    return {"address": mac, "connected": True}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    for command in ("state", "apply-trackpad", "revert-trackpad"):
        sub.add_parser(command)
    sub.add_parser("set-settings").add_argument("json")
    sub.add_parser("connect").add_argument("address")
    sub.add_parser("setup-wireless").add_argument("kind", choices=("keyboard", "trackpad"))
    args = parser.parse_args()
    try:
        if args.command == "state":
            result = om.merge_devices()
        elif args.command == "set-settings":
            result = set_settings(args.json)
        elif args.command == "connect":
            result = connect(args.address)
        elif args.command == "setup-wireless":
            result = setup_wireless(args.kind)
        elif args.command == "apply-trackpad":
            result = apply_trackpad()
        else:
            result = revert_trackpad()
        print(json.dumps({"ok": True, **result}))
        return 0
    except (OSError, ValueError, RuntimeError, subprocess.TimeoutExpired) as exc:
        print(json.dumps({"ok": False, "error": str(exc)}))
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
