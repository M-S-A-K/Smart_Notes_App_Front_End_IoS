//
//  Theme.swift
//  Smart_Notes_App_ios
//
//  Created by M_Salik_Amin_Kayani on 08/11/2026.
//

import SwiftUI

enum AppTheme {
    // Exact CSS Variables from index.css
    static let canvas       = Color(hex: "#f7f9fa")
    static let surface      = Color(hex: "#ffffff")
    static let surfaceSoft  = Color(hex: "#f1f5f6")
    static let border       = Color(hex: "#e4eaec")
    static let borderStrong = Color(hex: "#d6e0e3")
    static let ink          = Color(hex: "#172326")
    static let inkSoft      = Color(hex: "#607074")
    static let muted        = Color(hex: "#8a979a")
    static let accent       = Color(hex: "#35b8c8")
    static let accentHover  = Color(hex: "#27a7b7")
    static let accentSoft   = Color(hex: "#e8f8fa")
    static let accentSofter = Color(hex: "#f3fbfc")
    static let danger       = Color(hex: "#d85b5b")
    static let dangerSoft   = Color(hex: "#fff1f1")
    
    // Avatar Gradient (#d9f5f8 -> #a8e4ea, text #147d88)
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
            .shadow(color: Color(hex: "#224146").opacity(0.06), radius: 10, x: 0, y: 4)
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
