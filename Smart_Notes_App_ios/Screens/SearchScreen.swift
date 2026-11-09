//
//  SearchScreen.swift
//  Smart_Notes_App_ios
//
//  Created by M_Salik_Amin_Kayani on 09/11/2026.
//

import SwiftUI

struct SearchScreen: View {
    @State private var query = ""
    @State private var result: SearchResult?
    @State private var openHit: SearchResult.Hit?
    @State private var lockedHit: SearchResult.Hit?
    @State private var password = ""
    @State private var error = ""

    private let suggestions = ["Meeting", "Ideas", "University"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(AppTheme.muted)
                    TextField("Search notes, voice transcripts, and chats", text: $query)
                        .textInputAutocapitalization(.never)
                    if !query.isEmpty {
                        Button("Clear") { query = "" }
                            .font(.caption.bold())
                            .foregroundStyle(AppTheme.accentHover)
                            .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14)
                .frame(height: 48)
                .softCard(radius: 14)

                if !error.isEmpty {
                    Text(error).font(.footnote).foregroundStyle(AppTheme.danger)
                }

                if query.isEmpty {
                    VStack(spacing: 12) {
                        EmptyState(
                            icon: "magnifyingglass",
                            title: "Find anything, quickly",
                            text: "Search note text, voice-note names, transcripts, tags, people, and conversations."
                        )
                        HStack(spacing: 8) {
                            ForEach(suggestions, id: \.self) { item in
                                Button(item) { query = item }
                                    .font(.caption.bold())
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .foregroundStyle(AppTheme.inkSoft)
                                    .background(AppTheme.surface)
                                    .overlay(Capsule().stroke(AppTheme.border))
                                    .clipShape(Capsule())
                                    .buttonStyle(.plain)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                } else if let r = result {
                    if r.notes.isEmpty && r.messages.isEmpty {
                        EmptyState(
                            icon: "magnifyingglass",
                            title: "No results found",
                            text: "We couldn’t find anything for “\(query)”. Try a shorter phrase."
                        )
                        .frame(maxWidth: .infinity)
                    }
                    if !r.notes.isEmpty {
                        Text("Notes (\(r.notes.count))").font(.headline)
                        ForEach(r.notes) { n in
                            Button {
                                Task { await tapHit(n) }
                            } label: {
                                HStack {
                                    Image(systemName: n.noteType == "group" ? "person.2" : "doc.text")
                                        .foregroundStyle(AppTheme.accentHover)
                                        .frame(width: 34, height: 34)
                                        .background(AppTheme.accentSoft)
                                        .clipShape(RoundedRectangle(cornerRadius: 9))
                                    Text(n.title).font(.subheadline.bold()).foregroundStyle(AppTheme.ink)
                                    Spacer()
                                    if n.isLocked == true {
                                        Image(systemName: "lock.fill")
                                            .font(.caption)
                                            .foregroundStyle(AppTheme.accentHover)
                                    }
                                    Image(systemName: "chevron.right").foregroundStyle(AppTheme.muted)
                                }
                                .padding(14)
                                .softCard(radius: 14)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    if !r.messages.isEmpty {
                        Text("Conversations (\(r.messages.count))").font(.headline)
                        ForEach(r.messages) { m in
                            Text((m.messageText ?? m.sharedTitle ?? "").plainText)
                                .font(.subheadline)
                                .padding(14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .softCard(radius: 14)
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(AppTheme.canvas)
        .navigationTitle("Search")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: query) { _, q in Task { await run(q) } }
        .navigationDestination(item: Binding(
            get: { openHit?.id },
            set: { if $0 == nil { openHit = nil } }
        )) { id in
            NoteRouter(noteId: id, preUnlocked: true)
        }
        .alert("Locked note", isPresented: Binding(get: { lockedHit != nil },
                                                   set: { if !$0 { lockedHit = nil } })) {
            SecureField("Password", text: $password)
            Button("Unlock note") {
                if let hit = lockedHit {
                    Task { await unlock(hit) }
                }
            }
            Button("Cancel", role: .cancel) { password = "" }
        } message: {
            Text("Enter this note’s password to continue.")
        }
    }

    private func tapHit(_ hit: SearchResult.Hit) async {
        // Always check NoteDetail.isLocked so locked notes NEVER open without password!
        if let d = try? await API.shared.noteDetail(hit.id), d.isLocked {
            lockedHit = hit
            return
        }
        if hit.isLocked == true {
            lockedHit = hit
        } else {
            openHit = hit
        }
    }

    private func unlock(_ hit: SearchResult.Hit) async {
        do {
            try await API.shared.send("POST", "/api/notes/\(hit.id)/verify-lock", body: ["password": password])
            error = ""
            openHit = hit
        } catch {
            self.error = error.localizedDescription
        }
        password = ""
    }

    private func run(_ q: String) async {
        guard !q.trimmingCharacters(in: .whitespaces).isEmpty else { result = nil; return }
        result = try? await API.shared.search(q)
    }
}

struct NoteRouter: View {
    let noteId: Int
    var preUnlocked: Bool = false

    @Environment(\.dismiss) private var dismiss
    @State private var detail: NoteDetail?
    @State private var unlocked = false
    @State private var showLockPrompt = false
    @State private var password = ""
    @State private var error = ""

    var body: some View {
        Group {
            if let d = detail {
                if d.isLocked && !unlocked && !preUnlocked {
                    VStack(spacing: 14) {
                        Image(systemName: "lock.fill")
                            .font(.largeTitle)
                            .foregroundStyle(AppTheme.accent)
                        Text("Locked Note")
                            .font(.headline)
                        if !error.isEmpty {
                            Text(error).font(.caption).foregroundStyle(AppTheme.danger)
                        }
                        Button("Enter Password") { showLockPrompt = true }
                            .buttonStyle(.borderedProminent)
                            .tint(AppTheme.accent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppTheme.canvas)
                } else if d.noteType == "group" {
                    GroupNoteScreen(noteId: noteId)
                } else {
                    NoteScreen(noteId: noteId)
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppTheme.canvas)
            }
        }
        .task {
            if let d = try? await API.shared.noteDetail(noteId) {
                detail = d
                if d.isLocked && !preUnlocked {
                    showLockPrompt = true
                }
            } else if let pkg = OfflineStore.loadSma(noteId) {
                detail = pkg.detail
            }
        }
        .alert("Locked note", isPresented: $showLockPrompt) {
            SecureField("Password", text: $password)
            Button("Unlock") {
                Task {
                    do {
                        try await API.shared.send("POST", "/api/notes/\(noteId)/verify-lock", body: ["password": password])
                        unlocked = true
                        error = ""
                    } catch {
                        self.error = "Incorrect password."
                    }
                    password = ""
                }
            }
            Button("Cancel", role: .cancel) { dismiss() }
        }
    }
}
