//
//  LibraryScreens.swift
//  Smart_Notes_App_ios
//
//  Created by M_Salik_Amin_Kayani on 08/11/2026.
//

import SwiftUI

struct NotesListScreen: View {
    @ObservedObject private var api = API.shared
    @State private var notes: [NoteSummary] = []
    @State private var tags: [Tag] = []
    @State private var selectedTag: String?
    @State private var error = ""
    @State private var openNoteId: Int?
    @State private var lockedNote: NoteSummary?
    @State private var password = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if api.isOffline {
                        OfflineBanner()
                    }

                    NavigationLink { SearchScreen() } label: {
                        HStack {
                            Image(systemName: "magnifyingglass")
                            Text("Search your notes")
                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .frame(height: 48)
                        .foregroundStyle(AppTheme.muted)
                        .softCard(radius: 14)
                    }
                    .buttonStyle(.plain)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            chip("All", selected: selectedTag == nil) { selectedTag = nil }
                            ForEach(tags) { t in
                                chip(t.name, selected: selectedTag == t.name) { selectedTag = t.name }
                            }
                        }
                    }

                    if !error.isEmpty && !api.isOffline {
                        Text(error).font(.footnote).foregroundStyle(AppTheme.danger)
                    }

                    if notes.isEmpty {
                        EmptyState(
                            icon: "doc.text",
                            title: api.isOffline ? "No downloaded (.sma) notes" : "No notes yet — create your first note",
                            text: api.isOffline
                                ? "Download notes while online to access their .sma copies offline."
                                : "A thought, a list, or a voice memo is a perfect place to begin."
                        )
                        .frame(maxWidth: .infinity)
                    }

                    ForEach(notes) { note in
                        Button { tap(note) } label: { NoteCard(note: note) }
                            .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
            .background(AppTheme.canvas)
            .navigationTitle("Notes")
            .toolbar {
                NavigationLink { GroupNotesListScreen() } label: {
                    Label("Group notes", systemImage: "bubble.left.and.bubble.right")
                        .font(.caption.bold())
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if !api.isOffline {
                    NavigationLink { NoteScreen() } label: {
                        Image(systemName: "plus")
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                            .frame(width: 54, height: 54)
                            .background(AppTheme.accent)
                            .clipShape(Circle())
                            .shadow(color: AppTheme.accent.opacity(0.35), radius: 8, y: 4)
                    }
                    .buttonStyle(.plain)
                    .padding(20)
                }
            }
            .navigationDestination(item: $openNoteId) { NoteScreen(noteId: $0) }
            .refreshable { await load() }
            .onAppear { Task { await load() } }
            .onChange(of: selectedTag) { _, _ in Task { await load() } }
            .alert("Locked note", isPresented: Binding(get: { lockedNote != nil },
                                                       set: { if !$0 { lockedNote = nil } })) {
                SecureField("Password", text: $password)
                Button("Unlock note") {
                    if let n = lockedNote { Task { await unlock(n) } }
                }
                Button("Cancel", role: .cancel) { password = "" }
            } message: {
                Text("Enter this note’s password to continue.")
            }
        }
    }

    private func chip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.bold())
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .foregroundStyle(selected ? .white : AppTheme.inkSoft)
                .background(selected ? AppTheme.ink : AppTheme.surface)
                .overlay(Capsule().stroke(selected ? AppTheme.ink : AppTheme.border))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func tap(_ note: NoteSummary) {
        if note.isLocked { lockedNote = note } else { openNoteId = note.id }
    }

    private func unlock(_ note: NoteSummary) async {
            // If offline, verify against the encrypted .sma file!
            if api.isOffline {
                if OfflineStore.verifyOfflineLock(noteId: note.id, password: password) {
                    openNoteId = note.id
                    self.error = ""
                } else {
                    self.error = "Incorrect password for offline note."
                }
                password = ""
                return
            }
            do {
                try await API.shared.send("POST", "/api/notes/\(note.id)/verify-lock", body: ["password": password])
                // Also keep the .sma file's password synced!
                if OfflineStore.isOffline(note.id) {
                    OfflineStore.updateLockPassword(noteId: note.id, isLocked: true, newPassword: password)
                }
                openNoteId = note.id
                self.error = ""
            } catch {
                if OfflineStore.verifyOfflineLock(noteId: note.id, password: password) {
                    openNoteId = note.id
                    self.error = ""
                } else {
                    self.error = error.localizedDescription
                }
            }
            password = ""
        }

    private func load() async {
        do {
            notes = try await API.shared.notes(type: "personal", tag: selectedTag)
            tags = (try? await API.shared.tags()) ?? []
            error = ""
        } catch {
            // Offline fallback: show downloaded .sma notes!
            notes = OfflineStore.allOfflineSummaries(type: "personal", tag: selectedTag)
            self.error = error.localizedDescription
        }
    }
}

struct NoteCard: View {
    let note: NoteSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Text(note.title)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                HStack(spacing: 5) {
                    if note.isGroup {
                        Text("Group Note")
                            .font(.system(size: 9, weight: .heavy))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(AppTheme.accentSoft)
                            .foregroundStyle(AppTheme.accentHover)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    if OfflineStore.isOffline(note.id) {
                        Text("Offline (.sma)")
                            .font(.system(size: 9, weight: .heavy))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(AppTheme.accentSoft)
                            .foregroundStyle(AppTheme.accentHover)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    if note.isLocked {
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                            .foregroundStyle(AppTheme.accentHover)
                            .frame(width: 24, height: 24)
                            .background(AppTheme.accentSoft)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }

            let clean = note.snippet.plainText
            if note.isLocked {
                Text("Locked note")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.inkSoft)
            } else if clean.isEmpty {
                HStack(spacing: 5) {
                    Image(systemName: "mic.fill")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.accentHover)
                    Text("Voice / attachment note")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.inkSoft)
                }
            } else {
                Text(clean)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.inkSoft)
                    .lineLimit(3)
            }

            HStack {
                Spacer()
                Text(note.updatedAt.timeAgo)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.muted)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(AppTheme.ink)
        .softCard()
    }
}
