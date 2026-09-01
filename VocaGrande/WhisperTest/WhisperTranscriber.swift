//
//  WhisperTranscriber.swift
//  VocaGrande
//
//  Owns the local whisper.cpp context and transcribes audio files to Spanish text.
//

import AVFoundation
import Foundation
import whisper

nonisolated final class WhisperTranscriber: @unchecked Sendable {

    enum Failure: LocalizedError {
        case modelNotFound
        case modelLoadFailed
        case emptyRecording
        case audioConversionFailed
        case inferenceFailed(Int32)

        var errorDescription: String? {
            switch self {
            case .modelNotFound:
                return "ggml-small.bin was not found in the app bundle."
            case .modelLoadFailed:
                return "Whisper could not load ggml-small.bin."
            case .emptyRecording:
                return "The recording is empty — nothing was captured from the microphone."
            case .audioConversionFailed:
                return "The recording could not be converted to 16 kHz mono audio."
            case .inferenceFailed(let code):
                return "Whisper failed to transcribe (whisper_full returned \(code))."
            }
        }
    }

    /// Whisper inference is blocking and slow, so everything runs on this serial queue.
    private let queue = DispatchQueue(label: "com.funcodelic.VocaGrande.whisper")
    private var context: OpaquePointer?

    deinit {
        if let context {
            whisper_free(context)
        }
    }

    /// Loads the bundled model once; the context stays alive for the lifetime of this object.
    func loadModel() async throws {
        try await run { _ = try self.contextLoadingIfNeeded() }
    }

    func transcribe(fileURL: URL) async throws -> String {
        try await run {
            let context = try self.contextLoadingIfNeeded()
            let samples = try Self.pcmSamples(from: fileURL)
            return try Self.transcribe(samples: samples, using: context)
        }
    }

    private func run<T: Sendable>(_ work: @escaping @Sendable () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                continuation.resume(with: Result { try work() })
            }
        }
    }

    // MARK: - Model

    private func contextLoadingIfNeeded() throws -> OpaquePointer {
        if let context {
            return context
        }

        guard let url = Bundle.main.url(forResource: "ggml-small",
                                        withExtension: "bin",
                                        subdirectory: "models")
                ?? Bundle.main.url(forResource: "ggml-small", withExtension: "bin")
        else {
            throw Failure.modelNotFound
        }

        var params = whisper_context_default_params()
        params.flash_attn = true

        guard let context = whisper_init_from_file_with_params(url.path, params) else {
            throw Failure.modelLoadFailed
        }

        self.context = context
        return context
    }

    // MARK: - Inference

    private static func transcribe(samples: [Float], using context: OpaquePointer) throws -> String {
        // ACCURACY LEVER 1 — beam search instead of greedy decoding.
        // Greedy takes the highest-probability token at every step and never reconsiders.
        // Beam search keeps N candidate transcriptions alive and picks the best complete one,
        // which recovers from early wrong guesses. Usually the single biggest quality win here.
        // To try it, swap the line below for:
        //     var params = whisper_full_default_params(WHISPER_SAMPLING_BEAM_SEARCH)
        //     params.beam_search.beam_size = 5
        // Cost: roughly 2-3x slower inference. Not currently enabled.
        var params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
        params.n_threads = Int32(max(1, min(8, ProcessInfo.processInfo.activeProcessorCount - 2)))
        params.translate = false
        params.no_timestamps = true
        params.print_realtime = false
        params.print_progress = false
        params.print_timestamps = false
        params.print_special = false

        // Pins the language to Spanish instead of auto-detecting — this is already the
        // "tell it which language you're speaking" win. Whisper is never left guessing
        // between Spanish and Italian. For a language picker later, this "es" becomes a
        // parameter ("it", "fr", …); leaving it nil/"auto" re-enables detection.
        //
        // ACCURACY LEVER 2 — initial_prompt.
        // Whisper conditions on preceding text, so a Spanish primer biases it toward Spanish
        // spelling, accents and punctuation, and can be seeded with vocabulary you expect.
        // It must be a C string that outlives the whisper_full call, so it belongs inside
        // this same withCString nest, e.g.:
        //     "Transcripción en español con acentos y puntuación correctos.".withCString { prompt in
        //         params.initial_prompt = prompt
        //         ...
        //     }
        // Note it costs decoder context (~224 tokens max) and a too-specific prompt can make
        // Whisper hallucinate those words into silence. Not currently enabled.
        let result = "es".withCString { language -> Int32 in
            params.language = language
            params.detect_language = false
            return samples.withUnsafeBufferPointer { buffer in
                whisper_full(context, params, buffer.baseAddress, Int32(buffer.count))
            }
        }

        guard result == 0 else {
            throw Failure.inferenceFailed(result)
        }

        var text = ""
        for index in 0..<whisper_full_n_segments(context) {
            if let segment = whisper_full_get_segment_text(context, index) {
                text += String(cString: segment)
            }
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Audio

    /// Reads the recording as the 16 kHz mono float samples whisper_full() expects,
    /// resampling if the recorded file did not already land on that format.
    private static func pcmSamples(from url: URL) throws -> [Float] {
        let file = try AVAudioFile(forReading: url)
        let sourceFormat = file.processingFormat

        guard let targetFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                               sampleRate: 16_000,
                                               channels: 1,
                                               interleaved: false) else {
            throw Failure.audioConversionFailed
        }

        let frameCount = AVAudioFrameCount(file.length)
        guard frameCount > 0,
              let inputBuffer = AVAudioPCMBuffer(pcmFormat: sourceFormat, frameCapacity: frameCount) else {
            throw Failure.emptyRecording
        }
        try file.read(into: inputBuffer)

        if sourceFormat == targetFormat {
            return floats(from: inputBuffer)
        }

        guard let converter = AVAudioConverter(from: sourceFormat, to: targetFormat) else {
            throw Failure.audioConversionFailed
        }

        let ratio = targetFormat.sampleRate / sourceFormat.sampleRate
        let capacity = AVAudioFrameCount(Double(inputBuffer.frameLength) * ratio) + 4096
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity) else {
            throw Failure.audioConversionFailed
        }

        // AVAudioConverter's input block is typed @Sendable but is invoked synchronously
        // on this thread, so feeding it the buffer we just read is safe.
        nonisolated(unsafe) let sourceBuffer = inputBuffer
        nonisolated(unsafe) var suppliedInput = false

        var conversionError: NSError?
        let status = converter.convert(to: outputBuffer, error: &conversionError) { _, inputStatus in
            if suppliedInput {
                inputStatus.pointee = .endOfStream
                return nil
            }
            suppliedInput = true
            inputStatus.pointee = .haveData
            return sourceBuffer
        }

        if status == .error {
            if let conversionError {
                throw conversionError
            }
            throw Failure.audioConversionFailed
        }

        let samples = floats(from: outputBuffer)
        guard !samples.isEmpty else {
            throw Failure.emptyRecording
        }
        return samples
    }

    private static func floats(from buffer: AVAudioPCMBuffer) -> [Float] {
        guard let channel = buffer.floatChannelData else { return [] }
        return Array(UnsafeBufferPointer(start: channel[0], count: Int(buffer.frameLength)))
    }
}
