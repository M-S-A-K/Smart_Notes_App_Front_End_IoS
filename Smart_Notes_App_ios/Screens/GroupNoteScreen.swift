//
//  GroupNoteScreen.swift
//  Smart_Notes_App_ios
//
//  Created by M_Salik_Amin_Kayani on 08/11/2026.
//

import SwiftUI

struct GroupNotesListScreen: View {
    @ObservedObject private var socket = RealtimeSocket.shared
    @ObservedObject private var api = API.shared
    @State private var notes: [NoteSummary] = []
    @State private var showNew = false
    @State private var title = ""
    @State private var openId: Int?
    @State private var lockedNote: NoteSummary?
    @State private var password = ""
    @State private var error = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if api.isOffline {
                    OfflineBanner()
                }

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

                if !error.isEmpty && !api.isOffline {
                    Text(error).font(.footnote).foregroundStyle(AppTheme.danger)
                }
                if notes.isEmpty {
                    EmptyState(
                        icon: "bubble.left.and.bubble.right",
                        title: api.isOffline ? "No offline group notes" : "No group notes yet",
                        text: api.isOffline
                            ? "Download group notes while online to view their .sma snapshot offline."
                            : "Create a group note or wait for a collaborator to share one with you."
                    )
                    .frame(maxWidth: .infinity)
                }
                ForEach(notes) { n in
                    Button {
                        if n.isLocked { lockedNote = n } else { openId = n.id }
                    } label: {
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
            if !api.isOffline {
                Button { showNew = true } label: {
                    Label("New group", systemImage: "plus")
                        .font(.caption.bold())
                }
            }
        }
        .navigationDestination(item: $openId) { GroupNoteScreen(noteId: $0) }
        .alert("New group note", isPresented: $showNew) {
            TextField("Group note title", text: $title)
            Button("Create") { Task { await create() } }
            Button("Cancel", role: .cancel) { title = "" }
        } message: {
            Text("Enter a title for this group note.")
        }
        .alert("Locked group note", isPresented: Binding(get: { lockedNote != nil },
                                                         set: { if !$0 { lockedNote = nil } })) {
            SecureField("Password", text: $password)
            Button("Unlock") {
                if let n = lockedNote {
                    Task { await unlock(n) }
                }
            }
            Button("Cancel", role: .cancel) { password = "" }
        }
        .onAppear {
            socket.start()
            Task { await load() }
        }
    }

    private func unlock(_ n: NoteSummary) async {
        if api.isOffline {
            if OfflineStore.verifyOfflineLock(noteId: n.id, password: password) {
                openId = n.id
                self.error = ""
            } else {
                self.error = "Incorrect password for offline group note."
            }
            password = ""
            return
        }
        do {
            try await API.shared.send("POST", "/api/notes/\(n.id)/verify-lock", body: ["password": password])
            if OfflineStore.isOffline(n.id) {
                OfflineStore.updateLockPassword(noteId: n.id, isLocked: true, newPassword: password)
            }
            openId = n.id
            self.error = ""
        } catch {
            if OfflineStore.verifyOfflineLock(noteId: n.id, password: password) {
                openId = n.id
                self.error = ""
            } else {
                self.error = error.localizedDescription
            }
        }
        password = ""
    }

    private func create() async {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else {
            self.error = "Please enter a group note title."
            return
        }
        do {
            openId = try await API.shared.createGroup(title: clean)
            title = ""
            self.error = ""
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func load() async {
        do {
            notes = try await API.shared.notes(type: "group")
            self.error = ""
        } catch {
            notes = OfflineStore.allOfflineSummaries(type: "group")
            self.error = error.localizedDescription
        }
    }
}

struct GroupNoteScreen: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var state: AppState
    @ObservedObject private var api = API.shared
    @ObservedObject private var socket = RealtimeSocket.shared
    @StateObject private var recorder = Recorder()
    let noteId: Int

    @State private var detail: NoteDetail?
    @State private var members: [Person] = []
    @State private var friends: [Person] = []
    @State private var items: [Contribution] = []
    @State private var editingMode = false

    @State private var showTextForm = false
    @State private var showLocationForm = false
    @State private var showReminderForm = false

    @State private var textEntry = ""
    @State private var placeEntry = ""
    @State private var subLocationEntry = ""
    @State private var placeLat: Double? = nil
    @State private var placeLng: Double? = nil
    @State private var reminderTitleEntry = ""
    @State private var when = Date().addingTimeInterval(3600)

    @State private var busy = false
    @State private var error = ""
    @State private var toastMessage = ""

    @State private var showMembers = false
    @State private var showAdd = false
    @State private var showLeave = false
    @State private var showLock = false
    @State private var lockPassword = ""
    @State private var isOfflineSaved = false
    @State private var editItem: Contribution?
    @State private var editText = ""
    @State private var excludeContribution: Contribution?

    private var me: Int { state.user?.userId ?? 0 }
    private var isOwner: Bool { detail?.ownerId == me }
    private var ownerName: String {
        members.first { $0.id == detail?.ownerId }?.fullName ?? (state.user?.fullName ?? "Owner")
    }

    private var myEntries: [Contribution] {
        items.filter { $0.userId == me && !$0.isDeletedPlaceholder }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if api.isOffline {
                    OfflineBanner()
                }

                memberChipsBar
                headerSection

                Text(detail?.title ?? "Group Note")
                    .font(.largeTitle.bold())
                    .foregroundStyle(AppTheme.ink)

                if !error.isEmpty {
                    Text(error).font(.footnote).foregroundStyle(AppTheme.danger)
                }

                if editingMode {
                    editingSectionView
                } else {
                    readSectionView
                }
            }
            .padding(16)
            .padding(.bottom, 64)
        }
        .background(AppTheme.surface)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if editingMode {
                    Button {
                        withAnimation { editingMode = false }
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.subheadline.bold())
                    }
                } else {
                    optionsMenu
                }
            }
        }
        .overlay(alignment: .bottomTrailing) {
            floatingEditButton
        }
        .overlay(alignment: .bottom) {
            toastBannerView
        }
        .task {
            socket.start()
            await load()
        }
        .onChange(of: socket.tick) { _, _ in
            if !editingMode {
                Task { await load() }
            }
        }
        .sheet(isPresented: $showMembers) { membersSheet }
        .sheet(isPresented: $showAdd) { addMemberSheet }
        .sheet(item: $excludeContribution) { item in excludeMemberSheet(for: item) }
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

    // MARK: - Subviews (Broken Up for Instant Swift Compilation)
    private var memberChipsBar: some View {
        HStack(spacing: 8) {
            if isOwner && !api.isOffline {
                Button {
                    Task {
                        friends = (try? await API.shared.friends()) ?? friends
                        showAdd = true
                    }
                } label: {
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
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text("GROUP NOTE")
                    .font(.system(size: 10, weight: .heavy))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(AppTheme.accentSoft)
                    .foregroundStyle(AppTheme.accentHover)
                    .clipShape(Capsule())
                if editingMode {
                    Text("EDITING YOUR ENTRIES")
                        .font(.system(size: 9, weight: .heavy))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(AppTheme.surfaceSoft)
                        .foregroundStyle(AppTheme.inkSoft)
                        .clipShape(Capsule())
                }
                if isOfflineSaved {
                    Text("Offline (.sma)")
                        .font(.system(size: 9, weight: .heavy))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(AppTheme.accentSoft)
                        .foregroundStyle(AppTheme.accentHover)
                        .clipShape(Capsule())
                }
            }
            Text("Owned by \(ownerName) · \(max(members.count, 1)) \(members.count <= 1 ? "member" : "members")")
                .font(.caption)
                .foregroundStyle(AppTheme.muted)
        }
    }

    private var editingSectionView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("YOUR CONTRIBUTIONS")
                .font(.system(size: 10, weight: .heavy))
                .foregroundStyle(AppTheme.accentHover)

            if myEntries.isEmpty {
                Text("You haven't added any entries yet. Use the buttons below to add your contribution.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .softCard(background: AppTheme.surfaceSoft)
            } else {
                ForEach(myEntries) { item in
                    editableEntryCard(for: item)
                }
            }

            addSection
        }
    }

    private func editableEntryCard(for item: Contribution) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(item.type.capitalized, systemImage: iconFor(item.type))
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.accentHover)
                Spacer()
                if item.type == "text" {
                    Button {
                        editText = item.text?.plainText ?? ""
                        editItem = item
                    } label: {
                        Image(systemName: "pencil")
                            .font(.caption.bold())
                            .foregroundStyle(AppTheme.inkSoft)
                    }
                    .buttonStyle(.plain)
                }
                Button {
                    excludeContribution = item
                } label: {
                    Image(systemName: "eye.slash")
                        .font(.caption.bold())
                        .foregroundStyle(AppTheme.inkSoft)
                }
                .buttonStyle(.plain)

                Button(role: .destructive) {
                    Task { await markContributionDeleted(item) }
                } label: {
                    Image(systemName: "trash")
                        .font(.caption.bold())
                        .foregroundStyle(AppTheme.danger)
                }
                .buttonStyle(.plain)
            }
            ContributionRow(item: item, showAuthor: false)
        }
        .padding(12)
        .softCard(background: AppTheme.surfaceSoft)
    }

    @ViewBuilder
    private var readSectionView: some View {
        if items.isEmpty && error.isEmpty {
            Text("No content has been added yet. Tap the + button or ⋯ menu to add your contribution.")
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
                .contextMenu {
                    if !api.isOffline && !item.isDeletedPlaceholder {
                        actions(for: item)
                    }
                }
        }
    }

    @ViewBuilder
    private var floatingEditButton: some View {
        if !editingMode && !api.isOffline {
            Button {
                withAnimation { editingMode = true }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.and.person.rectangle")
                    Text("Edit / Add")
                        .font(.caption.bold())
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .frame(height: 48)
                .background(AppTheme.accent)
                .clipShape(Capsule())
                .shadow(color: AppTheme.accent.opacity(0.35), radius: 8, y: 4)
            }
            .buttonStyle(.plain)
            .padding(20)
        }
    }

    @ViewBuilder
    private var toastBannerView: some View {
        if !toastMessage.isEmpty {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                Text(toastMessage).font(.caption.bold())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .foregroundStyle(AppTheme.accentHover)
            .softCard(radius: 14, background: AppTheme.surface, borderColor: AppTheme.accent)
            .padding(.bottom, 24)
        }
    }

    private func iconFor(_ type: String) -> String {
        switch type {
        case "location": return "mappin.and.ellipse"
        case "reminder": return "clock"
        case "voice": return "mic"
        default: return "doc.text"
        }
    }

    private func showToast(_ msg: String) {
        withAnimation { toastMessage = msg }
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            withAnimation {
                if toastMessage == msg { toastMessage = "" }
            }
        }
    }

    private func markContributionDeleted(_ item: Contribution) async {
        do {
            if item.type == "text" {
                try await API.shared.send("PUT", "/api/notes/\(noteId)/contributions/\(item.id)",
                                          body: ["text": "__DELETED__"])
            } else {
                try await API.shared.send("DELETE", "/api/notes/\(noteId)/contributions/\(item.id)")
                try await API.shared.send("POST", "/api/notes/\(noteId)/contributions",
                                          body: ["type": "text", "text": "__DELETED__"])
            }
            RealtimeSocket.shared.notifyChange("group:\(noteId)")
            await load()
            showToast("Entry marked as deleted")
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: ⋯ Options Menu
    private var optionsMenu: some View {
        Menu {
            if !api.isOffline {
                Button {
                    withAnimation { editingMode = true }
                } label: {
                    Label("Edit / Add my entries", systemImage: "pencil")
                }
                if isOwner {
                    Button {
                        Task {
                            friends = (try? await API.shared.friends()) ?? friends
                            showAdd = true
                        }
                    } label: {
                        Label("Add member", systemImage: "person.badge.plus")
                    }
                }
            }
            Button { showMembers = true } label: { Label("Members", systemImage: "person.2") }
            Button {
                if let d = detail {
                    OfflineStore.saveSma(detail: d, members: members, contributions: items)
                    isOfflineSaved = true
                    showToast("Saved group note (.sma) + voice audio for offline viewing")
                }
            } label: {
                Label(isOfflineSaved ? "Update offline (.sma)" : "Download (.sma)", systemImage: "arrow.down.doc")
            }
            if !api.isOffline {
                Button { showLock = true } label: {
                    Label(detail?.isLocked == true ? "Unlock / Remove lock" : "Lock note", systemImage: "lock")
                }
                Button(role: .destructive) { showLeave = true } label: {
                    Label(isOwner ? "Delete" : "Leave group",
                          systemImage: isOwner ? "trash" : "rectangle.portrait.and.arrow.right")
                }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.title3)
        }
    }

    @ViewBuilder
    private func actions(for item: Contribution) -> some View {
        if item.type == "text" && item.userId == me {
            Button("Edit") { editText = item.text?.plainText ?? ""; editItem = item }
        }
        if item.userId == me || isOwner {
            Button("Hide from member (Exclude)") {
                excludeContribution = item
            }
            Button("Delete", role: .destructive) {
                Task { await markContributionDeleted(item) }
            }
        }
    }

    // MARK: Add to Note Bar (Supports Simultaneous Text + Location + Reminder)
    private var addSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider()
            Text("ADD TO NOTE")
                .font(.system(size: 10, weight: .heavy))
                .foregroundStyle(AppTheme.accentHover)

            HStack(spacing: 8) {
                ActionPill(icon: "doc.text", text: "Text", filled: showTextForm) {
                    showTextForm.toggle()
                }
                ActionPill(icon: "mappin.and.ellipse", text: "Location", filled: showLocationForm) {
                    showLocationForm.toggle()
                }
                ActionPill(icon: "clock", text: "Reminder", filled: showReminderForm) {
                    showReminderForm.toggle()
                }
                ActionPill(
                    icon: recorder.isRecording ? "stop.circle" : "mic",
                    text: recorder.isRecording
                        ? String(format: "%d:%02d", recorder.seconds / 60, recorder.seconds % 60)
                        : "Voice",
                    filled: recorder.isRecording
                ) {
                    Task { await toggleRecording() }
                }
            }

            if busy {
                HStack { ProgressView(); Text("Transcribing…").font(.caption) }
            }

            if showTextForm {
                VStack(alignment: .leading, spacing: 8) {
                    Text("New Text Entry").font(.caption2.bold()).foregroundStyle(AppTheme.inkSoft)
                    TextField("Write your contribution…", text: $textEntry)
                        .textFieldStyle(.roundedBorder)
                }
                .padding(12)
                .softCard(background: AppTheme.surfaceSoft)
            }

            if showLocationForm {
                InteractiveLocationPicker(
                    placeName: $placeEntry,
                    subLocation: $subLocationEntry,
                    latitude: $placeLat,
                    longitude: $placeLng
                ) {
                    Task { await submitAllOpenForms() }
                }
            }

            if showReminderForm {
                VStack(alignment: .leading, spacing: 8) {
                    Text("New Reminder Entry").font(.caption2.bold()).foregroundStyle(AppTheme.inkSoft)
                    TextField("Reminder title", text: $reminderTitleEntry)
                        .textFieldStyle(.roundedBorder)
                    DatePicker("When", selection: $when)
                        .font(.caption.bold())
                }
                .padding(12)
                .softCard(background: AppTheme.surfaceSoft)
            }

            if showTextForm || showReminderForm {
                HStack {
                    Spacer()
                    Button("Save Added Items") {
                        Task { await submitAllOpenForms() }
                    }
                    .font(.caption.bold())
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.accent)
                }
            }
        }
        .padding(.top, 6)
    }

    private func submitAllOpenForms() async {
        do {
            if showTextForm && !textEntry.trimmingCharacters(in: .whitespaces).isEmpty {
                try await API.shared.send("POST", "/api/notes/\(noteId)/contributions",
                                          body: ["type": "text", "text": textEntry.trimmingCharacters(in: .whitespaces)])
                textEntry = ""; showTextForm = false
            }
            if showLocationForm && !placeEntry.trimmingCharacters(in: .whitespaces).isEmpty {
                let p = placeEntry.trimmingCharacters(in: .whitespaces)
                var locBody: [String: Any] = ["type": "location", "text": p, "subLocation": subLocationEntry]
                if let lat = placeLat, let lng = placeLng {
                    locBody["latitude"] = lat
                    locBody["longitude"] = lng
                }
                try await API.shared.send("POST", "/api/notes/\(noteId)/contributions", body: locBody)
                placeEntry = ""; subLocationEntry = ""; placeLat = nil; placeLng = nil; showLocationForm = false
                showToast("📍 Location added (\(p))")
            }
            if showReminderForm && !reminderTitleEntry.trimmingCharacters(in: .whitespaces).isEmpty {
                let r = reminderTitleEntry.trimmingCharacters(in: .whitespaces)
                let iso = ISO8601DateFormatter().string(from: when)
                try await API.shared.send("POST", "/api/notes/\(noteId)/contributions",
                                          body: ["type": "reminder", "text": r, "remindAt": iso])
                ReminderAlarmManager.shared.scheduleSingle(title: r, date: when)
                reminderTitleEntry = ""; showReminderForm = false
                showToast("⏰ Reminder added (\(r))")
            }
            RealtimeSocket.shared.notifyChange("group:\(noteId)")
            await load()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func toggleRecording() async {
        if recorder.isRecording {
            let (url, seconds) = recorder.stop()
            busy = true
            do {
                try await API.shared.uploadVoice(noteId: noteId, fileURL: url, seconds: seconds, name: "Voice note")
                self.error = ""
                RealtimeSocket.shared.notifyChange("group:\(noteId)")
                showToast("🎤 Voice contribution added")
            } catch {
                self.error = error.localizedDescription
            }
            busy = false
            await load()
        } else if await recorder.start() == false {
            self.error = "Allow microphone access in Settings."
        }
    }

    private func toggleLock() async {
        let currentlyLocked = detail?.isLocked == true
        let path = currentlyLocked ? "unlock" : "lock"
        let enteredPass = lockPassword
        do {
            try await API.shared.send("POST", "/api/notes/\(noteId)/\(path)", body: ["password": enteredPass])
            self.error = ""
            await load()
            if OfflineStore.isOffline(noteId), let d = detail {
                OfflineStore.saveSma(
                    detail: d,
                    members: members,
                    contributions: items,
                    lockPassword: currentlyLocked ? nil : enteredPass
                )
            }
        } catch {
            self.error = error.localizedDescription
        }
        lockPassword = ""
    }

    // MARK: Sheets (Members, Add Member, & Exclude Member)
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
        let available = friends.filter { f in
            !members.contains { m in
                m.id == f.id || (!f.email.isEmpty && m.email.caseInsensitiveCompare(f.email) == .orderedSame)
            }
        }
        return NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("ADD MEMBER")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(AppTheme.accentHover)
                Text("Choose from friends")
                    .font(.title3.bold())

                if friends.isEmpty {
                    Text("You haven't added any friends yet. Open the Chat tab and tap + to add a friend first.")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.muted)
                        .padding(.vertical, 16)
                } else if available.isEmpty {
                    Text("All of your friends are already members of this group note.")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.muted)
                        .padding(.vertical, 16)
                }

                ForEach(available) { f in
                    Button {
                        showAdd = false
                        run {
                            try await API.shared.send("POST", "/api/notes/\(noteId)/members", body: ["userId": f.id])
                        }
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
            .task {
                if let loaded = try? await API.shared.friends() {
                    friends = loaded
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func excludeMemberSheet(for item: Contribution) -> some View {
        let otherMembers = members.filter { $0.id != me && $0.id != detail?.ownerId }
        return NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("NOTE EXCLUSION")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(AppTheme.accentHover)
                Text("Hide this entry from a member")
                    .font(.title3.bold())
                Text("Selected members will not see this contribution when they open the group note.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.inkSoft)

                if otherMembers.isEmpty {
                    Text("Add other members to the group note first to exclude them from specific entries.")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.muted)
                        .padding(.vertical, 14)
                }

                ForEach(otherMembers) { m in
                    Button {
                        excludeContribution = nil
                        Task {
                            do {
                                try await API.shared.excludeMember(noteId: noteId, contributionId: item.id, targetUserId: m.id)
                                showToast("Hidden entry from \(m.fullName)")
                            } catch {
                                self.error = error.localizedDescription
                            }
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Avatar(name: m.fullName, size: 36)
                            Text(m.fullName).font(.subheadline.bold()).foregroundStyle(AppTheme.ink)
                            Spacer()
                            Label("Exclude", systemImage: "eye.slash")
                                .font(.caption.bold())
                                .foregroundStyle(AppTheme.danger)
                        }
                        .padding(10)
                        .softCard(background: AppTheme.surfaceSoft)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                HStack {
                    Spacer()
                    Button("Close") { excludeContribution = nil }
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
                self.error = ""
                RealtimeSocket.shared.notifyChange("group:\(noteId)")
                await load()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    private func load() async {
        isOfflineSaved = OfflineStore.isOffline(noteId)
        do {
            let d = try await API.shared.noteDetail(noteId)
            let m = try await API.shared.members(noteId)
            let c = try await API.shared.contributions(noteId)
            detail = d
            members = m
            items = c
            friends = (try? await API.shared.friends()) ?? friends
            if isOfflineSaved {
                OfflineStore.saveSma(detail: d, members: m, contributions: c)
            }
        } catch {
            if let pkg = OfflineStore.loadSma(noteId) {
                detail = pkg.detail
                members = pkg.members
                items = pkg.contributions
                editingMode = false
                self.error = ""
            } else {
                self.error = error.localizedDescription
            }
        }
    }
}

struct ContributionRow: View {
    let item: Contribution
    var showAuthor: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if item.isDeletedPlaceholder {
                HStack(spacing: 8) {
                    Image(systemName: "trash.slash")
                        .font(.caption)
                        .foregroundStyle(AppTheme.muted)
                    Text("This entry has been deleted")
                        .font(.footnote.italic())
                        .foregroundStyle(AppTheme.muted)
                    Spacer()
                }
                .padding(10)
                .background(AppTheme.surfaceSoft)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            } else if let v = item.voice {
                VoiceRow(voice: v)
            } else if item.type == "location" {
                MapPreviewCard(
                    placeName: item.location?.placeName ?? (item.text ?? "Saved location"),
                    subLocation: item.location?.subLocation,
                    latitude: item.location?.latitude,
                    longitude: item.location?.longitude
                )
            } else if item.type == "reminder" {
                ReminderPreviewCard(
                    title: item.reminder?.title ?? (item.text ?? "Reminder"),
                    remindAt: item.reminder?.remindAt ?? "",
                    isDone: item.reminder?.isCompletedOrPast ?? false
                )
            } else {
                RichTextView(html: item.text ?? "")
                    .padding(.bottom, 6)
                Divider()
            }

            if showAuthor {
                Text("— \(item.authorName)")
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.accentHover)
            }
        }
    }
}
