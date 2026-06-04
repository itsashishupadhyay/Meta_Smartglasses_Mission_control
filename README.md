# Meta Smartglasses Mission Control

Real-time, fully **on-device** object detection on **Meta (Ray-Ban) smartglasses**. The glasses' camera
is streamed to an iPhone, run through a **YOLOv8n Core ML** model, and the detections are drawn as live
bounding boxes on the phone and **announced aloud through the glasses' speakers**. The phone's IMU
(Core Motion) is shown live.

**Status:** ✅ Working on-device — live camera → detection → overlay + spoken labels confirmed.
Requires a **paid** Apple Developer account (see [Requirements](#requirements)).

Built on Meta's **Wearables Device Access Toolkit (DAT) v0.7.0** + Apple **Vision / Core ML**.

---

## Repository layout
```
Meta_Smartglasses_Mission_control/
├── Offline_Mission_Control/                  # the iOS app (Xcode project)
│   ├── Offline_Mission_Control/              # SwiftUI source + Resources/YOLOv8n.mlpackage
│   ├── Offline_Mission_Control.xcodeproj/    # incl. pinned Package.resolved (SDK version)
│   ├── Info.plist                            # Meta DAT keys (NO DAMEnabled — see Gotchas)
│   ├── Offline_Mission_Control.entitlements  # Hotspot + Wi-Fi info (paid account)
│   └── README.md                             # app-level architecture detail
├── weights/                                  # source YOLO weights (.onnx) + coco.names
├── tools/                                     # model conversion + project patch scripts
├── SOP-Pre-Development-Requirements.md         # pre-dev checklist
└── .gitignore
```
The Meta SDK is **not** vendored — Xcode fetches it via Swift Package Manager (pinned in `Package.resolved`).

---

## Requirements
| | |
|--|--|
| **Mac** | Xcode 26.x |
| **Apple Developer account** | **PAID ($99/yr) — required for camera streaming.** The video rides a Wi-Fi link the app must join to the glasses' hotspot, which needs the Hotspot entitlement that **free/Personal teams cannot provision.** |
| **iPhone** | physical device (the Simulator can't stream glasses); **Developer Mode** on |
| **Glasses** | Ray-Ban Meta, paired in the **Meta AI app** (v254+), **Developer Mode** on, firmware current |

---

## Build & run
1. **SDK package** — already pinned; Xcode resolves `github.com/facebook/meta-wearables-dat-ios`
   (products `MWDATCore`, `MWDATCamera`, `MWDATDisplay`). If missing: *File ▸ Add Package Dependencies…*
   → that URL → add the three products to the target.
2. **Signing** — *target ▸ Signing & Capabilities* → select your **paid team**. Automatic signing
   provisions **Hotspot Configuration** + **Access WiFi Information** (from the `.entitlements`).
3. **Run on a device** (⌘R). Walk the onboarding (Wi-Fi/Local Network → Meta AI → camera → connectivity
   check), then **Start Detection**, and tap **Join** on the Wi-Fi prompt for the glasses' camera hotspot.
4. **Logs:** filter the Xcode console by **`OMC`** for stage-by-stage diagnostics.

---

## ⚠️ Critical gotchas (hard-won — don't undo these)
1. **Camera streaming requires a PAID Apple account.** Free/Personal teams can't provision
   `com.apple.developer.networking.HotspotConfiguration`. Symptom otherwise: `StreamError.videoStreamingError`
   and **no Wi-Fi-join prompt**.
2. **`MWDAT.DAMEnabled` must NOT be set in `Info.plist` for camera streaming.** It's a *Display-mode* flag
   (DisplayAccess sample sets it; CameraAccess sample omits it). With it on, the camera Wi-Fi path is
   skipped → same `videoStreamingError`. **Camera streaming and the on-glasses Display HUD are mutually
   exclusive** via this static flag.
3. **Free-team development:** run `python3 tools/unpatch_entitlements.py` to drop the paid entitlements so
   the project signs (camera streaming won't work). Re-enable with `tools/patch_entitlements.py` on a paid team.

---

## Model
`Offline_Mission_Control/Resources/YOLOv8n.mlpackage` (NMS baked in → Vision returns labeled boxes) is
committed and auto-bundled. To regenerate or swap models:
```bash
python3.11 -m venv .venv-convert
.venv-convert/bin/pip install --upgrade pip ultralytics coremltools
.venv-convert/bin/python tools/convert_yolo_to_coreml.py
```
`weights/` holds the source ONNX (`yolov8n`, `yolov5s`, `yolo26n`) + `coco.names`.

---

## How it works
```
Glasses camera (DAT Stream) ──► ObjectDetector (Core ML + Vision, off-main actor)
                                       │ [Detection]
   phone overlay (live boxes) ◄────────┼───────► SpeechAnnouncer (TTS → glasses BT speakers)
   IMU panel (phone Core Motion) ◄─────┘
```
- A first-launch **onboarding** flow gates the app until Local Network + Meta AI + camera are granted and
  a connectivity check passes (`@AppStorage("hasCompletedOnboarding")`).
- The full file map + app-level detail are in `Offline_Mission_Control/README.md`.

---

## Known limitations / next steps
- **On-glasses HUD card** is off in this build (the `DAMEnabled` trade-off) — a Display-glasses build is separate.
- **Glasses IMU** isn't exposed by the DAT preview → the IMU shown is the **phone's** (Core Motion).
- DAT is in **Developer Preview**: publishing third-party glasses integrations publicly isn't open yet.
