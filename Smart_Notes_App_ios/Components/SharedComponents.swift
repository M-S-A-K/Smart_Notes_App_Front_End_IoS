//
//  SharedComponents.swift
//  Smart_Notes_App_ios
//
//  Created by M_Salik_Amin_Kayani on 08/11/2026.
//

import SwiftUI

struct PrimaryButton: View {
    let title: String
    var loading = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if loading { ProgressView().tint(.white) } else { Text(title).fontWeight(.bold) }
            }
            .frame(maxWidth: .infinity, minHeight: 48)
            .foregroundStyle(.white)
            .background(AppTheme.accent)
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        }
        .disabled(loading)
    }
}

struct AppTextField: View {
    let title: String
    @Binding var text: String
    var secure = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.footnote.bold())
            Group {
                if secure { SecureField("", text: $text) } else { TextField("", text: $text) }
            }
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .padding(.horizontal, 14)
            .frame(height: 48)
            .background(AppTheme.surface)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.borderStrong))
        }
    }
}

struct EmptyState: View {
    let icon: String
    let title: String
    let text: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon).font(.largeTitle).foregroundStyle(AppTheme.accent)
            Text(title).font(.headline)
            Text(text).font(.subheadline).foregroundStyle(AppTheme.inkSoft).multilineTextAlignment(.center)
        }
        .padding(30)
    }
}

struct ComingSoon: View {
    let name: String
    var body: some View { EmptyState(icon: "hammer", title: name, text: "Coming in the next batch") }
}

struct Card<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.subheadline.bold()).foregroundStyle(AppTheme.accentHover)
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .softCard()
    }
}

struct Avatar: View {
    let name: String
    var size: CGFloat = 42

    private var initials: String {
        name.split(separator: " ").prefix(2).compactMap { $0.first }.map(String.init).joined()
    }

    var body: some View {
        Text(initials)
            .font(.system(size: size * 0.32, weight: .heavy))
            .foregroundStyle(AppTheme.avatarText)
            .frame(width: size, height: size)
            .background(LinearGradient(colors: [AppTheme.avatarStart, AppTheme.avatarEnd],
                                       startPoint: .topLeading, endPoint: .bottomTrailing))
            .clipShape(Circle())
    }
}

struct QuickCard: View {
    let icon: String
    let title: String
    var highlight = false

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon).font(.title3)
                .foregroundStyle(highlight ? .white : AppTheme.accentHover)
                .frame(width: 42, height: 42)
                .background(highlight ? AppTheme.accent : AppTheme.accentSoft)
                .clipShape(RoundedRectangle(cornerRadius: 13))
            Text(title).font(.caption.bold()).foregroundStyle(AppTheme.ink)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .softCard(radius: 20)
    }
}


struct ActionPill: View {
    let icon: String
    let text: String
    var filled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(text, systemImage: icon)
                .font(.caption.bold()).lineLimit(1)
                .frame(maxWidth: .infinity, minHeight: 38)
                .foregroundStyle(filled ? AppTheme.accentHover : AppTheme.inkSoft)
                .background(filled ? AppTheme.accentSofter : AppTheme.surface)
                .overlay(RoundedRectangle(cornerRadius: 11).stroke(filled ? AppTheme.accent.opacity(0.4) : AppTheme.border))
                .clipShape(RoundedRectangle(cornerRadius: 11))
        }
    }
}
