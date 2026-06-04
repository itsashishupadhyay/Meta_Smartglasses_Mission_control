# SOP: Pre-Development Requirements — iOS App + Meta Smartglasses (Ray-Ban Meta)

**Standard Operating Procedure for environment, account, and project setup that must be completed _before_ writing any application code** for an iOS app integrating with Meta smartglasses via the **Meta Wearables Device Access Toolkit (DAT)**.

---

## Document control

| Field | Value |
|---|---|
| Document title | SOP — Pre-Development Requirements (iOS + Meta Wearables DAT) |
| Version | 1.0 |
| Date | 2026-06-03 |
| Owner | _<Team lead / iOS lead — placeholder>_ |
| Status | Active |
| Review cadence | Re-verify against official Meta + Apple docs each sprint (toolkit is in developer preview and changes frequently) |

> **Read this first — gated access & volatility notice.**
> The Meta Wearables Device Access Toolkit is in **Developer Preview**. Anyone can download the SDK, but **full capabilities are limited to "AI glasses supported countries," and publishing integrations to the public is _not_ available during the preview** (only select partners, expected to broaden later in 2026). **SDK version numbers, required keys, and access terms change often.** Every version number, key name, and URL in this SOP is marked **[verify against official docs]** where it is likely to drift — confirm against Meta's Wearables Developer Center and Apple's developer site before relying on it.

---

## 1. Purpose & scope

This SOP defines everything that must be in place **before the first line of application code is written** for an iOS app that pairs with and consumes data (camera, audio, sensors) from Ray-Ban Meta smartglasses using the Meta Wearables Device Access Toolkit. It covers hardware, accounts and gated access, Mac tooling, Apple project configuration, SDK acquisition, device pairing, and security hygiene, and ends with a "Definition of Ready" checklist. It does **not** cover application architecture or feature implementation — those begin only after every item here is satisfied.

---

## 2. Hardware requirements

You **cannot** develop or test this integration in the iOS Simulator. Smartglasses connectivity relies on Bluetooth and the companion app, which require a **physical iPhone** and the **physical glasses**.

- [ ] **Mac for development**
  - **Apple Silicon (M-series) strongly recommended** — best Xcode performance and the supported path going forward.
  - **Intel Macs**: acceptable only if they can run the required macOS + Xcode versions (see §4); confirm the Xcode version you need still supports Intel, as Apple is winding down Intel support. **[verify against official docs]**
- [ ] **Physical iPhone** (test device), able to run the minimum iOS version (see §4 / §5). **Simulator will not work** for glasses features.
- [ ] **Ray-Ban Meta smartglasses** — a supported model. Currently supported: **Ray-Ban Meta (Gen 1 & Gen 2), Ray-Ban Meta Optics, Meta Ray-Ban Display**. **[verify against official docs]**
- [ ] **Charging case** for the glasses (needed for firmware updates and to keep the glasses charged during testing).
- [ ] **Stable Wi-Fi** (for SDK/app downloads, firmware updates, Developer Center) and **Bluetooth enabled** on the iPhone (the glasses connect over Bluetooth).
- [ ] **Apple USB/USB‑C cable** to connect the iPhone to the Mac for on-device builds and debugging (or wireless debugging configured).
- [ ] _(Optional but recommended)_ A **second iPhone** so one device can stay paired/configured while another is reset for clean-state testing.

---

## 3. Account & access requirements

Two independent account ecosystems are required: **Apple** (to build/sign/run on a device) and **Meta** (to access the toolkit and register the app).

### 3.1 Apple
- [ ] **Apple Developer Program membership (paid, US$99/yr)** for the organization or individual. Required for on-device provisioning, distribution, and most entitlements. A free Apple ID allows limited 7‑day on-device runs but is **not sufficient** for a real project. **[verify against official docs]**
- [ ] Team **roles assigned** (Account Holder, Admin, App Manager, Developer) for everyone who needs to manage signing or builds.
- [ ] **Apple Developer Team ID** noted — you will need it for the toolkit's `TeamID` Info.plist value (see §5).

### 3.2 Meta
- [ ] **Meta developer access** — a **Meta Managed Account** used to set up your **organization, members, and projects** in the **Wearables Developer Center**. **[verify against official docs]**
- [ ] **Apply for / opt into the Wearables Device Access Toolkit Developer Preview** (application/notify form at the Meta wearables developer site). Note this is **gated**; approval and regional eligibility are not guaranteed. **[verify against official docs]**
- [ ] **Confirm your country is an "AI glasses supported country."** Download is global, but **full toolkit capabilities require a supported country.** **[verify against official docs]**
- [ ] **Register the app/project** in the Wearables Developer Center to obtain the auto-generated **`MetaAppID`** and **`ClientToken`** (required in Info.plist — see §5/§6).
- [ ] **Accept all applicable terms / developer agreements / NDA** presented during preview enrollment and Developer Center setup. Treat preview materials as **confidential** unless Meta states otherwise. **[verify against official docs]**

> **Publishing constraint (set expectations now):** During the Developer Preview, you can build and share builds **with testers inside your own organization** (via release channels), but you **cannot publish glasses integrations to the public** unless you are a select partner. Do not commit to a public App Store release of glasses features on a fixed date until publishing opens. **[verify against official docs]**

---

## 4. Software & tooling on the Mac

| Tool / component | Minimum / target | Notes |
|---|---|---|
| **macOS** | Version required by the chosen Xcode | Keep current; match Xcode's requirement. **[verify against official docs]** |
| **Xcode** | **14.0+** (use a current stable release) | Toolkit setup docs list Xcode 14.0+ as supported; prefer the latest stable Xcode for current iOS SDKs. **[verify against official docs]** |
| **Xcode Command Line Tools** | Matching Xcode | Install via `xcode-select --install` or Xcode settings. |
| **Swift** | Version bundled with your Xcode | Toolkit ships as a Swift package; use the Swift toolchain from your Xcode. |
| **Dependency manager** | **Swift Package Manager (SPM)** | **SPM is the documented/recommended method.** No official CocoaPods/xcframework path is documented. **[verify against official docs]** |
| **Meta AI companion app (iPhone)** | **v254+** | Required to pair glasses and enable Developer Mode. **[verify against official docs]** |
| **Glasses firmware** | **v20+** (Ray-Ban Meta) / **v21+** (Meta Ray-Ban Display) | Update via the Meta AI app before development. **[verify against official docs]** |

- [ ] macOS updated to a version compatible with the required Xcode.
- [ ] Xcode installed (stable channel) and launched once to finish component installation.
- [ ] Command Line Tools installed and selected (`xcode-select -p` points at the right Xcode).
- [ ] Swift toolchain available (verify `swift --version`).
- [ ] **Meta AI app v254+** installed on the **physical iPhone**.
- [ ] Glasses firmware updated to the minimum (or later) via the Meta AI app.

---

## 5. Apple project configuration prerequisites

Have these decided and ready (the actual Xcode project is created at the start of coding, but these values/settings must be pre-agreed and provisioned):

- [ ] **Bundle Identifier** chosen (reverse-DNS, e.g. `com.yourorg.glassesapp`) and **registered as an App ID** in the Apple Developer portal.
- [ ] **Signing & provisioning** ready:
  - Apple Developer **Team** selected; **signing identity (Apple Distribution / Apple Development) certificates** present in the Mac keychain.
  - **Provisioning profiles** for the App ID (automatic signing is fine for development; managed/manual for CI). Register all **test device UDIDs** for development profiles.
- [ ] **Minimum iOS deployment target set to iOS 15.2 or higher** (toolkit requirement). Going higher is fine if your features need it. **[verify against official docs]**
- [ ] **Capabilities** reviewed: enable any required background modes/capabilities your design needs (e.g. Background Modes if you will maintain connections in the background — add only what you actually use).
- [ ] **Required Info.plist keys identified** (values filled in once the project exists):

  **Toolkit-specific (under an `MWDAT` dictionary):** **[verify against official docs]**
  - `AppLinkURLScheme` — your app's custom URL scheme (e.g. `myexampleapp://`); enables the Meta AI app to call back into your app during registration.
  - `MetaAppID` — auto-generated when you register the project in the Wearables Developer Center (see §3.2).
  - `ClientToken` — auto-generated at project registration in the Wearables Developer Center.
  - `TeamID` — your **Apple Developer Team ID** (from Xcode → Signing & Capabilities).
  - _(Optional)_ `MWDAT → Analytics → OptOut` (Boolean) to opt out of toolkit analytics (collection is on by default).

  **URL scheme registration:**
  - `CFBundleURLTypes` entry registering the **same custom URL scheme** declared in `AppLinkURLScheme` (so the callback can route back to your app).

  **Standard iOS usage-description strings (user-facing consent):**
  - `NSCameraUsageDescription` — required (camera access via the toolkit). Example: *"This app needs camera access to stream from the glasses/phone camera."*
  - `NSBluetoothAlwaysUsageDescription` — required (connect to Meta Wearables over Bluetooth).
  - `NSMicrophoneUsageDescription` — include **if** your app records/processes microphone audio (mic/speakers are accessed via standard iOS **Bluetooth audio profiles**). **[verify against official docs]**
  - `NSLocalNetworkUsageDescription` (+ `NSBonjourServices`) — include **only if** your design performs local-network discovery; the iOS integration doc does not call this out for basic use. **[verify against official docs]**

> **Privacy note:** These glasses capture **audio and video**. Provide honest, specific usage strings; plan for an on-screen **recording/active-capture indicator**, explicit user consent, and a clear data-handling policy **before** shipping any capture feature.

---

## 6. SDK acquisition & integration prerequisites

- [ ] **Source of the SDK:** the official public repo **`https://github.com/facebook/meta-wearables-dat-ios`**, added to the Xcode project via **Swift Package Manager** (*File → Add Package Dependencies →* paste the URL). **[verify against official docs]**
- [ ] **Pin a specific version (tag), do not float on `main`.** Latest released at time of writing: **v0.7.0 (2026-05-14)** — **[verify against the repo's tags/Releases for the current version]**. Record the chosen version in the repo's README/`Package.resolved`.
- [ ] **Official documentation bookmarked** (single source of truth):
  - Wearables Developer Center docs: `https://wearables.developer.meta.com/docs`
  - iOS Setup / getting started: `https://wearables.developer.meta.com/docs/develop/dat/getting-started-toolkit/`
  - iOS integration guide: `https://wearables.developer.meta.com/docs/build-integration-ios/`
  - iOS Swift API reference (per-version)
  - Repo **CHANGELOG** and **Discussions** for release notes / breaking changes
  - **[verify all URLs are current]**
- [ ] **Review the SDK LICENSE** (in the repo) and confirm it is acceptable for your distribution model; capture any obligations. Also review **toolkit/preview terms** for usage limits (e.g. publishing restrictions). **[verify against official docs]**
- [ ] **Mock Device Kit** noted as the supported way to develop/test **without physical glasses** (pair a mock device, change state, simulate permissions and media streaming) — useful for CI and for engineers who don't yet have hardware. **[verify against official docs]**
- [ ] **Capability expectations aligned with the SDK, not assumptions:** camera access is provided via the toolkit; microphone/speaker access is via standard iOS Bluetooth audio profiles. **Do not assume raw video-frame or unrestricted sensor access** — confirm exactly which capabilities the current SDK exposes against the API reference before designing features. **[verify against official docs]**

---

## 7. Device pairing prerequisites

Complete this on the **physical iPhone + glasses** before integration testing:

- [ ] Glasses **charged** (use the charging case).
- [ ] **Meta AI app v254+** installed and signed in.
- [ ] **Glasses paired to the iPhone _through the Meta AI app first_** (the app is the system of record for the device connection; the SDK builds on top of this pairing). **[verify against official docs]**
- [ ] **Firmware updated** to the minimum (v20+ Ray-Ban Meta / v21+ Display) **or later**, via the Meta AI app. **[verify against official docs]**
- [ ] **Developer Mode enabled** on the glasses/app: Meta AI app → **Settings → App Info → tap the version number 5 times → toggle Developer Mode on**. **[verify against official docs]**
- [ ] Verified the glasses **connect and function normally** in the Meta AI app (capture a photo/short clip) before involving your own app.

---

## 8. Environment & security

- [ ] **No secrets in source control.** `MetaAppID`, `ClientToken`, Apple Team ID, signing certs, and provisioning profiles must **not** be committed in plaintext where avoidable.
  - Prefer build-time injection (xcconfig files kept out of git, CI secret variables, or a secrets manager) over hard-coding into a tracked `Info.plist`.
  - Note: `ClientToken` ships inside the app bundle to function — treat it as a **client identifier, not a high-trust secret**, and follow Meta's guidance for any server-side tokens. **[verify against official docs]**
- [ ] **`.gitignore` in place before the first commit**, covering at least:
  - `*.xcuserstate`, `xcuserdata/`, `DerivedData/`, `build/`
  - `*.xcconfig` files that contain secrets (e.g. `Secrets.xcconfig`)
  - `*.mobileprovision`, `*.p12`, `*.certSigningRequest`, keychains
  - `.env`, local credential files
  - (Keep `Package.resolved` **tracked** so SDK versions are reproducible.)
- [ ] **Code-signing identities stored safely:** developer/distribution certificates and private keys held in the macOS Keychain and/or a managed signing solution (e.g. an Xcode-managed or `fastlane match`-style encrypted store) — **never** committed to the repo. **[verify against official docs]**
- [ ] **Access scoping:** limit who holds the Apple Account Holder role and Meta org admin rights; document where credentials live (see §10 references / secrets manager).
- [ ] **Privacy/data handling agreed** for captured audio/video (retention, on-device vs cloud processing, consent UX, recording indicator) before any capture code is written.

---

## 9. Verification checklist — "Definition of Ready"

The team is ready to start coding **only when every box below is checked.**

**Hardware**
- [ ] Mac (Apple Silicon preferred) runs the required macOS + Xcode.
- [ ] Physical iPhone available (Simulator confirmed not usable for glasses features).
- [ ] Supported Ray-Ban Meta glasses + charging case on hand.
- [ ] Stable Wi-Fi; Bluetooth enabled on the iPhone; iPhone↔Mac cable/wireless debugging working.

**Accounts & access**
- [ ] Paid Apple Developer Program membership active; Team ID recorded; roles assigned.
- [ ] Meta Managed Account + organization set up; **accepted into the DAT Developer Preview**; country confirmed as a supported "AI glasses" region.
- [ ] App/project registered in the Wearables Developer Center; **`MetaAppID` and `ClientToken` obtained**.
- [ ] All Apple + Meta terms / NDA accepted; publishing limitation understood.

**Mac tooling**
- [ ] Xcode + Command Line Tools installed and selected; `swift --version` OK.
- [ ] SPM chosen as the dependency manager.
- [ ] Meta AI app **v254+** installed on the iPhone.

**Apple project config**
- [ ] Bundle ID registered; signing certs + provisioning profiles in place; test device UDIDs registered.
- [ ] Deployment target set to **iOS 15.2+**.
- [ ] Required Info.plist keys identified and values ready: `MWDAT`(`AppLinkURLScheme`, `MetaAppID`, `ClientToken`, `TeamID`), `CFBundleURLTypes` URL scheme, `NSCameraUsageDescription`, `NSBluetoothAlwaysUsageDescription` (+ mic/local-network if applicable).

**SDK**
- [ ] `meta-wearables-dat-ios` added via SPM, **pinned to a specific version**; `Package.resolved` committed.
- [ ] LICENSE and preview terms reviewed; official docs + CHANGELOG bookmarked.
- [ ] Mock Device Kit identified for hardware-free dev/test.

**Pairing**
- [ ] Glasses paired via the Meta AI app; firmware at/above minimum; **Developer Mode enabled**; basic capture verified in the Meta AI app.

**Security**
- [ ] `.gitignore` committed; no secrets in source control; signing identities stored safely; capture/privacy handling agreed.

> When all boxes are checked, **and** each **[verify against official docs]** item has been confirmed against current Meta/Apple documentation, the project is **Ready** for code.

---

## 10. References

> URLs and version numbers below were accurate as of **2026-06-03** but **must be confirmed as current** — the toolkit is in active developer preview.

**Meta — Wearables Device Access Toolkit**
- Wearables Developer Center (docs home): https://wearables.developer.meta.com/docs
- iOS Setup / getting started: https://wearables.developer.meta.com/docs/develop/dat/getting-started-toolkit/
- iOS integration guide: https://wearables.developer.meta.com/docs/build-integration-ios/
- iOS Swift API reference (per-version): https://wearables.developer.meta.com/docs/reference/ios_swift/dat/
- iOS SDK source + CHANGELOG: https://github.com/facebook/meta-wearables-dat-ios
- Android SDK (for reference): https://github.com/facebook/meta-wearables-dat-android
- FAQ: https://developers.meta.com/wearables/faq/
- Announcement blog: https://developers.meta.com/blog/introducing-meta-wearables-device-access-toolkit/
- Preview signup / notify: https://developers.meta.com/wearables/notify/

**Apple — Developer**
- Apple Developer Program: https://developer.apple.com/programs/
- Account & certificates/identifiers/profiles: https://developer.apple.com/account/
- Info.plist usage-description keys (privacy): https://developer.apple.com/documentation/bundleresources/information_property_list
- Core Bluetooth: https://developer.apple.com/documentation/corebluetooth
- AVFoundation: https://developer.apple.com/documentation/avfoundation
- Distributing / managing signing: https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases

---

*End of SOP. Re-run §9 and re-verify all **[verify against official docs]** items at the start of each sprint while the toolkit remains in developer preview.*
