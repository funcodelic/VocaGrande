//
//  WhisperTestView.swift
//  VocaGrande
//
//  Created by Troy Mulder on 8/16/26.
//

import SwiftUI

struct WhisperTestView: View {

    private enum Phase {
        case loadingModel, ready, recording, transcribing, failed
    }

    @State private var recorder = AudioRecorder()
    @State private var transcriber = WhisperTranscriber()

    @State private var phase: Phase = .loadingModel
    @State private var status = "Loading model…"
    @State private var transcript = ""
    @State private var recordingURL: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("VocaGrande — Whisper test")
                .font(.title2.bold())

            Text(status)
                .foregroundStyle(phase == .failed ? .red : .secondary)

            HStack(spacing: 12) {
                Button("Record", action: startRecording)
                    .disabled(phase == .loadingModel || phase == .recording || phase == .transcribing)

                Button("Stop", action: stopRecording)
                    .disabled(phase != .recording)

                Button("Transcribe") { transcribe() }
                    .disabled(recordingURL == nil || phase == .recording || phase == .transcribing)
            }

            ScrollView {
                Text(transcript.isEmpty ? "—" : transcript)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(minHeight: 140)
        }
        .padding(20)
        .frame(minWidth: 420, minHeight: 320)
        .task {
            do {
                try await transcriber.loadModel()
                phase = .ready
                status = "Ready"
            } catch {
                fail(error)
            }
        }
    }

    private func startRecording() {
        Task {
            do {
                transcript = ""
                recordingURL = try await recorder.start()
                phase = .recording
                status = "Recording… speak Spanish, then press Stop."
            } catch {
                fail(error)
            }
        }
    }

    private func stopRecording() {
        recorder.stop()
        phase = .ready
        status = "Recording stopped"
        transcribe()
    }

    private func transcribe() {
        guard let url = recordingURL else { return }
        Task {
            phase = .transcribing
            status = "Transcribing…"
            do {
                let text = try await transcriber.transcribe(fileURL: url)
                transcript = text.isEmpty ? "(Whisper returned no text)" : text
                phase = .ready
                status = "Done"
            } catch {
                fail(error)
            }
        }
    }

    private func fail(_ error: Error) {
        phase = .failed
        status = "❌ \(error.localizedDescription)"
    }
}

#Preview {
    WhisperTestView()
}
