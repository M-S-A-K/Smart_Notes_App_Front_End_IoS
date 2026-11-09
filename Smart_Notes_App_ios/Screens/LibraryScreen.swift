//
//  LibraryScreens.swift
//  Smart_Notes_App_ios
//
//  Created by M_Salik_Amin_Kayani on 08/11/2026.
//
import SwiftUI

struct NotesListScreen: View {
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
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            chip("All", selected: selectedTag == nil) { selectedTag = nil }
                            ForEach(tags) { t in chip(t.name, selected: selectedTag == t.name) { selectedTag = t.name } }
                        }
                    }
                    if !error.isEmpty { Text(error).foregroundStyle(AppTheme.danger) }
                    if notes.isEmpty && error.isEmpty {
                        EmptyState(icon: "doc.text", title: "No notes yet", text: "Tap + to create your first note.")
                            .frame(maxWidth: .infinity)
                    }
                    ForEach(notes) { note in
                        Button { tap(note) } label: { NoteCard(note: note) }.buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
            .background(AppTheme.canvas)
            .navigationTitle("Notes")
            .toolbar {
                NavigationLink { GroupNotesListScreen() } label: { Label("Group notes", systemImage: "person.2") }
            }
            .overlay(alignment: .bottomTrailing) {
                NavigationLink { NoteScreen() } label: {
                    Image(systemName: "plus").font(.title2.bold()).foregroundStyle(.white)
                        .frame(width: 56, height: 56).background(AppTheme.accent)
                        .clipShape(Circle()).shadow(radius: 6, y: 3)
                }
                .padding(20)
            }
            .navigationDestination(item: $openNoteId) { NoteScreen(noteId: $0) }
            .refreshable { await load() }
            .onAppear { Task { await load() } }
            .onChange(of: selectedTag) { _, _ in Task { await load() } }
            .alert("Locked note", isPresented: Binding(get: { lockedNote != nil },
                                                       set: { if !$0 { lockedNote = nil } })) {
                SecureField("Password", text: $password)
                Button("Open") { Task { await unlock() } }
                Button("Cancel", role: .cancel) { password = "" }
            }
        }
    }

    private func chip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.caption.bold())
                .padding(.horizontal, 14).padding(.vertical, 8)
                .foregroundStyle(selected ? .white : AppTheme.inkSoft)
                .background(selected ? AppTheme.ink : AppTheme.surface)
                .overlay(Capsule().stroke(AppTheme.border))
                .clipShape(Capsule())
        }
    }

    private func tap(_ note: NoteSummary) {
        if note.isLocked { lockedNote = note } else { openNoteId = note.id }
    }

    private func unlock() async {
        guard let note = lockedNote else { return }
        do {
            try await API.shared.send("POST", "/api/notes/\(note.id)/verify-lock", body: ["password": password])
            openNoteId = note.id
        } catch { self.error = error.localizedDescription }
        password = ""
    }

    private func load() async {
        do {
            notes = try await API.shared.notes(type: "personal", tag: selectedTag)
            tags = (try? await API.shared.tags()) ?? []
            error = ""
        } catch { self.error = error.localizedDescription }
    }
}

struct NoteCard: View {
    let note: NoteSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(note.title).font(.headline).lineLimit(1)
                Spacer()
                if note.isGroup { Text("Group").font(.caption2.bold()).foregroundStyle(AppTheme.accentHover) }
                if note.isLocked { Image(systemName: "lock.fill").foregroundStyle(AppTheme.accentHover) }
            }
            Text(note.isLocked ? "Locked note" : note.snippet)
                .font(.subheadline).foregroundStyle(AppTheme.inkSoft).lineLimit(3)
            Text(note.updatedAt.timeAgo).font(.caption).foregroundStyle(AppTheme.muted)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(AppTheme.ink)
        .softCard()
    }
}
