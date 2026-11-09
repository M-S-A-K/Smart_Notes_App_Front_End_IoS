//
//  ChatScreen.swift
//  Smart_Notes_App_ios
//
//  Created by M_Salik_Amin_Kayani on 08/11/2026.
//

import SwiftUI

struct ChatScreen: View {
    @State private var friends: [Person] = []
    @State private var query = ""
    @State private var showAdd = false
    @State private var linkOrCode = ""
    @State private var manualEmailOrPhone = ""
    @State private var statusBanner = ""
    @State private var error = ""

    private var filteredFriends: [Person] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return friends }
        return friends.filter {
            $0.fullName.lowercased().contains(q) || $0.email.lowercased().contains(q)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if !statusBanner.isEmpty {
                        Label(statusBanner, systemImage: "checkmark")
                            .font(.caption.bold())
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .foregroundStyle(AppTheme.avatarText)
                            .background(AppTheme.accentSoft)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    HStack {
                        Image(systemName: "magnifyingglass").foregroundStyle(AppTheme.muted)
                        TextField("Search conversations or messages", text: $query)
                            .textInputAutocapitalization(.never)
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 48)
                    .softCard(radius: 14, background: AppTheme.surfaceSoft)

                    if !error.isEmpty {
                        Text(error).font(.footnote).foregroundStyle(AppTheme.danger)
                    }

                    if filteredFriends.isEmpty {
                        EmptyState(
                            icon: "bubble.left",
                            title: query.isEmpty ? "No chats yet" : "No conversations found",
                            text: query.isEmpty
                                ? "Add a contact to start a private conversation."
                                : "Try a different name or message."
                        )
                        .frame(maxWidth: .infinity)
                    }

                    ForEach(filteredFriends) { f in
                        NavigationLink { ChatThread(friend: f) } label: {
                            HStack(spacing: 12) {
                                Avatar(name: f.fullName)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(f.fullName)
                                        .font(.subheadline.bold())
                                        .foregroundStyle(AppTheme.ink)
                                    Text(f.email)
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.inkSoft)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.muted)
                            }
                            .padding(12)
                            .softCard(radius: 14)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
            .background(AppTheme.canvas)
            .navigationTitle("Chat")
            .toolbar {
                Button { showAdd = true } label: {
                    Image(systemName: "plus")
                        .frame(width: 36, height: 36)
                        .background(AppTheme.surface)
                        .overlay(RoundedRectangle(cornerRadius: 11).stroke(AppTheme.border))
                        .clipShape(RoundedRectangle(cornerRadius: 11))
                }
            }
            .sheet(isPresented: $showAdd) { addContactSheet }
            .refreshable { await load() }
            .onAppear { Task { await load() } }
        }
    }

    private var addContactSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("NEW CONTACT")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(AppTheme.accentHover)
                    Text("Add contact")
                        .font(.title2.bold())

                    HStack(spacing: 10) {
                        Image(systemName: "paperplane")
                            .foregroundStyle(AppTheme.accentHover)
                            .frame(width: 38, height: 38)
                            .background(AppTheme.accentSoft)
                            .clipShape(RoundedRectangle(cornerRadius: 11))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Add from profile link").font(.subheadline.bold())
                            Text("Paste a Smart Notes contact link or code.")
                                .font(.caption)
                                .foregroundStyle(AppTheme.inkSoft)
                        }
                    }

                    TextField("Paste contact link or code", text: $linkOrCode)
                        .textInputAutocapitalization(.never)
                        .textFieldStyle(.roundedBorder)

                    PrimaryButton(title: "Add contact") {
                        let parsed = ContactLinkHelper.extractEmailOrPhone(from: linkOrCode)
                        Task { await add(parsed) }
                    }

                    Divider()

                    Text("Enter manually instead")
                        .font(.caption.bold())
                        .foregroundStyle(AppTheme.accentHover)

                    AppTextField(
                        label: "Email or phone number",
                        placeholder: "maya@smartnotes.pk or 03001234567",
                        text: $manualEmailOrPhone
                    )

                    Button {
                        Task { await add(manualEmailOrPhone) }
                    } label: {
                        Text("Add manually")
                            .font(.subheadline.bold())
                            .foregroundStyle(AppTheme.ink)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(AppTheme.surface)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.border))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    if !error.isEmpty {
                        Text(error).font(.caption).foregroundStyle(AppTheme.danger)
                    }
                }
                .padding(22)
            }
            .presentationDetents([.medium, .large])
        }
    }

    private func add(_ raw: String) async {
        let key = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }
        do {
            try await API.shared.send("POST", "/api/friends", body: ["emailOrPhone": key])
            linkOrCode = ""; manualEmailOrPhone = ""; error = ""
            showAdd = false
            statusBanner = "Contact added"
            await load()
            try? await Task.sleep(for: .seconds(1.8))
            statusBanner = ""
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func load() async {
        do {
            friends = try await API.shared.friends()
            error = ""
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct ChatThread: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) private var dismiss
    let friend: Person

    @State private var messages: [Message] = []
    @State private var notes: [NoteSummary] = []
    @State private var text = ""
    @State private var showNotes = false
    @State private var showDetails = false
    @State private var opened: Message?
    @State private var error = ""

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        Text("Today")
                            .font(.caption2)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(AppTheme.surfaceSoft)
                            .foregroundStyle(AppTheme.muted)
                            .clipShape(Capsule())

                        ForEach(messages) { m in
                            BubbleView(
                                message: m,
                                senderName: friend.fullName,
                                mine: m.senderId == state.user?.userId
                            ) {
                                opened = m
                            }
                            .id(m.id)
                        }
                    }
                    .padding(16)
                }
                .onChange(of: messages.count) { _, _ in
                    if let last = messages.last { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }

            if !error.isEmpty {
                Text(error).font(.footnote).foregroundStyle(AppTheme.danger).padding(.horizontal)
            }

            HStack(spacing: 10) {
                Button { showNotes = true } label: {
                    Image(systemName: "paperclip")
                        .font(.title3)
                        .foregroundStyle(AppTheme.inkSoft)
                }
                TextField("Write a message…", text: $text)
                    .padding(.horizontal, 14)
                    .frame(height: 44)
                    .background(AppTheme.surfaceSoft)
                    .overlay(RoundedRectangle(cornerRadius: 13).stroke(AppTheme.border))
                    .clipShape(RoundedRectangle(cornerRadius: 13))

                Button { Task { await sendText() } } label: {
                    Image(systemName: "paperplane.fill")
                        .foregroundStyle(.white)
                        .frame(width: 42, height: 42)
                        .background(AppTheme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(12)
            .background(AppTheme.surface)
        }
        .background(AppTheme.canvas)
        .navigationTitle(friend.fullName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showDetails = true } label: { Image(systemName: "ellipsis") }
            }
        }
        .sheet(isPresented: $showNotes) {
            NavigationStack {
                List(notes) { note in
                    NavigationLink {
                        ShareSheet(noteId: note.id, friend: friend) {
                            showNotes = false
                            Task { await load() }
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(note.title.isEmpty ? "Untitled note" : note.title).font(.subheadline.bold())
                            Text(note.snippet.plainText).font(.caption).foregroundStyle(AppTheme.inkSoft).lineLimit(1)
                        }
                    }
                }
                .navigationTitle("Choose from your library")
                .navigationBarTitleDisplayMode(.inline)
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showDetails) {
            VStack(spacing: 16) {
                Avatar(name: friend.fullName, size: 72)
                Text(friend.fullName).font(.title3.bold())
                Text(friend.email).font(.caption).foregroundStyle(AppTheme.inkSoft)
                Button(role: .destructive) {
                    Task {
                        try? await API.shared.send("DELETE", "/api/friends/\(friend.id)")
                        showDetails = false
                        dismiss()
                    }
                } label: {
                    Text("Delete contact").font(.subheadline.bold())
                }
                .padding(.top, 12)
            }
            .padding(24)
            .presentationDetents([.fraction(0.4)])
        }
        .sheet(item: $opened) { msg in
            SharedNoteSheet(
                message: msg,
                senderName: msg.senderId == state.user?.userId ? "You" : friend.fullName
            )
        }
        .task {
            notes = ((try? await API.shared.notes(type: "personal")) ?? []).filter { !$0.isLocked }
            await load()
        }
    }

    private func sendText() async {
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        do {
            try await API.shared.sendMessage(to: friend.id, text: text, noteId: nil)
            text = ""
            await load()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func load() async {
        do {
            messages = try await API.shared.messages(friend.id)
            try? await API.shared.send("PUT", "/api/messages/read-all/\(friend.id)")
            error = ""
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct BubbleView: View {
    let message: Message
    var senderName: String = ""
    let mine: Bool
    let onOpen: () -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if !mine { Avatar(name: senderName, size: 30) }
            if mine { Spacer(minLength: 45) }

            VStack(alignment: mine ? .trailing : .leading, spacing: 4) {
                if !mine && !senderName.isEmpty {
                    Text(senderName).font(.system(size: 10)).foregroundStyle(AppTheme.muted)
                }
                if let t = message.messageText, !t.isEmpty {
                    Text(t)
                        .font(.footnote)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 10)
                        .foregroundStyle(mine ? .white : AppTheme.ink)
                        .background(mine ? AppTheme.accent : AppTheme.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 15)
                                .stroke(mine ? AppTheme.accent : AppTheme.border)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 15))
                }
                if let title = message.sharedTitle {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "doc.text")
                                .foregroundStyle(AppTheme.accentHover)
                                .frame(width: 36, height: 36)
                                .background(AppTheme.accentSoft)
                                .clipShape(RoundedRectangle(cornerRadius: 10))

                            VStack(alignment: .leading, spacing: 3) {
                                Text("SHARED NOTE")
                                    .font(.system(size: 9, weight: .heavy))
                                    .foregroundStyle(AppTheme.accentHover)
                                Text(title)
                                    .font(.subheadline.bold())
                                    .foregroundStyle(AppTheme.ink)
                                let txt = message.displaySharedText
                                if !txt.isEmpty {
                                    Text(txt)
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.inkSoft)
                                        .lineLimit(2)
                                }
                            }
                        }

                        if let loc = message.payload?.location {
                            MapPreviewCard(placeName: loc.placeName, subLocation: loc.subLocation)
                        }
                        if let voices = message.payload?.voices {
                            ForEach(voices) { v in
                                VoiceRow(voice: v)
                            }
                        }

                        Divider()
                        Button(action: onOpen) {
                            HStack(spacing: 4) {
                                Text("Open note")
                                Image(systemName: "chevron.right")
                            }
                            .font(.caption.bold())
                            .foregroundStyle(AppTheme.accentHover)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(12)
                    .frame(maxWidth: 300, alignment: .leading)
                    .softCard(radius: 16)
                }
                Text(message.sentAt.asDate?.formatted(date: .omitted, time: .shortened) ?? "")
                    .font(.system(size: 9))
                    .foregroundStyle(AppTheme.muted)
            }

            if !mine { Spacer(minLength: 45) }
        }
    }
}
