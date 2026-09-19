import ARKit
import Combine
import Foundation

final class LiDARScannerModel: NSObject, ObservableObject, ARSessionDelegate {
    @Published private(set) var nearestDepth: Float = 0
    @Published private(set) var averageDepth: Float = 0
    @Published private(set) var depthSamples: Int = 0
    @Published private(set) var anomalyScore: Int = 0
    @Published private(set) var temporalChange: Float = 0
    @Published private(set) var confidence: Float = 0
    @Published private(set) var frameCount: Int = 0
    @Published private(set) var status = "READY"
    @Published private(set) var isLiDARAvailable = false
    @Published private(set) var errorMessage: String?

    let session = ARSession()

    private let analysisQueue = DispatchQueue(label: "ghostscience.lidar.analysis", qos: .userInitiated)
    private let analyzer = DepthAnalyzer()
    private var lastProcess = Date.distantPast
    private var running = false
    private var lastConfiguration: ARWorldTrackingConfiguration?

    nonisolated func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard Date().timeIntervalSince(lastProcess) >= 0.08 else { return }
        lastProcess = Date()

        guard let depth = (frame.smoothedSceneDepth ?? frame.sceneDepth) else { return }
        let depthMap = depth.depthMap
        let confidenceMap = depth.confidenceMap

        analysisQueue.async { [weak self] in
            guard let self else { return }
            let result = self.analyzer.analyze(depthMap, confidenceMap: confidenceMap)
            DispatchQueue.main.async {
                guard self.running else { return }
                self.nearestDepth = result.nearest
                self.averageDepth = result.average
                self.depthSamples = result.samples
                self.anomalyScore = result.anomalyScore
                self.temporalChange = result.temporalChange
                self.confidence = result.confidence
                self.frameCount += 1
                self.status = result.anomalyScore >= 70 ? "DEPTH CHANGE" : "SCANNING"
            }
        }
    }

    func start() {
        guard !running else { return }
        guard ARWorldTrackingConfiguration.isSupported else {
            status = "AR UNSUPPORTED"
            errorMessage = "ARKit world tracking is not supported on this device."
            return
        }

        let supportsSceneDepth = ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth)
        let supportsSmoothedDepth = ARWorldTrackingConfiguration.supportsFrameSemantics(.smoothedSceneDepth)
        isLiDARAvailable = supportsSceneDepth

        let configuration = ARWorldTrackingConfiguration()
        var semantics: ARConfiguration.FrameSemantics = []
        if supportsSceneDepth { semantics.insert(.sceneDepth) }
        if supportsSmoothedDepth { semantics.insert(.smoothedSceneDepth) }
        configuration.frameSemantics = semantics

        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification) {
            configuration.sceneReconstruction = .meshWithClassification
        } else if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            configuration.sceneReconstruction = .mesh
        }

        configuration.environmentTexturing = .automatic
        configuration.planeDetection = [.horizontal, .vertical]

        session.delegate = self
        analyzer.reset()
        lastConfiguration = configuration
        running = true
        frameCount = 0
        errorMessage = nil
        status = supportsSceneDepth ? "STARTING LIDAR" : "CAMERA ONLY"
        session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }

    func stop() {
        guard running else { return }
        session.pause()
        running = false
        status = "PAUSED"
    }

    func resetTracking() {
        analyzer.reset()
        frameCount = 0
        guard let configuration = lastConfiguration else {
            start()
            return
        }
        session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        status = isLiDARAvailable ? "SCANNING" : "CAMERA ONLY"
    }

    func clearError() {
        errorMessage = nil
    }

    nonisolated func session(_ session: ARSession, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.status = "SESSION ERROR"
            self.errorMessage = error.localizedDescription
            self.running = false
        }
    }

    nonisolated func sessionWasInterrupted(_ session: ARSession) {
        DispatchQueue.main.async { self.status = "INTERRUPTED" }
    }

    nonisolated func sessionInterruptionEnded(_ session: ARSession) {
        DispatchQueue.main.async {
            self.status = self.isLiDARAvailable ? "SCANNING" : "CAMERA ONLY"
            if let configuration = self.lastConfiguration {
                session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
            }
        }
    }
}
