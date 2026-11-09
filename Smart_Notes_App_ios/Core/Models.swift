//
//  Models.swift
//  Smart_Notes_App_ios
//
//  Created by M_Salik_Amin_Kayani on 08/11/2026.
//

import Foundation
import UserNotifications
import AVFoundation
import AudioToolbox
import Combine

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
    var isDone: Bool? = false

    var isPast: Bool {
        guard let d = remindAt.asDate else { return false }
        return d < Date()
    }

    var isCompletedOrPast: Bool {
        (isDone ?? false) || isPast
    }
}

struct Place: Codable, Identifiable {
    let id: Int
    let placeName: String
    let subLocation: String?
    var latitude: Double? = nil
    var longitude: Double? = nil
}

struct Created: Decodable {
    let id: Int
}

struct Person: Codable, Identifiable, Hashable {
    let id: Int
    let fullName: String
    let email: String
    var phone: String? = nil

    enum CodingKeys: String, CodingKey {
        case id, userId, friendId, fullName, email, phone, role
    }

    init(id: Int, fullName: String, email: String, phone: String? = nil) {
        self.id = id
        self.fullName = fullName
        self.email = email
        self.phone = phone
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let v = try? c.decode(Int.self, forKey: .id) {
            self.id = v
        } else if let v = try? c.decode(Int.self, forKey: .userId) {
            self.id = v
        } else if let v = try? c.decode(Int.self, forKey: .friendId) {
            self.id = v
        } else {
            self.id = 0
        }
        self.fullName = (try? c.decode(String.self, forKey: .fullName)) ?? "Friend"
        self.email = (try? c.decode(String.self, forKey: .email)) ?? ""
        self.phone = try? c.decode(String.self, forKey: .phone)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(fullName, forKey: .fullName)
        try c.encode(email, forKey: .email)
        try c.encodeIfPresent(phone, forKey: .phone)
    }
}

struct CalendarItem: Codable, Identifiable {
    let id: Int
    let noteId: Int
    let noteTitle: String
    let title: String
    let remindAt: String
    var isDone: Bool? = false

    var isPast: Bool {
        guard let d = remindAt.asDate else { return false }
        return d < Date()
    }

    var isCompletedOrPast: Bool {
        (isDone ?? false) || isPast
    }
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
        let latitude: Double?
        let longitude: Double?
    }
    struct Rem: Decodable {
        let title: String
        let remindAt: String
        let isDone: Bool?
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
    var isRead: Bool? = false
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

    var isDeletedPlaceholder: Bool {
        guard let t = text?.plainText.trimmingCharacters(in: .whitespacesAndNewlines) else { return false }
        return t == "__DELETED__" || t == "[Deleted]" || t == "This entry has been deleted"
    }
}

struct SearchResult: Decodable {
    struct Hit: Decodable, Identifiable {
        let id: Int
        let title: String
        let noteType: String
        let isLocked: Bool?
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

// MARK: - Encrypted .sma Offline Note + Voice Audio Storage
struct SmaPackage: Codable {
    var detail: NoteDetail
    var members: [Person]
    var contributions: [Contribution]
    var lockPassword: String?
    var savedAt: String
}

enum OfflineStore {
    private static let secretKey = Array("SmartNotes_FYP_2026_Secret_Key".utf8)

    private static var folderURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("OfflineNotes", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private static var voicesFolderURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("OfflineVoices", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private static func fileURL(for noteId: Int) -> URL {
        folderURL.appendingPathComponent("note_\(noteId).sma")
    }

    static func localVoiceURL(for voiceId: Int, filePath: String) -> URL {
        let ext = (filePath as NSString).pathExtension.isEmpty ? "wav" : (filePath as NSString).pathExtension
        return voicesFolderURL.appendingPathComponent("voice_\(voiceId).\(ext)")
    }

    static func hasLocalVoice(voiceId: Int, filePath: String) -> URL? {
        let url = localVoiceURL(for: voiceId, filePath: filePath)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    private static func transform(_ data: Data) -> Data {
        var out = Data(capacity: data.count)
        for (i, byte) in data.enumerated() {
            out.append(byte ^ secretKey[i % secretKey.count])
        }
        return out
    }

    static func isOffline(_ noteId: Int) -> Bool {
        FileManager.default.fileExists(atPath: fileURL(for: noteId).path)
    }

    static func saveSma(
        detail: NoteDetail,
        members: [Person] = [],
        contributions: [Contribution] = [],
        lockPassword: String? = nil
    ) {
        let existingPass = loadSma(detail.id)?.lockPassword
        let finalPass = lockPassword ?? existingPass
        let pkg = SmaPackage(
            detail: detail,
            members: members,
            contributions: contributions,
            lockPassword: detail.isLocked ? finalPass : nil,
            savedAt: ISO8601DateFormatter().string(from: Date())
        )
        if let json = try? JSONEncoder().encode(pkg) {
            let encrypted = transform(json).base64EncodedData()
            try? encrypted.write(to: fileURL(for: detail.id), options: .atomic)
        }
        // Also download all voice audio files onto the phone so they play offline!
        var allVoices = detail.voiceNotes
        for c in contributions {
            if let v = c.voice { allVoices.append(v) }
        }
        Task {
            await downloadVoices(allVoices)
        }
    }

    static func downloadVoices(_ voices: [VoiceNote]) async {
        for v in voices {
            let localURL = localVoiceURL(for: v.id, filePath: v.filePath)
            if FileManager.default.fileExists(atPath: localURL.path) { continue }
            let fullString = v.filePath.hasPrefix("http")
                ? v.filePath
                : API.shared.baseURL + (v.filePath.hasPrefix("/") ? v.filePath : "/" + v.filePath)
            guard let remoteURL = URL(string: fullString) else { continue }
            var req = URLRequest(url: remoteURL)
            if let uid = API.shared.userId {
                req.setValue(String(uid), forHTTPHeaderField: "X-User-Id")
            }
            if let (data, resp) = try? await URLSession.shared.data(for: req),
               let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode),
               !data.isEmpty {
                try? data.write(to: localURL, options: .atomic)
            }
        }
    }

    static func updateLockPassword(noteId: Int, isLocked: Bool, newPassword: String?) {
        guard var pkg = loadSma(noteId) else { return }
        pkg.detail = NoteDetail(
            id: pkg.detail.id,
            ownerId: pkg.detail.ownerId,
            title: pkg.detail.title,
            content: pkg.detail.content,
            noteType: pkg.detail.noteType,
            isLocked: isLocked,
            updatedAt: pkg.detail.updatedAt,
            tags: pkg.detail.tags,
            reminders: pkg.detail.reminders,
            locations: pkg.detail.locations,
            voiceNotes: pkg.detail.voiceNotes
        )
        pkg.lockPassword = isLocked ? newPassword : nil
        if let json = try? JSONEncoder().encode(pkg) {
            let encrypted = transform(json).base64EncodedData()
            try? encrypted.write(to: fileURL(for: noteId), options: .atomic)
        }
    }

    static func verifyOfflineLock(noteId: Int, password: String) -> Bool {
        guard let pkg = loadSma(noteId) else { return false }
        if !pkg.detail.isLocked { return true }
        guard let savedPass = pkg.lockPassword, !savedPass.isEmpty else { return false }
        return savedPass == password
    }

    static func loadSma(_ noteId: Int) -> SmaPackage? {
        guard let raw = try? Data(contentsOf: fileURL(for: noteId)) else { return nil }
        if let b64 = Data(base64Encoded: raw) {
            let decrypted = transform(b64)
            if let pkg = try? JSONDecoder().decode(SmaPackage.self, from: decrypted) {
                return pkg
            }
        }
        return try? JSONDecoder().decode(SmaPackage.self, from: raw)
    }

    static func allOfflineSummaries(type: String? = nil, tag: String? = nil) -> [NoteSummary] {
        guard let files = try? FileManager.default.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil) else {
            return []
        }
        var list: [NoteSummary] = []
        for url in files where url.pathExtension.lowercased() == "sma" {
            let name = url.deletingPathExtension().lastPathComponent
            guard let idStr = name.split(separator: "_").last,
                  let noteId = Int(idStr),
                  let pkg = loadSma(noteId) else { continue }
            let d = pkg.detail
            if let type, d.noteType != type { continue }
            if let tag, !d.tags.contains(where: { $0.name.caseInsensitiveCompare(tag) == .orderedSame }) { continue }

            let snippet: String
            if d.noteType == "group" {
                snippet = pkg.contributions.last(where: { !$0.isDeletedPlaceholder })?.text ?? "Offline group note (.sma)"
            } else if !d.content.plainText.isEmpty {
                snippet = d.content.plainText
            } else if !d.voiceNotes.isEmpty {
                snippet = "🎤 Voice note attached (\(d.voiceNotes.count))"
            } else if let loc = d.locations.first {
                snippet = "📍 \(loc.placeName)"
            } else if let rem = d.reminders.first {
                snippet = "⏰ \(rem.title)"
            } else {
                snippet = "Saved offline (.sma)"
            }

            list.append(
                NoteSummary(
                    id: d.id,
                    title: d.title,
                    noteType: d.noteType,
                    isLocked: d.isLocked,
                    updatedAt: d.updatedAt,
                    snippet: snippet
                )
            )
        }
        return list.sorted { $0.updatedAt > $1.updatedAt }
    }
}

// MARK: - 8 Cool Musical Ringtones (Plays Real Melodies via AVAudioPlayer)
enum RingtoneTone: String, CaseIterable, Identifiable {
    case marimbaVibe = "Marimba Vibe"
    case crystalChime = "Crystal Chime"
    case neonPulse = "Neon Pulse"
    case morningDew = "Morning Dew"
    case cosmicBell = "Cosmic Bell"
    case softHarp = "Soft Harp"
    case classicDigital = "Classic Digital"
    case zenKalimba = "Zen Kalimba"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .marimbaVibe: return "music.quarternote.3"
        case .crystalChime: return "sparkles"
        case .neonPulse: return "waveform.path.ecg"
        case .morningDew: return "sun.max.fill"
        case .cosmicBell: return "bell.and.waves.left.and.right.fill"
        case .softHarp: return "guitars.fill"
        case .classicDigital: return "alarm.fill"
        case .zenKalimba: return "leaf.fill"
        }
    }

    var notes: [(freq: Double, duration: Double)] {
        switch self {
        case .marimbaVibe:
            return [(523.25, 0.14), (659.25, 0.14), (783.99, 0.14), (1046.50, 0.28), (783.99, 0.14), (1046.50, 0.35)]
        case .crystalChime:
            return [(659.25, 0.18), (783.99, 0.18), (987.77, 0.18), (1318.51, 0.40)]
        case .neonPulse:
            return [(440.0, 0.10), (554.37, 0.10), (659.25, 0.10), (880.0, 0.18), (659.25, 0.10), (880.0, 0.28)]
        case .morningDew:
            return [(587.33, 0.20), (659.25, 0.20), (783.99, 0.20), (1174.66, 0.42)]
        case .cosmicBell:
            return [(523.25, 0.22), (783.99, 0.22), (1046.50, 0.22), (1567.98, 0.45)]
        case .softHarp:
            return [(392.00, 0.15), (493.88, 0.15), (587.33, 0.15), (783.99, 0.15), (987.77, 0.35)]
        case .classicDigital:
            return [(880.0, 0.12), (0.0, 0.05), (880.0, 0.12), (0.0, 0.05), (1174.66, 0.26)]
        case .zenKalimba:
            return [(440.0, 0.18), (523.25, 0.18), (659.25, 0.18), (783.99, 0.36)]
        }
    }

    func makeWavData() -> Data {
        let sampleRate = 44100
        var samples: [Int16] = []
        for note in notes {
            let count = Int(Double(sampleRate) * note.duration)
            for i in 0..<count {
                if note.freq <= 0 {
                    samples.append(0)
                    continue
                }
                let t = Double(i) / Double(sampleRate)
                let env = exp(-4.0 * t / note.duration)
                let wave = sin(2.0 * .pi * note.freq * t) + 0.35 * sin(4.0 * .pi * note.freq * t)
                let val = Int16(max(-32767, min(32767, wave * env * 14000.0)))
                samples.append(val)
            }
        }
        var data = Data()
        let dataSize = UInt32(samples.count * 2)
        let fileSize = dataSize + 36
        data.append("RIFF".data(using: .ascii)!)
        withUnsafeBytes(of: fileSize.littleEndian) { data.append(contentsOf: $0) }
        data.append("WAVEfmt ".data(using: .ascii)!)
        withUnsafeBytes(of: UInt32(16).littleEndian) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: UInt16(1).littleEndian) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: UInt16(1).littleEndian) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: UInt32(sampleRate).littleEndian) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: UInt32(sampleRate * 2).littleEndian) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: UInt16(2).littleEndian) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: UInt16(16).littleEndian) { data.append(contentsOf: $0) }
        data.append("data".data(using: .ascii)!)
        withUnsafeBytes(of: dataSize.littleEndian) { data.append(contentsOf: $0) }
        samples.withUnsafeBufferPointer { buffer in
            data.append(UnsafeBufferPointer(
                start: UnsafeRawPointer(buffer.baseAddress)?.assumingMemoryBound(to: UInt8.self),
                count: samples.count * 2
            ))
        }
        return data
    }
}

@MainActor
final class ReminderAlarmManager: ObservableObject {
    static let shared = ReminderAlarmManager()

    @Published var activeAlarmTitle: String? = nil
    @Published var selectedTone: RingtoneTone = {
        let raw = UserDefaults.standard.string(forKey: "selectedRingtone") ?? RingtoneTone.marimbaVibe.rawValue
        return RingtoneTone(rawValue: raw) ?? .marimbaVibe
    }() {
        didSet {
            UserDefaults.standard.set(selectedTone.rawValue, forKey: "selectedRingtone")
        }
    }

    private var audioPlayer: AVAudioPlayer?
    private var watchTimer: Timer?
    private var triggeredKeys: Set<String> = []
    private var watchedReminders: [(id: String, title: String, date: Date, isDone: Bool)] = []

    init() {
        startWatcher()
    }

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    func syncReminders(_ items: [CalendarItem]) {
        requestPermission()
        var list: [(String, String, Date, Bool)] = []
        for item in items {
            if let d = item.remindAt.asDate {
                let done = item.isDone ?? false
                let key = "rem-\(item.id)-\(Int(d.timeIntervalSince1970))"
                list.append((key, item.title, d, done))
                if !done {
                    scheduleSystemNotification(id: key, title: item.title, body: "From “\(item.noteTitle)”", date: d)
                }
            }
        }
        watchedReminders = list
    }

    func scheduleSingle(title: String, date: Date) {
        requestPermission()
        let key = "custom-\(title)-\(Int(date.timeIntervalSince1970))"
        watchedReminders.append((key, title, date, false))
        scheduleSystemNotification(id: key, title: title, body: "Smart Notes Reminder", date: date)
    }

    private func scheduleSystemNotification(id: String, title: String, body: String, date: Date) {
        guard date > Date() else { return }
        let content = UNMutableNotificationContent()
        content.title = "🔔 Reminder: \(title)"
        content.body = body
        content.sound = .default

        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let req = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(req)
    }

    private func startWatcher() {
        watchTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkDueReminders()
            }
        }
    }

    private func checkDueReminders() {
        let now = Date()
        for rem in watchedReminders where !rem.isDone {
            let diff = now.timeIntervalSince(rem.date)
            if diff >= 0 && diff < 60 && !triggeredKeys.contains(rem.id) {
                triggeredKeys.insert(rem.id)
                startRinging(title: rem.title)
                break
            }
        }
    }

    func previewTone(_ tone: RingtoneTone) {
        playAudio(for: tone, loop: false)
    }

    func startRinging(title: String) {
        activeAlarmTitle = title
        playAudio(for: selectedTone, loop: true)
    }

    private func playAudio(for tone: RingtoneTone, loop: Bool) {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        let data = tone.makeWavData()
        audioPlayer = try? AVAudioPlayer(data: data)
        audioPlayer?.numberOfLoops = loop ? -1 : 0
        audioPlayer?.volume = 1.0
        audioPlayer?.prepareToPlay()
        audioPlayer?.play()
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
    }

    func stopRinging() {
        audioPlayer?.stop()
        audioPlayer = nil
        activeAlarmTitle = nil
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
