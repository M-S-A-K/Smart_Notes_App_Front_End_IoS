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
                        Button { editing.toggle() } label: {
                            Text(editing ? "Cancel" : "Edit profile")
                                .font(.caption.bold())
                                .frame(maxWidth: .infinity, minHeight: 40)
                                .background(AppTheme.surface)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.border))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .foregroundStyle(AppTheme.ink)
                }
                .padding(18)
                .softCard(radius: 20)

                // Expandable Share Profile Link Card (matches mockup page 22)
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
                    .softCard(radius: 17, background: AppTheme.accentSofter, borderColor: Color(hex: "#cfecef"))
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
                            Toggle("", isOn: $state.appLock)
                                .labelsHidden()
                                .tint(AppTheme.accent)
                        }
                        .padding(14)

                        Divider()

                        Button { changing.toggle() } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "lock")
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
