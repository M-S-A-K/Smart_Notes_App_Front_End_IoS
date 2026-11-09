//
//  RootView.swift
//  Smart_Notes_App_ios
//
//  Created by M_Salik_Amin_Kayani on 08/11/2026.
//

import SwiftUI

struct RootView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var alarm = ReminderAlarmManager.shared
    @State private var showSplash = true

    var body: some View {
        ZStack {
            if state.user == nil {
                AuthView()
            } else {
                TabView {
                    HomeScreen().tabItem { Label("Home", systemImage: "house") }
                    NotesListScreen().tabItem { Label("Notes", systemImage: "doc.text") }
                    CalendarScreen().tabItem { Label("Reminder", systemImage: "bell.badge") }
                    ChatScreen().tabItem { Label("Chat", systemImage: "bubble.left") }
                    ProfileScreen().tabItem { Label("Profile", systemImage: "person") }
                }
                .tint(AppTheme.accent)
            }

            if let ringTitle = alarm.activeAlarmTitle {
                VStack {
                    HStack(spacing: 12) {
                        Image(systemName: "bell.and.waves.left.and.right.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("REMINDER ALARM")
                                .font(.system(size: 10, weight: .heavy))
                                .foregroundStyle(.white.opacity(0.85))
                            Text(ringTitle)
                                .font(.headline.bold())
                                .foregroundStyle(.white)
                        }
                        Spacer()
                        Button("Stop") {
                            alarm.stopRinging()
                        }
                        .font(.subheadline.bold())
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.white)
                        .foregroundStyle(AppTheme.accentHover)
                        .clipShape(Capsule())
                    }
                    .padding(16)
                    .background(AppTheme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .shadow(radius: 12, y: 5)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(99)
            }

            if state.locked && state.user != nil {
                AppLockView()
                    .zIndex(98)
            }
            if showSplash {
                SplashView()
                    .zIndex(100)
            }
        }
        .preferredColorScheme(state.darkMode ? .dark : .light)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background && state.appLock && !state.appLockPin.isEmpty && state.user != nil {
                state.locked = true
            }
        }
        .task {
            try? await Task.sleep(for: .seconds(1.8))
            withAnimation { showSplash = false }
        }
    }
}

struct SplashView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.largeTitle.bold())
                .foregroundStyle(.white)
                .frame(width: 76, height: 76)
                .background(AppTheme.accent)
                .clipShape(RoundedRectangle(cornerRadius: 23))
                .shadow(color: AppTheme.accent.opacity(0.3), radius: 15, y: 8)
            Text("Smart Notes")
                .font(.title.bold())
                .foregroundStyle(AppTheme.ink)
            Text("Capture the moment. Keep what matters.")
                .font(.footnote)
                .foregroundStyle(AppTheme.inkSoft)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.surface)
    }
}

struct AppLockView: View {
    @EnvironmentObject var state: AppState
    @State private var pinInput = ""

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 46))
                .foregroundStyle(AppTheme.accent)
                .frame(width: 82, height: 82)
                .background(AppTheme.accentSoft)
                .clipShape(RoundedRectangle(cornerRadius: 22))

            Text("Smart Notes is Locked")
                .font(.title2.bold())
                .foregroundStyle(AppTheme.ink)

            Text("Enter your App Lock passcode or use Face ID to continue.")
                .font(.caption)
                .foregroundStyle(AppTheme.inkSoft)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 260)

            SecureField("Enter passcode", text: $pinInput)
                .keyboardType(.asciiCapable)
                .textInputAutocapitalization(.never)
                .padding(.horizontal, 14)
                .frame(width: 240, height: 48)
                .background(AppTheme.surfaceSoft)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.borderStrong))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            if !state.unlockError.isEmpty {
                Text(state.unlockError)
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.danger)
            }

            PrimaryButton(title: "Unlock") {
                _ = state.verifyPin(pinInput)
                pinInput = ""
            }
            .frame(width: 240)

            Button {
                Task { await state.unlockWithFaceID() }
            } label: {
                Label("Unlock with Face ID", systemImage: "faceid")
                    .font(.footnote.bold())
                    .foregroundStyle(AppTheme.accentHover)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.surface)
        .task { await state.unlockWithFaceID() }
    }
}
