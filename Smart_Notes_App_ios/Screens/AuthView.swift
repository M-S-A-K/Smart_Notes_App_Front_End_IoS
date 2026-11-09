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
    @State private var password = ""
    @State private var error = ""
    @State private var loading = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Image(systemName: "note.text")
                    .font(.title).foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(AppTheme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                Text(isLogin ? "Log in to your notes" : "Create your account")
                    .font(.largeTitle.bold())

                if !isLogin { AppTextField(placeholder: "Full name", text: $name) }
                AppTextField(title: "Email", text: $email)
                AppTextField(title: "Password", text: $password, secure: true)

                if !error.isEmpty {
                    Text(error).font(.footnote).foregroundStyle(AppTheme.danger)
                }

                PrimaryButton(title: isLogin ? "Log in" : "Create account", loading: loading) {
                    Task { await submit() }
                }

                Button(isLogin ? "New here? Create account" : "Have an account? Log in") {
                    isLogin.toggle()
                    error = ""
                }
                .font(.subheadline.bold())
                .foregroundStyle(AppTheme.accentHover)
                .frame(maxWidth: .infinity)
            }
            .padding(24)
        }
        .background(AppTheme.canvas)
    }

    private func submit() async {
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
