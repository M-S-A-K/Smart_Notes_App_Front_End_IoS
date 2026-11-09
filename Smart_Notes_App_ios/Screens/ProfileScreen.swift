//
//  ProfileScreen.swift
//  Smart_Notes_App_ios
//
//  Created by M_Salik_Amin_Kayani on 08/11/2026.
//

import SwiftUI

struct ProfileScreen: View {
    @EnvironmentObject var state: AppState
    @State private var name = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var editing = false
    @State private var changing = false
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var message = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Profile").font(.largeTitle.bold())

                // Hero card
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 14) {
                        Avatar(name: name, size: 64)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(name).font(.title3.bold())
                            Text(phone.isEmpty ? email : "\(email) · \(phone)")
                                .font(.caption).foregroundStyle(AppTheme.inkSoft)
                        }
                    }
                    HStack(spacing: 8) {
                        ShareLink(item: "Add me on Smart Notes: \(email)") {
                            Label("Share profile", systemImage: "square.and.arrow.up")
                                .font(.caption.bold()).frame(maxWidth: .infinity, minHeight: 40)
                                .background(AppTheme.surface).overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.border))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        Button { editing.toggle() } label: {
                            Text(editing ? "Cancel" : "Edit profile")
                                .font(.caption.bold()).frame(maxWidth: .infinity, minHeight: 40)
                                .background(AppTheme.surface).overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.border))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .foregroundStyle(AppTheme.ink)
                }
                .padding(16).frame(maxWidth: .infinity, alignment: .leading).softCard(radius: 20)

                if editing {
                    VStack(spacing: 10) {
                        TextField("Full name", text: $name).textFieldStyle(.roundedBorder)
                        TextField("Email", text: $email).textFieldStyle(.roundedBorder).textInputAutocapitalization(.never)
                        TextField("Phone", text: $phone).textFieldStyle(.roundedBorder)
                        PrimaryButton(title: "Save changes") { Task { await saveProfile() } }
                    }
                    .padding(16).softCard()
                }

                Text("Keep your notes private").font(.headline)
                VStack(spacing: 0) {
                    Toggle(isOn: $state.appLock) { Label("App lock", systemImage: "lock") }
                        .tint(AppTheme.accent).padding(14)
                    Divider()
                    Button { changing.toggle() } label: {
                        HStack { Label("Change password", systemImage: "key"); Spacer(); Image(systemName: "chevron.right") }
                            .padding(14)
                    }
                    .buttonStyle(.plain)
                }
                .softCard()

                if changing {
                    VStack(spacing: 10) {
                        SecureField("Current password", text: $currentPassword).textFieldStyle(.roundedBorder)
                        SecureField("New password", text: $newPassword).textFieldStyle(.roundedBorder)
                        PrimaryButton(title: "Update password") { Task { await changePassword() } }
                    }
                    .padding(16).softCard()
                }

                if !message.isEmpty { Text(message).font(.footnote).foregroundStyle(AppTheme.accentHover) }

                Button(role: .destructive) { state.logout() } label: {
                    Label("Log out", systemImage: "rectangle.portrait.and.arrow.right")
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .softCard()
            }
            .padding(16)
        }
        .background(AppTheme.canvas)
        .task {
            name = state.user?.fullName ?? ""
            email = state.user?.email ?? ""
            if let p = try? await API.shared.profile() { name = p.fullName; email = p.email; phone = p.phone ?? "" }
        }
    }

    private func saveProfile() async {
        do {
            try await API.shared.send("PUT", "/api/profile", body: ["fullName": name, "email": email, "phone": phone])
            if let id = state.user?.userId { state.setUser(AuthUser(userId: id, fullName: name, email: email)) }
            editing = false
            message = "Profile saved"
        } catch { message = error.localizedDescription }
    }

    private func changePassword() async {
        do {
            try await API.shared.send("POST", "/api/profile/password",
                                      body: ["currentPassword": currentPassword, "newPassword": newPassword])
            currentPassword = ""; newPassword = ""; changing = false
            message = "Password updated"
        } catch { message = error.localizedDescription }
    }
}
