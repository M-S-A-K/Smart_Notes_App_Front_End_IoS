//
//  HomeScreen.swift
//  Smart_Notes_App_ios
//
//  Created by M_Salik_Amin_Kayani on 08/11/2026.
//

import SwiftUI

struct HomeScreen: View {
    @EnvironmentObject var state: AppState
    @State private var notes: [NoteSummary] = []
    @State private var today: [CalendarItem] = []

    private var name: String { state.user?.fullName ?? "Alex" }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(Date().formatted(.dateTime.weekday(.wide).month(.wide).day()))
                                .font(.footnote)
                                .foregroundStyle(AppTheme.inkSoft)
                            Text("Good morning, \(name.components(separatedBy: " ").first ?? "")")
                                .font(.title.bold())
                                .foregroundStyle(AppTheme.ink)
                        }
                        Spacer()
                        NavigationLink { SearchScreen() } label: {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(AppTheme.ink)
                                .frame(width: 42, height: 42)
                                .background(AppTheme.surface)
                                .overlay(RoundedRectangle(cornerRadius: 13).stroke(AppTheme.border))
                                .clipShape(RoundedRectangle(cornerRadius: 13))
                        }
                        .buttonStyle(.plain)

                        NavigationLink { ProfileScreen() } label: {
                            Avatar(name: name)
                        }
                        .buttonStyle(.plain)
                    }

                    // 3 Quick Action Cards
                    HStack(spacing: 10) {
                        NavigationLink { NoteScreen() } label: {
                            QuickCard(icon: "plus", title: "New note")
                        }
                        NavigationLink { NoteScreen(record: true) } label: {
                            QuickCard(icon: "mic", title: "Voice note", highlight: true)
                        }
                        NavigationLink { GroupNotesListScreen() } label: {
                            QuickCard(icon: "bubble.left.and.bubble.right", title: "Group note")
                        }
                    }
                    .buttonStyle(.plain)

                    // Today / Your Reminders
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .bottom) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("TODAY")
                                    .font(.system(size: 10, weight: .heavy))
                                    .foregroundStyle(AppTheme.accentHover)
                                Text("Your reminders")
                                    .font(.title3.bold())
                                    .foregroundStyle(AppTheme.ink)
                            }
                            Spacer()
                            NavigationLink { CalendarScreen() } label: {
                                HStack(spacing: 3) {
                                    Text("Open calendar")
                                    Image(systemName: "chevron.right")
                                }
                                .font(.caption.bold())
                                .foregroundStyle(AppTheme.inkSoft)
                            }
                        }

                        if today.isEmpty {
                            HStack(spacing: 10) {
                                Image(systemName: "calendar")
                                    .foregroundStyle(AppTheme.accentHover)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("A clear day").font(.caption.bold()).foregroundStyle(AppTheme.ink)
                                    Text("No reminders today.").font(.caption2).foregroundStyle(AppTheme.muted)
                                }
                                Spacer()
                            }
                            .padding(14)
                            .softCard()
                        } else {
                            ForEach(today.prefix(2)) { item in
                                NavigationLink { NoteRouter(noteId: item.noteId) } label: {
                                    ReminderRow(item: item)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Refresh Your Mind / Recent Notes
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .bottom) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("REFRESH YOUR MIND")
                                    .font(.system(size: 10, weight: .heavy))
                                    .foregroundStyle(AppTheme.accentHover)
                                Text("Recent notes")
                                    .font(.title3.bold())
                                    .foregroundStyle(AppTheme.ink)
                            }
                            Spacer()
                            NavigationLink { NotesListScreen() } label: {
                                HStack(spacing: 3) {
                                    Text("See all")
                                    Image(systemName: "chevron.right")
                                }
                                .font(.caption.bold())
                                .foregroundStyle(AppTheme.inkSoft)
                            }
                        }

                        let recent = Array(notes.filter { !$0.isLocked && !$0.isGroup }.prefix(3))
                        if recent.isEmpty {
                            HStack(spacing: 10) {
                                Image(systemName: "doc.text").foregroundStyle(AppTheme.accentHover)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("No notes yet").font(.caption.bold()).foregroundStyle(AppTheme.ink)
                                    Text("Create a note to see it here.").font(.caption2).foregroundStyle(AppTheme.muted)
                                }
                                Spacer()
                            }
                            .padding(16)
                            .softCard()
                        } else {
                            VStack(spacing: 0) {
                                ForEach(Array(recent.enumerated()), id: \.element.id) { index, note in
                                    NavigationLink { NoteScreen(noteId: note.id) } label: {
                                        HStack(spacing: 10) {
                                            Image(systemName: "doc.text")
                                                .font(.subheadline)
                                                .foregroundStyle(AppTheme.accentHover)
                                                .frame(width: 32, height: 32)
                                                .background(AppTheme.accentSoft)
                                                .clipShape(RoundedRectangle(cornerRadius: 10))

                                            VStack(alignment: .leading, spacing: 3) {
                                                HStack(spacing: 5) {
                                                    Text(note.title.isEmpty ? "Untitled note" : note.title)
                                                        .font(.footnote.bold())
                                                        .foregroundStyle(AppTheme.ink)
                                                        .lineLimit(1)
                                                    if OfflineStore.isOffline(note.id) {
                                                        Text("Offline")
                                                            .font(.system(size: 8, weight: .heavy))
                                                            .padding(.horizontal, 5)
                                                            .padding(.vertical, 2)
                                                            .background(AppTheme.accentSoft)
                                                            .foregroundStyle(AppTheme.accentHover)
                                                            .clipShape(Capsule())
                                                    }
                                                }
                                                Text(note.snippet.plainText.isEmpty ? "Start writing…" : note.snippet.plainText)
                                                    .font(.caption2)
                                                    .foregroundStyle(AppTheme.inkSoft)
                                                    .lineLimit(1)
                                            }
                                            Spacer()
                                            Text(note.updatedAt.timeAgo)
                                                .font(.caption2)
                                                .foregroundStyle(AppTheme.muted)
                                            Image(systemName: "chevron.right")
                                                .font(.caption2)
                                                .foregroundStyle(AppTheme.muted)
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 12)
                                    }
                                    .buttonStyle(.plain)
                                    if index < recent.count - 1 {
                                        Divider()
                                    }
                                }
                            }
                            .softCard()
                        }
                    }
                }
                .padding(16)
            }
            .background(AppTheme.canvas)
            .onAppear { Task { await load() } }
        }
    }

    private func load() async {
        notes = (try? await API.shared.notes()) ?? []
        let all = (try? await API.shared.calendar()) ?? []
        today = all.filter { Calendar.current.isDateInToday($0.remindAt.asDate ?? .distantPast) }
    }
}
