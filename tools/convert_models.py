#!/usr/bin/env python3
"""
Convert object-detection models to Core ML (.mlpackage) with NMS baked in, so Apple's Vision
framework treats each as an object detector and returns VNRecognizedObjectObservation
(labels + boxes) — the exact shape Offline_Mission_Control's ObjectDetector consumes.

Output .mlpackages land in the app's Resources/ folder; their base names must match the
`resourceName` values in DetectionModel.swift.

Usage (Python 3.11/3.12 recommended for coremltools/torch wheels):
    python3.11 -m venv tools/.venv-convert
    tools/.venv-convert/bin/pip install --upgrade pip ultralytics coremltools
    tools/.venv-convert/bin/python tools/convert_models.py            # convert all
    tools/.venv-convert/bin/python tools/convert_models.py yolov8m-oiv7   # one/several

Only datasets with public, drop-in pretrained checkpoints are listed:
  • COCO (80 classes)          — yolov8n, yolo11l
  • Open Images V7 (600)       — yolov8m-oiv7, yolov8x-oiv7
Objects365 / LVIS / PASCAL VOC have no clean public Core ML checkpoint (training required),
so they are intentionally not included here.
"""
import glob
import os
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "Offline_Mission_Control" / "Offline_Mission_Control" / "Resources"
WORK = ROOT / "tools" / "_build"

# key -> (ultralytics weights file, output .mlpackage base name)
MODELS = {
    "yolov8n":      ("yolov8n.pt",      "YOLOv8n"),        # COCO, 80 classes (already bundled)
    "yolo11l":      ("yolo11l.pt",      "YOLO11l"),        # COCO, 80 classes, higher accuracy
    "yolov8m-oiv7": ("yolov8m-oiv7.pt", "YOLOv8m-OIV7"),   # Open Images V7, 600 classes
    "yolov8x-oiv7": ("yolov8x-oiv7.pt", "YOLOv8x-OIV7"),   # Open Images V7, 600 classes (bulky)
}


def convert(key: str, weights: str, out_name: str) -> None:
    from ultralytics import YOLO

    print(f"\n=== {key}: exporting {weights} -> {out_name}.mlpackage ===")
    model = YOLO(weights)  # auto-downloads canonical weights into WORK
    exported = model.export(format="coreml", nms=True, imgsz=640)
    print("export() returned:", exported)

    src = str(exported) if exported and os.path.isdir(str(exported)) else None
    if not src:
        for c in glob.glob("**/*.mlpackage", recursive=True):
            if os.path.isdir(c):
                src = c
                break
    if not src:
        print(f"ERROR: could not locate exported .mlpackage for {key}")
        sys.exit(2)

    dst = OUT_DIR / f"{out_name}.mlpackage"
    if dst.exists():
        shutil.rmtree(dst)
    shutil.copytree(src, dst)
    # Avoid the next model's export picking up this one.
    shutil.rmtree(src, ignore_errors=True)
    print(f"OK: {src} -> {dst}")


def main() -> None:
    WORK.mkdir(parents=True, exist_ok=True)
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    os.chdir(WORK)

    print("Python:", sys.version.split()[0])
    try:
        import coremltools
        import ultralytics
        print("ultralytics", ultralytics.__version__, "| coremltools", coremltools.__version__)
    except Exception as e:  # noqa: BLE001
        print("FATAL import error:", e)
        raise

    keys = sys.argv[1:] or list(MODELS.keys())
    unknown = [k for k in keys if k not in MODELS]
    if unknown:
        print("Unknown model keys:", unknown, "\nAvailable:", list(MODELS.keys()))
        sys.exit(1)

    for key in keys:
        weights, out_name = MODELS[key]
        convert(key, weights, out_name)

    print("\nDONE:", ", ".join(keys))


if __name__ == "__main__":
    main()
