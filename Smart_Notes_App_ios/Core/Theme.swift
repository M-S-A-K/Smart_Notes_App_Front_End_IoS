//
//  Theme.swift
//  Smart_Notes_App_ios
//
//  Created by M_Salik_Amin_Kayani on 08/11/2026.
//

import SwiftUI
import UIKit

enum AppTheme {
    private static func dynamic(light: String, dark: String) -> Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(Color(hex: dark)) : UIColor(Color(hex: light))
        })
    }

    static let canvas       = dynamic(light: "#f7f9fa", dark: "#0f1719")
    static let surface      = dynamic(light: "#ffffff", dark: "#172326")
    static let surfaceSoft  = dynamic(light: "#f1f5f6", dark: "#1e2d31")
    static let border       = dynamic(light: "#e4eaec", dark: "#2a3c40")
    static let borderStrong = dynamic(light: "#d6e0e3", dark: "#374d52")
    static let ink          = dynamic(light: "#172326", dark: "#f1f7f8")
    static let inkSoft      = dynamic(light: "#607074", dark: "#9cb0b5")
    static let muted        = dynamic(light: "#8a979a", dark: "#6e8287")
    static let accent       = Color(hex: "#35b8c8")
    static let accentHover  = Color(hex: "#27a7b7")
    static let accentSoft   = dynamic(light: "#e8f8fa", dark: "#19383d")
    static let accentSofter = dynamic(light: "#f3fbfc", dark: "#142c30")
    static let danger       = Color(hex: "#d85b5b")
    static let dangerSoft   = dynamic(light: "#fff1f1", dark: "#3b1d1d")

    static let avatarStart  = Color(hex: "#d9f5f8")
    static let avatarEnd    = Color(hex: "#a8e4ea")
    static let avatarText   = Color(hex: "#147d88")
}

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch cleaned.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

struct SoftCardModifier: ViewModifier {
    var radius: CGFloat = 18
    var background: Color = AppTheme.surface
    var borderColor: Color = AppTheme.border

    func body(content: Content) -> some View {
        content
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 3)
    }
}

extension View {
    func softCard(
        radius: CGFloat = 18,
        background: Color = AppTheme.surface,
        borderColor: Color = AppTheme.border
    ) -> some View {
        self.modifier(SoftCardModifier(radius: radius, background: background, borderColor: borderColor))
    }
}
