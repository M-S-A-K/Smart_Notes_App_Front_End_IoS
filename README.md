# Smart Notes App — iOS Frontend 📱

> **"Capture the moment, keep what matters."**

An intuitive, modern iOS application for smart personal notes, voice memos with Whisper speech-to-text, calendar scheduling, private friend chats with selective note sharing, and collaborative group notes.

The user interface follows the official Figma design system (`#35b8c8` teal theme, soft card surfaces, and rich typography) and interfaces directly with the ASP.NET Core backend.

* **Backend Repository:** [SmartNotesApp_Backend_v2](https://github.com/M-S-A-K/SmartNotesApp_Backend_v2)

---

## 🚀 Key Features

* **Authentication & Profiles:** Quick login & registration, local session management, profile link generation, and password updates.
* **Home Screen:** Quick action cards (*+ New note*, *Voice note*, *Group note*), today's scheduled reminders banner, and recent notes.
* **Notes Library:** Tag chips (*Work*, *Personal*, *Ideas*, *Meeting*, *University*, *Study*, *FYP*), custom tags, and full-text search.
* **Dual View & Edit Modes:**
  * **View Mode:** Clean reading layout with map location card, scheduled reminder card, voice note player with waveforms, and a 3-dots options menu (*Edit*, *Share*, *Download*, *Lock*, *Delete*).
  * **Edit Mode:** Rich text formatting (Bold, Italic, Underline, Strikethrough, Alignments, Lists), tag selector, inline location & reminder pickers, and mic recorder.
* **Voice Notes & Transcripts:** Record audio with a live timer, pause/resume, and stop & save. Automatically uploads to backend Whisper AI for transcription with a "See text" transcript modal and waveform playback.
* **Schedule & Calendar:** Graphical month calendar with reminder day indicators, today breakdown, and direct links to notes.
* **Private Chat & Note Sharing:** Direct messaging with contacts, add friends via link/code or phone, and a selective share sheet (*Text*, *Location*, *Reminder*, *Voice notes*).
* **Collaborative Group Notes:** Multi-member notes with author contribution badges (`— Author`), and member access management.
* **Privacy & Security:** Password lock for sensitive notes, App Lock passcode/Face ID protection, and offline note downloads.

---

## 🛠️ Prerequisites

Before getting started, make sure you have:
* **macOS:** macOS 14.0 (Sonoma) or newer
* **Xcode:** Xcode 15.0 or newer (Swift 5.9+, iOS 17.0+ deployment target)
* **Backend Server:** Running instance of [SmartNotesApp_Backend_v2](https://github.com/M-S-A-K/SmartNotesApp_Backend_v2) (default port: `http://localhost:5262`)

---

## 📥 How to Clone and Run

### 1. Clone the Repository
Open your Terminal and run:
```bash
git clone https://github.com/M-S-A-K/Smart_Notes_App_Front_End_IoS.git
cd Smart_Notes_App_Front_End_IoS
```

### 2. Configure the Backend URL
Open `Smart_Notes_App_ios/Core/APIService.swift` in Xcode or your editor:
```swift
final class API {
    static let shared = API()

    // Simulator default:
    let baseURL = "http://localhost:5262"
    
    // Physical iPhone on same Wi-Fi (replace with your Mac's LAN IP):
    // let baseURL = "http://192.168.1.50:5262"
```
* **iOS Simulator:** Keep `http://localhost:5262`.
* **Physical iPhone:** Use your Mac's local IP address (e.g. `http://192.168.x.x:5262`) and ensure both devices are on the same Wi-Fi.

### 3. Open the Project in Xcode
Double-click `Smart_Notes_App_ios.xcodeproj` or run:
```bash
open Smart_Notes_App_ios.xcodeproj
```

### 4. Build and Run
1. In Xcode's top toolbar, choose an **iOS Simulator** (e.g., *iPhone 15* or *iPhone 16*) or your connected physical device.
2. Press **`Cmd + R`** (or click the ▶ **Play** button) to build and run the app.

---

## 📂 Project Structure

```text
Smart_Notes_App_ios/
├── App/
│   ├── MyApp.swift              # App entry point
│   └── RootView.swift           # Splash screen & main tab routing
├── Core/
│   ├── APIService.swift         # REST API client & multipart upload
│   ├── AppState.swift           # User session & authentication state
│   ├── Models.swift             # Swift Codable data models
│   └── Theme.swift              # App colors, hex extensions, & card styles
├── Screens/
│   ├── AuthView.swift           # Login & Account registration
│   ├── HomeScreen.swift         # Dashboard with quick cards & reminders
│   ├── LibraryScreen.swift      # Notes library with tag filters
│   ├── NoteScreen.swift         # Note view & editing with 3-dots menu
│   ├── GroupNoteScreen.swift    # Collaborative group note workspace
│   ├── CalendarScreen.swift     # Monthly calendar & reminder schedule
│   ├── ChatScreen.swift         # Private conversations & contact management
│   ├── ProfileScreen.swift      # Profile view, app lock, & security settings
│   └── SearchScreen.swift       # Global note, transcript, & chat search
├── Components/
│   ├── SharedComponents.swift   # Buttons, TextFields, Cards, and Avatars
│   ├── VoiceComponents.swift    # Voice recorder panel, waveform & audio player
│   └── ShareSheet.swift         # Selective note share modal
└── Smart-Notes-App-ios-Info.plist # Permissions (Microphone, Face ID, ATS)
```

---

## 🔒 Permissions & Info.plist

The app includes descriptions in `Smart-Notes-App-ios-Info.plist` for:
* **`NSMicrophoneUsageDescription`**: Used to record audio for voice notes.
* **`NSFaceIDUsageDescription`**: Used for biometric note and app unlocking.
* **`NSAppTransportSecurity`**: Configured with `NSAllowsArbitraryLoads = true` for local development against local HTTP backend servers.

---

## 👥 Final Year Project (FYP) Team

* **HAIQA NAVEED** — `2023-ARID-3663`
* **MUHAMMAD SALIK AMIN KAYANI** — `2023-ARID-3816`
* **USMAN ALI** — `2023-ARID-3942`
* **MUHAMMAD SAFFI ULLAH** — `2023-ARID-3814`
* **RAJA MUHAMMAD NABEEL HUSSAIN** — `2023-ARID-3878`

**Supervisor:** Sir Saeed
