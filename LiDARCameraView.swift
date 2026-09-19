import ARKit
import RealityKit
import SwiftUI
import UIKit

struct LiDARCameraView: UIViewRepresentable {
    @ObservedObject var model: LiDARScannerModel

    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero)
        view.session = model.session
        view.automaticallyConfigureSession = false
        view.renderOptions = [.disableMotionBlur]
        return view
    }

    func updateUIView(_ uiView: ARView, context: Context) {}

    static func dismantleUIView(_ uiView: ARView, coordinator: ()) {
        uiView.session.pause()
    }
}
