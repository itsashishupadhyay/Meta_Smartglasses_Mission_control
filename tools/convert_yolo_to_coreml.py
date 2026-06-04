#!/usr/bin/env python3
"""
Convert YOLOv8n -> Core ML (.mlpackage) with NMS baked in, so Apple's Vision framework
treats it as an object detector and returns VNRecognizedObjectObservation (labels + boxes).

Paths resolve relative to this script, so it works wherever this repo lives.
Run with a Python that has coremltools wheels (3.11 / 3.12 recommended):
    python3.11 -m venv .venv-convert
    .venv-convert/bin/pip install --upgrade pip ultralytics coremltools
    .venv-convert/bin/python tools/convert_yolo_to_coreml.py
"""
import glob
import os
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "Offline_Mission_Control" / "Offline_Mission_Control" / "Resources"
WORK = ROOT / "tools" / "_build"
WORK.mkdir(parents=True, exist_ok=True)
OUT_DIR.mkdir(parents=True, exist_ok=True)
os.chdir(WORK)  # keep downloaded weights/exports out of the repo root

print("Python:", sys.version.split()[0])
try:
    import coremltools
    import ultralytics
    print("ultralytics", ultralytics.__version__, "| coremltools", coremltools.__version__)
except Exception as e:  # noqa: BLE001
    print("FATAL import error:", e)
    raise

from ultralytics import YOLO  # noqa: E402

model = YOLO("yolov8n.pt")  # auto-downloads canonical weights into WORK
exported = model.export(format="coreml", nms=True, imgsz=640)
print("export() returned:", exported)

src = None
if exported and os.path.isdir(str(exported)):
    src = str(exported)
else:
    for c in glob.glob("**/*.mlpackage", recursive=True):
        if os.path.isdir(c):
            src = c
            break

if not src:
    print("ERROR: could not locate exported .mlpackage. Dir listing:", os.listdir("."))
    sys.exit(2)

dst = OUT_DIR / "YOLOv8n.mlpackage"
if dst.exists():
    shutil.rmtree(dst)
shutil.copytree(src, dst)
print(f"OK: copied {src} -> {dst}")
print("DONE")
