# FaceSwap Cam — iOS Build Instructions

A SwiftUI app for real-time face swapping using the front camera, Vision face
detection, Core Image blending, WebRTC transport, and a voice changer that
replaces your microphone audio with a pre-recorded voice sample.

---

## Prerequisites

| Requirement | Version / Notes |
| --- | --- |
| **macOS** | Ventura (13) or later recommended |
| **Xcode** | 14.0 or later (the project uses `objectVersion = 56` / `compatibilityVersion = "Xcode 14.0"`) |
| **iOS Deployment Target** | iOS 16.0+ (matches the Podfile) |
| **CocoaPods** | `sudo gem install cocoapods` (1.12+) |
| **Apple Developer account** | Required for running on a physical device and for archiving/IPA export. A free account works for on-device debugging; a paid account is required for App Store / TestFlight distribution. |

The app requests camera, microphone, and photo library access, all declared in
`FaceswapCam/Info.plist`.

---

## Project Structure

```
FaceswapiOS/
├── Podfile                          # CocoaPods manifest (GoogleWebRTC)
├── BUILD_INSTRUCTIONS.md
├── FaceswapCam/
│   ├── FaceswapCamApp.swift         # @main entry point
│   ├── ContentView.swift            # Main UI (preview, selectors, controls)
│   ├── CameraManager.swift          # AVCaptureSession + VNDetectFaceRectangles
│   ├── FaceSwapProcessor.swift      # Core Image blend + temporal smoothing
│   ├── ImagePicker.swift            # Photo-library image selection
│   ├── CameraPreviewView.swift      # UIViewRepresentable camera preview
│   ├── Info.plist
│   ├── Assets.xcassets
│   └── Managers/
│       └── VoiceChangerManager.swift # VAD + pre-recorded voice replacement
└── FaceswapCam.xcodeproj/
    ├── project.pbxproj
    ├── project.workspacecsettings/
    └── xcshareddata/xcschemes/FaceswapCam.xcscheme
```

---

## Build Steps

### 1. Install dependencies

From the project root (the directory containing the `Podfile`):

```bash
cd /path/to/FaceswapiOS
pod install
```

This generates `FaceswapCam.xcworkspace`, a `Pods/` directory, and a
`Podfile.lock` resolving `GoogleWebRTC ~> 1.1`.

> **Always build from the `.xcworkspace`, never the `.xcodeproj`, once
> `pod install` has been run.** The bare project cannot see the Pods target
> and will fail with `No such module 'GoogleWebRTC'`.

### 2. Open the workspace

```bash
open FaceswapCam.xcworkspace
```

### 3. Configure signing

In Xcode, select the **FaceswapCam** target → **Signing & Capabilities**:

1. Tick **Automatically manage signing**.
2. Pick your **Team** from the dropdown.
3. Xcode registers a bundle identifier based on
   `PRODUCT_BUNDLE_IDENTIFIER` (`com.faceswap.cam`). If that identifier is
   already taken by another account, change it to something unique such as
   `com.yourname.faceswapcam`.

### 4. Run

Select a simulator (iPhone 14 / iOS 16+) or a connected device and press
**Cmd + R**.

To use the camera on a device you must grant the camera, microphone, and photo
library permissions when prompted.

---

## Building an IPA

### Option A — Xcode Organizer (recommended)

1. Select **Any iOS Device (arm64)** as the run destination.
2. Choose **Product ▸ Archive**.
3. When the Organizer opens, select the archive and click **Distribute App**.
4. Choose a distribution method:
   - **Development** — install on registered devices
   - **Ad Hoc** — install on registered devices without a debugger
   - **App Store Connect** — upload to TestFlight / the App Store
   - **Enterprise** — in-house distribution (Enterprise account only)
5. Follow the prompts and choose an export location.

You get `FaceswapCam.ipa` (plus a `DistributionSummary.plist`,
`ExportOptions.plist`, and `Packaging.log`).

For Development/Ad Hoc exports you will also be offered the option to
**Include manifest for over-the-air installation**, which produces a
`manifest.plist` + download link you can host for OTA installs.

### Option B — Command line

```bash
# Clean build archive
xcodebuild clean archive \
  -workspace FaceswapCam.xcworkspace \
  -scheme FaceswapCam \
  -configuration Release \
  -destination "generic/platform=iOS" \
  -archivePath build/FaceswapCam.xcarchive

# Export the .ipa
xcodebuild -exportArchive \
  -archivePath build/FaceswapCam.xcarchive \
  -exportPath build/export \
  -exportOptionsPlist ExportOptions.plist
```

A minimal `ExportOptions.plist` for an ad hoc build:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>development</string>
    <key>teamID</key>
    <string>YOUR_TEAM_ID</string>
    <key>compileBitcode</key>
    <false/>
</dict>
</plist>
```

### Installing an IPA

- **Finder (macOS Catalina+)**: drag the IPA into the device's sidebar in
  Finder while connected.
- **Apple Configurator 2**: drag the IPA onto the device.
- **`ios-deploy`**: `ios-deploy --bundle build/export/FaceswapCam.ipa`

---

## Features

- **Real-time face replacement** from the front camera using
  `AVCaptureSession` at VGA (640×480).
- **Vision framework face detection** via `VNDetectFaceRectanglesRequest` on
  each `CMSampleBuffer`.
- **Core Image blending** using `CIBlendWithMask` plus a `CIColorMatrix`
  alpha pass so the blend amount is continuously adjustable.
- **Temporal smoothing** of the detected face rectangle to reduce jitter.
- **Adjustable blend amount and face size** through live sliders.
- **Custom face image selection** from the photo library.
- **Live status overlay** showing face-detected state and current FPS.
- **Voice changer** (`VoiceChangerManager`) that performs voice activity
  detection on the microphone and plays a pre-recorded voice sample instead
  of your real audio.
- **WebRTC support** via `GoogleWebRTC` for call audio transport
  (`RTCPeerConnectionFactory`, `RTCAudioTrack`).
- **Dark-mode-first UI** built entirely in SwiftUI.
- **Camera, microphone, and photo library usage descriptions** with proper
  permission prompts.

---

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| `No such module 'GoogleWebRTC'` | Run `pod install`, then open `FaceswapCam.xcworkspace` (not the `.xcodeproj`). |
| `pod install` fails to find a spec | `pod repo update` then retry. |
| Signing error "no profile found" | Set your Team in *Signing & Capabilities*; make sure the device is registered. |
| Blank camera preview | Check the camera permission under *Settings ▸ FaceSwap Cam*; preview only renders once a face image is selected and START is tapped. |
| Build works in Debug but not Release | Ensure you are archiving the **FaceswapCam** scheme with the **Release** configuration. |
| Pods out of sync after a `git pull` | Delete `Pods/`, `Podfile.lock`, and `FaceswapCam.xcworkspace`, then re-run `pod install`. |
| Xcode complains about an untrusted developer | Trust the certificate under *Settings ▸ General ▸ VPN & Device Management*. |

---

## Clean rebuild

```bash
rm -rf Pods Podfile.lock FaceswapCam.xcworkspace build
pod install
open FaceswapCam.xcworkspace
```
