//
//  SharedComponents.swift
//  Smart_Notes_App_ios
//
//  Created by M_Salik_Amin_Kayani on 08/11/2026.
//


import SwiftUI

struct AppTextField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var isSecure = false
    @State private var showPassword = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.caption.bold()).foregroundStyle(AppTheme.ink)
            HStack {
                if isSecure && !showPassword {
                    SecureField(placeholder, text: $text)
                        .textInputAutocapitalization(.never)
                } else {
                    TextField(placeholder, text: $text)
                        .textInputAutocapitalization(.never)
                }
                if isSecure {
                    Button { showPassword.toggle() } label: {
                        Image(systemName: showPassword ? "eye.slash" : "eye")
                            .foregroundStyle(AppTheme.muted)
                    }
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 48)
            .background(AppTheme.surface)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.borderStrong))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

struct PrimaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.bold())
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 46)
                .background(AppTheme.accent)
                .clipShape(RoundedRectangle(cornerRadius: 13))
                .shadow(color: AppTheme.accent.opacity(0.26), radius: 7, y: 4)
        }
    }
}

struct EmptyState: View {
    let icon: String
    let title: String
    let text: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(AppTheme.accentHover)
                .frame(width: 58, height: 58)
                .background(AppTheme.accentSoft)
                .clipShape(RoundedRectangle(cornerRadius: 18))
            Text(title).font(.headline).foregroundStyle(AppTheme.ink)
            Text(text)
                .font(.caption)
                .foregroundStyle(AppTheme.inkSoft)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
        }
        .padding(28)
    }
}

struct Card<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .heavy))
                .foregroundStyle(AppTheme.accentHover)
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
        let parts = name.split(separator: " ").prefix(2).compactMap { $0.first }.map(String.init).joined()
        return parts.isEmpty ? "SN" : parts.uppercased()
    }

    var body: some View {
        Text(initials)
            .font(.system(size: size * 0.32, weight: .heavy))
            .foregroundStyle(AppTheme.avatarText)
            .frame(width: size, height: size)
            .background(
                LinearGradient(
                    colors: [AppTheme.avatarStart, AppTheme.avatarEnd],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(Circle())
    }
}

struct QuickCard: View {
    let icon: String
    let title: String
    var highlight = false

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3.weight(.semibold))
                .foregroundStyle(highlight ? .white : AppTheme.accentHover)
                .frame(width: 40, height: 40)
                .background(highlight ? AppTheme.accent : AppTheme.accentSoft)
                .clipShape(RoundedRectangle(cornerRadius: 13))
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(AppTheme.ink)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .softCard(
            radius: 20,
            background: highlight ? AppTheme.accentSofter : AppTheme.surface,
            borderColor: highlight ? AppTheme.accent.opacity(0.35) : AppTheme.border
        )
    }
}

struct ActionPill: View {
    let icon: String
    let text: String
    var filled = false
    var onClear: (() -> Void)? = nil
    let action: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Button(action: action) {
                HStack(spacing: 6) {
                    Image(systemName: icon).font(.caption.bold())
                    Text(text).font(.caption.bold()).lineLimit(1)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 11)
                .frame(maxWidth: .infinity, minHeight: 38)
            }
            if filled, let onClear {
                Divider().frame(height: 22)
                Button(action: onClear) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(AppTheme.muted)
                        .frame(width: 32, height: 38)
                }
            }
        }
        .foregroundStyle(filled ? AppTheme.accentHover : AppTheme.inkSoft)
        .background(filled ? AppTheme.accentSofter : AppTheme.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 11)
                .stroke(filled ? AppTheme.accent.opacity(0.4) : AppTheme.border)
        )
        .clipShape(RoundedRectangle(cornerRadius: 11))
    }
}

struct MapPreviewCard: View {
    let placeName: String
    let subLocation: String?

    private var displayTitle: String {
        if let sub = subLocation, !sub.isEmpty {
            return "\(placeName) — \(sub)"
        }
        return placeName
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color(hex: "#edf4f4")

            // Stylized road lines matching mockup
            Rectangle()
                .fill(Color.white.opacity(0.85))
                .frame(height: 9)
                .rotationEffect(.degrees(-8))
                .offset(y: -4)

            Rectangle()
                .fill(Color.white.opacity(0.75))
                .frame(height: 8)
                .rotationEffect(.degrees(52))
                .offset(x: 20, y: -10)

            RoundedRectangle(cornerRadius: 5)
                .fill(Color(hex: "#d9e7e8"))
                .frame(width: 46, height: 24)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(12)

            // Pin badge
            ZStack {
                Circle()
                    .fill(AppTheme.accent)
                    .frame(width: 30, height: 30)
                    .shadow(color: AppTheme.accent.opacity(0.35), radius: 5, y: 3)
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding(.leading, 26)
            .padding(.bottom, 10)

            // Label card
            VStack(alignment: .leading, spacing: 2) {
                Text(displayTitle)
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(1)
                Text((subLocation?.isEmpty == false) ? "\(placeName) · Indoor location" : "Saved location")
                    .font(.system(size: 9))
                    .foregroundStyle(AppTheme.muted)
                    .lineLimit(1)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(AppTheme.surface.opacity(0.95))
            .clipShape(RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(AppTheme.border))
            .padding(8)
        }
        .frame(maxWidth: .infinity, minHeight: 92, maxHeight: 92)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: "#dbe7e9")))
    }
}

struct ReminderPreviewCard: View {
    let title: String
    let remindAt: String
    var leadText: String = "30 min before"
    var onAddToCalendar: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "clock")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppTheme.accentHover)
                .frame(width: 32, height: 32)
                .background(AppTheme.accentSoft)
                .clipShape(RoundedRectangle(cornerRadius: 9))

            VStack(alignment: .leading, spacing: 2) {
                Text("REMINDER")
                    .font(.system(size: 8, weight: .heavy))
                    .foregroundStyle(AppTheme.accentHover)
                Text(remindAt.niceTime)
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(2)
                Text("Notification \(leadText.lowercased())")
                    .font(.system(size: 9))
                    .foregroundStyle(AppTheme.inkSoft)
                    .lineLimit(1)
                if let onAddToCalendar {
                    Button("Add to calendar", action: onAddToCalendar)
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundStyle(AppTheme.accentHover)
                        .padding(.top, 2)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(11)
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
        .softCard(radius: 14, background: AppTheme.accentSofter, borderColor: Color(hex: "#cce9ed"))
    }
}
