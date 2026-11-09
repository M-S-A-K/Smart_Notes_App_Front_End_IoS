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
    @StateObject private var richController = RichTextEditorController()

    @State private var noteId: Int?
    @State private var editing: Bool
    private let autoRecord: Bool

    @State private var title = ""
    @State private var content = ""
    @State private var detail: NoteDetail?
    @State private var allTags: [Tag] = []
    @State private var status = "Draft"
    @State private var busy = false
    @State private var error = ""
    @State private var panel = "" // "tags", "location", "reminder"
    @State private var newTag = ""
    @State private var reminderTitle = ""
    @State private var reminderDate = Date()
    @State private var reminderLead = "30 min before"
    @State private var placeName = ""
    @State private var subLocation = ""
    @State private var saveTask: Task<Void, Never>?
    @State private var showDelete = false
    @State private var showShare = false
    @State private var showLock = false
    @State private var lockPassword = ""
    @State private var showGroupSwitch = true
    @State private var switchedGroupNoteId: Int?
    @State private var isOffline = false
    @State private var showOfflineToast = false

    private let knownPlaces = ["BIIT", "Central Library", "Innovation Hub", "City Campus", "Design Studio"]
    private let leadChoices = ["At start time", "10 min before", "30 min before", "1 hour before"]

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
        ScrollViewReader { scrollProxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Color.clear.frame(height: 1).id("TOP")

                    // Offline & Locked status pills
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

                    // Title
                    if editing {
                        TextField("Untitled note", text: $title)
                            .font(.largeTitle.bold())
                            .foregroundStyle(AppTheme.ink)
                    } else {
                        Text(title.isEmpty ? "Untitled note" : title)
                            .font(.largeTitle.bold())
                            .foregroundStyle(AppTheme.ink)
                    }

                    tagsRow
                    Divider()

                    if editing {
                        detailButtons
                        if showGroupSwitch {
                            groupSwitchRow
                        }
                        FormatBar(controller: richController)
                        RichTextEditor(html: $content, controller: richController)
                            .frame(minHeight: 210)
                            .padding(6)
                            .background(AppTheme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        RichTextView(html: content, emptyText: voices.isEmpty ? "No content yet." : "")
                            .padding(.vertical, 6)
                    }

                    ForEach(voices) { v in
                        VoiceRow(voice: v, showDelete: editing) { deleteVoice(v) }
                    }

                    if editing {
                        recorderBar
                    } else {
                        previews
                    }

                    if !error.isEmpty {
                        Text(error).font(.footnote).foregroundStyle(AppTheme.danger)
                    }

                    Color.clear.frame(height: 1).id("BOTTOM")
                }
                .padding(16)
            }
            .overlay(alignment: .bottomTrailing) {
                VStack(spacing: 6) {
                    Button { withAnimation { scrollProxy.scrollTo("TOP", anchor: .top) } } label: {
                        Image(systemName: "chevron.up")
                            .font(.caption.bold())
                            .foregroundStyle(AppTheme.accentHover)
                            .frame(width: 34, height: 34)
                            .softCard(radius: 11)
                    }
                    Button { withAnimation { scrollProxy.scrollTo("BOTTOM", anchor: .bottom) } } label: {
                        Image(systemName: "chevron.down")
                            .font(.caption.bold())
                            .foregroundStyle(AppTheme.accentHover)
                            .frame(width: 34, height: 34)
                            .softCard(radius: 11)
                    }
                }
                .padding(.trailing, 14)
                .padding(.bottom, 18)
            }
        }
        .background(AppTheme.surface)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $switchedGroupNoteId) { GroupNoteScreen(noteId: $0) }
        .toolbar {
            ToolbarItem(placement: .principal) {
                if editing {
                    Text(status)
                        .font(.caption.bold())
                        .foregroundStyle(status == "Saved" ? AppTheme.accentHover : AppTheme.muted)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                if editing {
                    Button { Task { await finish() } } label: {
                        Image(systemName: "checkmark")
                            .font(.subheadline.bold())
                            .foregroundStyle(AppTheme.accentHover)
                    }
                } else if noteId != nil {
                    menu
                }
            }
        }
        .overlay(alignment: .bottom) {
            if showOfflineToast {
                Label("Available offline", systemImage: "checkmark")
                    .font(.caption.bold())
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .foregroundStyle(AppTheme.accentHover)
                    .softCard(radius: 14)
                    .padding(.bottom, 24)
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
            if let id = noteId {
                ShareSheet(noteId: id) { showShare = false }
                    .presentationDetents([.medium, .large])
            }
        }
        .alert("Delete this note?", isPresented: $showDelete) {
            Button("Delete", role: .destructive) { Task { await deleteNote() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Its linked reminders will also be removed.")
        }
        .alert(detail?.isLocked == true ? "Remove note lock" : "Lock this note", isPresented: $showLock) {
            SecureField("Password (4+ characters)", text: $lockPassword)
            Button(detail?.isLocked == true ? "Remove lock" : "Set password") { Task { await toggleLock() } }
            Button("Cancel", role: .cancel) { lockPassword = "" }
        } message: {
            Text(detail?.isLocked == true
                 ? "Enter the current note password to remove protection."
                 : "Set a password that will be required whenever this note opens.")
        }
    }

    // MARK: Menu (Read Mode)
    private var menu: some View {
        Menu {
            Button { editing = true } label: { Label("Edit", systemImage: "pencil") }
            Button { showShare = true } label: { Label("Share", systemImage: "paperplane") }
            Button {
                if let id = noteId {
                    OfflineStore.markOffline(id)
                    isOffline = true
                    withAnimation { showOfflineToast = true }
                    Task {
                        try? await Task.sleep(for: .seconds(1.6))
                        withAnimation { showOfflineToast = false }
                    }
                }
            } label: {
                Label(isOffline ? "Available offline" : "Download", systemImage: "checkmark.circle")
            }
            Button { showLock = true } label: {
                Label(detail?.isLocked == true ? "Unlock / Remove lock" : "Lock note", systemImage: "lock")
            }
            Button(role: .destructive) { showDelete = true } label: { Label("Delete", systemImage: "trash") }
        } label: {
            Image(systemName: "ellipsis")
                .foregroundStyle(AppTheme.ink)
                .frame(width: 36, height: 36)
                .background(AppTheme.surface)
                .overlay(RoundedRectangle(cornerRadius: 11).stroke(AppTheme.border))
                .clipShape(RoundedRectangle(cornerRadius: 11))
        }
    }

    // MARK: Switch to Group Note Row
    private var groupSwitchRow: some View {
        HStack(spacing: 6) {
            Button {
                Task { await convertToGroupNote() }
            } label: {
                Label("Switch to Group Note", systemImage: "bubble.left.and.bubble.right")
                    .font(.caption2.bold())
                    .foregroundStyle(AppTheme.accentHover)
            }
            Button { showGroupSwitch = false } label: {
                Image(systemName: "xmark")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.muted)
            }
            Spacer()
        }
    }

    private func convertToGroupNote() async {
        guard let id = await ensureSaved() else { return }
        let t = title.trimmingCharacters(in: .whitespaces).isEmpty ? "Untitled group note" : title
        do {
            try await API.shared.updateNote(id, title: t, content: "", noteType: "group")
            if !content.plainText.isEmpty {
                try? await API.shared.send("POST", "/api/notes/\(id)/contributions",
                                           body: ["type": "text", "text": content])
            }
            switchedGroupNoteId = id
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: Tags Row & Inline Picker
    private var tagsRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button { if editing { Task { await open("tags") } } } label: {
                HStack(spacing: 8) {
                    Image(systemName: "tag").font(.caption).foregroundStyle(AppTheme.inkSoft)
                    if let tags = detail?.tags, !tags.isEmpty {
                        ForEach(tags) { t in
                            Text(t.name)
                                .font(.caption2.bold())
                                .padding(.horizontal, 9)
                                .padding(.vertical, 4)
                                .background(AppTheme.accentSoft)
                                .foregroundStyle(AppTheme.accentHover)
                                .clipShape(Capsule())
                        }
                    } else {
                        Text(editing ? "Add tag" : "No tags")
                            .font(.caption)
                            .foregroundStyle(AppTheme.inkSoft)
                    }
                    if editing {
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(AppTheme.muted)
                    }
                    Spacer()
                    Text(editing ? "Edited just now" : "Updated \(detail?.updatedAt.timeAgo ?? "recently")")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.muted)
                }
            }
            .buttonStyle(.plain)

            if panel == "tags" && editing {
                tagsPanel
            }
        }
    }

    private var tagsPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(allTags) { tag in
                        let on = detail?.tags.contains { $0.id == tag.id } ?? false
                        Button { toggleTag(tag, on: on) } label: {
                            HStack(spacing: 5) {
                                Circle()
                                    .fill(on ? AppTheme.accent : AppTheme.borderStrong)
                                    .frame(width: 7, height: 7)
                                Text(tag.name).font(.caption.bold())
                                if on {
                                    Image(systemName: "checkmark").font(.system(size: 10, weight: .bold))
                                }
                            }
                            .padding(.horizontal, 11)
                            .padding(.vertical, 7)
                            .background(on ? AppTheme.accentSoft : AppTheme.surface)
                            .overlay(Capsule().stroke(on ? AppTheme.accent : AppTheme.border))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            HStack {
                TextField("Create new tag", text: $newTag)
                    .textFieldStyle(.roundedBorder)
                Button("Add") { addTag() }
                    .font(.caption.bold())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(AppTheme.surface)
                    .overlay(RoundedRectangle(cornerRadius: 9).stroke(AppTheme.border))
                    .clipShape(RoundedRectangle(cornerRadius: 9))
            }
        }
        .padding(12)
        .softCard(background: AppTheme.surfaceSoft)
    }

    private func toggleTag(_ tag: Tag, on: Bool) {
        guard let id = noteId else { return }
        run {
            if on {
                try await API.shared.send("DELETE", "/api/notes/\(id)/tags/\(tag.id)")
            } else {
                try await API.shared.send("POST", "/api/notes/\(id)/tags", body: ["name": tag.name])
            }
        }
    }

    private func addTag() {
        guard let id = noteId, !newTag.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let name = newTag.trimmingCharacters(in: .whitespaces)
        newTag = ""
        run { try await API.shared.send("POST", "/api/notes/\(id)/tags", body: ["name": name]) }
    }

    // MARK: Location + Reminder Buttons & Inline Forms
    private var detailButtons: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                ActionPill(
                    icon: "mappin.and.ellipse",
                    text: locationText,
                    filled: detail?.locations.first != nil,
                    onClear: {
                        if let p = detail?.locations.first, let id = noteId {
                            run { try await API.shared.send("DELETE", "/api/notes/\(id)/locations/\(p.id)") }
                        }
                    }
                ) {
                    Task { await open("location") }
                }

                ActionPill(
                    icon: "clock",
                    text: reminderText,
                    filled: detail?.reminders.first != nil,
                    onClear: {
                        if let r = detail?.reminders.first, let id = noteId {
                            run { try await API.shared.send("DELETE", "/api/notes/\(id)/reminders/\(r.id)") }
                        }
                    }
                ) {
                    Task { await open("reminder") }
                }
            }
            if panel == "location" { locationPanel }
            if panel == "reminder" { reminderPanel }
        }
    }

    private var locationPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Location").font(.caption2.bold()).foregroundStyle(AppTheme.inkSoft)
                    TextField("University, building, or place", text: $placeName)
                        .textFieldStyle(.roundedBorder)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Room / Sub-location").font(.caption2.bold()).foregroundStyle(AppTheme.inkSoft)
                    TextField("LT5 or Room 204", text: $subLocation)
                        .textFieldStyle(.roundedBorder)
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(knownPlaces, id: \.self) { place in
                        Button {
                            placeName = place
                        } label: {
                            Label(place, systemImage: "mappin")
                                .font(.caption2.bold())
                                .padding(.horizontal, 9)
                                .padding(.vertical, 5)
                                .background(AppTheme.surface)
                                .overlay(Capsule().stroke(AppTheme.border))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            HStack {
                Spacer()
                Button("Save location") {
                    guard let id = noteId, !placeName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    let (p, s) = (placeName.trimmingCharacters(in: .whitespaces), subLocation.trimmingCharacters(in: .whitespaces))
                    placeName = ""; subLocation = ""; panel = ""
                    run {
                        if let old = detail?.locations.first {
                            try? await API.shared.send("DELETE", "/api/notes/\(id)/locations/\(old.id)")
                        }
                        try await API.shared.send("POST", "/api/notes/\(id)/locations",
                                                  body: ["placeName": p, "subLocation": s])
                    }
                }
                .font(.caption.bold())
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.accent)
            }
        }
        .padding(12)
        .softCard(background: AppTheme.surfaceSoft)
    }

    private var reminderPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Reminder name").font(.caption2.bold()).foregroundStyle(AppTheme.inkSoft)
                TextField(title.isEmpty ? "Reminder name" : title, text: $reminderTitle)
                    .textFieldStyle(.roundedBorder)
            }
            DatePicker("Date & Time", selection: $reminderDate)
                .font(.caption.bold())
            HStack {
                Text("Notify").font(.caption.bold()).foregroundStyle(AppTheme.inkSoft)
                Spacer()
                Picker("Notify", selection: $reminderLead) {
                    ForEach(leadChoices, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.menu)
            }
            HStack {
                Spacer()
                Button("Save reminder") {
                    guard let id = noteId else { return }
                    let name = reminderTitle.trimmingCharacters(in: .whitespaces).isEmpty
                        ? (title.isEmpty ? "Reminder" : title)
                        : reminderTitle.trimmingCharacters(in: .whitespaces)
                    let iso = ISO8601DateFormatter().string(from: reminderDate)
                    reminderTitle = ""; panel = ""
                    run {
                        if let old = detail?.reminders.first {
                            try? await API.shared.send("DELETE", "/api/notes/\(id)/reminders/\(old.id)")
                        }
                        try await API.shared.send("POST", "/api/notes/\(id)/reminders",
                                                  body: ["title": name, "remindAt": iso])
                    }
                }
                .font(.caption.bold())
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.accent)
            }
        }
        .padding(12)
        .softCard(background: AppTheme.surfaceSoft)
    }

    // MARK: Voice Recorder Bar (Edit Mode)
    private var recorderBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            if recorder.isRecording {
                HStack(spacing: 10) {
                    Circle().fill(AppTheme.danger).frame(width: 12, height: 12)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(recorder.isPaused ? "Recording paused" : "Recording voice note")
                            .font(.caption)
                            .foregroundStyle(AppTheme.inkSoft)
                        Text(String(format: "%d:%02d", recorder.seconds / 60, recorder.seconds % 60))
                            .font(.headline.monospacedDigit())
                    }
                    Spacer()
                    Button(recorder.isPaused ? "Resume" : "Pause") {
                        recorder.togglePause()
                    }
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(AppTheme.surface)
                    .overlay(RoundedRectangle(cornerRadius: 9).stroke(AppTheme.border))
                    .clipShape(RoundedRectangle(cornerRadius: 9))

                    Button(role: .destructive) { recorder.cancel() } label: {
                        Label("Delete", systemImage: "trash").font(.caption.bold())
                    }
                    .padding(.horizontal, 8)

                    Button("Stop & save") { Task { await stopRecording() } }
                        .font(.caption.bold())
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.accent)
                }
            } else if busy {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Transcribing voice note…").font(.caption).foregroundStyle(AppTheme.inkSoft)
                    Spacer()
                }
            } else {
                HStack(spacing: 12) {
                    Button { Task { await startRecord() } } label: {
                        Image(systemName: "mic")
                            .foregroundStyle(AppTheme.accentHover)
                            .frame(width: 42, height: 42)
                            .background(AppTheme.surface)
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(voices.isEmpty ? "Add a voice note" : "Add another voice note")
                            .font(.caption)
                            .foregroundStyle(AppTheme.inkSoft)
                        Text("Tap the mic to start")
                            .font(.subheadline.bold())
                            .foregroundStyle(AppTheme.ink)
                    }
                    Spacer()
                }
            }
        }
        .padding(14)
        .background(AppTheme.surfaceSoft)
        .overlay(RoundedRectangle(cornerRadius: 17).stroke(AppTheme.border))
        .clipShape(RoundedRectangle(cornerRadius: 17))
    }

    // MARK: Read-Mode Previews (Side-by-Side Map & Reminder Cards)
    @ViewBuilder private var previews: some View {
        let loc = detail?.locations.first
        let rem = detail?.reminders.first
        if loc != nil || rem != nil {
            HStack(alignment: .top, spacing: 8) {
                if let loc {
                    MapPreviewCard(placeName: loc.placeName, subLocation: loc.subLocation)
                }
                if let rem {
                    ReminderPreviewCard(title: rem.title, remindAt: rem.remindAt, leadText: reminderLead)
                }
            }
            .padding(.top, 4)
        }
    }

    // MARK: API Actions
    private func load(initial: Bool = false) async {
        allTags = (try? await API.shared.tags()) ?? allTags
        guard let id = noteId else { return }
        isOffline = OfflineStore.isOffline(id)
        do {
            let d = try await API.shared.noteDetail(id)
            detail = d
            if initial || !editing {
                title = d.title
                content = d.content
            }
        } catch {
            self.error = error.localizedDescription
        }
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
            } else if force || !title.isEmpty || !content.plainText.isEmpty {
                noteId = try await API.shared.createNote(title: t, content: content)
                await load()
            }
            status = "Saved"
            error = ""
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func ensureSaved() async -> Int? {
        if noteId == nil { await save(force: true) }
        return noteId
    }

    private func open(_ name: String) async {
        guard await ensureSaved() != nil else { return }
        if name == "location", let loc = detail?.locations.first {
            placeName = loc.placeName
            subLocation = loc.subLocation ?? ""
        }
        if name == "reminder", let rem = detail?.reminders.first {
            reminderTitle = rem.title
            reminderDate = rem.remindAt.asDate ?? Date()
        }
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
            if let id {
                try? await API.shared.updateNote(id, title: t, content: c)
            } else if !title.isEmpty || !c.plainText.isEmpty {
                _ = try? await API.shared.createNote(title: t, content: c)
            }
        }
    }

    private func startRecord() async {
        guard await ensureSaved() != nil else { return }
        if await recorder.start() == false {
            error = "Allow microphone access in Settings."
        }
    }

    private func stopRecording() async {
        guard let id = noteId else { return }
        let (url, seconds) = recorder.stop()
        busy = true
        do {
            try await API.shared.uploadVoice(
                noteId: id,
                fileURL: url,
                seconds: seconds,
                name: "Voice note \(voices.count + 1)"
            )
            error = ""
        } catch {
            self.error = error.localizedDescription
        }
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
        } catch {
            self.error = error.localizedDescription
        }
        lockPassword = ""
    }

    private func deleteNote() async {
        guard let id = noteId else { return }
        do {
            try await API.shared.send("DELETE", "/api/notes/\(id)")
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
}
