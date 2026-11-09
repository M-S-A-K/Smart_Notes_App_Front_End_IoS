//
//  VoiceRecorderPanel.swift
//  Smart_Notes_App_ios
//
//  Created by M_Salik_Amin_Kayani on 09/11/2026.
//


import SwiftUI

struct VoiceRecorderPanel: View {
    let onSave: (RecordedVoice) -> Void
    let onCancel: () -> Void

    @StateObject private var service = VoiceRecorderService()

    private var timeLabel: String {
        let total = Int(service.elapsed)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                Circle()
                    .fill(service.isPaused ? AppTheme.muted : AppTheme.danger)
                    .frame(width: 9, height: 9)

                Text(
                    service.errorMessage != nil ? "Recording unavailable" :
                    service.isPaused ? "Recording paused" :
                    service.isRecording ? "Recording" : "Starting recording…"
                )
                .font(.subheadline.bold())

                Spacer()

                Text(timeLabel)
                    .font(.system(.title3, design: .monospaced).weight(.semibold))
                    .monospacedDigit()
            }

            if let error = service.errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.danger)
            }

            HStack(spacing: 12) {
                Button {
                    service.discard()
                    onCancel()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .foregroundStyle(AppTheme.danger)

                Spacer()

                Button {
                    service.pauseOrResume()
                } label: {
                    Label(
                        service.isPaused ? "Resume" : "Pause",
                        systemImage: service.isPaused ? "play.fill" : "pause.fill"
                    )
                }
                .disabled(!service.isRecording)

                Button {
                    guard let recording = service.finish() else { return }
                    onSave(recording)
                } label: {
                    Label("Stop & Save", systemImage: "stop.fill")
                        .fontWeight(.semibold)
                }
                .disabled(!service.isRecording)
            }
            .font(.subheadline)
        }
        .padding(16)
        .softCard()
        .task {
            await service.start()
        }
        .onDisappear {
            if service.isRecording {
                service.discard()
            }
        }
    }
}
