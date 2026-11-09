//
//  ShareSheet.swift
//  Smart_Notes_App_ios
//
//  Created by M_Salik_Amin_Kayani on 09/11/2026.
//


import SwiftUI

struct ShareSheet: View {
    let noteId: Int
    var friend: Person? = nil
    let onDone: () -> Void

    @State private var detail: NoteDetail?
    @State private var chosen: Set<String> = ["text"]
    @State private var friends: [Person] = []
    @State private var selectedFriendId: Int?
    @State private var error = ""

    private let options = [
        ("text", "Text"),
        ("location", "Location"),
        ("reminder", "Reminder"),
        ("voice", "Voice notes")
    ]

    private var valid: Bool {
        chosen.contains("text") || chosen.contains("voice")
    }

    private func available(_ key: String) -> Bool {
        guard let d = detail else { return key == "text" }
        switch key {
        case "location": return !d.locations.isEmpty
        case "reminder": return !d.reminders.isEmpty
        case "voice": return !d.voiceNotes.isEmpty
        default: return true
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("SHARE NOTE")
                .font(.system(size: 10, weight: .heavy))
                .foregroundStyle(AppTheme.accentHover)
            Text("Choose what to include")
                .font(.title3.bold())
                .foregroundStyle(AppTheme.ink)
            Text("Include text or a voice note, then add any optional details.")
                .font(.caption)
                .foregroundStyle(AppTheme.inkSoft)

            VStack(spacing: 8) {
                ForEach(options, id: \.0) { item in
                    let isAvail = available(item.0)
                    let isSel = chosen.contains(item.0)
                    Button {
                        if isSel { chosen.remove(item.0) } else { chosen.insert(item.0) }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: isSel ? "checkmark.square.fill" : "square")
                                .foregroundStyle(isSel ? AppTheme.accent : AppTheme.borderStrong)
                            Text(item.1)
                                .font(.footnote.bold())
                                .foregroundStyle(AppTheme.ink)
                            Spacer()
                            if !isAvail {
                                Text("Not added").font(.caption2).foregroundStyle(AppTheme.muted)
                            }
                        }
                        .padding(.horizontal, 12)
                        .frame(height: 44)
                        .background(isSel ? AppTheme.accentSoft : AppTheme.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(isSel ? AppTheme.accent : AppTheme.border)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(!isAvail)
                    .buttonStyle(.plain)
                }
            }

            if friend == nil && !friends.isEmpty {
                Text("SEND TO")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(AppTheme.accentHover)
                    .padding(.top, 4)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(friends) { f in
                            let active = selectedFriendId == f.id
                            Button {
                                selectedFriendId = f.id
                            } label: {
                                HStack(spacing: 6) {
                                    Avatar(name: f.fullName, size: 26)
                                    Text(f.fullName).font(.caption.bold())
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(active ? AppTheme.accentSoft : AppTheme.surface)
                                .overlay(Capsule().stroke(active ? AppTheme.accent : AppTheme.border))
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            if !error.isEmpty {
                Text(error).font(.caption).foregroundStyle(AppTheme.danger)
            }

            Spacer(minLength: 0)

            HStack {
                Button("Cancel") { onDone() }
                    .font(.subheadline.bold())
                    .foregroundStyle(AppTheme.inkSoft)
                    .padding(.horizontal, 14)
                Spacer()
                Button("Share selected") {
                    if let friend {
                        send(to: friend.id)
                    } else if let targetId = selectedFriendId ?? friends.first?.id {
                        send(to: targetId)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.accent)
                .disabled(!valid || (friend == nil && friends.isEmpty))
            }
        }
        .padding(22)
        .background(AppTheme.surface)
        .task {
            if let d = try? await API.shared.noteDetail(noteId) {
                detail = d
                var initial: Set<String> = ["text"]
                if !d.locations.isEmpty { initial.insert("location") }
                if !d.reminders.isEmpty { initial.insert("reminder") }
                if !d.voiceNotes.isEmpty { initial.insert("voice") }
                chosen = initial
            }
            if friend == nil {
                friends = (try? await API.shared.friends()) ?? []
                selectedFriendId = friends.first?.id
            }
        }
    }

    private func send(to targetId: Int) {
        Task {
            do {
                try await API.shared.sendMessage(to: targetId, text: nil, noteId: noteId, elements: chosen)
                onDone()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}

struct SharedNoteSheet: View {
    let message: Message
    var senderName: String = "a contact"
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 6) {
                        Image(systemName: "person")
                        Text("Shared by \(senderName) · View only")
                    }
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .foregroundStyle(AppTheme.accentHover)
                    .background(AppTheme.accentSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 9))

                    Text(message.sharedTitle ?? "Shared note")
                        .font(.largeTitle.bold())
                        .foregroundStyle(AppTheme.ink)

                    if let p = message.payload {
                        if let t = p.text, !t.isEmpty {
                            RichTextView(html: t)
                        }
                        ForEach(p.voices ?? []) { v in
                            VoiceRow(voice: v)
                        }
                        if p.location != nil || p.reminder != nil {
                            HStack(alignment: .top, spacing: 8) {
                                if let l = p.location {
                                    MapPreviewCard(placeName: l.placeName, subLocation: l.subLocation)
                                }
                                if let r = p.reminder {
                                    ReminderPreviewCard(title: r.title, remindAt: r.remindAt)
                                }
                            }
                        }
                    } else if let raw = message.sharedContent, !raw.isEmpty {
                        RichTextView(html: raw)
                    }
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(AppTheme.surface)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: { Image(systemName: "chevron.left") }
                }
            }
        }
    }
}
