//
//  RichTextEditor.swift
//  Smart_Notes_App_ios
//

import SwiftUI
import UIKit
import Combine

enum RichHTML {
    static let baseSize: CGFloat = 17
    static let ink = UIColor(red: 23 / 255, green: 35 / 255, blue: 38 / 255, alpha: 1)

    static var baseAttributes: [NSAttributedString.Key: Any] {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 5
        return [.font: UIFont.systemFont(ofSize: baseSize), .foregroundColor: ink, .paragraphStyle: style]
    }

    static func html(from text: NSAttributedString) -> String {
        let ns = text.string as NSString
        guard ns.length > 0 else { return "" }
        var out = ""
        var start = 0
        while true {
            let found = ns.range(of: "\n", range: NSRange(location: start, length: ns.length - start))
            let end = found.location == NSNotFound ? ns.length : found.location
            out += paragraph(text, NSRange(location: start, length: end - start))
            if found.location == NSNotFound { break }
            start = end + 1
        }
        return out
    }

    private static func paragraph(_ text: NSAttributedString, _ range: NSRange) -> String {
        guard range.length > 0 else { return "<p><br></p>" }
        var align = ""
        if let p = text.attribute(.paragraphStyle, at: range.location, effectiveRange: nil) as? NSParagraphStyle {
            if p.alignment == .center { align = " style=\"text-align:center\"" }
            if p.alignment == .right { align = " style=\"text-align:right\"" }
        }
        let ns = text.string as NSString
        var inner = ""
        text.enumerateAttributes(in: range) { attrs, r, _ in
            inner += run(attrs, ns.substring(with: r))
        }
        return "<p\(align)>\(inner)</p>"
    }

    private static func run(_ a: [NSAttributedString.Key: Any], _ s: String) -> String {
        var t = s.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
        let font = a[.font] as? UIFont ?? .systemFont(ofSize: baseSize)
        var css = ""
        if abs(font.pointSize - baseSize) > 0.5 { css += "font-size:\(Int(font.pointSize))px;" }
        if font.familyName != UIFont.systemFont(ofSize: baseSize).familyName {
            css += "font-family:'\(font.familyName)';"
        }
        if !css.isEmpty { t = "<span style=\"\(css)\">\(t)</span>" }
        if (a[.strikethroughStyle] as? Int ?? 0) != 0 { t = "<s>\(t)</s>" }
        if (a[.underlineStyle] as? Int ?? 0) != 0 { t = "<u>\(t)</u>" }
        let traits = font.fontDescriptor.symbolicTraits
        if traits.contains(.traitItalic) { t = "<i>\(t)</i>" }
        if traits.contains(.traitBold) { t = "<b>\(t)</b>" }
        return t
    }

    static func attributed(from html: String) -> NSAttributedString {
        let trimmed = html.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.contains("<") && trimmed.contains(">") else {
            return NSAttributedString(string: html, attributes: baseAttributes)
        }
        let result = NSMutableAttributedString()
        var bold = false, italic = false, underline = false, strike = false
        var size = baseSize
        var fontName: String?
        var spans: [(CGFloat, String?)] = []
        var align = NSTextAlignment.left
        var first = true

        func currentFont() -> UIFont {
            var f = fontName.flatMap { UIFont(name: $0, size: size) } ?? UIFont.systemFont(ofSize: size)
            var t: UIFontDescriptor.SymbolicTraits = []
            if bold { t.insert(.traitBold) }
            if italic { t.insert(.traitItalic) }
            if !t.isEmpty, let d = f.fontDescriptor.withSymbolicTraits(t) {
                f = UIFont(descriptor: d, size: size)
            }
            return f
        }

        func add(_ s: String) {
            guard !s.isEmpty else { return }
            let style = NSMutableParagraphStyle()
            style.alignment = align
            style.lineSpacing = 5
            var attrs: [NSAttributedString.Key: Any] = [
                .font: currentFont(),
                .foregroundColor: ink,
                .paragraphStyle: style
            ]
            if underline { attrs[.underlineStyle] = NSUnderlineStyle.single.rawValue }
            if strike { attrs[.strikethroughStyle] = NSUnderlineStyle.single.rawValue }
            result.append(NSAttributedString(string: s, attributes: attrs))
        }

        func handle(_ tag: String) {
            let name = tag.split(separator: " ").first.map { String($0).lowercased() } ?? ""
            switch name {
            case "p", "div", "blockquote":
                if !first { add("\n") }
                first = false
                align = tag.contains("text-align:center") ? .center : tag.contains("text-align:right") ? .right : .left
            case "h1":
                if !first { add("\n") }; first = false; size = 26; bold = true
            case "/h1":
                size = baseSize; bold = false
            case "h2":
                if !first { add("\n") }; first = false; size = 22; bold = true
            case "/h2":
                size = baseSize; bold = false
            case "h3":
                if !first { add("\n") }; first = false; size = 19; bold = true
            case "/h3":
                size = baseSize; bold = false
            case "br":
                add("\n")
            case "li":
                if !first { add("\n") }; first = false; add("• ")
            case "b", "strong": bold = true
            case "/b", "/strong": bold = false
            case "i", "em": italic = true
            case "/i", "/em": italic = false
            case "u": underline = true
            case "/u": underline = false
            case "s", "strike", "del": strike = true
            case "/s", "/strike", "/del": strike = false
            case "span":
                spans.append((size, fontName))
                if let n = number(after: "font-size:", in: tag) { size = n }
                if let f = fontFamily(in: tag) { fontName = f }
            case "/span":
                if let last = spans.popLast() { size = last.0; fontName = last.1 }
            default: break
            }
        }

        var rest = Substring(html)
        while !rest.isEmpty {
            if rest.first == "<", let close = rest.firstIndex(of: ">") {
                handle(String(rest[rest.index(after: rest.startIndex)..<close]))
                rest = rest[rest.index(after: close)...]
            } else {
                var end = rest.firstIndex(of: "<") ?? rest.endIndex
                if end == rest.startIndex { end = rest.index(after: rest.startIndex) }
                add(decode(String(rest[..<end])))
                rest = rest[end...]
            }
        }
        return result
    }

    private static func number(after key: String, in tag: String) -> CGFloat? {
        guard let r = tag.range(of: key) else { return nil }
        let digits = tag[r.upperBound...].prefix { $0.isNumber }
        return Double(digits).map { CGFloat($0) }
    }

    private static func fontFamily(in tag: String) -> String? {
        guard let r = tag.range(of: "font-family:'") else { return nil }
        let rest = tag[r.upperBound...]
        guard let end = rest.firstIndex(of: "'") else { return nil }
        return String(rest[..<end])
    }

    static func decode(_ s: String) -> String {
        s.replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
    }
}

extension String {
    var plainText: String {
        guard contains("<") && contains(">") else { return self }
        var t = replacingOccurrences(of: "<br>", with: " ")
            .replacingOccurrences(of: "</p>", with: " ")
            .replacingOccurrences(of: "</li>", with: " ")
        t = t.replacingOccurrences(of: "<[^>]*(>|$)", with: "", options: .regularExpression)
        return RichHTML.decode(t).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

@MainActor
final class RichTextEditorController: ObservableObject {
    weak var textView: UITextView?
    @Published var blockStyle: String = "Body"
    @Published var fontSizeLabel: String = "Medium"
    @Published var fontFamily: String = "Arial"
    var onHTMLChange: ((String) -> Void)?

    func setHTML(_ html: String) {
        guard let tv = textView else { return }
        let current = RichHTML.html(from: tv.attributedText)
        if current != html {
            tv.attributedText = RichHTML.attributed(from: html)
        }
    }

    func toggleTrait(_ trait: UIFontDescriptor.SymbolicTraits) {
        guard let tv = textView else { return }
        let range = tv.selectedRange
        if range.length > 0 {
            let m = NSMutableAttributedString(attributedString: tv.attributedText)
            m.enumerateAttribute(.font, in: range) { val, r, _ in
                let f = (val as? UIFont) ?? UIFont.systemFont(ofSize: RichHTML.baseSize)
                var traits = f.fontDescriptor.symbolicTraits
                if traits.contains(trait) { traits.remove(trait) } else { traits.insert(trait) }
                if let desc = f.fontDescriptor.withSymbolicTraits(traits) {
                    m.addAttribute(.font, value: UIFont(descriptor: desc, size: f.pointSize), range: r)
                }
            }
            tv.attributedText = m
            tv.selectedRange = range
            notifyChange()
        } else {
            var attrs = tv.typingAttributes
            let f = (attrs[.font] as? UIFont) ?? UIFont.systemFont(ofSize: RichHTML.baseSize)
            var traits = f.fontDescriptor.symbolicTraits
            if traits.contains(trait) { traits.remove(trait) } else { traits.insert(trait) }
            if let desc = f.fontDescriptor.withSymbolicTraits(traits) {
                attrs[.font] = UIFont(descriptor: desc, size: f.pointSize)
                tv.typingAttributes = attrs
            }
        }
    }

    func toggleAttribute(_ key: NSAttributedString.Key) {
        guard let tv = textView else { return }
        let range = tv.selectedRange
        if range.length > 0 {
            let m = NSMutableAttributedString(attributedString: tv.attributedText)
            let existing = (m.attribute(key, at: range.location, effectiveRange: nil) as? Int) ?? 0
            let next = existing == 0 ? NSUnderlineStyle.single.rawValue : 0
            m.addAttribute(key, value: next, range: range)
            tv.attributedText = m
            tv.selectedRange = range
            notifyChange()
        } else {
            var attrs = tv.typingAttributes
            let existing = (attrs[key] as? Int) ?? 0
            attrs[key] = existing == 0 ? NSUnderlineStyle.single.rawValue : 0
            tv.typingAttributes = attrs
        }
    }

    func applyFontSize(_ size: CGFloat, label: String) {
        fontSizeLabel = label
        guard let tv = textView else { return }
        let range = tv.selectedRange
        if range.length > 0 {
            let m = NSMutableAttributedString(attributedString: tv.attributedText)
            m.enumerateAttribute(.font, in: range) { val, r, _ in
                let f = (val as? UIFont) ?? UIFont.systemFont(ofSize: RichHTML.baseSize)
                m.addAttribute(.font, value: f.withSize(size), range: r)
            }
            tv.attributedText = m
            tv.selectedRange = range
            notifyChange()
        } else {
            var attrs = tv.typingAttributes
            let f = (attrs[.font] as? UIFont) ?? UIFont.systemFont(ofSize: RichHTML.baseSize)
            attrs[.font] = f.withSize(size)
            tv.typingAttributes = attrs
        }
    }

    func applyBlockStyle(_ style: String) {
        blockStyle = style
        switch style {
        case "Heading 1": applyFontSize(26, label: "Large"); toggleTrait(.traitBold)
        case "Heading 2": applyFontSize(22, label: "Large"); toggleTrait(.traitBold)
        case "Heading 3": applyFontSize(19, label: "Medium"); toggleTrait(.traitBold)
        case "Quote": toggleTrait(.traitItalic)
        default: applyFontSize(17, label: "Medium")
        }
    }

    func applyFontFamily(_ family: String) {
        fontFamily = family
        guard let tv = textView else { return }
        let range = tv.selectedRange
        let size = ((tv.typingAttributes[.font] as? UIFont)?.pointSize) ?? RichHTML.baseSize
        let chosen = UIFont(name: family, size: size) ?? UIFont.systemFont(ofSize: size)
        if range.length > 0 {
            let m = NSMutableAttributedString(attributedString: tv.attributedText)
            m.addAttribute(.font, value: chosen, range: range)
            tv.attributedText = m
            tv.selectedRange = range
            notifyChange()
        } else {
            var attrs = tv.typingAttributes
            attrs[.font] = chosen
            tv.typingAttributes = attrs
        }
    }

    func applyAlignment(_ alignment: NSTextAlignment) {
        guard let tv = textView else { return }
        let ns = tv.text as NSString
        let lineRange = ns.lineRange(for: tv.selectedRange)
        let m = NSMutableAttributedString(attributedString: tv.attributedText)
        let style = NSMutableParagraphStyle()
        style.alignment = alignment
        style.lineSpacing = 5
        if lineRange.length > 0 {
            m.addAttribute(.paragraphStyle, value: style, range: lineRange)
            let sel = tv.selectedRange
            tv.attributedText = m
            tv.selectedRange = sel
            notifyChange()
        }
        var typing = tv.typingAttributes
        typing[.paragraphStyle] = style
        tv.typingAttributes = typing
    }

    func insertListPrefix(_ prefix: String) {
        guard let tv = textView else { return }
        let ns = tv.text as NSString
        let lineRange = ns.lineRange(for: tv.selectedRange)
        let m = NSMutableAttributedString(attributedString: tv.attributedText)
        m.replaceCharacters(in: NSRange(location: lineRange.location, length: 0),
                            with: NSAttributedString(string: prefix, attributes: RichHTML.baseAttributes))
        tv.attributedText = m
        tv.selectedRange = NSRange(location: lineRange.location + prefix.count, length: 0)
        notifyChange()
    }

    func notifyChange() {
        guard let tv = textView else { return }
        onHTMLChange?(RichHTML.html(from: tv.attributedText))
    }
}

struct FormatBar: View {
    @ObservedObject var controller: RichTextEditorController

    var body: some View {
        VStack(spacing: 6) {
            // Row 1: Style, Size, Font Family (matches mockup)
            HStack(spacing: 6) {
                Menu {
                    ForEach(["Body", "Heading 1", "Heading 2", "Heading 3", "Quote"], id: \.self) { item in
                        Button(item) { controller.applyBlockStyle(item) }
                    }
                } label: {
                    dropdownPill(controller.blockStyle)
                }

                Menu {
                    Button("Small") { controller.applyFontSize(14, label: "Small") }
                    Button("Medium") { controller.applyFontSize(17, label: "Medium") }
                    Button("Large") { controller.applyFontSize(22, label: "Large") }
                } label: {
                    dropdownPill(controller.fontSizeLabel)
                }

                Menu {
                    ForEach(["Arial", "Times New Roman", "Georgia", "Verdana", "Courier New"], id: \.self) { f in
                        Button(f) { controller.applyFontFamily(f) }
                    }
                } label: {
                    dropdownPill(controller.fontFamily)
                }
            }

            // Row 2: B, I, U, S, Alignments, List dropdown
            HStack(spacing: 4) {
                toolButton(label: "B", bold: true) { controller.toggleTrait(.traitBold) }
                toolButton(label: "I", italic: true) { controller.toggleTrait(.traitItalic) }
                toolButton(label: "U", underline: true) { controller.toggleAttribute(.underlineStyle) }
                toolButton(icon: "strikethrough") { controller.toggleAttribute(.strikethroughStyle) }

                Divider().frame(height: 20)

                toolButton(icon: "text.alignleft") { controller.applyAlignment(.left) }
                toolButton(icon: "text.aligncenter") { controller.applyAlignment(.center) }
                toolButton(icon: "text.alignright") { controller.applyAlignment(.right) }

                Divider().frame(height: 20)

                Menu {
                    Button("• Plain bullet") { controller.insertListPrefix("• ") }
                    Button("1, 2, 3") { controller.insertListPrefix("1. ") }
                    Button("i, ii, iii") { controller.insertListPrefix("i. ") }
                    Button("Checklist") { controller.insertListPrefix("☐ ") }
                } label: {
                    HStack(spacing: 4) {
                        Text("List").font(.caption2.bold())
                        Image(systemName: "chevron.down").font(.system(size: 9, weight: .bold))
                    }
                    .foregroundStyle(AppTheme.inkSoft)
                    .padding(.horizontal, 10)
                    .frame(height: 30)
                    .background(AppTheme.surface)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.border))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                Spacer(minLength: 0)
            }
        }
        .padding(8)
        .softCard(radius: 12)
    }

    private func dropdownPill(_ title: String) -> some View {
        HStack {
            Text(title).font(.caption2.bold()).lineLimit(1)
            Spacer(minLength: 2)
            Image(systemName: "chevron.down").font(.system(size: 9, weight: .bold))
        }
        .foregroundStyle(AppTheme.inkSoft)
        .padding(.horizontal, 9)
        .frame(maxWidth: .infinity, minHeight: 32)
        .background(AppTheme.surface)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.border))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func toolButton(
        label: String? = nil,
        icon: String? = nil,
        bold: Bool = false,
        italic: Bool = false,
        underline: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Group {
                if let icon {
                    Image(systemName: icon).font(.system(size: 13, weight: .semibold))
                } else if let label {
                    Text(label)
                        .font(.system(size: 14, weight: bold ? .bold : .semibold))
                        .italic(italic)
                        .underline(underline)
                }
            }
            .foregroundStyle(AppTheme.inkSoft)
            .frame(width: 30, height: 30)
            .background(Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
    }
}

struct RichTextEditor: UIViewRepresentable {
    @Binding var html: String
    @ObservedObject var controller: RichTextEditorController
    var placeholder: String = "Start writing…"

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.backgroundColor = .clear
        tv.isScrollEnabled = true
        tv.font = UIFont.systemFont(ofSize: RichHTML.baseSize)
        tv.textColor = RichHTML.ink
        tv.typingAttributes = RichHTML.baseAttributes
        tv.textContainerInset = UIEdgeInsets(top: 10, left: 4, bottom: 10, right: 4)
        tv.delegate = context.coordinator
        controller.textView = tv
        controller.onHTMLChange = { newHTML in
            if self.html != newHTML {
                self.html = newHTML
            }
        }
        if !html.isEmpty {
            tv.attributedText = RichHTML.attributed(from: html)
        }
        return tv
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        controller.textView = uiView
        if !uiView.isFirstResponder {
            let current = RichHTML.html(from: uiView.attributedText)
            if current != html {
                uiView.attributedText = RichHTML.attributed(from: html)
            }
        }
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: RichTextEditor
        init(_ parent: RichTextEditor) { self.parent = parent }

        func textViewDidChange(_ textView: UITextView) {
            let encoded = RichHTML.html(from: textView.attributedText)
            if parent.html != encoded {
                parent.html = encoded
            }
        }
    }
}

struct RichTextView: View {
    let html: String
    var emptyText: String = "No content yet."

    var body: some View {
        if html.plainText.isEmpty {
            Text(emptyText)
                .foregroundStyle(AppTheme.muted)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Text(AttributedString(RichHTML.attributed(from: html)))
                .lineSpacing(5)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
