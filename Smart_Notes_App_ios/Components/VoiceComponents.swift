//
//  VoiceComponents.swift
//  Smart_Notes_App_ios
//
//  Created by M_Salik_Amin_Kayani on 09/11/2026.
//


import SwiftUI
import AVFoundation
import Combine

@MainActor
final class Recorder: ObservableObject {
    @Published var isRecording = false
    @Published var isPaused = false
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
        isPaused = false
        isRecording = true
        startTimer()
        return true
    }

    func togglePause() {
        guard isRecording else { return }
        if isPaused {
            recorder?.record()
            isPaused = false
            startTimer()
        } else {
            recorder?.pause()
            isPaused = true
            timer?.invalidate()
        }
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.seconds += 1 }
        }
    }

    func stop() -> (URL, Int) {
        recorder?.stop()
        timer?.invalidate()
        isRecording = false
        isPaused = false
        return (fileURL, max(seconds, 1))
    }

    func cancel() {
        _ = stop()
    }
}

struct VoiceRow: View {
    let voice: VoiceNote
    var showDelete = false
    var onDelete: () -> Void = {}

    @State private var player: AVPlayer?
    @State private var playing = false
    @State private var showText = false

    private var resolvedURL: URL? {
        if voice.filePath.hasPrefix("http") {
            return URL(string: voice.filePath)
        }
        let path = voice.filePath.hasPrefix("/") ? voice.filePath : "/" + voice.filePath
        return URL(string: API.shared.baseURL + path)
    }

    var body: some View {
        HStack(spacing: 12) {
            Button(action: toggle) {
                Image(systemName: playing ? "pause.fill" : "play.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(AppTheme.accent)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(voice.displayName.uppercased())
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(1)
                if let s = voice.durationSeconds {
                    Text(String(format: "0:00 / %d:%02d", s / 60, s % 60))
                        .font(.system(size: 9).monospacedDigit())
                        .foregroundStyle(AppTheme.muted)
                }
                Button("See text") { showText = true }
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(AppTheme.accentHover)
            }

            Spacer(minLength: 6)

            // Mockup waveform bars
            HStack(spacing: 2.5) {
                ForEach(0..<18, id: \.self) { idx in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(playing && idx < 9 ? AppTheme.accent : AppTheme.borderStrong)
                        .frame(width: 3, height: CGFloat(7 + ((idx * 7) % 15)))
                }
            }

            if showDelete {
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.muted)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .softCard(radius: 15)
        .onReceive(NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)) { _ in
            playing = false
            player?.seek(to: .zero)
        }
        .sheet(isPresented: $showText) {
            VStack(alignment: .leading, spacing: 12) {
                Text("VOICE TRANSCRIPT")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(AppTheme.accentHover)
                Text(voice.displayName)
                    .font(.title3.bold())
                    .foregroundStyle(AppTheme.ink)
                ScrollView {
                    Text(voice.transcript?.isEmpty == false
                         ? voice.transcript!
                         : "No transcribed text is available for this recording yet.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.inkSoft)
                        .lineSpacing(5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                HStack {
                    Spacer()
                    Button("Close") { showText = false }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.accent)
                }
            }
            .padding(22)
            .presentationDetents([.medium])
        }
    }

    private func toggle() {
        if player == nil, let url = resolvedURL {
            try? AVAudioSession.sharedInstance().setCategory(.playback)
            try? AVAudioSession.sharedInstance().setActive(true)
            player = AVPlayer(url: url)
        }
        if playing { player?.pause() } else { player?.play() }
        playing.toggle()
    }
}
