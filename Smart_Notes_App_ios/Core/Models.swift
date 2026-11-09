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

struct Tag: Codable, Identifiable { let id: Int; let name: String }
struct Reminder: Codable, Identifiable { let id: Int; let title: String; let remindAt: String }
struct Place: Codable, Identifiable { let id: Int; let placeName: String; let subLocation: String? }
struct Created: Decodable { let id: Int }
struct Person: Codable, Identifiable { let id: Int; let fullName: String; let email: String }

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

// A shared note travels inside the message as JSON text
struct SharedPayload: Decodable {
    struct Loc: Decodable { let placeName: String; let subLocation: String? }
    struct Rem: Decodable { let title: String; let remindAt: String }
    let text: String?
    let location: Loc?
    let reminder: Rem?
    let voices: [VoiceNote]?
}

struct Message: Codable, Identifiable {
    let id: Int
    let senderId: Int
    let messageText: String?
    let sharedTitle: String?
    let sharedContent: String?
    let sentAt: String

    var payload: SharedPayload? {
        guard let data = sharedContent?.data(using: .utf8) else { return nil }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try? decoder.decode(SharedPayload.self, from: data)
    }
}

struct Contribution: Codable, Identifiable {
    let id: Int
    let userId: Int
    let authorName: String
    let type: String          // text, location, reminder, voice
    let text: String?
    let reminder: Reminder?
    let location: Place?
    let voice: VoiceNote?
}

struct SearchResult: Decodable {
    struct Hit: Decodable, Identifiable { let id: Int; let title: String; let noteType: String }
    struct Msg: Decodable, Identifiable { let id: Int; let messageText: String?; let sharedTitle: String? }
    let notes: [Hit]
    let messages: [Msg]
}

struct Profile: Decodable {
    let fullName: String
    let email: String
    let phone: String?
}

extension String {
    var asDate: Date? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        f.timeZone = TimeZone(identifier: "UTC")
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.date(from: String(prefix(19)))
    }
    var timeAgo: String {
        guard let date = asDate else { return "" }
        return RelativeDateTimeFormatter().localizedString(for: date, relativeTo: Date())
    }
    var niceTime: String {
        asDate?.formatted(date: .abbreviated, time: .shortened) ?? self
    }
}



