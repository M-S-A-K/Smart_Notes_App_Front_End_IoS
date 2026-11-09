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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(AppTheme.muted)
                    TextField("Search notes and chats", text: $query).textInputAutocapitalization(.never)
                }
                .padding(.horizontal, 14).frame(height: 48).softCard(radius: 14)

                if query.isEmpty {
                    EmptyState(icon: "magnifyingglass", title: "Find anything, quickly",
                               text: "Search note text, tags and conversations.").frame(maxWidth: .infinity)
                } else if let r = result {
                    if r.notes.isEmpty && r.messages.isEmpty {
                        EmptyState(icon: "magnifyingglass", title: "No results found",
                                   text: "Try a shorter phrase.").frame(maxWidth: .infinity)
                    }
                    if !r.notes.isEmpty {
                        Text("Notes").font(.headline)
                        ForEach(r.notes) { n in
                            NavigationLink { NoteRouter(noteId: n.id) } label: {
                                HStack {
                                    Image(systemName: n.noteType == "group" ? "person.2" : "doc.text")
                                        .foregroundStyle(AppTheme.accentHover)
                                    Text(n.title).foregroundStyle(AppTheme.ink)
                                    Spacer()
                                    Image(systemName: "chevron.right").foregroundStyle(AppTheme.muted)
                                }
                                .padding(14).softCard(radius: 14)
                            }
                        }
                    }
                    if !r.messages.isEmpty {
                        Text("Chats").font(.headline)
                        ForEach(r.messages) { m in
                            Text(m.messageText ?? m.sharedTitle ?? "")
                                .padding(14).frame(maxWidth: .infinity, alignment: .leading).softCard(radius: 14)
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
    }

    private func run(_ q: String) async {
        guard !q.trimmingCharacters(in: .whitespaces).isEmpty else { result = nil; return }
        result = try? await API.shared.search(q)
    }
}

// Opens the right screen for a note id (personal or group)
struct NoteRouter: View {
    let noteId: Int
    @State private var type: String?

    var body: some View {
        Group {
            if type == "group" { GroupNoteScreen(noteId: noteId) }
            else if type != nil { NoteScreen(noteId: noteId) }
            else { ProgressView() }
        }
        .task { type = (try? await API.shared.noteDetail(noteId))?.noteType ?? "personal" }
    }
}
