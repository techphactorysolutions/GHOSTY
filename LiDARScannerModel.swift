import Foundation
import ARKit
import Combine

final class LiDARScannerModel: NSObject, ObservableObject, ARSessionDelegate {
    @Published private(set) var nearestDepth: Float = 0
    @Published private(set) var depthSamples: Int = 0
    @Published private(set) var anomalyScore: Int = 0
    @Published private(set) var temporalChange: Float = 0
    @Published private(set) var status = "INITIALIZING"
    @Published private(set) var isLiDARAvailable = false
    @Published private(set) var errorMessage: String?

    let session = ARSession()
    private let analysisQueue = DispatchQueue(label: "ghostscience.lidar.analysis", qos: .userInitiated)
    private let analyzer = DepthAnalyzer()
    private var lastProcess = Date.distantPast
    private var running = false

    func start() {
        guard !running else { return }
        guard ARWorldTrackingConfiguration.isSupported else { status = "AR UNSUPPORTED"; return }
        let supportsDepth = ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth)
        isLiDARAvailable = supportsDepth
        let config = ARWorldTrackingConfiguration()
        if supportsDepth {
            config.frameSemantics = [.sceneDepth, .smoothedSceneDepth]
            if ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification) {
                config.sceneReconstruction = .meshWithClassification
            }
        }
        config.environmentTexturing = .automatic
        session.delegate = self
        analyzer.reset()
        session.run(config, options: [.resetTracking, .removeExistingAnchors])
        running = true
        status = supportsDepth ? "SCANNING" : "CAMERA ONLY"
    }

    func stop() {
        guard running else { return }
        session.pause(); running = false; status = "PAUSED"
    }

    func resetTracking() {
        analyzer.reset()
        guard running, let configuration = session.configuration else { return }
        session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        status = isLiDARAvailable ? "SCANNING" : "CAMERA ONLY"
    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        DispatchQueue.main.async { self.status = "SESSION ERROR"; self.errorMessage = error.localizedDescription }
    }
    func sessionWasInterrupted(_ session: ARSession) { DispatchQueue.main.async { self.status = "INTERRUPTED" } }
    func sessionInterruptionEnded(_ session: ARSession) { DispatchQueue.main.async { self.status = self.isLiDARAvailable ? "SCANNING" : "CAMERA ONLY" } }

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard Date().timeIntervalSince(lastProcess) >= 0.10 else { return }
        lastProcess = Date()
        guard let depth = (frame.smoothedSceneDepth ?? frame.sceneDepth)?.depthMap else { return }
        analysisQueue.async { [weak self] in
            guard let self else { return }
            let result = self.analyzer.analyze(depth)
            DispatchQueue.main.async {
                self.nearestDepth = result.nearest
                self.depthSamples = result.samples
                self.anomalyScore = result.anomalyScore
                self.temporalChange = result.temporalChange
                self.status = result.anomalyScore >= 70 ? "DEPTH CHANGE" : "SCANNING"
            }
        }
    }
}
