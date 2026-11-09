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

    // Simulator can use localhost. On a real iPhone use your Mac's IP.
    let baseURL = "http://localhost:5262"
    var userId: Int?

    // One function for every call
    func request<T: Decodable>(_ method: String, _ path: String, body: [String: Any]? = nil) async throws -> T {
        guard let url = URL(string: baseURL + path) else { throw APIError(message: "Bad URL") }
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

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(T.self, from: data)
    }

    // MARK: Auth
    func login(email: String, password: String) async throws -> AuthUser {
        try await request("POST", "/api/auth/login", body: ["email": email, "password": password])
    }

    func register(name: String, email: String, password: String) async throws -> AuthUser {
        try await request("POST", "/api/auth/register",
                          body: ["fullName": name, "email": email, "password": password])
    }

    // MARK: Notes
    func notes() async throws -> [NoteSummary] {
        try await request("GET", "/api/notes")
    }
    
    func send(_ method: String, _ path: String, body: [String: Any]? = nil) async throws {
        let _: Empty = try await request(method, path, body: body)
    }

    func noteDetail(_ id: Int) async throws -> NoteDetail {
        try await request("GET", "/api/notes/\(id)")
    }

    func createNote(title: String, content: String) async throws -> Int {
        let c: Created = try await request("POST", "/api/notes",
            body: ["title": title, "content": content, "noteType": "personal"])
        return c.id
    }

    func updateNote(_ id: Int, title: String, content: String) async throws {
        try await send("PUT", "/api/notes/\(id)",
            body: ["title": title, "content": content, "noteType": "personal"])
    }

    func calendar() async throws -> [CalendarItem] {
        try await request("GET", "/api/notes/calendar")
    }
    
    func notes(type: String? = nil, tag: String? = nil) async throws -> [NoteSummary] {
        var query: [String] = []
        if let type { query.append("type=\(type)") }
        if let tag, let t = tag.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) { query.append("tag=\(t)") }
        let q = query.isEmpty ? "" : "?" + query.joined(separator: "&")
        return try await request("GET", "/api/notes" + q)
    }

    func tags() async throws -> [Tag] { try await request("GET", "/api/notes/tags") }
    func friends() async throws -> [Person] { try await request("GET", "/api/friends") }
    func messages(_ friendId: Int) async throws -> [Message] { try await request("GET", "/api/messages/\(friendId)") }
    func members(_ noteId: Int) async throws -> [Person] { try await request("GET", "/api/notes/\(noteId)/members") }
    func contributions(_ noteId: Int) async throws -> [Contribution] { try await request("GET", "/api/notes/\(noteId)/contributions") }

    func sendMessage(to friendId: Int, text: String?, noteId: Int?) async throws {
        var body: [String: Any] = ["includeText": true, "includeLocation": true, "includeReminder": true]
        if let text { body["text"] = text }
        if let noteId { body["sharedNoteId"] = noteId }
        try await send("POST", "/api/messages/\(friendId)", body: body)
    }

    func createGroup(title: String) async throws -> Int {
        let c: Created = try await request("POST", "/api/notes",
            body: ["title": title, "content": "", "noteType": "group"])
        return c.id
    }
    
}
