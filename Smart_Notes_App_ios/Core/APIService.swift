//
//  APIService.swift
//  Smart_Notes_App_ios
//
//  Created by M_Salik_Amin_Kayani on 08/11/2026.
//

import Foundation
import Combine

struct APIError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

struct Empty: Decodable {}

// MARK: - Simple WebSocket + Live Auto-Sync Manager for Chat & Group Notes
@MainActor
final class RealtimeSocket: ObservableObject {
    static let shared = RealtimeSocket()

    @Published var tick: Int = 0
    private var webSocketTask: URLSessionWebSocketTask?
    private var timer: Timer?

    func start() {
        connectWebSocket()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick &+= 1
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
    }

    private func connectWebSocket() {
        let wsBase = API.shared.baseURL
            .replacingOccurrences(of: "https://", with: "wss://")
            .replacingOccurrences(of: "http://", with: "ws://")
        guard let url = URL(string: "\(wsBase)/ws?userId=\(API.shared.userId ?? 0)") else { return }
        let task = URLSession.shared.webSocketTask(with: url)
        self.webSocketTask = task
        task.resume()
        listen()
    }

    private func listen() {
        webSocketTask?.receive { [weak self] result in
            guard let self else { return }
            if case .success = result {
                Task { @MainActor in
                    self.tick &+= 1
                    self.listen()
                }
            }
        }
    }

    func notifyChange(_ event: String = "refresh") {
        webSocketTask?.send(.string(event)) { _ in }
        tick &+= 1
    }
}

final class API: ObservableObject {
    static let shared = API()

    let baseURL = "http://localhost:5262"
    //let baseURL = "http://192.168.100.107:5262"

    var userId: Int?
    @Published var isOffline: Bool = false

    func request<T: Decodable>(_ method: String, _ path: String, body: [String: Any]? = nil) async throws -> T {
        guard let url = URL(string: baseURL + path) else { throw APIError(message: "Invalid URL") }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.timeoutInterval = 8
        if let userId { req.setValue(String(userId), forHTTPHeaderField: "X-User-Id") }
        if let body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: req)
            Task { @MainActor in self.isOffline = false }
        } catch let urlError as URLError where urlError.code == .cancelled {
            throw urlError
        } catch {
            Task { @MainActor in self.isOffline = true }
            throw APIError(message: "You are offline")
        }

        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(code) else {
            let message = (try? JSONDecoder().decode([String: String].self, from: data))?["error"]
            throw APIError(message: message ?? "Server error (\(code))")
        }

        if T.self == Empty.self, let empty = Empty() as? T {
            return empty
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(T.self, from: data)
    }

    func send(_ method: String, _ path: String, body: [String: Any]? = nil) async throws {
        let _: Empty = try await request(method, path, body: body)
    }

    // MARK: Auth
    func login(email: String, password: String) async throws -> AuthUser {
        try await request("POST", "/api/auth/login", body: ["email": email, "password": password])
    }

    func register(name: String, email: String, password: String, phone: String = "") async throws -> AuthUser {
        try await request("POST", "/api/auth/register",
                          body: ["fullName": name, "email": email, "password": password, "phone": phone])
    }

    // MARK: Notes
    func notes(type: String? = nil, tag: String? = nil) async throws -> [NoteSummary] {
        var query: [String] = []
        if let type { query.append("type=\(type)") }
        if let tag, let t = tag.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            query.append("tag=\(t)")
        }
        let q = query.isEmpty ? "" : "?" + query.joined(separator: "&")
        return try await request("GET", "/api/notes" + q)
    }

    func noteDetail(_ id: Int) async throws -> NoteDetail {
        let d: NoteDetail = try await request("GET", "/api/notes/\(id)")
        if OfflineStore.isOffline(id) && d.noteType == "personal" {
            OfflineStore.saveSma(detail: d)
        }
        return d
    }

    func createNote(title: String, content: String, noteType: String = "personal") async throws -> Int {
        let c: Created = try await request("POST", "/api/notes",
            body: ["title": title, "content": content, "noteType": noteType])
        return c.id
    }

    func updateNote(_ id: Int, title: String, content: String, noteType: String = "personal") async throws {
        try await send("PUT", "/api/notes/\(id)",
            body: ["title": title, "content": content, "noteType": noteType])
    }

    func createGroup(title: String) async throws -> Int {
        let c: Created = try await request("POST", "/api/notes",
            body: ["title": title, "content": "", "noteType": "group"])
        return c.id
    }

    func toggleReminder(noteId: Int, reminderId: Int) async throws {
        try await send("PUT", "/api/notes/\(noteId)/reminders/\(reminderId)/toggle")
    }

    func tags() async throws -> [Tag] {
        try await request("GET", "/api/notes/tags")
    }

    func calendar() async throws -> [CalendarItem] {
        let items: [CalendarItem] = try await request("GET", "/api/notes/calendar")
        await ReminderAlarmManager.shared.syncReminders(items)
        return items
    }

    // MARK: Group Notes & Exclusions
    func members(_ noteId: Int) async throws -> [Person] {
        try await request("GET", "/api/notes/\(noteId)/members")
    }

    func contributions(_ noteId: Int) async throws -> [Contribution] {
        try await request("GET", "/api/notes/\(noteId)/contributions")
    }

    func excludeMember(noteId: Int, contributionId: Int, targetUserId: Int) async throws {
        try await send(
            "POST",
            "/api/notes/\(noteId)/contributions/\(contributionId)/exclude",
            body: ["excludedUserId": targetUserId, "userId": targetUserId]
        )
    }

    // MARK: Friends & Chat
    func friends() async throws -> [Person] {
        try await request("GET", "/api/friends")
    }

    func messages(_ friendId: Int) async throws -> [Message] {
        try await request("GET", "/api/messages/\(friendId)")
    }

    func sendMessage(to friendId: Int, text: String?, noteId: Int?, elements: Set<String> = ["text"]) async throws {
        var body: [String: Any] = [
            "includeText": elements.contains("text"),
            "includeLocation": elements.contains("location"),
            "includeReminder": elements.contains("reminder"),
            "includeVoice": elements.contains("voice")
        ]
        if let text { body["text"] = text }
        if let noteId { body["sharedNoteId"] = noteId }
        try await send("POST", "/api/messages/\(friendId)", body: body)
        await RealtimeSocket.shared.notifyChange("chat:\(friendId)")
    }

    // MARK: Search & Profile
    func search(_ q: String) async throws -> SearchResult {
        let enc = q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? q
        return try await request("GET", "/api/search?q=\(enc)")
    }

    func profile() async throws -> Profile {
        try await request("GET", "/api/profile")
    }

    // MARK: Voice Upload (Whisper STT)
    func uploadVoice(noteId: Int, fileURL: URL, seconds: Int, name: String) async throws {
        let ext = fileURL.pathExtension.isEmpty ? "wav" : fileURL.pathExtension.lowercased()
        let mime = ext == "wav" ? "audio/wav" : "audio/m4a"
        let boundary = UUID().uuidString
        var body = Data()
        func add(_ s: String) { body.append(Data(s.utf8)) }

        for (key, value) in ["displayName": name, "durationSeconds": String(seconds), "language": "auto"] {
            add("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(key)\"\r\n\r\n\(value)\r\n")
        }
        add("--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"voice.\(ext)\"\r\nContent-Type: \(mime)\r\n\r\n")
        body.append(try Data(contentsOf: fileURL))
        add("\r\n--\(boundary)--\r\n")

        var req = URLRequest(url: URL(string: baseURL + "/api/notes/\(noteId)/voice")!)
        req.httpMethod = "POST"
        req.timeoutInterval = 180
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        req.setValue(String(userId ?? 0), forHTTPHeaderField: "X-User-Id")
        req.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: req)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        if !(200..<300).contains(code) {
            let message = (try? JSONDecoder().decode([String: String].self, from: data))?["error"]
            throw APIError(message: message ?? "Upload failed (\(code))")
        }
    }
}
