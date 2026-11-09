//
//  HomeScreen.swift
//  Smart_Notes_App_ios
//
//  Created by M_Salik_Amin_Kayani on 08/11/2026.
//

import SwiftUI

struct HomeScreen: View {
    @EnvironmentObject var state: AppState
    @ObservedObject private var api = API.shared
    @State private var notes: [NoteSummary] = []
    @State private var today: [CalendarItem] = []

    private var firstName: String {
        let full = state.user?.fullName ?? "Alex"
        return full.components(separatedBy: " ").first ?? full
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                if api.isOffline {
                    OfflineBanner()
                }

                // Header: Search Icon ONLY (No Avatar Icon) + Single-line greeting
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(Date().formatted(.dateTime.weekday(.wide).month(.wide).day()))
                            .font(.caption)
                            .foregroundStyle(AppTheme.inkSoft)
                        Text("Good morning, \(firstName)")
                            .font(.title2.bold())
                            .foregroundStyle(AppTheme.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }
                    Spacer(minLength: 8)
                    NavigationLink { SearchScreen() } label: {
                        Image(systemName: "magnifyingglass")
                            .font(.subheadline.bold())
                            .foregroundStyle(AppTheme.ink)
                            .frame(width: 40, height: 40)
                            .background(AppTheme.surface)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.border))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }

                // 3 Quick Action Cards
                HStack(spacing: 8) {
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

                // TODAY / Your reminders (Max 3)
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("TODAY")
                                .font(.system(size: 10, weight: .heavy))
                                .foregroundStyle(AppTheme.accentHover)
                            Text("Your reminders")
                                .font(.headline.bold())
                                .foregroundStyle(AppTheme.ink)
                        }
                        Spacer()
                        NavigationLink { CalendarScreen() } label: {
                            HStack(spacing: 3) {
                                Text("Open reminders")
                                Image(systemName: "chevron.right")
                            }
                            .font(.caption.bold())
                            .foregroundStyle(AppTheme.inkSoft)
                        }
                        .buttonStyle(.plain)
                    }

                    if today.isEmpty {
                        HStack(spacing: 10) {
                            Image(systemName: "bell.badge")
                                .foregroundStyle(AppTheme.accentHover)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("A clear day").font(.caption.bold()).foregroundStyle(AppTheme.ink)
                                Text("No reminders today.").font(.caption2).foregroundStyle(AppTheme.muted)
                            }
                            Spacer()
                        }
                        .padding(12)
                        .softCard(radius: 15)
                    } else {
                        VStack(spacing: 6) {
                            ForEach(today.prefix(3)) { item in
                                NavigationLink { NoteRouter(noteId: item.noteId) } label: {
                                    HStack(spacing: 10) {
                                        Text(item.remindAt.asDate?.formatted(date: .omitted, time: .shortened) ?? "")
                                            .font(.caption2.bold())
                                            .foregroundStyle(AppTheme.inkSoft)
                                            .frame(width: 56, alignment: .leading)
                                        Capsule()
                                            .fill(item.isCompletedOrPast ? Color.green : AppTheme.accent)
                                            .frame(width: 3, height: 28)
                                        VStack(alignment: .leading, spacing: 1) {
                                            HStack(spacing: 4) {
                                                Text(item.title)
                                                    .font(.caption.bold())
                                                    .strikethrough(item.isCompletedOrPast, color: AppTheme.muted)
                                                    .foregroundStyle(AppTheme.ink)
                                                    .lineLimit(1)
                                                if item.isCompletedOrPast {
                                                    Image(systemName: "checkmark.circle.fill")
                                                        .font(.caption2)
                                                        .foregroundStyle(.green)
                                                }
                                            }
                                            Text("From “\(item.noteTitle)”")
                                                .font(.caption2)
                                                .foregroundStyle(AppTheme.inkSoft)
                                                .lineLimit(1)
                                        }
                                        Spacer()
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .softCard(radius: 14)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                // REFRESH YOUR MIND / Recent notes (Max 3)
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("REFRESH YOUR MIND")
                                .font(.system(size: 10, weight: .heavy))
                                .foregroundStyle(AppTheme.accentHover)
                            Text("Recent notes")
                                .font(.headline.bold())
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
                        .buttonStyle(.plain)
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
                        .padding(14)
                        .softCard(radius: 15)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(recent.enumerated()), id: \.element.id) { index, note in
                                NavigationLink { NoteScreen(noteId: note.id) } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: "doc.text")
                                            .font(.caption.bold())
                                            .foregroundStyle(AppTheme.accentHover)
                                            .frame(width: 30, height: 30)
                                            .background(AppTheme.accentSoft)
                                            .clipShape(RoundedRectangle(cornerRadius: 9))

                                        VStack(alignment: .leading, spacing: 2) {
                                            HStack(spacing: 5) {
                                                Text(note.title)
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
                                            let clean = note.snippet.plainText
                                            Text(clean.isEmpty ? "🎤 Voice or attachment note" : clean)
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
                                    .padding(.vertical, 10)
                                }
                                .buttonStyle(.plain)
                                if index < recent.count - 1 {
                                    Divider()
                                }
                            }
                        }
                        .softCard(radius: 16)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(AppTheme.canvas)
            .onAppear { Task { await load() } }
        }
    }

    private func load() async {
        if let onlineNotes = try? await API.shared.notes() {
            notes = onlineNotes
        } else {
            notes = OfflineStore.allOfflineSummaries()
        }
        let all = (try? await API.shared.calendar()) ?? []
        today = all.filter { Calendar.current.isDateInToday($0.remindAt.asDate ?? .distantPast) }
    }
}
