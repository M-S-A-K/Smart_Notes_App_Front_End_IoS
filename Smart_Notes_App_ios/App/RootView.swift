//
//  RootView.swift
//  Smart_Notes_App_ios
//
//  Created by M_Salik_Amin_Kayani on 08/11/2026.
//

import SwiftUI

struct RootView: View {
    @EnvironmentObject var state: AppState
    @State private var showSplash = true

    var body: some View {
        ZStack {
            if state.user == nil {
                AuthView()
            } else {
                TabView {
                    HomeScreen().tabItem { Label("Home", systemImage: "house") }
                    NotesListScreen().tabItem { Label("Notes", systemImage: "doc.text") }
                    CalendarScreen().tabItem { Label("Schedule", systemImage: "calendar") }
                    ChatScreen().tabItem { Label("Chat", systemImage: "bubble.left") }
                    ProfileScreen().tabItem { Label("Profile", systemImage: "person") }
                }
                .tint(AppTheme.accent)
            }
            if state.locked { AppLockView() }
            if showSplash { SplashView() }
        }
        .task {
            try? await Task.sleep(for: .seconds(2.5))
            withAnimation { showSplash = false }
        }
    }
}

struct SplashView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "note.text")
                .font(.largeTitle).foregroundStyle(.white)
                .frame(width: 80, height: 80)
                .background(AppTheme.accent)
                .clipShape(RoundedRectangle(cornerRadius: 24))
            Text("Smart Notes").font(.title.bold())
            Text("Capture the moment. Keep what matters.").foregroundStyle(AppTheme.inkSoft)
            ProgressView().padding(.top, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.surface)
    }
}

struct AppLockView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.fill").font(.largeTitle).foregroundStyle(AppTheme.accent)
            Text("Smart Notes is locked").font(.headline)
            PrimaryButton(title: "Unlock") { Task { await state.unlockApp() } }.frame(width: 200)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.surface)
        .task { await state.unlockApp() }
    }
}
