//
//  ChatScreen.swift
//  Smart_Notes_App_ios
//
//  Created by M_Salik_Amin_Kayani on 08/11/2026.
//

import SwiftUI

struct ChatScreen: View {
    @State private var friends: [Person] = []
    @State private var showAdd = false
    @State private var contact = ""
    @State private var error = ""

    var body: some View {
        NavigationStack {
            List {
                if !error.isEmpty { Text(error).foregroundStyle(AppTheme.danger) }
                if friends.isEmpty {
                    EmptyState(icon: "bubble.left", title: "No chats yet", text: "Add a friend by email or phone.")
                        .frame(maxWidth: .infinity).listRowBackground(Color.clear)
                }
                ForEach(friends) { f in
                    NavigationLink { ChatThread(friend: f) } label: {
                        HStack(spacing: 12) {
                            Avatar(name: f.fullName)
                            VStack(alignment: .leading) {
                                Text(f.fullName).bold()
                                Text(f.email).font(.caption).foregroundStyle(AppTheme.inkSoft)
                            }
                        }
                    }
                }
                .onDelete { offsets in
                    let removed = offsets.map { friends[$0] }
                    Task {
                        for f in removed { try? await API.shared.send("DELETE", "/api/friends/\(f.id)") }
                        await load()
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.canvas)
            .navigationTitle("Chat")
            .toolbar { Button { showAdd = true } label: { Image(systemName: "person.badge.plus") } }
            .alert("Add friend", isPresented: $showAdd) {
                TextField("Email or phone", text: $contact).textInputAutocapitalization(.never)
                Button("Add") { Task { await add() } }
                Button("Cancel", role: .cancel) {}
            }
            .refreshable { await load() }
            .onAppear { Task { await load() } }
        }
    }

    private func add() async {
        do {
            try await API.shared.send("POST", "/api/friends", body: ["emailOrPhone": contact])
            contact = ""; error = ""
            await load()
        } catch { self.error = error.localizedDescription }
    }

    private func load() async {
        do { friends = try await API.shared.friends(); error = "" }
        catch { self.error = error.localizedDescription }
    }
}

struct ChatThread: View {
    @EnvironmentObject var state: AppState
    let friend: Person
    @State private var messages: [Message] = []
    @State private var notes: [NoteSummary] = []
    @State private var text = ""
    @State private var showNotes = false
    @State private var opened: Message?
    @State private var error = ""

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(messages) { m in
                            BubbleView(message: m, mine: m.senderId == state.user?.userId) { opened = m }.id(m.id)
                        }
                    }
                    .padding(16)
                }
                .onChange(of: messages.count) { _, _ in
                    if let last = messages.last { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
            if !error.isEmpty { Text(error).font(.footnote).foregroundStyle(AppTheme.danger).padding(.horizontal) }
            HStack(spacing: 10) {
                Button { showNotes = true } label: { Image(systemName: "paperclip").font(.title3) }
                TextField("Write a message…", text: $text).textFieldStyle(.roundedBorder)
                Button { Task { await sendText() } } label: { Image(systemName: "paperplane.fill").font(.title3) }
            }
            .padding(12)
            .background(AppTheme.surface)
        }
        .background(AppTheme.canvas)
        .navigationTitle(friend.fullName)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showNotes) {
            NavigationStack {
                List(notes) { note in
                    NavigationLink(note.title) {
                        ShareSheet(noteId: note.id, friend: friend) {
                            showNotes = false
                            Task { await load() }
                        }
                    }
                }
                .navigationTitle("Choose a note")
                .navigationBarTitleDisplayMode(.inline)
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(item: $opened) { SharedNoteSheet(message: $0) }
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
        } catch { self.error = error.localizedDescription }
    }

    private func load() async {
        do {
            messages = try await API.shared.messages(friend.id)
            try await API.shared.send("PUT", "/api/messages/read-all/\(friend.id)")
            error = ""
        } catch { self.error = error.localizedDescription }
    }
}

struct BubbleView: View {
    let message: Message
    let mine: Bool
    let onOpen: () -> Void

    var body: some View {
        HStack {
            if mine { Spacer(minLength: 50) }
            VStack(alignment: mine ? .trailing : .leading, spacing: 4) {
                if let t = message.messageText, !t.isEmpty {
                    Text(t)
                        .padding(.horizontal, 13).padding(.vertical, 10)
                        .foregroundStyle(mine ? .white : AppTheme.ink)
                        .background(mine ? AppTheme.accent : AppTheme.surface)
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(mine ? AppTheme.accent : AppTheme.border))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                if let title = message.sharedTitle {
                    Button(action: onOpen) {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "doc.text").foregroundStyle(AppTheme.accentHover)
                                .frame(width: 36, height: 36).background(AppTheme.accentSoft)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            VStack(alignment: .leading, spacing: 3) {
                                Text("SHARED NOTE").font(.system(size: 9, weight: .heavy)).foregroundStyle(AppTheme.accentHover)
                                Text(title).font(.subheadline.bold()).foregroundStyle(AppTheme.ink)
                                Text(message.payload?.text ?? "").font(.caption).foregroundStyle(AppTheme.inkSoft).lineLimit(2)
                                Text("Open note ›").font(.caption2.bold()).foregroundStyle(AppTheme.accentHover)
                            }
                        }
                        .padding(12).frame(maxWidth: 280, alignment: .leading).softCard(radius: 16)
                    }
                    .buttonStyle(.plain)
                }
                Text(message.sentAt.asDate?.formatted(date: .omitted, time: .shortened) ?? "")
                    .font(.caption2).foregroundStyle(AppTheme.muted)
            }
            if !mine { Spacer(minLength: 50) }
        }
    }
}
