//
//  CalendarScreen.swift
//  Smart_Notes_App_ios
//
//  Created by M_Salik_Amin_Kayani on 08/11/2026.
//

import SwiftUI

struct CalendarScreen: View {
    @State private var items: [CalendarItem] = []
    @State private var month = Date()
    @State private var selected = Date()

    private let cal = Calendar.current

    private var days: [Date] {
        guard let first = cal.date(from: cal.dateComponents([.year, .month], from: month)),
              let start = cal.date(byAdding: .day, value: -(cal.component(.weekday, from: first) - 1), to: first)
        else { return [] }
        return (0..<42).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
    }

    private func sameDay(_ i: CalendarItem, _ d: Date) -> Bool {
        cal.isDate(i.remindAt.asDate ?? .distantPast, inSameDayAs: d)
    }

    private var dayItems: [CalendarItem] { items.filter { sameDay($0, selected) } }

    private func textColor(_ d: Date) -> Color {
        if cal.isDate(d, inSameDayAs: selected) { return .white }
        if cal.isDateInToday(d) { return AppTheme.accentHover }
        return cal.isDate(d, equalTo: month, toGranularity: .month) ? AppTheme.ink : AppTheme.muted
    }

    private func shift(_ n: Int) { month = cal.date(byAdding: .month, value: n, to: month) ?? month }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(spacing: 10) {
                        HStack {
                            Button { shift(-1) } label: { Image(systemName: "chevron.left") }
                                .buttonStyle(.plain)
                            Spacer()
                            Text(month.formatted(.dateTime.month(.wide).year())).font(.headline)
                            Spacer()
                            Button { shift(1) } label: { Image(systemName: "chevron.right") }
                                .buttonStyle(.plain)
                        }
                        HStack {
                            ForEach(["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"], id: \.self) {
                                Text($0).font(.caption2.bold()).foregroundStyle(AppTheme.muted).frame(maxWidth: .infinity)
                            }
                        }
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 6) {
                            ForEach(days, id: \.self) { d in
                                Button { selected = d } label: {
                                    VStack(spacing: 3) {
                                        Text("\(cal.component(.day, from: d))").font(.caption.bold())
                                            .frame(width: 30, height: 30)
                                            .foregroundStyle(textColor(d))
                                            .background(cal.isDate(d, inSameDayAs: selected) ? AppTheme.accent : Color.clear)
                                            .overlay(Circle().stroke(cal.isDateInToday(d) ? AppTheme.accent : Color.clear))
                                            .clipShape(Circle())
                                        Circle()
                                            .fill(items.contains { sameDay($0, d) } ? AppTheme.accent : Color.clear)
                                            .frame(width: 4, height: 4)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(16)
                    .softCard(radius: 20)

                    VStack(alignment: .leading, spacing: 10) {
                        Text(selected.formatted(.dateTime.weekday(.wide).month(.wide).day())).font(.headline)
                        Text("\(dayItems.count) \(dayItems.count == 1 ? "reminder" : "reminders")")
                            .font(.caption).foregroundStyle(AppTheme.muted)
                        if dayItems.isEmpty {
                            EmptyState(
                                icon: "bell.badge",
                                title: "No reminders scheduled",
                                text: "Reminders from your notes appear here and ring at their scheduled time."
                            )
                            .frame(maxWidth: .infinity)
                        }
                        ForEach(dayItems) { item in
                            NavigationLink { NoteRouter(noteId: item.noteId) } label: {
                                ReminderRow(item: item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(16)
            }
            .background(AppTheme.canvas)
            .navigationTitle("Reminder")
            .toolbar {
                Button("Today") { selected = Date(); month = Date() }
                    .font(.caption.bold())
            }
            .onAppear {
                Task { items = (try? await API.shared.calendar()) ?? [] }
            }
        }
    }
}

struct ReminderRow: View {
    let item: CalendarItem
    var onToggle: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 10) {
            Text(item.remindAt.asDate?.formatted(date: .omitted, time: .shortened) ?? "")
                .font(.caption.bold())
                .foregroundStyle(AppTheme.inkSoft)
                .frame(width: 64, alignment: .leading)

            Capsule()
                .fill(item.isCompletedOrPast ? Color.green : AppTheme.accent)
                .frame(width: 4, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(item.title)
                        .font(.subheadline.bold())
                        .strikethrough(item.isCompletedOrPast, color: AppTheme.muted)
                        .foregroundStyle(item.isCompletedOrPast ? AppTheme.inkSoft : AppTheme.ink)
                    if item.isCompletedOrPast {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
                Text("From “\(item.noteTitle)”")
                    .font(.caption)
                    .foregroundStyle(AppTheme.inkSoft)
            }
            Spacer()
            Button {
                Task {
                    try? await API.shared.toggleReminder(noteId: item.noteId, reminderId: item.id)
                    onToggle?()
                }
            } label: {
                Image(systemName: item.isCompletedOrPast ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(item.isCompletedOrPast ? .green : AppTheme.muted)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .softCard()
    }
}
