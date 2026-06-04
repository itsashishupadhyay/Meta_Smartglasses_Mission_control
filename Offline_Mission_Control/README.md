# Offline Mission Control

On-device **YOLO object detection** on the **Meta (Ray-Ban) smartglasses** camera, for both
**Display** and **non-Display** glasses. Detections are drawn as live bounding boxes, announced
aloud, and (on Display glasses) summarized on the heads-up display. Phone IMU is shown live.
Everything runs **offline** on-device (Core ML + Vision + AVSpeech).

---

## What it does

| Capability | Display glasses | Non-Display glasses |
|---|---|---|
| Live glasses camera | ✅ streamed to phone | ✅ streamed to phone |
| Bounding boxes + labels | ✅ on phone (live) + HUD summary card on glasses | ✅ on phone (live) |
| Spoken object announcements (app-controlled play/pause/stop) | ✅ via glasses BT speakers | ✅ via glasses BT speakers |
| IMU readout | ✅ phone Core Motion | ✅ phone Core Motion |

---

## ⚠️ SDK reality check (read this first)

These come from reading the actual `meta-wearables-dat-ios` SDK source. They shaped the design:

1. **No live pixel overlay on the glasses display.** The DAT Display API is a *templated DSL*
   (`FlexBox`/`Text`/`Icon`/`Image`-by-URL) with **no canvas / no per-frame bitmap**. So we
   cannot draw live bounding boxes *onto the wearer's display*. Instead, the glasses show a
   **live-updating HUD summary card** ("person ×1 · car ×2"), and the full video+boxes overlay
   lives on the **phone**. (`GlassesDisplayService` + `DetectionHUD`.)
2. **No glasses IMU.** DAT exposes camera, display, BT audio and captouch — **no motion/IMU API**.
   "IMU data" therefore comes from the **iPhone** via Core Motion (`MotionService`). It's isolated
   behind a small type so a glasses-IMU source could replace it later if Meta exposes one.
3. **Camera streaming is fully supported** — `Stream.videoFramePublisher` → `VideoFrame` at
   360×640 / 504×896 / 720×1280, 15–30 fps (Bluetooth-limited). This is what we feed YOLO.
4. **Developer Preview is gated** — building works for everyone, but full capabilities require an
   "AI glasses supported country" and publishing to the public is not yet available. See the SOP
   in the parent folder.

---

## Setup

### 1. Add the Meta SDK Swift Package  ← the only required manual step
The SDK is a remote SwiftPM package (its manifest lives on release tags, so it can't be added from
the local clone). In Xcode:

1. **File ▸ Add Package Dependencies…**
2. URL: `https://github.com/facebook/meta-wearables-dat-ios`
3. Dependency rule: **Up to Next Major** from `0.7.0` (or pick a tag).
4. Add to the **Offline_Mission_Control** target, selecting these products:
   - `MWDATCore`
   - `MWDATCamera`
   - `MWDATDisplay`

> All app source files and the Core ML model are already wired — this project uses Xcode's
> *synchronized folder groups*, so files dropped into `Offline_Mission_Control/` are compiled
> automatically. The SDK package is the one thing Xcode must fetch itself.

### 2. Model — already converted
`Offline_Mission_Control/Resources/YOLOv8n.mlpackage` (6.2 MB, NMS baked in) is ready and
auto-bundled. Vision returns `VNRecognizedObjectObservation`s directly (no manual decode).
To regenerate or swap models, see [Swapping the model](#swapping-the-model).

### 3. Signing & registration
- Team ID `5KQ66KV2K8` and automatic signing are already set.
- `Info.plist` uses `MWDAT ▸ MetaAppID = 0` (**Developer Mode**). For a production build, replace
  `MetaAppID`/`ClientToken` with values from the Wearables Developer Center.
- On the phone, enable Developer Mode in the Meta AI app: *Settings ▸ (your glasses) ▸ tap version
  5× ▸ Developer Mode*.

### ⚠️ Real-glasses camera streaming requires a PAID Apple Developer account
Live camera frames from the glasses ride a **Wi-Fi link the app must join to the glasses' hotspot**,
which needs the `com.apple.developer.networking.HotspotConfiguration` + `…wifi-info` entitlements.
**Apple does not allow free/Personal teams to use these** — a free-team build gets the camera
*session* but the stream dies immediately with `StreamError.videoStreamingError` (and `quic … unable
to parse packet` in the log). The Bluetooth control link still works; only video is blocked.

The entitlements are pre-written in `Offline_Mission_Control.entitlements` but **left unwired** so the
project signs on a free team. To enable real streaming once you're on a **paid** Apple Developer team:
1. In Xcode, pick your paid team for the target (Signing & Capabilities).
2. Run `python3 tools/patch_entitlements.py` (wires `CODE_SIGN_ENTITLEMENTS`).
3. Build to a device — automatic signing provisions **Hotspot Configuration** + **Access WiFi Information**.
4. Delete the app, reinstall, onboard, **Start Detection** → live frames + boxes.

To revert to a free team: `python3 tools/unpatch_entitlements.py`.

### 4. Build & run
- Choose an **iOS device** destination (the DAT SDK is iOS-only; ignore the template's
  macОS/visionOS destinations).
- Launch, tap **Connect Glasses** (registers via the Meta AI app), then **Start Detection**.

### 5. No glasses? Use the Mock Device Kit
The SDK ships `MWDATMockDevice` (`MockDeviceKit` / `MockRaybanMeta` / `MockCameraKit`), which can
feed the phone camera as a simulated glasses stream — see the `CameraAccess` sample under
`../meta-wearables-dat-ios/samples/` to wire a mock toggle for hardware-free testing.

---

## Architecture

```
Offline_Mission_Control/
├─ Offline_Mission_ControlApp.swift   Wearables.configure() + handleUrl callback
├─ ContentView.swift                  owns MissionControlViewModel(Wearables.shared)
├─ Info.plist                         DAT keys (URL scheme, MWDAT, BT/accessory, usage strings)
├─ Resources/YOLOv8n.mlpackage        converted Core ML detector (auto-bundled)
│
├─ Detection/
│  ├─ Detection.swift                 result struct (Vision-convention box)
│  ├─ DetectionAggregator.swift       per-label counts → HUD/speech summary
│  └─ ObjectDetector.swift            actor: Core ML + Vision, off-main, `sending` frame in
├─ Glasses/
│  ├─ WearablesManager.swift          registration + device availability (display-capable?)
│  ├─ GlassesCameraService.swift      DeviceSession + Stream → live frames
│  ├─ GlassesDisplayService.swift     Display session + HUD card (pending-action pattern)
│  └─ DetectionHUD.swift              the FlexBox summary card (MWDATDisplay-only file)
├─ Motion/MotionService.swift         iPhone Core Motion (IMU)
├─ Audio/SpeechAnnouncer.swift        AVSpeech TTS → BT speakers, throttled, app-controlled
├─ ViewModels/MissionControlViewModel.swift   orchestrates the whole pipeline
├─ Support/                           AspectFit, DetectionPalette, ImageOrientation
└─ Views/                             HomeView, ConnectView, DetectionOverlayView,
                                      BoundingBoxLayer, ControlsBar, StatusHeader, IMUPanel
```

**Pipeline:** `Stream.videoFramePublisher` → `VideoFrame.makeUIImage()` → `ObjectDetector.detect`
(actor, Neural Engine) → `[Detection]` → phone overlay + HUD card (≤2 Hz, on change) + throttled
speech. Frames are dropped while a detection is in flight (`isDetecting` guard) so the UI stays live.

Concurrency: the project default-isolates to `MainActor` (Swift 6); the detector is an `actor` so
inference runs off-main, and frames cross the boundary via a `sending CGImage` parameter. The
SDK-independent half of the code type-checks clean against the iOS 26.5 SDK.

---

## Controls
- **Start/Stop Detection** — opens/closes the glasses camera session.
- **Audio** toggle + **pause/resume/stop** — control spoken announcements live.
- **Glasses HUD card** toggle — enabled only when a Display-capable device is connected.
- **Confidence threshold** slider — filters weak detections (default 35%).

## Swapping the model
`tools/convert_yolo_to_coreml.py` exports a Vision-ready Core ML model (NMS baked in). It currently
targets canonical **YOLOv8n** (matches `weights/yolov8n.onnx`). To use YOLO26n / YOLOv5s instead,
adjust the export and re-run (output lands in `Resources/`):
```bash
python3.11 -m venv .venv-convert
.venv-convert/bin/pip install --upgrade pip ultralytics coremltools
.venv-convert/bin/python tools/convert_yolo_to_coreml.py
```
The detector loads the model by bundle name (`YOLOv8n`), so it also runs (showing a clear
"model missing" status) if the resource is ever absent.

## Tuning
- Stream quality: `GlassesCameraService.resolution` / `.frameRate` (lower = less BT compression).
- Speech repeat rate: `SpeechAnnouncer.repeatInterval`.
- HUD refresh cadence: `MissionControlViewModel.maybeSendHUD` (currently ≤2 Hz, on summary change).

## Troubleshooting
- **`No such module 'MWDATCore'`** → do Setup step 1 (add the SwiftPM package).
- **"Model missing" badge** → ensure `Resources/YOLOv8n.mlpackage` exists; re-run the converter.
- **Can't connect / no device** → glasses paired in Meta AI app? Developer Mode on? Firmware ≥ v20
  (v21 for Display)? Meta AI app ≥ v254?
- **No audio on glasses** → confirm the glasses are the active Bluetooth audio output.
