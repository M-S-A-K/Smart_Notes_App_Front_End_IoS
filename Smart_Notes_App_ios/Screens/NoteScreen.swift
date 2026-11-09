//
//  NoteScreen.swift
//  Smart_Notes_App_ios
//
//  Created by M_Salik_Amin_Kayani on 08/11/2026.
//

import SwiftUI

struct NoteScreen: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var api = API.shared
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

    // Independent toggles so Location AND Reminder can be edited at the same time!
    @State private var showTagsPanel = false
    @State private var showLocationPanel = false
    @State private var showReminderPanel = false

    @State private var newTag = ""
    @State private var reminderTitle = ""
    @State private var reminderDate = Date().addingTimeInterval(3600)
    @State private var reminderLead = "30 min before"
    @State private var placeName = ""
    @State private var subLocation = ""
    @State private var placeLat: Double? = nil
    @State private var placeLng: Double? = nil

    @State private var saveTask: Task<Void, Never>?
    @State private var showDelete = false
    @State private var showShare = false
    @State private var showLock = false
    @State private var showTitleRequiredAlert = false
    @State private var lockPassword = ""
    @State private var showGroupSwitch = true
    @State private var switchedGroupNoteId: Int?
    @State private var isOfflineSaved = false
    @State private var toastMessage = ""

    private let knownPlaces = ["BIIT", "Commercial Market", "Shifa Hospital", "Centaurus Mall", "Saddar", "Faisal Mosque", "Murree"]
    private let leadChoices = ["At start time", "10 min before", "30 min before", "1 hour before"]

    init(noteId: Int? = nil, record: Bool = false) {
        _noteId = State(initialValue: noteId)
        _editing = State(initialValue: noteId == nil)
        autoRecord = record
    }

    private var voices: [VoiceNote] { detail?.voiceNotes ?? [] }
    private var hasAnyBodyContent: Bool {
        !content.plainText.isEmpty ||
        !voices.isEmpty ||
        !(detail?.locations.isEmpty ?? true) ||
        !(detail?.reminders.isEmpty ?? true) ||
        !placeName.trimmingCharacters(in: .whitespaces).isEmpty ||
        !reminderTitle.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var locationText: String {
        if !placeName.isEmpty {
            return [placeName, subLocation].filter { !$0.isEmpty }.joined(separator: " — ")
        }
        guard let p = detail?.locations.first else { return "Add location" }
        return [p.placeName, p.subLocation ?? ""].filter { !$0.isEmpty }.joined(separator: " — ")
    }

    private var reminderText: String {
        if let r = detail?.reminders.first { return r.remindAt.niceTime }
        return showReminderPanel ? reminderDate.formatted(date: .abbreviated, time: .shortened) : "Add reminder"
    }

    var body: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Color.clear.frame(height: 1).id("TOP")

                    if api.isOffline {
                        OfflineBanner()
                    }

                    if isOfflineSaved || detail?.isLocked == true {
                        HStack(spacing: 6) {
                            if isOfflineSaved {
                                Text("Offline (.sma)")
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

                    if editing {
                        TextField("Enter note title…", text: $title)
                            .font(.largeTitle.bold())
                            .foregroundStyle(AppTheme.ink)
                    } else {
                        Text(title)
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
                            .frame(minHeight: 200)
                            .padding(6)
                            .background(AppTheme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        RichTextView(
                            html: content,
                            emptyText: voices.isEmpty ? "No text content." : ""
                        )
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
                    .buttonStyle(.plain)

                    Button { withAnimation { scrollProxy.scrollTo("BOTTOM", anchor: .bottom) } } label: {
                        Image(systemName: "chevron.down")
                            .font(.caption.bold())
                            .foregroundStyle(AppTheme.accentHover)
                            .frame(width: 34, height: 34)
                            .softCard(radius: 11)
                    }
                    .buttonStyle(.plain)
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
                    }
                } else if noteId != nil {
                    menu
                }
            }
        }
        .overlay(alignment: .bottom) {
            if !toastMessage.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                    Text(toastMessage)
                        .font(.caption.bold())
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .foregroundStyle(AppTheme.accentHover)
                .softCard(radius: 14, background: AppTheme.surface, borderColor: AppTheme.accent)
                .padding(.bottom, 24)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onChange(of: title) { _, _ in scheduleSave() }
        .onChange(of: content) { _, _ in scheduleSave() }
        .task {
            await load(initial: true)
            if autoRecord { await startRecord() }
        }
        .sheet(isPresented: $showShare) {
            if let id = noteId {
                ShareSheet(noteId: id) { showShare = false }
                    .presentationDetents([.medium, .large])
            }
        }
        .alert("Title Required", isPresented: $showTitleRequiredAlert) {
            TextField("Enter note title", text: $title)
            Button("Save Note") {
                Task { await finish() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Please enter a title for your note so it isn't saved as Untitled.")
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
        }
    }

    private func showToast(_ msg: String) {
        withAnimation { toastMessage = msg }
        Task {
            try? await Task.sleep(for: .seconds(2.6))
            withAnimation {
                if toastMessage == msg { toastMessage = "" }
            }
        }
    }

    // MARK: Menu (Read Mode — Hides Edit When Offline!)
    private var menu: some View {
        Menu {
            if !api.isOffline {
                Button { editing = true } label: { Label("Edit", systemImage: "pencil") }
                Button { showShare = true } label: { Label("Share", systemImage: "paperplane") }
            }
            Button {
                if let d = detail {
                    OfflineStore.saveSma(detail: d)
                    isOfflineSaved = true
                    showToast("Saved as note_\(d.id).sma for offline use")
                }
            } label: {
                Label(isOfflineSaved ? "Update offline (.sma)" : "Download (.sma)", systemImage: "arrow.down.doc")
            }
            if !api.isOffline {
                Button { showLock = true } label: {
                    Label(detail?.isLocked == true ? "Unlock / Remove lock" : "Lock note", systemImage: "lock")
                }
                Button(role: .destructive) { showDelete = true } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.title3)
        }
    }

    // MARK: Fixed Switch to Group Note (Creates real group note & migrates content)
    private var groupSwitchRow: some View {
        HStack(spacing: 6) {
            Button {
                Task { await convertToGroupNote() }
            } label: {
                Label("Switch to Group Note", systemImage: "bubble.left.and.bubble.right")
                    .font(.caption2.bold())
                    .foregroundStyle(AppTheme.accentHover)
            }
            .buttonStyle(.plain)

            Button { showGroupSwitch = false } label: {
                Image(systemName: "xmark")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.muted)
            }
            .buttonStyle(.plain)
            Spacer()
        }
    }

    private func convertToGroupNote() async {
        let groupTitle = title.trimmingCharacters(in: .whitespaces).isEmpty ? "New Group Note" : title.trimmingCharacters(in: .whitespaces)
        do {
            // Create a genuine group note via POST /api/notes (noteType: "group")
            let newGroupId = try await API.shared.createGroup(title: groupTitle)

            // Copy any written text, location, or reminder into the new group note
            if !content.plainText.isEmpty {
                try? await API.shared.send("POST", "/api/notes/\(newGroupId)/contributions",
                                           body: ["type": "text", "text": content])
            }
            let locName = !placeName.isEmpty ? placeName : (detail?.locations.first?.placeName ?? "")
            let subLoc = !subLocation.isEmpty ? subLocation : (detail?.locations.first?.subLocation ?? "")
            if !locName.isEmpty {
                try? await API.shared.send("POST", "/api/notes/\(newGroupId)/contributions",
                                           body: ["type": "location", "text": locName, "subLocation": subLoc])
            }
            if showReminderPanel || detail?.reminders.first != nil {
                let rTitle = !reminderTitle.isEmpty ? reminderTitle : (detail?.reminders.first?.title ?? groupTitle)
                let iso = ISO8601DateFormatter().string(from: reminderDate)
                try? await API.shared.send("POST", "/api/notes/\(newGroupId)/contributions",
                                           body: ["type": "reminder", "text": rTitle, "remindAt": iso])
            }

            // Delete old personal draft if one was created
            if let oldId = noteId {
                try? await API.shared.send("DELETE", "/api/notes/\(oldId)")
                noteId = nil
            }
            switchedGroupNoteId = newGroupId
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: Tags Row
    private var tagsRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                if editing {
                    Task {
                        if await ensureSavedForAttachment() != nil {
                            showTagsPanel.toggle()
                        }
                    }
                }
            } label: {
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

            if showTagsPanel && editing {
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
                    .buttonStyle(.plain)
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

    // MARK: Location + Reminder Buttons (Can Open & Edit Both Together!)
    private var detailButtons: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                ActionPill(
                    icon: "mappin.and.ellipse",
                    text: locationText,
                    filled: detail?.locations.first != nil || showLocationPanel,
                    onClear: {
                        placeName = ""; subLocation = ""; showLocationPanel = false
                        if let p = detail?.locations.first, let id = noteId {
                            run { try await API.shared.send("DELETE", "/api/notes/\(id)/locations/\(p.id)") }
                        }
                    }
                ) {
                    if let loc = detail?.locations.first, placeName.isEmpty {
                        placeName = loc.placeName
                        subLocation = loc.subLocation ?? ""
                    }
                    showLocationPanel.toggle()
                }

                ActionPill(
                    icon: "clock",
                    text: reminderText,
                    filled: detail?.reminders.first != nil || showReminderPanel,
                    onClear: {
                        reminderTitle = ""; showReminderPanel = false
                        if let r = detail?.reminders.first, let id = noteId {
                            run { try await API.shared.send("DELETE", "/api/notes/\(id)/reminders/\(r.id)") }
                        }
                    }
                ) {
                    if let rem = detail?.reminders.first, reminderTitle.isEmpty {
                        reminderTitle = rem.title
                        reminderDate = rem.remindAt.asDate ?? Date()
                    }
                    showReminderPanel.toggle()
                }
            }
            if showLocationPanel { locationPanel }
            if showReminderPanel { reminderPanel }
        }
    }

    private var locationPanel: some View {
            InteractiveLocationPicker(
                placeName: $placeName,
                subLocation: $subLocation,
                latitude: $placeLat,
                longitude: $placeLng
            ) {
                Task { await saveLocationOnly() }
            }
        }
    
    private func saveLocationOnly() async {
            guard !placeName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
            guard let id = await ensureSavedForAttachment() else { return }
            let p = placeName.trimmingCharacters(in: .whitespaces)
            let s = subLocation.trimmingCharacters(in: .whitespaces)
            var body: [String: Any] = ["placeName": p, "subLocation": s]
            if let lat = placeLat, let lng = placeLng {
                body["latitude"] = lat
                body["longitude"] = lng
            }
            do {
                if let old = detail?.locations.first {
                    try? await API.shared.send("DELETE", "/api/notes/\(id)/locations/\(old.id)")
                }
                try await API.shared.send("POST", "/api/notes/\(id)/locations", body: body)
                showLocationPanel = false
                await load()
                showToast("📍 Location saved (\(p))")
            } catch {
                self.error = error.localizedDescription
            }
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
                Text("Rings alarm at scheduled time")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.muted)
                Spacer()
                Button("Save reminder") {
                    Task { await saveReminderOnly() }
                }
                .font(.caption.bold())
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.accent)
            }
        }
        .padding(12)
        .softCard(background: AppTheme.surfaceSoft)
    }


    private func saveReminderOnly() async {
        guard let id = await ensureSavedForAttachment() else { return }
        let name = reminderTitle.trimmingCharacters(in: .whitespaces).isEmpty
            ? (title.isEmpty ? "Reminder" : title)
            : reminderTitle.trimmingCharacters(in: .whitespaces)
        let iso = ISO8601DateFormatter().string(from: reminderDate)
        do {
            if let old = detail?.reminders.first {
                try? await API.shared.send("DELETE", "/api/notes/\(id)/reminders/\(old.id)")
            }
            try await API.shared.send("POST", "/api/notes/\(id)/reminders", body: ["title": name, "remindAt": iso])
            ReminderAlarmManager.shared.scheduleSingle(title: name, date: reminderDate)
            showReminderPanel = false
            await load()
            showToast("⏰ Reminder set for \(reminderDate.formatted(date: .omitted, time: .shortened))")
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: Read-Mode Previews
        @ViewBuilder private var previews: some View {
            let loc = detail?.locations.first
            let rem = detail?.reminders.first
            if loc != nil || rem != nil {
                HStack(alignment: .top, spacing: 8) {
                    if let loc {
                        MapPreviewCard(
                            placeName: loc.placeName,
                            subLocation: loc.subLocation,
                            latitude: loc.latitude,
                            longitude: loc.longitude
                        )
                    }
                    if let rem {
                        ReminderPreviewCard(
                            title: rem.title,
                            remindAt: rem.remindAt,
                            isDone: rem.isCompletedOrPast,
                            leadText: reminderLead
                        ) {
                            if let id = noteId {
                                run { try await API.shared.toggleReminder(noteId: id, reminderId: rem.id) }
                            }
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
    
    // MARK: Voice Recorder Bar
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
                    .buttonStyle(.plain)

                    Button(role: .destructive) { recorder.cancel() } label: {
                        Label("Delete", systemImage: "trash").font(.caption.bold())
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 6)

                    Button("Stop & save") { Task { await stopRecording() } }
                        .font(.caption.bold())
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.accent)
                }
            } else if busy {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Transcribing voice note & checking commands…")
                        .font(.caption)
                        .foregroundStyle(AppTheme.inkSoft)
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
                    .buttonStyle(.plain)

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

    

    // MARK: Data & Save Rules (No Blank Notes + Require Title)
    private func load(initial: Bool = false) async {
        allTags = (try? await API.shared.tags()) ?? allTags
        guard let id = noteId else { return }
        isOfflineSaved = OfflineStore.isOffline(id)
        do {
            let prevLocCount = detail?.locations.count ?? 0
            let prevRemCount = detail?.reminders.count ?? 0
            let d = try await API.shared.noteDetail(id)
            detail = d
            if initial || !editing {
                title = d.title
                content = d.content
            }
            if !initial {
                if d.locations.count > prevLocCount, let newLoc = d.locations.last {
                    showToast("📍 Location added (\(newLoc.placeName)) — check & verify")
                } else if d.reminders.count > prevRemCount, let newRem = d.reminders.last {
                    if let rDate = newRem.remindAt.asDate {
                        ReminderAlarmManager.shared.scheduleSingle(title: newRem.title, date: rDate)
                    }
                    showToast("⏰ Reminder added (\(newRem.title)) — check time")
                }
            }
        } catch {
            // Offline fallback from .sma file!
            if let pkg = OfflineStore.loadSma(id) {
                detail = pkg.detail
                title = pkg.detail.title
                content = pkg.detail.content
                editing = false
                self.error = ""
            } else {
                self.error = error.localizedDescription
            }
        }
    }

    private func scheduleSave() {
        guard editing else { return }
        // Never auto-save if title is empty or note has no content
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty && hasAnyBodyContent else {
            status = "Draft"
            return
        }
        status = "Saving…"
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .seconds(0.9))
            if Task.isCancelled { return }
            await save()
        }
    }

    private func save() async {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { return }
        guard hasAnyBodyContent || noteId != nil else { return }
        do {
            if let id = noteId {
                try await API.shared.updateNote(id, title: cleanTitle, content: content)
            } else {
                noteId = try await API.shared.createNote(title: cleanTitle, content: content)
                await load()
            }
            status = "Saved"
            error = ""
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func ensureSavedForAttachment() async -> Int? {
        if let id = noteId { return id }
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else {
            showTitleRequiredAlert = true
            return nil
        }
        do {
            let createdId = try await API.shared.createNote(title: cleanTitle, content: content)
            noteId = createdId
            await load()
            return createdId
        } catch {
            self.error = error.localizedDescription
            return nil
        }
    }

    private func finish() async {
        saveTask?.cancel()
        if recorder.isRecording { await stopRecording() }

        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        // Rule 1: If completely blank, just close without saving anything
        if cleanTitle.isEmpty && !hasAnyBodyContent && noteId == nil {
            dismiss()
            return
        }
        // Rule 2: If there is content/voice/location/reminder but no title, ask user for title!
        if cleanTitle.isEmpty {
            showTitleRequiredAlert = true
            return
        }

        await save()
        // If user had both Location and Reminder panels open, save both simultaneously!
        if showLocationPanel && !placeName.trimmingCharacters(in: .whitespaces).isEmpty {
            await saveLocationOnly()
        }
        if showReminderPanel {
            await saveReminderOnly()
        }

        editing = false
        showTagsPanel = false
        showLocationPanel = false
        showReminderPanel = false
        await load(initial: true)
    }

    private func startRecord() async {
        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            showTitleRequiredAlert = true
            return
        }
        guard await ensureSavedForAttachment() != nil else { return }
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
            let currentlyLocked = detail?.isLocked == true
            let path = currentlyLocked ? "unlock" : "lock"
            let enteredPass = lockPassword
            do {
                try await API.shared.send("POST", "/api/notes/\(id)/\(path)", body: ["password": enteredPass])
                self.error = ""
                await load()
                // Sync the new lock state & password into the downloaded .sma file!
                if OfflineStore.isOffline(id), let d = detail {
                    OfflineStore.saveSma(detail: d, lockPassword: currentlyLocked ? nil : enteredPass)
                }
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
