//
//  Models.swift
//  Smart_Notes_App_ios
//
//  Created by M_Salik_Amin_Kayani on 08/11/2026.
//


import Foundation

struct AuthUser: Codable {
    let userId: Int
    let fullName: String
    let email: String
}

struct NoteSummary: Codable, Identifiable {
    let id: Int
    let title: String
    let noteType: String
    let isLocked: Bool
    let updatedAt: String
    let snippet: String

    var isGroup: Bool { noteType == "group" }
}

struct Tag: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
}

struct Reminder: Codable, Identifiable {
    let id: Int
    let title: String
    let remindAt: String
}

struct Place: Codable, Identifiable {
    let id: Int
    let placeName: String
    let subLocation: String?
}

struct Created: Decodable {
    let id: Int
}

struct Person: Codable, Identifiable, Hashable {
    let id: Int
    let fullName: String
    let email: String
    var phone: String? = nil
}

struct CalendarItem: Codable, Identifiable {
    let id: Int
    let noteId: Int
    let noteTitle: String
    let title: String
    let remindAt: String
}

struct VoiceNote: Codable, Identifiable {
    let id: Int
    let displayName: String
    let filePath: String
    let durationSeconds: Int?
    let transcript: String?
}

struct NoteDetail: Codable {
    let id: Int
    let ownerId: Int
    let title: String
    let content: String
    let noteType: String
    let isLocked: Bool
    let updatedAt: String
    let tags: [Tag]
    let reminders: [Reminder]
    let locations: [Place]
    let voiceNotes: [VoiceNote]
}

struct SharedPayload: Decodable {
    struct Loc: Decodable {
        let placeName: String
        let subLocation: String?
    }
    struct Rem: Decodable {
        let title: String
        let remindAt: String
    }
    let text: String?
    let location: Loc?
    let reminder: Rem?
    let voices: [VoiceNote]?
}

struct Message: Codable, Identifiable {
    let id: Int
    let senderId: Int
    let receiverId: Int?
    let messageText: String?
    let sharedNoteId: Int?
    let sharedTitle: String?
    let sharedContent: String?
    let sentAt: String

    var payload: SharedPayload? {
        guard let data = sharedContent?.data(using: .utf8) else { return nil }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try? decoder.decode(SharedPayload.self, from: data)
    }

    var displaySharedText: String {
        if let p = payload {
            return (p.text ?? "").plainText
        }
        return (sharedContent ?? "").plainText
    }
}

struct Contribution: Codable, Identifiable {
    let id: Int
    let userId: Int
    let authorName: String
    let type: String // "text", "location", "reminder", "voice"
    let text: String?
    let reminder: Reminder?
    let location: Place?
    let voice: VoiceNote?
}

struct SearchResult: Decodable {
    struct Hit: Decodable, Identifiable {
        let id: Int
        let title: String
        let noteType: String
    }
    struct Msg: Decodable, Identifiable {
        let id: Int
        let senderId: Int?
        let receiverId: Int?
        let messageText: String?
        let sharedTitle: String?
    }
    let notes: [Hit]
    let messages: [Msg]
}

struct Profile: Decodable {
    let fullName: String
    let email: String
    let phone: String?
}

enum OfflineStore {
    private static let key = "smart_notes_offline_ids"

    static func isOffline(_ noteId: Int) -> Bool {
        let ids = UserDefaults.standard.array(forKey: key) as? [Int] ?? []
        return ids.contains(noteId)
    }

    static func markOffline(_ noteId: Int) {
        var ids = UserDefaults.standard.array(forKey: key) as? [Int] ?? []
        if !ids.contains(noteId) {
            ids.append(noteId)
            UserDefaults.standard.set(ids, forKey: key)
        }
    }
}

enum ContactLinkHelper {
    static func makeLink(name: String, email: String, phone: String) -> String {
        let dict: [String: String] = ["name": name, "email": email, "phone": phone]
        guard let data = try? JSONSerialization.data(withJSONObject: dict) else { return email }
        let code = data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return "smartnotes://contact?contact=\(code)"
    }

    static func extractEmailOrPhone(from input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        var code = trimmed
        if let comps = URLComponents(string: trimmed),
           let param = comps.queryItems?.first(where: { $0.name == "contact" })?.value {
            code = param
        } else if trimmed.hasPrefix("smartnotes://contact/") {
            code = String(trimmed.dropFirst("smartnotes://contact/".count))
        }
        var b64 = code.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        let rem = b64.count % 4
        if rem > 0 { b64 += String(repeating: "=", count: 4 - rem) }
        if let data = Data(base64Encoded: b64),
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
            if let email = obj["email"], !email.isEmpty { return email }
            if let phone = obj["phone"], !phone.isEmpty { return phone }
        }
        return trimmed
    }
}

extension String {
    var asDate: Date? {
        let iso = ISO8601DateFormatter()
        if let d = iso.date(from: self) { return d }
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        f.timeZone = TimeZone(identifier: "UTC")
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.date(from: String(prefix(19)))
    }

    var timeAgo: String {
        guard let date = asDate else { return "Recently" }
        let diff = Date().timeIntervalSince(date)
        if diff < 3600 {
            return "\(max(1, Int(round(diff / 60))))m ago"
        }
        if diff < 86400 {
            return "\(max(1, Int(round(diff / 3600))))h ago"
        }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }

    var niceTime: String {
        guard let date = asDate else { return self }
        if Calendar.current.isDateInToday(date) {
            return "Today, \(date.formatted(date: .omitted, time: .shortened))"
        }
        if Calendar.current.isDateInTomorrow(date) {
            return "Tomorrow, \(date.formatted(date: .omitted, time: .shortened))"
        }
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}

