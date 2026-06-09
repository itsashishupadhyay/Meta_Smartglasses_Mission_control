# Meta Smartglasses Mission Control

> Real-time, fully **on-device** object detection on **Ray-Ban Meta glasses**. The glasses' first-person
> camera is streamed to an iPhone, run through a **Core ML YOLO** model every frame, and the results are
> shown as **live bounding boxes + a ranked leaderboard on the phone** and **spoken to the glasses' speakers**.

**Stack:** Meta **Wearables Device Access Toolkit (DAT) v0.7.0** · Apple **Vision / Core ML** · SwiftUI (iOS 26).
Everything runs offline on-device — no cloud inference.

---

## What it does

| | Capability | How |
|--|--|--|
| 🎥 | **Live first-person detection** | Streams the glasses camera; draws bounding boxes on the phone in real time. |
| 🧠 | **Swappable models** | Pick a bundled YOLO model (COCO 80-class or Open Images V7 600-class); switches live. |
| 📊 | **Detected list + session leaderboard** | Ranked live classes, plus a per-object log: frames seen, time on screen, session timer. |
| 🔊 | **Spoken recap to the glasses** | Periodic TTS over the glasses' Bluetooth speakers ("Most seen: person, 42s, 120 frames…"). |
| ⚙️ | **Live camera tuning** | Resolution + frame rate change the running stream (in-place restart). |
| 🎚️ | **Detection tuning** | Confidence, dwell ("Appear For"), re-announce spacing, recap interval. |
| 🧭 | **Mission Logs (guided procedures)** | Run a JSON checklist: object cues, countdown timers, voice-confirm advance, highlighted target box. |
| 📐 | **Telemetry** | Live iPhone IMU (Core Motion) readout. |

---

## How it works

```
 Ray-Ban Meta glasses camera
        │   DAT camera Stream (MWDATCamera · RAW frames)
        ▼
 GlassesCameraService ──VideoFrame → UIImage──► onFrame  (MainActor)
        │
        ▼
 MissionControlViewModel.handleFrame()
        │  sending CGImage      ┌──────────────────────────────────────────┐
        ├───────────────────────►  ObjectDetector  (actor · OFF the main   │
        │                       │  thread · Core ML + Vision, NMS baked in) │
        │      [Detection] ◄────└──────────────────────────────────────────┘
        ▼
 DetectionStabilizer   ── dwell-time gate: a class must persist ≥ "Appear For" before it counts
        │
        ├─► detections ───────────► DetectionOverlayView ▸ BoundingBoxLayer   (boxes over the frame)
        ├─► DetectionAggregator ──► summary [ClassCount] ─► DetectedObjectsPanel  ("DETECTED" list)
        ├─► SessionStatsTracker ──► leaderboard + timer ─► DetectedObjectsPanel  ("SESSION LOG" page)
        └─► SpeechAnnouncer ──────► per-class TTS (throttled) ─────────────────► glasses speaker

 1 Hz timer ─► SessionStatsTracker.tick()  +  spoken leaderboard recap ────────► glasses speaker
```

### Key components

| Component | Role |
|--|--|
| `Offline_Mission_ControlApp` | Calls `Wearables.configure()` at launch; routes the Meta AI callback URL. |
| `WearablesManager` | SDK registration + device availability (`registrationStateStream`, `devicesStream`). |
| `GlassesCameraService` | Owns the `DeviceSession` + camera `Stream`; permission, auto device-select, start/stop, **live reconfigure**; `VideoFrame → UIImage` into `onFrame`. |
| `ObjectDetector` *(actor)* | Loads the bundled YOLO `.mlpackage`, runs Vision **off-main**; returns `[Detection]` ≥ confidence. |
| `DetectionStabilizer` | Temporal gate — only labels present ≥ `dwellSeconds` are "confirmed" (`0` = per-frame). |
| `DetectionAggregator` | Groups a frame's detections into a ranked `[ClassCount]`. |
| `SessionStatsTracker` | Per-session accounting: frames/class, time-on-screen, live elapsed timer → the leaderboard. |
| `SpeechAnnouncer` | On-device TTS over an A2DP audio session (routes to glasses); throttled, pause/resume/stop. |
| `MotionService` | iPhone IMU via Core Motion (the glasses IMU isn't exposed by the DAT preview). |
| `MissionControlViewModel` | `@MainActor` orchestrator wiring camera → detector → stabilizer → overlay/leaderboard/announcer. |
| `AppSettings` | UserDefaults-backed settings (camera + detection) with change hooks the orchestrator subscribes to. |
| `Theme` | The shared "Mission Control" dark design system (glass cards, accent gradient, monospaced telemetry). |

### UI at a glance

```
┌───────────────────────────┐   Sheets (settings):
│ glasses · model ▾    [⚙]  │   • Model        ◄ status-header model chip
│ ┌───────────────────────┐ │   • Camera       ◄ on-stage ⚙ (resolution, frame rate)
│ │  camera feed + boxes  │ │   • Detection    ◄ objects-panel ⚙ (confidence, dwell,
│ │  ●REC  18fps  960p ⚙  │ │                    re-announce, recap interval)
│ └───────────────────────┘ │
│ DETECTED ⇆ SESSION LOG  ⋯ │   ◄ swipe between the live list and the leaderboard
│ ▎person  ×1  ███████░ 94% │
│ ▶ Start │ 🔊 Audio │ 👓 Recap│
│ ▸ Telemetry (IMU)         │
└───────────────────────────┘
```

---

## Mission Logs (guided procedures)

A JSON-driven checklist mode layered on the live detector. Pick a bundled mission (e.g. the ISS RGA
Remove & Replace procedure) + a model, then for each step:

```
 cue card (task + object to find + call-out)
        │  show the object ──► detected (COCO proxy, e.g. "chair" = foot restraint)
        ▼
 speak the cue to the glasses  +  start inverse countdown  +  highlight that bounding box
        │
        ▼
 say the expected call-out ──► on-device speech recognition ──► fuzzy match ──► advance to next step
        (or swipe the cards / tap "Confirm step")            progress: N of total
```

- Missions live in `Resources/Missions/*.json` (schema + loader in `Mission/`).
- **Audio is half-duplex:** the mic is muted while the glasses cue plays (via the synthesizer delegate),
  so the cue text isn't transcribed as a confirmation. TTS goes out over A2DP; the iPhone mic captures input.
- Speech is optional — if mic/recognition is denied, the procedure still runs via swipe / Confirm.
- Key types: `Mission` (model), `MissionLibrary` (loader), `MissionEngine` (state machine), `FuzzyMatcher`,
  `SpeechListener` (SFSpeechRecognizer), `AudioSessionController`; UI under `Views/MissionLogs/`.

---

## Project layout

```
Meta_Smartglasses_Mission_control/
├── Offline_Mission_Control/                     # the iOS app (Xcode project)
│   └── Offline_Mission_Control/
│       ├── Glasses/      WearablesManager, GlassesCameraService, LocalNetworkPermission
│       ├── Detection/    ObjectDetector, DetectionStabilizer, DetectionAggregator,
│       │                 SessionStats, Detection, DetectionModel
│       ├── Mission/      Mission (model), MissionLibrary, MissionEngine, FuzzyMatcher
│       ├── Audio/        SpeechAnnouncer, SpeechListener, AudioSessionController
│       ├── Motion/       MotionService
│       ├── ViewModels/   MissionControlViewModel, OnboardingViewModel
│       ├── Views/        HomeView, CameraStage, DetectedObjectsPanel, ControlsBar,
│       │                 StatusHeader, *SettingsSheet, MissionLogs/, Onboarding, …
│       ├── Support/      Theme, AppSettings, AspectFit, ImageOrientation, DetectionPalette
│       └── Resources/    *.mlpackage (Core ML models) · Missions/*.json (state machines)
├── tools/        convert_models.py (Core ML export) + entitlement/pbxproj patch scripts
├── weights/      source YOLO ONNX + coco.names
└── README.md
```

The Meta SDK is **not** vendored — Xcode fetches it via Swift Package Manager (pinned in `Package.resolved`).
The Xcode project uses **file-system-synchronized groups**: new `.swift` files in the tree are auto-included.

---

## Models & datasets

The model is **selectable in-app** — tap the model chip in the status header (shows the active model + a
✓/⚠︎ availability status). Switching reloads the detector live. Models are bundled from
`Resources/*.mlpackage` (NMS baked in → Vision returns labeled `VNRecognizedObjectObservation`s). Regenerate
with the conversion script (Python 3.11/3.12 for the wheels):

```bash
python3.11 -m venv tools/.venv-convert
tools/.venv-convert/bin/pip install --upgrade pip ultralytics coremltools
tools/.venv-convert/bin/python tools/convert_models.py               # all known models
tools/.venv-convert/bin/python tools/convert_models.py yolov8m-oiv7   # just one
```

| Model (key) | Dataset | Classes | ~Size | Status |
|--|--|--|--|--|
| `yolov8n` | COCO | 80 | ~6 MB | ✅ committed |
| `yolo11l` | COCO | 80 | ~50 MB | ▶︎ generate locally (git-ignored) |
| `yolov8m-oiv7` | Open Images V7 | 600 | ~50 MB | ▶︎ generate locally (git-ignored) |
| `yolov8x-oiv7` | Open Images V7 | 600 | ~130 MB | ▶︎ generate locally (git-ignored) |

> Only the small **`YOLOv8n`** model is committed — the larger ones exceed GitHub's 100 MB file limit, so
> they're git-ignored. Run `tools/convert_models.py` to (re)generate any model into `Resources/` locally.

Any model exported to Core ML **with NMS** is drop-in — the overlay, aggregator, and leaderboard are all
class-count-agnostic. (Output `.mlpackage` base names must match `resourceName` in `Detection/DetectionModel.swift`.)

---

## Concurrency model

- **`@MainActor` is the project default** — view models, services, and views are main-isolated; SDK listener
  callbacks hop back via `Task { @MainActor in … }`.
- **`ObjectDetector` is a dedicated `actor`** — the single off-main hop. Frames cross as `sending CGImage`;
  inference runs on Neural Engine / GPU / CPU (`computeUnits = .all`) without blocking the UI.
- **Frame back-pressure** — `handleFrame` drops frames while a detection is in flight (`isDetecting`), so the
  detector never queues behind the camera. Camera reconfigure coalesces rapid setting changes.

---

## Requirements

| | |
|--|--|
| **Mac** | Xcode 26.x |
| **Apple Developer account** | **Paid** — camera video rides a Wi-Fi link to the glasses' hotspot, needing the Hotspot entitlement that free/Personal teams can't provision. |
| **iPhone** | physical device (the Simulator can't stream glasses); **Developer Mode** on. |
| **Glasses** | Ray-Ban Meta, paired in the **Meta AI app** (v254+), **Developer Mode** on, firmware current. |

## Build & run

1. **Open** `Offline_Mission_Control/Offline_Mission_Control.xcodeproj` — Xcode resolves
   `github.com/facebook/meta-wearables-dat-ios` (products `MWDATCore`, `MWDATCamera`).
2. **Sign** — select your paid team under *Signing & Capabilities* (provisions Hotspot Configuration + Access
   Wi-Fi Information). On a free team, run `python3 tools/unpatch_entitlements.py` to strip those so it signs
   (camera streaming won't work); re-apply with `patch_entitlements.py`.
3. **Run on device** (⌘R). Complete onboarding (Wi-Fi/Local Network → Meta AI → camera → connectivity check),
   tap **Start Detection**, then **Join** the glasses' Wi-Fi prompt. Filter the console by **`OMC`** for logs.

---

## Notes & constraints

- **Glasses output is audio.** A *visual* card on the Ray-Ban Display can't run while the glasses camera
  streams — the DAT Display mode (`MWDAT.DAMEnabled`) that drives the on-glasses UI disables camera streaming,
  and it's a launch-time process flag. So `DAMEnabled = false` and the glasses get a **spoken** leaderboard
  recap; the full visual experience (frame + boxes + leaderboard) lives on the phone.
- **The IMU is the phone's** — the glasses IMU isn't exposed by the DAT Developer Preview.
- **DAT is in Developer Preview** — publishing third-party glasses integrations publicly isn't open yet.
