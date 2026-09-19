import AVFoundation
import SwiftUI

struct ContentView: View {
    @StateObject private var scanner = LiDARScannerModel()
    @StateObject private var recorder = AudioRecorder()
    @State private var mode: ScanMode = .matrix
    @State private var showingInfo = false

    var body: some View {
        ZStack {
            LiDARCameraView(model: scanner)
                .ignoresSafeArea()

            if mode == .matrix {
                ScanGridOverlay()
                    .opacity(0.32)
                    .allowsHitTesting(false)
            }

            VStack(spacing: 0) {
                header
                Spacer()
                telemetry
                controls
            }
        }
        .background(.black)
        .onAppear { scanner.start() }
        .onDisappear {
            recorder.stop()
            scanner.stop()
        }
        .alert("Scanner", isPresented: Binding(
            get: { scanner.errorMessage != nil || recorder.errorMessage != nil },
            set: { if !$0 { scanner.clearError(); recorder.errorMessage = nil } }
        )) {
            Button("OK") { scanner.clearError(); recorder.errorMessage = nil }
        } message: {
            Text(scanner.errorMessage ?? recorder.errorMessage ?? "Unknown scanner error.")
        }
        .sheet(isPresented: $showingInfo) { InfoView() }
    }

    private var header: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("GHOST SCIENCE")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .tracking(2)
                Text("M3 • LiDAR FIELD INSTRUMENT")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Circle().fill(scanner.isLiDARAvailable ? .green : .orange).frame(width: 7, height: 7)
            Text(scanner.isLiDARAvailable ? "LiDAR ONLINE" : "CAMERA ONLY")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(scanner.isLiDARAvailable ? .green : .orange)
            Button { showingInfo = true } label: {
                Image(systemName: "info.circle")
                    .font(.system(size: 17))
                    .foregroundStyle(.white)
            }
            .accessibilityLabel("Scanner information")
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(.black.opacity(0.78))
    }

    private var telemetry: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Telemetry(label: "NEAREST", value: scanner.nearestDepth > 0 ? String(format: "%.2f m", scanner.nearestDepth) : "—")
                Telemetry(label: "AVERAGE", value: scanner.averageDepth > 0 ? String(format: "%.2f m", scanner.averageDepth) : "—")
                Telemetry(label: "SAMPLES", value: "\(scanner.depthSamples)")
            }
            HStack(spacing: 12) {
                Telemetry(label: "CHANGE", value: String(format: "%.3f m", scanner.temporalChange))
                Telemetry(label: "CONF", value: String(format: "%02d%%", Int(scanner.confidence * 100)))
                Telemetry(label: "ANOMALY", value: String(format: "%02d", scanner.anomalyScore))
            }
            HStack {
                Text(mode.rawValue.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.cyan)
                Spacer()
                Text("FRAME \(scanner.frameCount)")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.secondary)
                Text(scanner.status.uppercased())
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(scanner.status == "DEPTH CHANGE" ? .yellow : .green)
            }
        }
        .padding(14)
        .background(.black.opacity(0.82))
        .overlay(Rectangle().stroke(.white.opacity(0.14), lineWidth: 1))
    }

    private var controls: some View {
        VStack(spacing: 12) {
            Picker("Mode", selection: $mode) {
                ForEach(ScanMode.allCases) { item in Text(item.rawValue).tag(item) }
            }
            .pickerStyle(.segmented)

            HStack(spacing: 12) {
                Button { recorder.toggle() } label: {
                    ZStack {
                        Circle().fill(.black.opacity(0.9))
                        Circle().stroke(recorder.isRecording ? .red : .white.opacity(0.35), lineWidth: 2)
                        RoundedRectangle(cornerRadius: recorder.isRecording ? 3 : 10)
                            .fill(recorder.isRecording ? .red : .white)
                            .frame(width: 18, height: 18)
                    }
                    .frame(width: 58, height: 58)
                }
                .accessibilityLabel(recorder.isRecording ? "Stop EVP recording" : "Start EVP recording")

                Button { scanner.resetTracking() } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 19, weight: .semibold))
                        .frame(width: 48, height: 48)
                }
                .buttonStyle(.bordered)
                .tint(.white)
                .accessibilityLabel("Reset LiDAR tracking")

                VStack(alignment: .leading, spacing: 3) {
                    Text(recorder.isRecording ? "EVP RECORDING" : "SCANNER READY")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                    Text(recorder.lastFileURL == nil ? "LiDAR depth + camera + audio" : "Last EVP saved locally")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 18)
        .background(.black.opacity(0.94))
    }
}

enum ScanMode: String, CaseIterable, Identifiable {
    case matrix = "Matrix"
    case vision = "Vision"
    case depth = "Depth"
    var id: String { rawValue }
}

struct Telemetry: View {
    let label: String
    let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 7, design: .monospaced)).foregroundStyle(.secondary)
            Text(value).font(.system(size: 12, weight: .medium, design: .monospaced))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ScanGridOverlay: View {
    var body: some View {
        Canvas { context, size in
            let step: CGFloat = 34
            var path = Path()
            stride(from: 0, through: size.width, by: step).forEach { x in
                path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: size.height))
            }
            stride(from: 0, through: size.height, by: step).forEach { y in
                path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: size.width, y: y))
            }
            context.stroke(path, with: .color(.green.opacity(0.15)), lineWidth: 0.5)
        }
    }
}

struct InfoView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Sensors") {
                    Label("Live rear-camera feed", systemImage: "camera")
                    Label("LiDAR scene depth on supported devices", systemImage: "sensor.tag.radiowaves.forward")
                    Label("Temporal depth-change analysis", systemImage: "waveform.path.ecg")
                    Label("Optional local EVP audio recording", systemImage: "waveform")
                }
                Section("Interpretation") {
                    Text("Anomaly scores represent unusual changes in measured depth. They are not evidence that a ghost or spirit is present. LiDAR measures reflected infrared light from physical surfaces.")
                }
                Section("Device") {
                    Text("A physical LiDAR-equipped iPhone or iPad is required for depth scanning. The iOS Simulator cannot provide LiDAR depth.")
                }
            }
            .navigationTitle("M3 Scanner")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
