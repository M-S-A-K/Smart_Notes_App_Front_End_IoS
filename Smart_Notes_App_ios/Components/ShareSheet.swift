//
//  ShareSheet.swift
//  Smart_Notes_App_ios
//
//  Created by M_Salik_Amin_Kayani on 09/11/2026.
//

import SwiftUI

// Pick what to share (text or voice is required), then send
struct ShareSheet: View {
    let noteId: Int
    var friend: Person? = nil
    let onDone: () -> Void

    @State private var detail: NoteDetail?
    @State private var chosen: Set<String> = ["text"]
    @State private var friends: [Person] = []
    @State private var error = ""

    private let options = [("text", "Text"), ("location", "Location"), ("reminder", "Reminder"), ("voice", "Voice notes")]
    private var valid: Bool { chosen.contains("text") || chosen.contains("voice") }

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
        List {
            Section("Choose what to include") {
                ForEach(options, id: \.0) { item in
                    Button {
                        if chosen.contains(item.0) { chosen.remove(item.0) } else { chosen.insert(item.0) }
                    } label: {
                        HStack {
                            Image(systemName: chosen.contains(item.0) ? "checkmark.square.fill" : "square")
                                .foregroundStyle(AppTheme.accent)
                            Text(item.1)
                            Spacer()
                            if !available(item.0) { Text("Not added").font(.caption).foregroundStyle(AppTheme.muted) }
                        }
                    }
                    .disabled(!available(item.0))
                    .foregroundStyle(AppTheme.ink)
                }
            }
            if !error.isEmpty { Text(error).foregroundStyle(AppTheme.danger) }
            if let friend {
                Button("Share with \(friend.fullName)") { send(to: friend) }.disabled(!valid)
            } else {
                Section("Send to") {
                    ForEach(friends) { f in Button(f.fullName) { send(to: f) }.disabled(!valid) }
                }
            }
        }
        .navigationTitle("Share note")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            detail = try? await API.shared.noteDetail(noteId)
            if friend == nil { friends = (try? await API.shared.friends()) ?? [] }
        }
    }

    private func send(to f: Person) {
        Task {
            do {
                try await API.shared.sendMessage(to: f.id, text: nil, noteId: noteId, elements: chosen)
                onDone()
            } catch { self.error = error.localizedDescription }
        }
    }
}

// Opens a note that someone shared in chat (view only)
struct SharedNoteSheet: View {
    let message: Message

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(message.sharedTitle ?? "").font(.title.bold())
                    if let p = message.payload {
                        if let t = p.text, !t.isEmpty { Text(t).lineSpacing(6) }
                        ForEach(p.voices ?? []) { VoiceRow(voice: $0) }
                        if let l = p.location {
                            Label([l.placeName, l.subLocation ?? ""].filter { !$0.isEmpty }.joined(separator: " — "),
                                  systemImage: "mappin.and.ellipse")
                        }
                        if let r = p.reminder {
                            Label("\(r.title) · \(r.remindAt.niceTime)", systemImage: "clock")
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(AppTheme.canvas)
            .navigationTitle("Shared note · View only")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
