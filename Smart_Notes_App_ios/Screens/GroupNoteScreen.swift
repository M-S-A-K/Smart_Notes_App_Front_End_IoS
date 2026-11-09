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
            VStack(spacing: 12) {
                if !error.isEmpty { Text(error).foregroundStyle(AppTheme.danger) }
                if notes.isEmpty && error.isEmpty {
                    EmptyState(icon: "person.2", title: "No group notes", text: "Tap + to create one.")
                }
                ForEach(notes) { n in
                    NavigationLink { GroupNoteScreen(noteId: n.id) } label: { NoteCard(note: n) }
                        .buttonStyle(.plain)
                }
            }
            .padding(16)
        }
        .background(AppTheme.canvas)
        .navigationTitle("Group Notes")
        .toolbar { Button { showNew = true } label: { Label("New group", systemImage: "plus") } }
        .navigationDestination(item: $openId) { GroupNoteScreen(noteId: $0) }
        .alert("New group note", isPresented: $showNew) {
            TextField("Title", text: $title)
            Button("Create") { Task { await create() } }
            Button("Cancel", role: .cancel) {}
        }
        .onAppear { Task { await load() } }
    }

    private func create() async {
        do { openId = try await API.shared.createGroup(title: title.isEmpty ? "Untitled group" : title); title = "" }
        catch { self.error = error.localizedDescription }
    }

    private func load() async {
        do { notes = try await API.shared.notes(type: "group"); error = "" }
        catch { self.error = error.localizedDescription }
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
    @State private var kind = ""             // "", text, location, reminder
    @State private var text = ""
    @State private var subLocation = ""
    @State private var when = Date()
    @State private var busy = false
    @State private var error = ""
    @State private var showMembers = false
    @State private var showAdd = false
    @State private var showLeave = false
    @State private var editItem: Contribution?
    @State private var editText = ""

    private var me: Int { state.user?.userId ?? 0 }
    private var isOwner: Bool { detail?.ownerId == me }
    private var ownerName: String { members.first { $0.id == detail?.ownerId }?.fullName ?? "" }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("GROUP NOTE").font(.system(size: 10, weight: .heavy))
                    .padding(.horizontal, 9).padding(.vertical, 5)
                    .background(AppTheme.accentSoft).foregroundStyle(AppTheme.accentHover).clipShape(Capsule())
                Text("Owned by \(ownerName) · \(members.count) \(members.count == 1 ? "member" : "members")")
                    .font(.caption).foregroundStyle(AppTheme.muted)
                Text(detail?.title ?? "").font(.largeTitle.bold())
                if !error.isEmpty { Text(error).font(.footnote).foregroundStyle(AppTheme.danger) }
                if items.isEmpty && error.isEmpty {
                    Text("No content has been added yet.").font(.footnote).foregroundStyle(AppTheme.muted)
                }
                ForEach(items) { item in
                    ContributionRow(item: item).contextMenu { actions(for: item) }
                }
                addSection
            }
            .padding(16)
        }
        .background(AppTheme.canvas)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { optionsMenu } }
        .task { await load() }
        .sheet(isPresented: $showMembers) { membersSheet }
        .sheet(isPresented: $showAdd) { addMemberSheet }
        .alert(isOwner ? "Delete this group note?" : "Leave this group?", isPresented: $showLeave) {
            Button(isOwner ? "Delete" : "Leave", role: .destructive) { Task { await leave() } }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Edit entry", isPresented: Binding(get: { editItem != nil }, set: { if !$0 { editItem = nil } })) {
            TextField("Text", text: $editText)
            Button("Save") {
                if let i = editItem {
                    run { try await API.shared.send("PUT", "/api/notes/\(noteId)/contributions/\(i.id)", body: ["text": editText]) }
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: Menus
    private var optionsMenu: some View {
        Menu {
            if isOwner { Button { showAdd = true } label: { Label("Add member", systemImage: "person.badge.plus") } }
            Button { showMembers = true } label: { Label("Members", systemImage: "person.2") }
            Button(role: .destructive) { showLeave = true } label: {
                Label(isOwner ? "Delete" : "Leave group",
                      systemImage: isOwner ? "trash" : "rectangle.portrait.and.arrow.right")
            }
        } label: { Image(systemName: "ellipsis") }
    }

    @ViewBuilder private func actions(for item: Contribution) -> some View {
        if item.type == "text" && item.userId == me {
            Button("Edit") { editText = item.text ?? ""; editItem = item }
        }
        if item.userId == me || isOwner {
            Button("Delete", role: .destructive) {
                run { try await API.shared.send("DELETE", "/api/notes/\(noteId)/contributions/\(item.id)") }
            }
        }
    }

    // MARK: Add to note
    private var addSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ADD TO NOTE").font(.system(size: 10, weight: .heavy)).foregroundStyle(AppTheme.accentHover)
            HStack(spacing: 8) {
                ActionPill(icon: "note.text", text: "Text", filled: kind == "text") { kind = kind == "text" ? "" : "text" }
                ActionPill(icon: "mappin", text: "Location", filled: kind == "location") { kind = kind == "location" ? "" : "location" }
                ActionPill(icon: "clock", text: "Reminder", filled: kind == "reminder") { kind = kind == "reminder" ? "" : "reminder" }
                ActionPill(icon: recorder.isRecording ? "stop.circle" : "mic",
                           text: recorder.isRecording ? String(format: "%d:%02d", recorder.seconds / 60, recorder.seconds % 60) : "Voice",
                           filled: recorder.isRecording) { Task { await toggleRecording() } }
            }
            if busy { HStack { ProgressView(); Text("Transcribing…").font(.caption) } }
            if !kind.isEmpty {
                VStack(spacing: 8) {
                    TextField(kind == "location" ? "Place" : kind == "reminder" ? "Reminder name" : "Write something…",
                              text: $text).textFieldStyle(.roundedBorder)
                    if kind == "location" { TextField("Room (optional)", text: $subLocation).textFieldStyle(.roundedBorder) }
                    if kind == "reminder" { DatePicker("When", selection: $when) }
                    Button("Add") { add() }.fontWeight(.bold)
                }
                .padding(12).softCard()
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
            } catch { self.error = error.localizedDescription }
            busy = false
            await load()
        } else if await recorder.start() == false {
            error = "Allow microphone access in Settings."
        }
    }

    // MARK: Sheets
    private var membersSheet: some View {
        NavigationStack {
            List(members) { m in
                HStack(spacing: 12) {
                    Avatar(name: m.fullName, size: 36)
                    VStack(alignment: .leading) {
                        Text(m.fullName).bold()
                        Text(m.id == detail?.ownerId ? "Owner" : "Member").font(.caption).foregroundStyle(AppTheme.inkSoft)
                    }
                    Spacer()
                    if isOwner && m.id != detail?.ownerId {
                        Button("Remove", role: .destructive) {
                            run { try await API.shared.send("DELETE", "/api/notes/\(noteId)/members/\(m.id)") }
                        }
                        .font(.caption).buttonStyle(.borderless)
                    }
                }
            }
            .navigationTitle("Members")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
    }

    private var addMemberSheet: some View {
        let available = friends.filter { f in !members.contains { $0.id == f.id } }
        return NavigationStack {
            List {
                if available.isEmpty { Text("All friends are already members.").foregroundStyle(AppTheme.muted) }
                ForEach(available) { f in
                    Button {
                        showAdd = false
                        run { try await API.shared.send("POST", "/api/notes/\(noteId)/members", body: ["userId": f.id]) }
                    } label: {
                        HStack(spacing: 12) { Avatar(name: f.fullName, size: 36); Text(f.fullName); Spacer(); Image(systemName: "plus") }
                    }
                    .foregroundStyle(AppTheme.ink)
                }
            }
            .navigationTitle("Choose from friends")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
    }

    // MARK: Data
    private func leave() async {
        do {
            if isOwner { try await API.shared.send("DELETE", "/api/notes/\(noteId)") }
            else { try await API.shared.send("DELETE", "/api/notes/\(noteId)/members/me") }
            dismiss()
        } catch { self.error = error.localizedDescription }
    }

    private func run(_ work: @escaping () async throws -> Void) {
        Task {
            do { try await work(); error = ""; await load() }
            catch { self.error = error.localizedDescription }
        }
    }

    private func load() async {
        do {
            detail = try await API.shared.noteDetail(noteId)
            members = try await API.shared.members(noteId)
            items = try await API.shared.contributions(noteId)
            friends = (try? await API.shared.friends()) ?? []
        } catch { self.error = error.localizedDescription }
    }
}

struct ContributionRow: View {
    let item: Contribution

    private var icon: String {
        switch item.type {
        case "location": return "mappin.and.ellipse"
        case "reminder": return "clock"
        default: return "text.alignleft"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let v = item.voice {
                VoiceRow(voice: v)
            } else {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: icon).foregroundStyle(AppTheme.accentHover)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.text ?? "").font(.subheadline)
                        if let sub = item.location?.subLocation, !sub.isEmpty {
                            Text(sub).font(.caption).foregroundStyle(AppTheme.inkSoft)
                        }
                        if let r = item.reminder {
                            Text(r.remindAt.niceTime).font(.caption).foregroundStyle(AppTheme.inkSoft)
                        }
                    }
                    Spacer()
                }
                .padding(14)
                .softCard()
            }
            Text("— \(item.authorName)").font(.caption.bold()).foregroundStyle(AppTheme.accentHover)
        }
    }
}
