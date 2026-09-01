//
//  AudioRecorder.swift
//  VocaGrande
//
//  Records the microphone to a temporary 16 kHz mono WAV file for Whisper.
//

import AVFoundation

final class AudioRecorder {

    enum Failure: LocalizedError {
        case microphonePermissionDenied
        case couldNotStartRecording

        var errorDescription: String? {
            switch self {
            case .microphonePermissionDenied:
                return "Microphone access was denied. Enable it in System Settings › Privacy & Security › Microphone."
            case .couldNotStartRecording:
                return "The microphone could not be started."
            }
        }
    }

    private var recorder: AVAudioRecorder?
    private(set) var recordingURL: URL?

    /// Whisper wants 16 kHz mono PCM, so record straight into that format.
    private static let settings: [String: Any] = [
        AVFormatIDKey: Int(kAudioFormatLinearPCM),
        AVSampleRateKey: 16_000.0,
        AVNumberOfChannelsKey: 1,
        AVLinearPCMBitDepthKey: 16,
        AVLinearPCMIsFloatKey: false,
        AVLinearPCMIsBigEndianKey: false
    ]

    func start() async throws -> URL {
        guard await AVCaptureDevice.requestAccess(for: .audio) else {
            throw Failure.microphonePermissionDenied
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("vocagrande-recording.wav")
        try? FileManager.default.removeItem(at: url)

        let recorder = try AVAudioRecorder(url: url, settings: Self.settings)
        guard recorder.record() else {
            throw Failure.couldNotStartRecording
        }

        self.recorder = recorder
        self.recordingURL = url
        return url
    }

    @discardableResult
    func stop() -> URL? {
        recorder?.stop()
        recorder = nil
        return recordingURL
    }
}
