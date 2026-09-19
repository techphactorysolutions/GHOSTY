# Ghost Science M3 — LiDAR Edition

A native SwiftUI + ARKit iOS scanner inspired by the supplied Ghost Science M3 screenshots.

## Functional features

- Live rear-camera ARKit feed.
- Real LiDAR `sceneDepth` and `smoothedSceneDepth` on supported devices.
- Runtime device capability detection.
- Live nearest/average depth, valid sample count, temporal depth change, confidence and anomaly score.
- ARKit world tracking, horizontal/vertical plane detection, and scene reconstruction when supported.
- Reset/relocalize button.
- Local EVP audio recording to M4A with microphone permission handling.
- Scanner error/interruption handling.
- Swift unit tests for the depth-analysis engine.
- Shared Xcode scheme and GitHub Actions CI.

## What "anomaly" means

The app detects changes in measured depth over time. It does **not** establish that a ghost or spirit exists. LiDAR measures reflected infrared light from physical surfaces.

## Requirements

- macOS with Xcode 16 or newer.
- iOS 17 or newer.
- Physical LiDAR-equipped iPhone/iPad for actual depth scanning. The Simulator cannot provide LiDAR depth.

## GitHub

Push the repository contents directly to GitHub. The shared scheme is committed under `GhostScienceM3Clone.xcodeproj/xcshareddata/xcschemes/`, so GitHub Actions can build and test the project without requiring an uncommitted user scheme.

## Xcode

1. Open `GhostScienceM3Clone.xcodeproj`.
2. Select a physical LiDAR-equipped iPhone.
3. Set your Apple Developer Team under Signing & Capabilities.
4. Build and Run.
5. Allow Camera access when prompted.
6. Press the red record button to record EVP audio; press the reset button to restart LiDAR tracking.
