import SwiftUI

struct ContentView: View {
    @StateObject private var scanner = LiDARScannerModel()
    @State private var mode: ScanMode = .matrix
    @State private var recording = false

    var body: some View {
        ZStack {
            LiDARCameraView(model: scanner)
                .ignoresSafeArea()

            ScanGridOverlay()
                .opacity(mode == .matrix ? 0.42 : 0.18)
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                header
                Spacer()
                telemetry
                controls
            }
        }
        .onAppear { scanner.start() }
        .onDisappear { scanner.stop() }
    }

    private var header: some View {
        HStack {
            Text("GHOST SCIENCE")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .tracking(2)
            Spacer()
            Circle()
                .fill(scanner.isLiDARAvailable ? Color.green : Color.red)
                .frame(width: 7, height: 7)
            Text(scanner.isLiDARAvailable ? "LiDAR ONLINE" : "LiDAR N/A")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(.black.opacity(0.72))
    }

    private var telemetry: some View {
        VStack(spacing: 9) {
            HStack {
                Telemetry(label: "DEPTH", value: String(format: "%.2f m", scanner.nearestDepth))
                Telemetry(label: "POINTS", value: "\(scanner.depthSamples)")
                Telemetry(label: "ANOMALY", value: String(format: "%02d", scanner.anomalyScore))
            }

            HStack {
                Text(mode.rawValue.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.cyan)
                Spacer()
                Text(scanner.status.uppercased())
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.green)
            }
        }
        .padding(14)
        .background(.black.opacity(0.78))
        .overlay(Rectangle().stroke(.white.opacity(0.12), lineWidth: 1))
    }

    private var controls: some View {
        VStack(spacing: 12) {
            Picker("Mode", selection: $mode) {
                ForEach(ScanMode.allCases) { item in
                    Text(item.rawValue).tag(item)
                }
            }
            .pickerStyle(.segmented)

            HStack(spacing: 18) {
                Button {
                    recording.toggle()
                } label: {
                    ZStack {
                        Circle().fill(.black.opacity(0.85))
                        Circle().stroke(recording ? .red : .white.opacity(0.35), lineWidth: 2)
                        Circle().fill(recording ? .red : .white).frame(width: 18, height: 18)
                    }
                    .frame(width: 58, height: 58)
                }
                .accessibilityLabel(recording ? "Stop recording" : "Start recording")

                VStack(alignment: .leading, spacing: 3) {
                    Text(recording ? "RECORDING" : "READY")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                    Text("LiDAR depth + camera analysis")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 18)
        .background(.black.opacity(0.92))
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
            Text(label).font(.system(size: 8, design: .monospaced)).foregroundStyle(.secondary)
            Text(value).font(.system(size: 13, weight: .medium, design: .monospaced))
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
            context.stroke(path, with: .color(.green.opacity(0.14)), lineWidth: 0.5)
        }
    }
}
