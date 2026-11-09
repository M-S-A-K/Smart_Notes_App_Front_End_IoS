//
//  GroupNoteScreen.swift
//  Smart_Notes_App_ios
//
//  Created by M_Salik_Amin_Kayani on 08/11/2026.
//

import SwiftUI

struct GroupNotesListScreen: View {
    @State private var notes: [NoteSummary] = []
    @State private var showNew = false
    @State private var title = ""
    @State private var openId: Int?
    @State private var error = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                NavigationLink { SearchScreen() } label: {
                    HStack {
                        Image(systemName: "magnifyingglass")
                        Text("Search all notes, including group notes")
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 48)
                    .foregroundStyle(AppTheme.muted)
                    .softCard(radius: 14)
                }
                .buttonStyle(.plain)

                if !error.isEmpty {
                    Text(error).font(.footnote).foregroundStyle(AppTheme.danger)
                }
                if notes.isEmpty && error.isEmpty {
                    EmptyState(
                        icon: "bubble.left.and.bubble.right",
                        title: "No group notes yet",
                        text: "Create a group note or wait for a collaborator to share one with you."
                    )
                    .frame(maxWidth: .infinity)
                }
                ForEach(notes) { n in
                    NavigationLink { GroupNoteScreen(noteId: n.id) } label: {
                        NoteCard(note: n)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
        }
        .background(AppTheme.canvas)
        .navigationTitle("Group Notes")
        .toolbar {
            Button { showNew = true } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                    Text("New group").font(.caption.bold())
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .foregroundStyle(.white)
                .background(AppTheme.accent)
                .clipShape(Capsule())
            }
        }
        .navigationDestination(item: $openId) { GroupNoteScreen(noteId: $0) }
        .alert("New group note", isPresented: $showNew) {
            TextField("Group note title", text: $title)
            Button("Create") { Task { await create() } }
            Button("Cancel", role: .cancel) { title = "" }
        }
        .onAppear { Task { await load() } }
    }

    private func create() async {
        do {
            openId = try await API.shared.createGroup(title: title.isEmpty ? "Untitled group note" : title)
            title = ""
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func load() async {
        do {
            notes = try await API.shared.notes(type: "group")
            error = ""
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct GroupNoteScreen: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var state: AppState
    @StateObject private var recorder = Recorder()
    let noteId: Int

    @State private var detail: NoteDetail?
    @State private var members: [Person] = []
    @State private var friends: [Person] = []
    @State private var items: [Contribution] = []
    @State private var kind = "" // "", "text", "location", "reminder"
    @State private var text = ""
    @State private var subLocation = ""
    @State private var when = Date()
    @State private var busy = false
    @State private var error = ""

    @State private var showMembers = false
    @State private var showAdd = false
    @State private var showLeave = false
    @State private var showLock = false
    @State private var lockPassword = ""
    @State private var isOffline = false
    @State private var showOfflineToast = false
    @State private var editItem: Contribution?
    @State private var editText = ""

    private var me: Int { state.user?.userId ?? 0 }
    private var isOwner: Bool { detail?.ownerId == me }
    private var ownerName: String {
        members.first { $0.id == detail?.ownerId }?.fullName ?? (state.user?.fullName ?? "Owner")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Member chips bar
                HStack(spacing: 8) {
                    if isOwner {
                        Button { showAdd = true } label: {
                            Label("Add members", systemImage: "plus")
                                .font(.caption2.bold())
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(AppTheme.surface)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.border))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(members) { m in
                                HStack(spacing: 5) {
                                    Avatar(name: m.fullName, size: 22)
                                    Text(m.fullName).font(.caption2.bold()).lineLimit(1)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(AppTheme.surfaceSoft)
                                .overlay(Capsule().stroke(AppTheme.border))
                                .clipShape(Capsule())
                            }
                        }
                    }
                }

                // Group Note Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("GROUP NOTE")
                        .font(.system(size: 10, weight: .heavy))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(AppTheme.accentSoft)
                        .foregroundStyle(AppTheme.accentHover)
                        .clipShape(Capsule())
                    Text("Owned by \(ownerName) · \(members.count) \(members.count == 1 ? "member" : "members")")
                        .font(.caption)
                        .foregroundStyle(AppTheme.muted)
                }

                Text(detail?.title ?? "Untitled group note")
                    .font(.largeTitle.bold())
                    .foregroundStyle(AppTheme.ink)

                if isOffline || detail?.isLocked == true {
                    HStack(spacing: 6) {
                        if isOffline {
                            Text("Offline")
                                .font(.system(size: 9, weight: .heavy))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(AppTheme.accentSoft)
                                .foregroundStyle(AppTheme.accentHover)
                                .clipShape(Capsule())
                        }
                        if detail?.isLocked == true {
                            Label("Locked", systemImage: "lock.fill")
                                .font(.system(size: 9, weight: .heavy))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(AppTheme.accentSoft)
                                .foregroundStyle(AppTheme.accentHover)
                                .clipShape(Capsule())
                        }
                    }
                }

                if !error.isEmpty {
                    Text(error).font(.footnote).foregroundStyle(AppTheme.danger)
                }

                if items.isEmpty && error.isEmpty {
                    Text("No content has been added yet.")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.muted)
                        .frame(maxWidth: .infinity)
                        .padding(24)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(AppTheme.borderStrong, style: StrokeStyle(lineWidth: 1, dash: [5]))
                        )
                }

                ForEach(items) { item in
                    ContributionRow(item: item)
                        .contextMenu { actions(for: item) }
                }

                addSection
            }
            .padding(16)
        }
        .background(AppTheme.surface)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { optionsMenu }
        }
        .overlay(alignment: .bottom) {
            if showOfflineToast {
                Label("Offline copy saved", systemImage: "checkmark")
                    .font(.caption.bold())
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .foregroundStyle(AppTheme.accentHover)
                    .softCard(radius: 14)
                    .padding(.bottom, 24)
            }
        }
        .task { await load() }
        .sheet(isPresented: $showMembers) { membersSheet }
        .sheet(isPresented: $showAdd) { addMemberSheet }
        .alert(isOwner ? "Delete this group note?" : "Leave this group?", isPresented: $showLeave) {
            Button(isOwner ? "Delete" : "Leave", role: .destructive) { Task { await leave() } }
            Button("Cancel", role: .cancel) {}
        }
        .alert(detail?.isLocked == true ? "Remove note lock" : "Lock this note", isPresented: $showLock) {
            SecureField("Password (4+ characters)", text: $lockPassword)
            Button(detail?.isLocked == true ? "Remove lock" : "Set password") { Task { await toggleLock() } }
            Button("Cancel", role: .cancel) { lockPassword = "" }
        }
        .alert("Edit entry", isPresented: Binding(get: { editItem != nil }, set: { if !$0 { editItem = nil } })) {
            TextField("Text", text: $editText)
            Button("Save") {
                if let i = editItem {
                    run {
                        try await API.shared.send("PUT", "/api/notes/\(noteId)/contributions/\(i.id)",
                                                  body: ["text": editText])
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: Options Menu
    private var optionsMenu: some View {
        Menu {
            if isOwner {
                Button { showAdd = true } label: { Label("Add member", systemImage: "person.badge.plus") }
            }
            Button { showMembers = true } label: { Label("Members", systemImage: "person.2") }
            Button {
                OfflineStore.markOffline(noteId)
                isOffline = true
                withAnimation { showOfflineToast = true }
                Task {
                    try? await Task.sleep(for: .seconds(1.6))
                    withAnimation { showOfflineToast = false }
                }
            } label: {
                Label(isOffline ? "Available offline" : "Download", systemImage: "checkmark.circle")
            }
            Button { showLock = true } label: {
                Label(detail?.isLocked == true ? "Unlock / Remove lock" : "Lock note", systemImage: "lock")
            }
            Button(role: .destructive) { showLeave = true } label: {
                Label(isOwner ? "Delete" : "Leave group",
                      systemImage: isOwner ? "trash" : "rectangle.portrait.and.arrow.right")
            }
        } label: {
            Image(systemName: "ellipsis")
                .foregroundStyle(AppTheme.ink)
                .frame(width: 36, height: 36)
                .background(AppTheme.surface)
                .overlay(RoundedRectangle(cornerRadius: 11).stroke(AppTheme.border))
                .clipShape(RoundedRectangle(cornerRadius: 11))
        }
    }

    @ViewBuilder private func actions(for item: Contribution) -> some View {
        if item.type == "text" && item.userId == me {
            Button("Edit") { editText = item.text?.plainText ?? ""; editItem = item }
        }
        if item.userId == me || isOwner {
            Button("Delete", role: .destructive) {
                run { try await API.shared.send("DELETE", "/api/notes/\(noteId)/contributions/\(item.id)") }
            }
        }
    }

    // MARK: Add to Note Bar
    private var addSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider()
            Text("ADD TO NOTE")
                .font(.system(size: 10, weight: .heavy))
                .foregroundStyle(AppTheme.accentHover)

            HStack(spacing: 8) {
                ActionPill(icon: "doc.text", text: "Text", filled: kind == "text") {
                    kind = (kind == "text") ? "" : "text"
                }
                ActionPill(icon: "mappin.and.ellipse", text: "Location", filled: kind == "location") {
                    kind = (kind == "location") ? "" : "location"
                }
                ActionPill(icon: "clock", text: "Reminder", filled: kind == "reminder") {
                    kind = (kind == "reminder") ? "" : "reminder"
                }
                ActionPill(
                    icon: recorder.isRecording ? "stop.circle" : "mic",
                    text: recorder.isRecording
                        ? String(format: "%d:%02d", recorder.seconds / 60, recorder.seconds % 60)
                        : "Voice note",
                    filled: recorder.isRecording
                ) {
                    Task { await toggleRecording() }
                }
            }

            if busy {
                HStack { ProgressView(); Text("Transcribing…").font(.caption) }
            }

            if !kind.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    TextField(
                        kind == "location" ? "University, building, or place"
                        : kind == "reminder" ? "Reminder name"
                        : "Start writing your note…",
                        text: $text
                    )
                    .textFieldStyle(.roundedBorder)

                    if kind == "location" {
                        TextField("Room / Sub-location (LT5)", text: $subLocation)
                            .textFieldStyle(.roundedBorder)
                    }
                    if kind == "reminder" {
                        DatePicker("Date & Time", selection: $when)
                            .font(.caption.bold())
                    }
                    HStack {
                        Spacer()
                        Button("Add") { add() }
                            .font(.caption.bold())
                            .buttonStyle(.borderedProminent)
                            .tint(AppTheme.accent)
                    }
                }
                .padding(12)
                .softCard(background: AppTheme.surfaceSoft)
            }
        }
        .padding(.top, 6)
    }

    private func add() {
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        var body: [String: Any] = ["type": kind, "text": text]
        if kind == "location" { body["subLocation"] = subLocation }
        if kind == "reminder" { body["remindAt"] = ISO8601DateFormatter().string(from: when) }
        text = ""; subLocation = ""; kind = ""
        run { try await API.shared.send("POST", "/api/notes/\(noteId)/contributions", body: body) }
    }

    private func toggleRecording() async {
        if recorder.isRecording {
            let (url, seconds) = recorder.stop()
            busy = true
            do {
                try await API.shared.uploadVoice(noteId: noteId, fileURL: url, seconds: seconds, name: "Voice note")
                error = ""
            } catch {
                self.error = error.localizedDescription
            }
            busy = false
            await load()
        } else if await recorder.start() == false {
            error = "Allow microphone access in Settings."
        }
    }

    private func toggleLock() async {
        let path = detail?.isLocked == true ? "unlock" : "lock"
        do {
            try await API.shared.send("POST", "/api/notes/\(noteId)/\(path)", body: ["password": lockPassword])
            error = ""
            await load()
        } catch {
            self.error = error.localizedDescription
        }
        lockPassword = ""
    }

    // MARK: Sheets
    private var membersSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("GROUP NOTE MEMBERS")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(AppTheme.accentHover)
                Text(detail?.title ?? "Group Note")
                    .font(.title3.bold())
                ForEach(members) { m in
                    HStack(spacing: 12) {
                        Avatar(name: m.fullName, size: 36)
                        VStack(alignment: .leading) {
                            Text(m.fullName).font(.subheadline.bold())
                            Text(m.id == detail?.ownerId ? "Owner" : "Member")
                                .font(.caption)
                                .foregroundStyle(AppTheme.inkSoft)
                        }
                        Spacer()
                        if isOwner && m.id != detail?.ownerId {
                            Button("Remove", role: .destructive) {
                                run { try await API.shared.send("DELETE", "/api/notes/\(noteId)/members/\(m.id)") }
                            }
                            .font(.caption)
                        }
                    }
                    .padding(10)
                    .softCard(background: AppTheme.surfaceSoft)
                }
                Spacer()
                HStack {
                    Spacer()
                    Button("Done") { showMembers = false }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.accent)
                }
            }
            .padding(20)
        }
        .presentationDetents([.medium])
    }

    private var addMemberSheet: some View {
        let available = friends.filter { f in !members.contains { $0.id == f.id } }
        return NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("ADD MEMBER")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(AppTheme.accentHover)
                Text("Choose from friends")
                    .font(.title3.bold())
                if available.isEmpty {
                    Text("All friends are already members.")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.muted)
                        .padding(.vertical, 16)
                }
                ForEach(available) { f in
                    Button {
                        showAdd = false
                        run { try await API.shared.send("POST", "/api/notes/\(noteId)/members", body: ["userId": f.id]) }
                    } label: {
                        HStack(spacing: 12) {
                            Avatar(name: f.fullName, size: 36)
                            VStack(alignment: .leading) {
                                Text(f.fullName).font(.subheadline.bold()).foregroundStyle(AppTheme.ink)
                                Text(f.email).font(.caption).foregroundStyle(AppTheme.muted)
                            }
                            Spacer()
                            Image(systemName: "plus").foregroundStyle(AppTheme.accentHover)
                        }
                        .padding(10)
                        .softCard(background: AppTheme.surfaceSoft)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                HStack {
                    Spacer()
                    Button("Done") { showAdd = false }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.accent)
                }
            }
            .padding(20)
        }
        .presentationDetents([.medium])
    }

    private func leave() async {
        do {
            if isOwner {
                try await API.shared.send("DELETE", "/api/notes/\(noteId)")
            } else {
                try await API.shared.send("DELETE", "/api/notes/\(noteId)/members/\(me)")
            }
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func run(_ work: @escaping () async throws -> Void) {
        Task {
            do {
                try await work()
                error = ""
                await load()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    private func load() async {
        isOffline = OfflineStore.isOffline(noteId)
        do {
            detail = try await API.shared.noteDetail(noteId)
            members = try await API.shared.members(noteId)
            items = try await API.shared.contributions(noteId)
            friends = (try? await API.shared.friends()) ?? []
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct ContributionRow: View {
    let item: Contribution

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let v = item.voice {
                VoiceRow(voice: v)
            } else if item.type == "location" {
                MapPreviewCard(
                    placeName: item.location?.placeName ?? (item.text ?? "Saved location"),
                    subLocation: item.location?.subLocation
                )
            } else if item.type == "reminder" {
                ReminderPreviewCard(
                    title: item.reminder?.title ?? (item.text ?? "Reminder"),
                    remindAt: item.reminder?.remindAt ?? ""
                )
            } else {
                RichTextView(html: item.text ?? "")
                    .padding(.bottom, 8)
                Divider()
            }
            Text("— \(item.authorName)")
                .font(.caption.bold())
                .foregroundStyle(AppTheme.accentHover)
        }
    }
}
