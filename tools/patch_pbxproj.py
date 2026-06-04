#!/usr/bin/env python3
"""
Point the app target at the hand-written Info.plist (the DAT keys are nested dicts/arrays that
can't be expressed via INFOPLIST_KEY_* build settings). Flips GENERATE_INFOPLIST_FILE YES->NO and
adds INFOPLIST_FILE for the two APP build configs only. Idempotent; aborts unless it finds 2 matches.
Paths resolve relative to this script.
"""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PBX = str(ROOT / "Offline_Mission_Control" / "Offline_Mission_Control.xcodeproj" / "project.pbxproj")

OLD = '\t\t\t\tGENERATE_INFOPLIST_FILE = YES;\n\t\t\t\t"INFOPLIST_KEY_UIApplicationSceneManifest_Generation[sdk=iphoneos*]" = YES;'
NEW = ('\t\t\t\tGENERATE_INFOPLIST_FILE = NO;\n'
       '\t\t\t\tINFOPLIST_FILE = Info.plist;\n'
       '\t\t\t\t"INFOPLIST_KEY_UIApplicationSceneManifest_Generation[sdk=iphoneos*]" = YES;')

text = open(PBX).read()
if "INFOPLIST_FILE = Info.plist;" in text:
    print("Already patched; nothing to do.")
    sys.exit(0)

count = text.count(OLD)
if count != 2:
    print(f"ABORT: expected 2 app-config matches, found {count}. No changes written.")
    sys.exit(1)

open(PBX, "w").write(text.replace(OLD, NEW))
print("PATCHED: GENERATE_INFOPLIST_FILE=NO + INFOPLIST_FILE=Info.plist on 2 app build configs.")
