import SwiftUI
import ARKit
import RealityKit

struct LiDARCameraView: UIViewRepresentable {
    @ObservedObject var model: LiDARScannerModel

    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero)
        view.session = model.session
        view.automaticallyConfigureSession = false
        view.environment.background = .cameraFeed
        return view
    }

    func updateUIView(_ uiView: ARView, context: Context) {}
}
