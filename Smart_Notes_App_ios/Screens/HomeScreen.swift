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

    private var name: String { state.user?.fullName ?? "" }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(Date().formatted(.dateTime.weekday(.wide).month(.wide).day()))
                                .font(.footnote).foregroundStyle(AppTheme.inkSoft)
                            Text("Good day, \(name.components(separatedBy: " ").first ?? "")")
                                .font(.title.bold())
                        }
                        Spacer()
                        Avatar(name: name)
                    }

                    HStack(spacing: 10) {
                        NavigationLink { NoteScreen() } label: { QuickCard(icon: "plus", title: "New note") }
                        NavigationLink { NoteScreen() } label: { QuickCard(icon: "mic", title: "Voice note", highlight: true) }
                        NavigationLink { GroupNotesListScreen() } label: { QuickCard(icon: "person.2", title: "Group note") }
                    }
                    .buttonStyle(.plain)

                    Text("Your reminders").font(.headline)
                    if today.isEmpty { Text("A clear day. No reminders today.").foregroundStyle(AppTheme.inkSoft) }
                    ForEach(today) { ReminderRow(item: $0) }

                    Text("Recent notes").font(.headline)
                    ForEach(notes.filter { !$0.isLocked && !$0.isGroup }.prefix(3)) { note in
                        NavigationLink { NoteScreen(noteId: note.id) } label: { NoteCard(note: note) }
                            .buttonStyle(.plain)
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
