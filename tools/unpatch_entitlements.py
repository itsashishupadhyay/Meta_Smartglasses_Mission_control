#!/usr/bin/env python3
"""
Remove CODE_SIGN_ENTITLEMENTS from the app build configs so the project signs on a free/Personal
Apple team (Personal teams cannot provision Hotspot / Access WiFi Information). Re-apply with
tools/patch_entitlements.py once on a PAID account to enable real-glasses camera streaming.
Paths resolve relative to this script.
"""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PBX = str(ROOT / "Offline_Mission_Control" / "Offline_Mission_Control.xcodeproj" / "project.pbxproj")

text = open(PBX).read()
LINE = "\t\t\t\tCODE_SIGN_ENTITLEMENTS = Offline_Mission_Control.entitlements;\n"
count = text.count(LINE)
if count == 0:
    print("No CODE_SIGN_ENTITLEMENTS lines to remove (already unwired).")
    sys.exit(0)

open(PBX, "w").write(text.replace(LINE, ""))
print(f"Removed {count} CODE_SIGN_ENTITLEMENTS line(s). Project now signs without paid entitlements.")
