import Foundation
import CoreVideo

struct DepthAnalysis {
    let nearest: Float
    let samples: Int
    let anomalyScore: Int
    let temporalChange: Float
}

final class DepthAnalyzer {
    private var previous: [Float] = []
    private var previousWidth = 0
    private var previousHeight = 0

    func reset() {
        previous.removeAll(keepingCapacity: true)
        previousWidth = 0
        previousHeight = 0
    }

    func analyze(_ buffer: CVPixelBuffer) -> DepthAnalysis {
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        let width = CVPixelBufferGetWidth(buffer)
        let height = CVPixelBufferGetHeight(buffer)
        guard width > 0, height > 0, let base = CVPixelBufferGetBaseAddress(buffer) else {
            return DepthAnalysis(nearest: 0, samples: 0, anomalyScore: 0, temporalChange: 0)
        }
        let floatsPerRow = CVPixelBufferGetBytesPerRow(buffer) / MemoryLayout<Float32>.stride
        let ptr = base.assumingMemoryBound(to: Float32.self)
        let stepX = max(1, width / 32)
        let stepY = max(1, height / 24)
        var current: [Float] = []
        current.reserveCapacity(32 * 24)
        var nearest = Float.greatestFiniteMagnitude
        var valid = 0

        for y in Swift.stride(from: 0, to: height, by: stepY) {
            let row = ptr.advanced(by: y * floatsPerRow)
            for x in Swift.stride(from: 0, to: width, by: stepX) {
                let d = row[x]
                if d.isFinite && d >= 0.1 && d <= 8.0 {
                    current.append(d); valid += 1; nearest = min(nearest, d)
                } else { current.append(0) }
            }
        }

        var meanDelta: Float = 0
        var changed = 0
        if previous.count == current.count && previousWidth == width && previousHeight == height {
            var deltaSum: Float = 0
            var compared = 0
            for i in current.indices {
                let old = previous[i], new = current[i]
                guard old > 0, new > 0 else { continue }
                let delta = abs(new - old)
                deltaSum += delta
                if delta > 0.18 { changed += 1 }
                compared += 1
            }
            if compared > 0 { meanDelta = deltaSum / Float(compared) }
        }
        previous = current
        previousWidth = width
        previousHeight = height
        guard valid > 10 else { return DepthAnalysis(nearest: 0, samples: valid, anomalyScore: 0, temporalChange: meanDelta) }
        let changedRatio = Float(changed) / Float(max(1, current.count))
        let score = min(100, Int((meanDelta / 0.5) * 60 + changedRatio * 40))
        return DepthAnalysis(nearest: nearest.isFinite ? nearest : 0, samples: valid, anomalyScore: max(0, score), temporalChange: meanDelta)
    }
}
