//
//  NoteScreen.swift
//  Smart_Notes_App_ios
//
//  Created by M_Salik_Amin_Kayani on 08/11/2026.
//
import SwiftUI

struct NoteScreen: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var recorder = Recorder()

    @State private var noteId: Int?
    @State private var editing: Bool
    private let autoRecord: Bool

    @State private var title = ""
    @State private var content = ""
    @State private var detail: NoteDetail?
    @State private var allTags: [Tag] = []
    @State private var status = ""
    @State private var busy = false
    @State private var error = ""
    @State private var panel = ""            // "tags", "location", "reminder"
    @State private var newTag = ""
    @State private var reminderTitle = ""
    @State private var reminderDate = Date()
    @State private var placeName = ""
    @State private var subLocation = ""
    @State private var saveTask: Task<Void, Never>?
    @State private var showDelete = false
    @State private var showShare = false
    @State private var showLock = false
    @State private var lockPassword = ""

    // New note (noteId nil) opens in edit mode. Existing note opens in read mode.
    init(noteId: Int? = nil, record: Bool = false) {
        _noteId = State(initialValue: noteId)
        _editing = State(initialValue: noteId == nil)
        autoRecord = record
    }

    private var voices: [VoiceNote] { detail?.voiceNotes ?? [] }
    private var locationText: String {
        guard let p = detail?.locations.first else { return "Add location" }
        return [p.placeName, p.subLocation ?? ""].filter { !$0.isEmpty }.joined(separator: " — ")
    }
    private var reminderText: String { detail?.reminders.first?.remindAt.niceTime ?? "Add reminder" }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if editing {
                    TextField("Untitled note", text: $title).font(.largeTitle.bold())
                } else {
                    Text(title.isEmpty ? "Untitled note" : title).font(.largeTitle.bold())
                }
                tagsRow
                if editing { detailButtons }
                if editing { contentEditor } else { contentView }
                ForEach(voices) { v in
                    VoiceRow(voice: v, showDelete: editing) { deleteVoice(v) }
                }
                if editing { recorderBar } else { previews }
                if !error.isEmpty { Text(error).font(.footnote).foregroundStyle(AppTheme.danger) }
            }
            .padding(16)
        }
        .background(AppTheme.canvas)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                if editing { Text(status).font(.caption).foregroundStyle(AppTheme.muted) }
            }
            ToolbarItem(placement: .topBarTrailing) {
                if editing {
                    Button { Task { await finish() } } label: { Image(systemName: "checkmark") }
                } else if noteId != nil {
                    menu
                }
            }
        }
        .onChange(of: title) { _, _ in scheduleSave() }
        .onChange(of: content) { _, _ in scheduleSave() }
        .task {
            await load(initial: true)
            if autoRecord { await startRecord() }
        }
        .onDisappear { saveOnLeave() }
        .sheet(isPresented: $showShare) {
            if let id = noteId { NavigationStack { ShareSheet(noteId: id) { showShare = false } } }
        }
        .alert("Delete this note?", isPresented: $showDelete) {
            Button("Delete", role: .destructive) { Task { await deleteNote() } }
            Button("Cancel", role: .cancel) {}
        } message: { Text("Its linked reminders will also be removed.") }
        .alert(detail?.isLocked == true ? "Remove lock" : "Lock this note", isPresented: $showLock) {
            SecureField("Password (4+ characters)", text: $lockPassword)
            Button(detail?.isLocked == true ? "Remove lock" : "Set password") { Task { await toggleLock() } }
            Button("Cancel", role: .cancel) { lockPassword = "" }
        }
    }

    // MARK: Menu (read mode)
    private var menu: some View {
        Menu {
            Button { editing = true } label: { Label("Edit", systemImage: "pencil") }
            Button { showShare = true } label: { Label("Share", systemImage: "paperplane") }
            Button { showLock = true } label: {
                Label(detail?.isLocked == true ? "Remove lock" : "Lock note", systemImage: "lock")
            }
            Button(role: .destructive) { showDelete = true } label: { Label("Delete", systemImage: "trash") }
        } label: { Image(systemName: "ellipsis") }
    }

    // MARK: Tags
    private var tagsRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button { if editing { Task { await open("tags") } } } label: {
                HStack(spacing: 8) {
                    Image(systemName: "tag").foregroundStyle(AppTheme.inkSoft)
                    if let tags = detail?.tags, !tags.isEmpty {
                        ForEach(tags) { t in
                            Text(t.name).font(.caption.bold())
                                .padding(.horizontal, 9).padding(.vertical, 4)
                                .background(AppTheme.accentSoft).foregroundStyle(AppTheme.accentHover)
                                .clipShape(Capsule())
                        }
                    } else {
                        Text(editing ? "Add tag" : "No tags").font(.caption).foregroundStyle(AppTheme.inkSoft)
                    }
                    Spacer()
                    if !editing, let d = detail {
                        Text("Updated \(d.updatedAt.timeAgo)").font(.caption2).foregroundStyle(AppTheme.muted)
                    }
                }
            }
            .buttonStyle(.plain)
            if panel == "tags" && editing { tagsPanel }
        }
    }

    private var tagsPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(allTags) { tag in
                        let on = detail?.tags.contains { $0.id == tag.id } ?? false
                        Button { toggleTag(tag, on: on) } label: {
                            Text(tag.name).font(.caption.bold())
                                .padding(.horizontal, 12).padding(.vertical, 7)
                                .background(on ? AppTheme.accentSoft : AppTheme.surface)
                                .overlay(Capsule().stroke(on ? AppTheme.accent : AppTheme.border))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            HStack {
                TextField("Create new tag", text: $newTag).textFieldStyle(.roundedBorder)
                Button("Add") { addTag() }
            }
        }
        .padding(12).softCard()
    }

    private func toggleTag(_ tag: Tag, on: Bool) {
        guard let id = noteId else { return }
        run {
            if on { try await API.shared.send("DELETE", "/api/notes/\(id)/tags/\(tag.id)") }
            else { try await API.shared.send("POST", "/api/notes/\(id)/tags", body: ["name": tag.name]) }
        }
    }

    private func addTag() {
        guard let id = noteId, !newTag.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let name = newTag
        newTag = ""
        run { try await API.shared.send("POST", "/api/notes/\(id)/tags", body: ["name": name]) }
    }

    // MARK: Location + reminder (edit mode)
    private var detailButtons: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                ActionPill(icon: "mappin", text: locationText, filled: detail?.locations.first != nil) {
                    Task { await open("location") }
                }
                ActionPill(icon: "clock", text: reminderText, filled: detail?.reminders.first != nil) {
                    Task { await open("reminder") }
                }
            }
            if panel == "location" { locationPanel }
            if panel == "reminder" { reminderPanel }
        }
    }

    private var locationPanel: some View {
        VStack(spacing: 10) {
            if let p = detail?.locations.first, let id = noteId {
                HStack {
                    Text(locationText).bold()
                    Spacer()
                    Button("Remove", role: .destructive) {
                        run { try await API.shared.send("DELETE", "/api/notes/\(id)/locations/\(p.id)") }
                    }
                }
            } else {
                TextField("University, building, or place", text: $placeName).textFieldStyle(.roundedBorder)
                TextField("Room / Sub-location (LT5)", text: $subLocation).textFieldStyle(.roundedBorder)
                Button("Save location") {
                    guard let id = noteId, !placeName.isEmpty else { return }
                    let (p, s) = (placeName, subLocation)
                    placeName = ""; subLocation = ""; panel = ""
                    run { try await API.shared.send("POST", "/api/notes/\(id)/locations",
                                                    body: ["placeName": p, "subLocation": s]) }
                }
                .fontWeight(.bold)
            }
        }
        .padding(12).softCard()
    }

    private var reminderPanel: some View {
        VStack(spacing: 10) {
            if let r = detail?.reminders.first, let id = noteId {
                HStack {
                    VStack(alignment: .leading) {
                        Text(r.title).bold()
                        Text(r.remindAt.niceTime).font(.caption).foregroundStyle(AppTheme.inkSoft)
                    }
                    Spacer()
                    Button("Remove", role: .destructive) {
                        run { try await API.shared.send("DELETE", "/api/notes/\(id)/reminders/\(r.id)") }
                    }
                }
            } else {
                TextField("Reminder name", text: $reminderTitle).textFieldStyle(.roundedBorder)
                DatePicker("When", selection: $reminderDate)
                Button("Save reminder") {
                    guard let id = noteId else { return }
                    let name = reminderTitle.isEmpty ? (title.isEmpty ? "Reminder" : title) : reminderTitle
                    let iso = ISO8601DateFormatter().string(from: reminderDate)
                    reminderTitle = ""; panel = ""
                    run { try await API.shared.send("POST", "/api/notes/\(id)/reminders",
                                                    body: ["title": name, "remindAt": iso]) }
                }
                .fontWeight(.bold)
            }
        }
        .padding(12).softCard()
    }

    // MARK: Text
    private var contentEditor: some View {
        TextEditor(text: $content)
            .frame(minHeight: 200)
            .scrollContentBackground(.hidden)
            .padding(8)
            .background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var contentView: some View {
        Text(content.isEmpty && voices.isEmpty ? "No content yet." : content)
            .lineSpacing(6)
            .foregroundStyle(content.isEmpty ? AppTheme.muted : AppTheme.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Voice recorder bar (edit mode)
    private var recorderBar: some View {
        HStack(spacing: 12) {
            if recorder.isRecording {
                Circle().fill(AppTheme.danger).frame(width: 12, height: 12)
                VStack(alignment: .leading) {
                    Text("Recording voice note").font(.caption)
                    Text(String(format: "%d:%02d", recorder.seconds / 60, recorder.seconds % 60))
                        .font(.headline.monospacedDigit())
                }
                Spacer()
                Button("Delete", role: .destructive) { recorder.cancel() }.font(.caption)
                Button("Stop & save") { Task { await stopRecording() } }
                    .buttonStyle(.borderedProminent).tint(AppTheme.accent)
            } else if busy {
                ProgressView()
                Text("Transcribing…").font(.caption)
                Spacer()
            } else {
                Button { Task { await startRecord() } } label: {
                    Image(systemName: "mic").foregroundStyle(AppTheme.accentHover)
                        .frame(width: 42, height: 42).background(AppTheme.surface).clipShape(Circle())
                }
                VStack(alignment: .leading) {
                    Text(voices.isEmpty ? "Add a voice note" : "Add another voice note")
                        .font(.caption).foregroundStyle(AppTheme.inkSoft)
                    Text("Tap the mic to start").font(.subheadline.bold())
                }
                Spacer()
            }
        }
        .padding(14)
        .background(AppTheme.surfaceSoft)
        .overlay(RoundedRectangle(cornerRadius: 17).stroke(AppTheme.border))
        .clipShape(RoundedRectangle(cornerRadius: 17))
    }

    // MARK: Read-mode previews
    @ViewBuilder private var previews: some View {
        if detail?.locations.first != nil { infoCard("mappin.and.ellipse", "LOCATION", locationText, nil) }
        if let r = detail?.reminders.first { infoCard("clock", "REMINDER", r.title, r.remindAt.niceTime) }
    }

    private func infoCard(_ icon: String, _ label: String, _ title: String, _ subtitle: String?) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(AppTheme.accentHover)
                .frame(width: 38, height: 38).background(AppTheme.accentSoft)
                .clipShape(RoundedRectangle(cornerRadius: 11))
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.system(size: 9, weight: .heavy)).foregroundStyle(AppTheme.accentHover)
                Text(title).font(.subheadline.bold())
                if let subtitle { Text(subtitle).font(.caption).foregroundStyle(AppTheme.inkSoft) }
            }
            Spacer()
        }
        .padding(14)
        .softCard(background: AppTheme.accentSofter)
    }

    // MARK: Actions
    private func load(initial: Bool = false) async {
        guard let id = noteId else { return }
        do {
            let d = try await API.shared.noteDetail(id)
            detail = d
            if initial || !editing { title = d.title; content = d.content }
            allTags = (try? await API.shared.tags()) ?? allTags
        } catch { self.error = error.localizedDescription }
    }

    private func scheduleSave() {
        guard editing else { return }
        status = "Saving…"
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .seconds(0.8))
            if Task.isCancelled { return }
            await save()
        }
    }

    private func save(force: Bool = false) async {
        let t = title.trimmingCharacters(in: .whitespaces).isEmpty ? "Untitled note" : title
        do {
            if let id = noteId {
                try await API.shared.updateNote(id, title: t, content: content)
            } else if force || !title.isEmpty || !content.isEmpty {
                noteId = try await API.shared.createNote(title: t, content: content)
                await load()
            }
            status = "Saved"
            error = ""
        } catch { self.error = error.localizedDescription; status = "" }
    }

    // Tags, location, reminder and voice need a saved note first
    private func ensureSaved() async -> Int? {
        if noteId == nil { await save(force: true) }
        return noteId
    }

    private func open(_ name: String) async {
        guard await ensureSaved() != nil else { return }
        panel = (panel == name) ? "" : name
    }

    private func finish() async {
        saveTask?.cancel()
        if recorder.isRecording { await stopRecording() }
        await save()
        editing = false
        panel = ""
        await load(initial: true)
        if noteId == nil { dismiss() }
    }

    private func saveOnLeave() {
        guard editing else { return }
        let (id, t, c) = (noteId, title.isEmpty ? "Untitled note" : title, content)
        Task {
            if let id { try? await API.shared.updateNote(id, title: t, content: c) }
            else if !title.isEmpty || !c.isEmpty { _ = try? await API.shared.createNote(title: t, content: c) }
        }
    }

    private func startRecord() async {
        guard await ensureSaved() != nil else { return }
        if await recorder.start() == false { error = "Allow microphone access in Settings." }
    }

    private func stopRecording() async {
        guard let id = noteId else { return }
        let (url, seconds) = recorder.stop()
        busy = true
        do {
            try await API.shared.uploadVoice(noteId: id, fileURL: url, seconds: seconds,
                                             name: "Voice note \(voices.count + 1)")
            error = ""
        } catch { self.error = error.localizedDescription }
        busy = false
        await load()
    }

    private func deleteVoice(_ v: VoiceNote) {
        guard let id = noteId else { return }
        run { try await API.shared.send("DELETE", "/api/notes/\(id)/voice/\(v.id)") }
    }

    private func toggleLock() async {
        guard let id = noteId else { return }
        let path = detail?.isLocked == true ? "unlock" : "lock"
        do {
            try await API.shared.send("POST", "/api/notes/\(id)/\(path)", body: ["password": lockPassword])
            error = ""
            await load()
        } catch { self.error = error.localizedDescription }
        lockPassword = ""
    }

    private func deleteNote() async {
        guard let id = noteId else { return }
        do { try await API.shared.send("DELETE", "/api/notes/\(id)"); dismiss() }
        catch { self.error = error.localizedDescription }
    }

    // Runs an API call, then refreshes the note
    private func run(_ work: @escaping () async throws -> Void) {
        Task {
            do { try await work(); error = ""; await load() }
            catch { self.error = error.localizedDescription }
        }
    }
}
