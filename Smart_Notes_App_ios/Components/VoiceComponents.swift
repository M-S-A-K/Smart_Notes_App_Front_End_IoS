//
//  VoiceComponents.swift
//  Smart_Notes_App_ios
//
//  Created by M_Salik_Amin_Kayani on 09/11/2026.
//

import SwiftUI
import AVFoundation
import CoreMedia
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
    @State private var timeObserver: Any?
    @State private var playing = false
    @State private var currentTime: Double = 0
    @State private var showText = false

    private var totalDuration: Double {
        Double(max(voice.durationSeconds ?? 18, 1))
    }

    private var progressRatio: Double {
        min(max(currentTime / totalDuration, 0), 1)
    }

    // Plays from local offline .wav file first if downloaded!
    private var resolvedURL: URL? {
        if let local = OfflineStore.hasLocalVoice(voiceId: voice.id, filePath: voice.filePath) {
            return local
        }
        if voice.filePath.hasPrefix("http") {
            return URL(string: voice.filePath)
        }
        let path = voice.filePath.hasPrefix("/") ? voice.filePath : "/" + voice.filePath
        return URL(string: API.shared.baseURL + path)
    }

    private func formatSeconds(_ val: Double) -> String {
        let s = Int(max(0, round(val)))
        return String(format: "%d:%02d", s / 60, s % 60)
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
                Text("\(formatSeconds(currentTime)) / \(formatSeconds(totalDuration))")
                    .font(.system(size: 9).monospacedDigit())
                    .foregroundStyle(AppTheme.muted)
                Button("See text") { showText = true }
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(AppTheme.accentHover)
                    .buttonStyle(.plain)
            }
            .frame(width: 105, alignment: .leading)

            GeometryReader { geo in
                let barCount = 24
                HStack(spacing: 3) {
                    ForEach(0..<barCount, id: \.self) { idx in
                        let barFraction = Double(idx) / Double(barCount - 1)
                        let isPlayed = barFraction <= progressRatio
                        RoundedRectangle(cornerRadius: 2)
                            .fill(isPlayed ? AppTheme.accent : AppTheme.borderStrong)
                            .frame(maxWidth: .infinity, maxHeight: CGFloat(8 + ((idx * 7) % 16)))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let ratio = min(max(value.location.x / max(geo.size.width, 1), 0), 1)
                            seek(to: ratio * totalDuration)
                        }
                )
            }
            .frame(height: 30)

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
            currentTime = 0
            player?.seek(to: .zero)
        }
        .onDisappear {
            if let obs = timeObserver {
                player?.removeTimeObserver(obs)
                timeObserver = nil
            }
            player?.pause()
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

    private func setupPlayerIfNeeded() {
        guard player == nil, let url = resolvedURL else { return }
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        try? AVAudioSession.sharedInstance().setActive(true)
        let av = AVPlayer(url: url)
        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        timeObserver = av.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            let secs = CMTimeGetSeconds(time)
            if secs.isFinite && secs >= 0 {
                currentTime = min(secs, totalDuration)
            }
        }
        player = av
    }

    private func seek(to seconds: Double) {
        setupPlayerIfNeeded()
        currentTime = seconds
        let target = CMTime(seconds: seconds, preferredTimescale: 600)
        player?.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    private func toggle() {
        setupPlayerIfNeeded()
        if playing {
            player?.pause()
        } else {
            player?.play()
        }
        playing.toggle()
    }
}
