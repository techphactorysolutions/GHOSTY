import AVFoundation
import Foundation

final class AudioRecorder: NSObject, ObservableObject, AVAudioRecorderDelegate {
    @Published private(set) var isRecording = false
    @Published private(set) var lastFileURL: URL?
    @Published var errorMessage: String?
    private var recorder: AVAudioRecorder?

    func toggle() { isRecording ? stop() : requestAndStart() }

    private func requestAndStart() {
        AVAudioApplication.requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                guard granted else { self?.errorMessage = "Microphone permission is required to record audio."; return }
                self?.start()
            }
        }
    }

    private func start() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: [.allowBluetooth])
            try session.setActive(true)
            let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
            let url = directory.appendingPathComponent("EVP-\(stamp).m4a")
            let settings: [String: Any] = [AVFormatIDKey: Int(kAudioFormatMPEG4AAC), AVSampleRateKey: 44_100, AVNumberOfChannelsKey: 1, AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue]
            let recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder.delegate = self
            guard recorder.record() else { throw NSError(domain: "AudioRecorder", code: 1, userInfo: [NSLocalizedDescriptionKey: "The audio recorder could not start."]) }
            self.recorder = recorder; isRecording = true; errorMessage = nil
        } catch { errorMessage = error.localizedDescription; isRecording = false; try? AVAudioSession.sharedInstance().setActive(false) }
    }

    func stop() {
        recorder?.stop()
        lastFileURL = recorder?.url
        recorder = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        DispatchQueue.main.async { self.lastFileURL = flag ? recorder.url : nil; self.isRecording = false; self.recorder = nil }
    }
}
