//
//  VoiceComponents.swift
//  Smart_Notes_App_ios
//
//  Created by M_Salik_Amin_Kayani on 09/11/2026.
//

import SwiftUI
import AVFoundation
import Combine

// Records 16 kHz mono WAV (what your Whisper backend wants)
@MainActor
final class Recorder: ObservableObject {
    @Published var isRecording = false
    @Published var seconds = 0
    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    private let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("voice.wav")

    func start() async -> Bool {
        guard await AVAudioApplication.requestRecordPermission() else { return false }
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try? session.setActive(true)
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false
        ]
        recorder = try? AVAudioRecorder(url: fileURL, settings: settings)
        guard recorder?.record() == true else { return false }
        seconds = 0
        isRecording = true
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.seconds += 1 }
        }
        return true
    }

    func stop() -> (URL, Int) {
        recorder?.stop()
        timer?.invalidate()
        isRecording = false
        return (fileURL, seconds)
    }

    func cancel() { _ = stop() }
}

struct VoiceRow: View {
    let voice: VoiceNote
    var showDelete = false
    var onDelete: () -> Void = {}

    @State private var player: AVPlayer?
    @State private var playing = false
    @State private var showText = false

    var body: some View {
        HStack(spacing: 12) {
            Button(action: toggle) {
                Image(systemName: playing ? "pause.fill" : "play.fill").foregroundStyle(.white)
                    .frame(width: 34, height: 34).background(AppTheme.accent).clipShape(Circle())
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(voice.displayName.uppercased()).font(.caption.bold())
                Button("See text") { showText = true }
                    .font(.caption2.bold()).foregroundStyle(AppTheme.accentHover)
            }
            Spacer()
            if let s = voice.durationSeconds {
                Text(String(format: "%d:%02d", s / 60, s % 60)).font(.caption).foregroundStyle(AppTheme.muted)
            }
            if showDelete {
                Button(role: .destructive, action: onDelete) { Image(systemName: "trash") }
            }
        }
        .padding(12)
        .softCard(radius: 14)
        .onReceive(NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)) { _ in
            playing = false
            player?.seek(to: .zero)
        }
        .sheet(isPresented: $showText) {
            VStack(alignment: .leading, spacing: 10) {
                Text("VOICE TRANSCRIPT").font(.system(size: 10, weight: .heavy)).foregroundStyle(AppTheme.accentHover)
                Text(voice.displayName).font(.title3.bold())
                ScrollView {
                    Text(voice.transcript?.isEmpty == false ? voice.transcript! : "No transcribed text is available for this recording yet.")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(20)
            .presentationDetents([.medium])
        }
    }

    private func toggle() {
        if player == nil, let url = URL(string: API.shared.baseURL + voice.filePath) {
            try? AVAudioSession.sharedInstance().setCategory(.playback)
            try? AVAudioSession.sharedInstance().setActive(true)
            player = AVPlayer(url: url)
        }
        if playing { player?.pause() } else { player?.play() }
        playing.toggle()
    }
}
