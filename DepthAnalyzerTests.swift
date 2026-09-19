import CoreVideo
import XCTest
@testable import GhostScienceM3Clone

final class DepthAnalyzerTests: XCTestCase {
    func testStableDepthHasNoTemporalChange() {
        let analyzer = DepthAnalyzer()
        let first = makeDepthBuffer(width: 32, height: 24, value: 2.0)
        let second = makeDepthBuffer(width: 32, height: 24, value: 2.0)

        _ = analyzer.analyze(first)
        let result = analyzer.analyze(second)

        XCTAssertEqual(result.samples, 768)
        XCTAssertEqual(result.nearest, 2.0, accuracy: 0.001)
        XCTAssertEqual(result.average, 2.0, accuracy: 0.001)
        XCTAssertEqual(result.temporalChange, 0, accuracy: 0.001)
        XCTAssertEqual(result.anomalyScore, 0)
    }

    func testLargeDepthChangeProducesAnomaly() {
        let analyzer = DepthAnalyzer()
        let first = makeDepthBuffer(width: 32, height: 24, value: 2.0)
        let second = makeDepthBuffer(width: 32, height: 24, value: 3.0)

        _ = analyzer.analyze(first)
        let result = analyzer.analyze(second)

        XCTAssertGreaterThan(result.temporalChange, 0.9)
        XCTAssertGreaterThan(result.anomalyScore, 70)
    }

    private func makeDepthBuffer(width: Int, height: Int, value: Float) -> CVPixelBuffer {
        var buffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_DepthFloat32,
            nil,
            &buffer
        )
        XCTAssertEqual(status, kCVReturnSuccess)
        guard let buffer else { fatalError("Unable to create depth buffer") }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        let ptr = CVPixelBufferGetBaseAddress(buffer)!.assumingMemoryBound(to: Float32.self)
        let stride = CVPixelBufferGetBytesPerRow(buffer) / MemoryLayout<Float32>.stride
        for y in 0..<height {
            for x in 0..<width { ptr[y * stride + x] = value }
        }
        return buffer
    }
}
