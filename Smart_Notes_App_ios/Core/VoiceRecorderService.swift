//
//  VoiceRecorderService.swift
//  Smart_Notes_App_ios
//
//  Created by M_Salik_Amin_Kayani on 09/11/2026.
//


import AVFoundation
import Foundation
import Combine

struct RecordedVoice: Identifiable {
    let id = UUID()
    let fileURL: URL
    let duration: TimeInterval
    var transcript: String? = nil
}

@MainActor
final class VoiceRecorderService: ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var isPaused = false
    @Published private(set) var elapsed: TimeInterval = 0
    @Published var errorMessage: String?

    private var recorder: AVAudioRecorder?
    private var clockTask: Task<Void, Never>?
    private var recordingURL: URL?

    func start() async {
        do {
            let permitted = await requestPermission()
            guard permitted else {
                throw RecorderError.permissionDenied
            }

            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord,
                                    mode: .default,
                                    options: [.defaultToSpeaker])
            try session.setActive(true)

            let folder = FileManager.default.urls(
                for: .documentDirectory,
                in: .userDomainMask
            )[0].appendingPathComponent("VoiceNotes", isDirectory: true)

            try FileManager.default.createDirectory(
                at: folder,
                withIntermediateDirectories: true
            )

            let url = folder.appendingPathComponent(
                "\(UUID().uuidString).m4a"
            )

            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]

            let audioRecorder = try AVAudioRecorder(
                url: url,
                settings: settings
            )

            audioRecorder.prepareToRecord()

            guard audioRecorder.record() else {
                throw RecorderError.couldNotStart
            }

            recorder = audioRecorder
            recordingURL = url
            elapsed = 0
            isRecording = true
            isPaused = false
            errorMessage = nil
            startClock()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func pauseOrResume() {
        guard let recorder else { return }

        if isPaused {
            recorder.record()
            isPaused = false
            startClock()
        } else {
            recorder.pause()
            isPaused = true
            clockTask?.cancel()
        }
    }

    func finish() -> RecordedVoice? {
        guard let recorder, let url = recordingURL else { return nil }

        let duration = recorder.currentTime
        recorder.stop()
        clockTask?.cancel()

        self.recorder = nil
        recordingURL = nil
        isRecording = false
        isPaused = false

        return RecordedVoice(fileURL: url, duration: duration)
    }

    func discard() {
        recorder?.stop()
        clockTask?.cancel()

        if let url = recordingURL {
            try? FileManager.default.removeItem(at: url)
        }

        recorder = nil
        recordingURL = nil
        elapsed = 0
        isRecording = false
        isPaused = false
    }

    private func startClock() {
        clockTask?.cancel()
        clockTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { break }
                elapsed += 1
            }
        }
    }

    private func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission {
                granted in
                continuation.resume(returning: granted)
            }
        }
    }
}

enum RecorderError: LocalizedError {
    case permissionDenied
    case couldNotStart

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Microphone permission is required to record a voice note."
        case .couldNotStart:
            return "The recording could not be started."
        }
    }
}
