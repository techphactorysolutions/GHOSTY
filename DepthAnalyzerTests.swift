import XCTest
import CoreVideo
@testable import GhostScienceM3Clone

final class DepthAnalyzerTests: XCTestCase {
    func testStableDepthProducesLowChange() throws {
        let analyzer = DepthAnalyzer()
        let buffer = try makeDepthBuffer(width: 32, height: 24, value: 2.0)
        _ = analyzer.analyze(buffer)
        let result = analyzer.analyze(buffer)
        XCTAssertEqual(result.samples, 32 * 24)
        XCTAssertEqual(result.temporalChange, 0, accuracy: 0.0001)
        XCTAssertLessThan(result.anomalyScore, 10)
    }

    func testLargeTemporalDepthChangeRaisesScore() throws {
        let analyzer = DepthAnalyzer()
        _ = analyzer.analyze(try makeDepthBuffer(width: 32, height: 24, value: 2.0))
        let result = analyzer.analyze(try makeDepthBuffer(width: 32, height: 24, value: 3.0))
        XCTAssertGreaterThan(result.temporalChange, 0.9)
        XCTAssertGreaterThan(result.anomalyScore, 70)
    }

    func testInvalidSamplesAreIgnored() throws {
        let analyzer = DepthAnalyzer()
        let result = analyzer.analyze(try makeDepthBuffer(width: 16, height: 16, value: 0))
        XCTAssertEqual(result.samples, 0)
        XCTAssertEqual(result.anomalyScore, 0)
    }

    private func makeDepthBuffer(width: Int, height: Int, value: Float) throws -> CVPixelBuffer {
        var buffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(nil, width, height, kCVPixelFormatType_DepthFloat32, nil, &buffer)
        XCTAssertEqual(status, kCVReturnSuccess)
        guard let buffer else { throw NSError(domain: "DepthAnalyzerTests", code: 1) }
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        let ptr = CVPixelBufferGetBaseAddress(buffer)!.assumingMemoryBound(to: Float32.self)
        let stride = CVPixelBufferGetBytesPerRow(buffer) / MemoryLayout<Float32>.stride
        for y in 0..<height { for x in 0..<width { ptr[y * stride + x] = value } }
        return buffer
    }
}
