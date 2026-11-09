//
//  ProfileScreen.swift
//  Smart_Notes_App_ios
//
//  Created by M_Salik_Amin_Kayani on 08/11/2026.
//

//
//  ProfileScreen.swift
//  Smart_Notes_App_ios
//

import SwiftUI
import UIKit

struct ProfileScreen: View {
    @EnvironmentObject var state: AppState
    @ObservedObject private var alarm = ReminderAlarmManager.shared
    @State private var showRingtonePicker = false
    @State private var name = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var editing = false
    @State private var sharing = false
    @State private var copied = false
    @State private var changing = false
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var message = ""
    @State private var showSetPinAlert = false
    @State private var pinDraft = ""

    private var shareLink: String {
        ContactLinkHelper.makeLink(name: name, email: email, phone: phone)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Profile").font(.largeTitle.bold()).foregroundStyle(AppTheme.ink)
                    Text("Account & preferences").font(.caption).foregroundStyle(AppTheme.muted)
                }

                // Hero Card
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 14) {
                        Avatar(name: name, size: 64)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(name).font(.title3.bold()).foregroundStyle(AppTheme.ink)
                            Text(phone.isEmpty ? email : "\(email) · \(phone)")
                                .font(.caption)
                                .foregroundStyle(AppTheme.inkSoft)
                        }
                    }
                    HStack(spacing: 8) {
                        Button { sharing.toggle() } label: {
                            Label("Share profile", systemImage: "paperplane")
                                .font(.caption.bold())
                                .frame(maxWidth: .infinity, minHeight: 40)
                                .background(AppTheme.surface)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.border))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)

                        Button { editing.toggle() } label: {
                            Text(editing ? "Cancel" : "Edit profile")
                                .font(.caption.bold())
                                .frame(maxWidth: .infinity, minHeight: 40)
                                .background(AppTheme.surface)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.border))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                    .foregroundStyle(AppTheme.ink)
                }
                .padding(18)
                .softCard(radius: 20)

                if sharing {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 10) {
                            Image(systemName: "person")
                                .foregroundStyle(AppTheme.accentHover)
                                .frame(width: 38, height: 38)
                                .background(AppTheme.accentSoft)
                                .clipShape(RoundedRectangle(cornerRadius: 11))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Your contact link").font(.subheadline.bold())
                                Text("Anyone opening this link in Smart Notes will add you to their contacts.")
                                    .font(.caption2)
                                    .foregroundStyle(AppTheme.inkSoft)
                            }
                        }
                        Text(shareLink)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(AppTheme.inkSoft)
                            .lineLimit(1)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(AppTheme.surface)
                            .overlay(RoundedRectangle(cornerRadius: 9).stroke(AppTheme.border))
                            .clipShape(RoundedRectangle(cornerRadius: 9))

                        PrimaryButton(title: copied ? "✓ Copied" : "Copy link") {
                            UIPasteboard.general.string = shareLink
                            copied = true
                            Task {
                                try? await Task.sleep(for: .seconds(1.6))
                                copied = false
                            }
                        }
                    }
                    .padding(16)
                    .softCard(radius: 17, background: AppTheme.accentSofter, borderColor: AppTheme.accent.opacity(0.35))
                }

                if editing {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Personal details").font(.subheadline.bold())
                        AppTextField(label: "Full name", placeholder: "Your name", text: $name)
                        AppTextField(label: "Email address", placeholder: "you@example.com", text: $email)
                        AppTextField(label: "Phone number", placeholder: "+1 415 555 0108", text: $phone)
                        PrimaryButton(title: "Save changes") { Task { await saveProfile() } }
                    }
                    .padding(16)
                    .softCard()
                }

                // Preferences Section (Dark Mode)
                VStack(alignment: .leading, spacing: 8) {
                    Text("ACCOUNT & PREFERENCES")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(AppTheme.accentHover)
                    Text("Appearance").font(.headline)

                    HStack(spacing: 12) {
                        Image(systemName: state.darkMode ? "moon.fill" : "sun.max.fill")
                            .foregroundStyle(AppTheme.accentHover)
                            .frame(width: 38, height: 38)
                            .background(AppTheme.accentSoft)
                            .clipShape(RoundedRectangle(cornerRadius: 11))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Dark mode").font(.footnote.bold())
                            Text("Switch between light and dark theme across Smart Notes.")
                                .font(.caption2)
                                .foregroundStyle(AppTheme.inkSoft)
                        }
                        Spacer()
                        Toggle("", isOn: $state.darkMode)
                            .labelsHidden()
                            .tint(AppTheme.accent)
                    }
                    .padding(14)
                    .softCard()
                    Button {
                        withAnimation { showRingtonePicker.toggle() }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: alarm.selectedTone.icon)
                                .foregroundStyle(AppTheme.accentHover)
                                .frame(width: 38, height: 38)
                                .background(AppTheme.accentSoft)
                                .clipShape(RoundedRectangle(cornerRadius: 11))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Reminder ringtone").font(.footnote.bold()).foregroundStyle(AppTheme.ink)
                                Text("Current tone: \(alarm.selectedTone.rawValue) (tap to change & preview)")
                                    .font(.caption2)
                                    .foregroundStyle(AppTheme.inkSoft)
                            }
                            Spacer()
                            Image(systemName: showRingtonePicker ? "chevron.up" : "chevron.down")
                                .font(.caption)
                                .foregroundStyle(AppTheme.muted)
                        }
                        .padding(14)
                        .softCard()
                    }
                    .buttonStyle(.plain)

                    if showRingtonePicker {
                        VStack(spacing: 6) {
                            ForEach(RingtoneTone.allCases) { tone in
                                let isSelected = alarm.selectedTone == tone
                                Button {
                                    alarm.selectedTone = tone
                                    alarm.previewTone(tone)
                                } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: tone.icon)
                                            .foregroundStyle(isSelected ? .white : AppTheme.accentHover)
                                            .frame(width: 30, height: 30)
                                            .background(isSelected ? AppTheme.accent : AppTheme.accentSoft)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                        Text(tone.rawValue)
                                            .font(.caption.bold())
                                            .foregroundStyle(AppTheme.ink)
                                        Spacer()
                                        if isSelected {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(AppTheme.accent)
                                        } else {
                                            Text("Tap to play")
                                                .font(.caption2)
                                                .foregroundStyle(AppTheme.muted)
                                        }
                                    }
                                    .padding(10)
                                    .background(isSelected ? AppTheme.accentSoft : AppTheme.surface)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(12)
                        .softCard(background: AppTheme.surfaceSoft)
                    }
                }

                // Security Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("SECURITY").font(.system(size: 10, weight: .heavy)).foregroundStyle(AppTheme.accentHover)
                    Text("Keep your notes private").font(.headline)

                    VStack(spacing: 0) {
                        HStack(spacing: 12) {
                            Image(systemName: "lock")
                                .foregroundStyle(AppTheme.accentHover)
                                .frame(width: 38, height: 38)
                                .background(AppTheme.accentSoft)
                                .clipShape(RoundedRectangle(cornerRadius: 11))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("App lock").font(.footnote.bold())
                                Text("Ask for your passcode when opening Smart Notes.")
                                    .font(.caption2)
                                    .foregroundStyle(AppTheme.inkSoft)
                            }
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { state.appLock },
                                set: { newValue in
                                    if newValue {
                                        pinDraft = ""
                                        showSetPinAlert = true
                                    } else {
                                        state.appLock = false
                                        state.appLockPin = ""
                                        message = "App lock disabled"
                                    }
                                }
                            ))
                            .labelsHidden()
                            .tint(AppTheme.accent)
                        }
                        .padding(14)

                        Divider()

                        Button { changing.toggle() } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "key")
                                    .foregroundStyle(AppTheme.accentHover)
                                    .frame(width: 38, height: 38)
                                    .background(AppTheme.accentSoft)
                                    .clipShape(RoundedRectangle(cornerRadius: 11))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Change password").font(.footnote.bold()).foregroundStyle(AppTheme.ink)
                                    Text("Update your account credentials.")
                                        .font(.caption2)
                                        .foregroundStyle(AppTheme.inkSoft)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.caption).foregroundStyle(AppTheme.muted)
                            }
                            .padding(14)
                        }
                        .buttonStyle(.plain)
                    }
                    .softCard()
                }

                if changing {
                    VStack(spacing: 12) {
                        AppTextField(label: "Current password", placeholder: "Current password", text: $currentPassword, isSecure: true)
                        AppTextField(label: "New password", placeholder: "New password", text: $newPassword, isSecure: true)
                        AppTextField(label: "Confirm new password", placeholder: "Confirm password", text: $confirmPassword, isSecure: true)
                        PrimaryButton(title: "Update password") { Task { await changePassword() } }
                    }
                    .padding(16)
                    .softCard()
                }

                if !message.isEmpty {
                    Text(message).font(.footnote.bold()).foregroundStyle(AppTheme.accentHover)
                }

                // Session Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("SESSION").font(.system(size: 10, weight: .heavy)).foregroundStyle(AppTheme.accentHover)
                    Text("Account access").font(.headline)

                    Button { state.logout() } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .foregroundStyle(AppTheme.danger)
                                .frame(width: 38, height: 38)
                                .background(AppTheme.dangerSoft)
                                .clipShape(RoundedRectangle(cornerRadius: 11))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Log out").font(.footnote.bold()).foregroundStyle(AppTheme.danger)
                                Text("Your notes will stay safely on this device.")
                                    .font(.caption2)
                                    .foregroundStyle(AppTheme.inkSoft)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(AppTheme.muted)
                        }
                        .padding(14)
                        .softCard()
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
        }
        .background(AppTheme.canvas)
        .alert("Set App Lock Passcode", isPresented: $showSetPinAlert) {
            SecureField("Passcode (4+ characters)", text: $pinDraft)
            Button("Enable Lock") {
                let clean = pinDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                if clean.count >= 4 {
                    state.appLockPin = clean
                    state.appLock = true
                    message = "App lock enabled"
                } else {
                    state.appLock = false
                    message = "Passcode must be at least 4 characters"
                }
                pinDraft = ""
            }
            Button("Cancel", role: .cancel) {
                state.appLock = false
                pinDraft = ""
            }
        } message: {
            Text("Enter a passcode that will be required (along with Face ID) to open Smart Notes.")
        }
        .task {
            name = state.user?.fullName ?? ""
            email = state.user?.email ?? ""
            if let p = try? await API.shared.profile() {
                name = p.fullName
                email = p.email
                phone = p.phone ?? ""
            }
        }
    }

    private func saveProfile() async {
        do {
            try await API.shared.send("PUT", "/api/profile", body: ["fullName": name, "email": email, "phone": phone])
            if let id = state.user?.userId {
                state.setUser(AuthUser(userId: id, fullName: name, email: email))
            }
            editing = false
            message = "Profile saved"
        } catch {
            message = error.localizedDescription
        }
    }

    private func changePassword() async {
        guard newPassword == confirmPassword || confirmPassword.isEmpty else {
            message = "Passwords do not match"
            return
        }
        do {
            try await API.shared.send("POST", "/api/profile/password",
                                      body: ["currentPassword": currentPassword, "newPassword": newPassword])
            currentPassword = ""; newPassword = ""; confirmPassword = ""; changing = false
            message = "Password updated"
        } catch {
            message = error.localizedDescription
        }
    }
}
