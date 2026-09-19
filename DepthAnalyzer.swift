import CoreVideo
import Foundation

struct DepthAnalysis: Equatable {
    let nearest: Float
    let average: Float
    let samples: Int
    let anomalyScore: Int
    let temporalChange: Float
    let confidence: Float
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

    func analyze(_ buffer: CVPixelBuffer, confidenceMap: CVPixelBuffer? = nil) -> DepthAnalysis {
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }

        let width = CVPixelBufferGetWidth(buffer)
        let height = CVPixelBufferGetHeight(buffer)
        guard width > 0, height > 0,
              let base = CVPixelBufferGetBaseAddress(buffer) else {
            return DepthAnalysis(nearest: 0, average: 0, samples: 0, anomalyScore: 0, temporalChange: 0, confidence: 0)
        }

        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        let floatsPerRow = bytesPerRow / MemoryLayout<Float32>.stride
        let ptr = base.assumingMemoryBound(to: Float32.self)
        let stepX = max(1, width / 32)
        let stepY = max(1, height / 24)

        var current = Array(repeating: Float(0), count: 32 * 24)
        var nearest = Float.greatestFiniteMagnitude
        var sum: Float = 0
        var valid = 0
        var index = 0

        for y in stride(from: 0, to: height, by: stepY) {
            let row = ptr.advanced(by: y * floatsPerRow)
            for x in stride(from: 0, to: width, by: stepX) {
                guard index < current.count else { break }
                let d = row[x]
                if d.isFinite && d >= 0.1 && d <= 8.0 {
                    current[index] = d
                    valid += 1
                    sum += d
                    nearest = min(nearest, d)
                }
                index += 1
            }
        }
        if index < current.count { current.removeLast(current.count - index) }

        var meanDelta: Float = 0
        var changed = 0
        var compared = 0
        if previous.count == current.count && previousWidth == width && previousHeight == height {
            var deltaSum: Float = 0
            for i in current.indices {
                let old = previous[i]
                let new = current[i]
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

        let avg = valid > 0 ? sum / Float(valid) : 0
        let changedRatio = compared > 0 ? Float(changed) / Float(compared) : 0
        let rawScore = (meanDelta / 0.5) * 60 + changedRatio * 40
        let score = min(100, max(0, Int(rawScore.rounded())))

        let confidence = confidenceValue(confidenceMap)
        return DepthAnalysis(
            nearest: nearest.isFinite ? nearest : 0,
            average: avg,
            samples: valid,
            anomalyScore: valid > 10 ? score : 0,
            temporalChange: meanDelta,
            confidence: confidence
        )
    }

    private func confidenceValue(_ buffer: CVPixelBuffer?) -> Float {
        guard let buffer else { return 0 }
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(buffer) else { return 0 }

        let width = CVPixelBufferGetWidth(buffer)
        let height = CVPixelBufferGetHeight(buffer)
        guard width > 0, height > 0 else { return 0 }
        let bytes = CVPixelBufferGetBytesPerRow(buffer)
        let ptr = base.assumingMemoryBound(to: UInt8.self)
        let stepX = max(1, width / 16)
        let stepY = max(1, height / 12)
        var sum = 0
        var count = 0
        for y in stride(from: 0, to: height, by: stepY) {
            let row = ptr.advanced(by: y * bytes)
            for x in stride(from: 0, to: width, by: stepX) {
                sum += Int(row[x])
                count += 1
            }
        }
        return count > 0 ? Float(sum) / Float(count * 2) : 0
    }
}
