# Ghost Science M3 — LiDAR Edition

A native SwiftUI/ARKit prototype inspired by the supplied Ghost Science M3 screenshots. It uses the iPhone/iPad LiDAR scanner when available and presents a dark, instrument-style scanning UI.

## What is real
- ARKit camera feed.
- LiDAR `sceneDepth` / `smoothedSceneDepth` on supported devices.
- AR mesh reconstruction when supported.
- Live depth sampling and a derived anomaly/roughness score.

## Important limitation
An iPhone LiDAR sensor measures reflected infrared light from physical surfaces. It cannot establish that a detected object is a ghost or spirit. The app therefore labels its output as a **depth anomaly** rather than claiming a paranormal detection.

## Build
1. Open Xcode 16+ on macOS.
2. Create a new iOS App named `GhostScienceM3Clone` using SwiftUI.
3. Replace the generated Swift files with the files in this folder.
4. Add `Privacy - Camera Usage Description` to the target Info settings with: `Camera access is required for AR scanning.`
5. Set the deployment target to iOS 17.0 or newer.
6. Run on a physical LiDAR-equipped iPhone/iPad. The simulator cannot provide LiDAR depth.

## Next phase
The natural production version would add:
- point-cloud / mesh rendering from `ARMeshAnchor` data;
- Vision human-body/pose overlay;
- depth-history tracking to flag transient shapes;
- audio/EVP recorder and spectrogram;
- an explicit experimental/simulation layer for any non-sensor "paranormal" effects.
