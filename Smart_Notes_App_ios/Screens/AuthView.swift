//
//  AuthViews.swift
//  Smart_Notes_App_ios
//
//  Created by M_Salik_Amin_Kayani on 08/11/2026.
//

import SwiftUI

struct AuthView: View {
    @EnvironmentObject var state: AppState
    @State private var isLogin = true
    @State private var name = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var error = ""
    @State private var loading = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Top Logo (or Back to login when creating an account)
                if isLogin {
                    HStack(spacing: 10) {
                        Image(systemName: "doc.text")
                            .font(.subheadline.bold())
                            .foregroundStyle(.white)
                            .frame(width: 35, height: 35)
                            .background(AppTheme.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 11))
                        Text("Smart Notes")
                            .font(.headline.bold())
                            .foregroundStyle(AppTheme.ink)
                    }
                    .padding(.bottom, 10)
                } else {
                    Button {
                        isLogin = true
                        error = ""
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                            Text("Back to login")
                        }
                        .font(.footnote.bold())
                        .foregroundStyle(AppTheme.inkSoft)
                    }
                    .padding(.bottom, 6)
                }

                // Heading
                VStack(alignment: .leading, spacing: 6) {
                    Text(isLogin ? "WELCOME BACK" : "GET STARTED")
                        .font(.system(size: 11, weight: .heavy))
                        .kerning(1.1)
                        .foregroundStyle(AppTheme.accentHover)

                    Text(isLogin ? "Log in to your notes" : "Create your account")
                        .font(.largeTitle.bold())
                        .foregroundStyle(AppTheme.ink)

                    Text(isLogin
                         ? "Your ideas are right where you left them."
                         : "A simple home for notes, reminders, and conversations.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.inkSoft)
                }
                .padding(.bottom, 4)

                // Form Fields
                if isLogin {
                    AppTextField(
                        label: "Email or phone number",
                        placeholder: "you@example.com or +1 415 555 0100",
                        text: $email
                    )
                    AppTextField(
                        label: "Password",
                        placeholder: "Enter your password",
                        text: $password,
                        isSecure: true
                    )
                } else {
                    AppTextField(
                        label: "Full name",
                        placeholder: "Your name",
                        text: $name
                    )
                    AppTextField(
                        label: "Email address",
                        placeholder: "you@example.com",
                        text: $email
                    )
                    AppTextField(
                        label: "Phone number",
                        placeholder: "+1 415 555 0100",
                        text: $phone
                    )
                    AppTextField(
                        label: "Password",
                        placeholder: "6+ characters",
                        text: $password,
                        isSecure: true
                    )
                    AppTextField(
                        label: "Confirm",
                        placeholder: "Repeat password",
                        text: $confirmPassword,
                        isSecure: true
                    )
                }

                if !error.isEmpty {
                    Text(error)
                        .font(.footnote.bold())
                        .foregroundStyle(AppTheme.danger)
                }

                PrimaryButton(title: isLogin ? "Log in" : "Create account", loading: loading) {
                    Task { await submit() }
                }
                .padding(.top, 4)

                // Switch Mode Link
                HStack(spacing: 4) {
                    Spacer()
                    Text(isLogin ? "New to Smart Notes?" : "Already have an account?")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.inkSoft)
                    Button(isLogin ? "Create account" : "Log in") {
                        isLogin.toggle()
                        error = ""
                    }
                    .font(.footnote.bold())
                    .foregroundStyle(AppTheme.accentHover)
                    Spacer()
                }
                .padding(.top, 4)
            }
            .padding(24)
        }
        .background(AppTheme.surface)
    }

    private func submit() async {
        if !isLogin && !confirmPassword.isEmpty && password != confirmPassword {
            error = "Passwords do not match"
            return
        }
        loading = true
        error = ""
        do {
            if isLogin {
                try await state.login(email: email, password: password)
            } else {
                try await state.register(name: name, email: email, password: password)
            }
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
    }
}
