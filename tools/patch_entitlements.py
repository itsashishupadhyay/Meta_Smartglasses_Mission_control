#!/usr/bin/env python3
"""
Wire the app target to Offline_Mission_Control.entitlements (adds CODE_SIGN_ENTITLEMENTS to the
two APP build configs). REQUIRES a PAID Apple Developer team to provision Hotspot / Access WiFi
Information — needed for real-glasses camera streaming. Aborts unless it finds exactly two anchors.
Paths resolve relative to this script.
"""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PBX = str(ROOT / "Offline_Mission_Control" / "Offline_Mission_Control.xcodeproj" / "project.pbxproj")

text = open(PBX).read()
if "CODE_SIGN_ENTITLEMENTS = Offline_Mission_Control.entitlements" in text:
    print("Already patched; nothing to do.")
    sys.exit(0)

OLD = '\t\t\t\tGENERATE_INFOPLIST_FILE = NO;\n\t\t\t\tINFOPLIST_FILE = Info.plist;'
NEW = ('\t\t\t\tCODE_SIGN_ENTITLEMENTS = Offline_Mission_Control.entitlements;\n'
       '\t\t\t\tGENERATE_INFOPLIST_FILE = NO;\n'
       '\t\t\t\tINFOPLIST_FILE = Info.plist;')

count = text.count(OLD)
if count != 2:
    print(f"ABORT: expected 2 app-config matches, found {count}. No changes written.")
    sys.exit(1)

open(PBX, "w").write(text.replace(OLD, NEW))
print("PATCHED: CODE_SIGN_ENTITLEMENTS added to 2 app build configs (needs a PAID team to sign).")
