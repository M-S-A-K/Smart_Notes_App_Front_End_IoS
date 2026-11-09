//
//  APIService.swift
//  Smart_Notes_App_ios
//
//  Created by M_Salik_Amin_Kayani on 08/11/2026.
//


import Foundation

struct APIError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

struct Empty: Decodable {}

final class API {
    static let shared = API()

    // Simulator uses localhost. On a physical iPhone, replace with your Mac's local IP.
    let baseURL = "http://localhost:5262"
    var userId: Int?

    func request<T: Decodable>(_ method: String, _ path: String, body: [String: Any]? = nil) async throws -> T {
        guard let url = URL(string: baseURL + path) else { throw APIError(message: "Invalid URL") }
        var req = URLRequest(url: url)
        req.httpMethod = method
        if let userId { req.setValue(String(userId), forHTTPHeaderField: "X-User-Id") }
        if let body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let (data, response) = try await URLSession.shared.data(for: req)
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
        try await request("GET", "/api/notes/\(id)")
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

    func tags() async throws -> [Tag] {
        try await request("GET", "/api/notes/tags")
    }

    func calendar() async throws -> [CalendarItem] {
        try await request("GET", "/api/notes/calendar")
    }

    // MARK: Group Notes
    func members(_ noteId: Int) async throws -> [Person] {
        try await request("GET", "/api/notes/\(noteId)/members")
    }

    func contributions(_ noteId: Int) async throws -> [Contribution] {
        try await request("GET", "/api/notes/\(noteId)/contributions")
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
