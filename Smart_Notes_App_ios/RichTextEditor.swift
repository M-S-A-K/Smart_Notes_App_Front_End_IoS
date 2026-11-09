//
//  RichTextEditor.swift
//  Smart_Notes_App_ios
//

import SwiftUI
import UIKit
import Combine

enum RichHTML {
    static let baseSize: CGFloat = 17
    static var ink: UIColor {
        UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 241 / 255, green: 247 / 255, blue: 248 / 255, alpha: 1)
                : UIColor(red: 23 / 255, green: 35 / 255, blue: 38 / 255, alpha: 1)
        }
    }

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

    static let romans = ["i", "ii", "iii", "iv", "v", "vi", "vii", "viii", "ix", "x", "xi", "xii"]

    func toggleTrait(_ trait: UIFontDescriptor.SymbolicTraits) {
        guard let tv = textView else { return }
        if !tv.isFirstResponder { tv.becomeFirstResponder() }
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
        if !tv.isFirstResponder { tv.becomeFirstResponder() }
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
        if !tv.isFirstResponder { tv.becomeFirstResponder() }
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
        if !tv.isFirstResponder { tv.becomeFirstResponder() }
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
        if !tv.isFirstResponder { tv.becomeFirstResponder() }
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

    // Full Multi-line List Support (Bullet, Numbered, Roman, Checklist)
    func applyListStyle(_ kind: String) {
        guard let tv = textView else { return }
        if !tv.isFirstResponder { tv.becomeFirstResponder() }

        let ns = tv.text as NSString
        if ns.length == 0 {
            let firstPrefix: String
            switch kind {
            case "number": firstPrefix = "1. "
            case "roman": firstPrefix = "i. "
            case "checklist": firstPrefix = "☐ "
            default: firstPrefix = "• "
            }
            tv.attributedText = NSAttributedString(string: firstPrefix, attributes: RichHTML.baseAttributes)
            tv.selectedRange = NSRange(location: (firstPrefix as NSString).length, length: 0)
            notifyChange()
            return
        }

        let sel = tv.selectedRange
        let lineRange = ns.lineRange(for: sel)
        let blockText = ns.substring(with: lineRange)
        let hasTrailingNewline = blockText.hasSuffix("\n")
        var lines = blockText.components(separatedBy: "\n")
        if hasTrailingNewline && lines.last == "" {
            lines.removeLast()
        }

        let transformed = lines.enumerated().map { idx, line -> String in
            let stripped = Self.stripExistingListPrefix(from: line)
            let p: String
            switch kind {
            case "number": p = "\(idx + 1). "
            case "roman":
                let r = idx < Self.romans.count ? Self.romans[idx] : "\(idx + 1)"
                p = "\(r). "
            case "checklist": p = "☐ "
            default: p = "• "
            }
            // If user clicked the same list style again on a single line, toggle it off
            if lines.count == 1 && line.hasPrefix(p) {
                return stripped
            }
            return p + stripped
        }.joined(separator: "\n") + (hasTrailingNewline ? "\n" : "")

        let m = NSMutableAttributedString(attributedString: tv.attributedText)
        let replacement = NSAttributedString(string: transformed, attributes: RichHTML.baseAttributes)
        m.replaceCharacters(in: lineRange, with: replacement)
        tv.attributedText = m
        let newCursor = lineRange.location + (transformed as NSString).length - (hasTrailingNewline ? 1 : 0)
        tv.selectedRange = NSRange(location: max(0, newCursor), length: 0)
        notifyChange()
    }

    static func stripExistingListPrefix(from line: String) -> String {
        for p in ["• ", "☐ ", "☑ "] {
            if line.hasPrefix(p) { return String(line.dropFirst(p.count)) }
        }
        if let r = line.range(of: #"^(\d+|[ivx]+)\.\s"#, options: .regularExpression) {
            return String(line[r.upperBound...])
        }
        return line
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
                    Button("• Plain bullet") { controller.applyListStyle("bullet") }
                    Button("1, 2, 3") { controller.applyListStyle("number") }
                    Button("i, ii, iii") { controller.applyListStyle("roman") }
                    Button("☑ Checklist") { controller.applyListStyle("checklist") }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "list.bullet").font(.system(size: 11, weight: .bold))
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

        // Toggle ☐ <-> ☑ when user taps a checklist box, and auto-continue lists on Return!
        func textViewDidChangeSelection(_ textView: UITextView) {
            let sel = textView.selectedRange
            guard sel.length == 0, sel.location > 0 else { return }
            let ns = textView.text as NSString
            let checkRange = NSRange(location: sel.location - 1, length: 1)
            let char = ns.substring(with: checkRange)
            if char == "☐" || char == "☑" {
                let replacement = (char == "☐") ? "☑" : "☐"
                let m = NSMutableAttributedString(attributedString: textView.attributedText)
                m.replaceCharacters(in: checkRange, with: replacement)
                textView.attributedText = m
                textView.selectedRange = NSRange(location: sel.location + 1, length: 0)
                parent.html = RichHTML.html(from: textView.attributedText)
            }
        }

        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            guard text == "\n" else { return true }
            let ns = textView.text as NSString
            let lineRange = ns.lineRange(for: NSRange(location: range.location, length: 0))
            let currentLine = ns.substring(with: lineRange).replacingOccurrences(of: "\n", with: "")

            if let nextPrefix = Self.nextListPrefix(for: currentLine) {
                let stripped = RichTextEditorController.stripExistingListPrefix(from: currentLine)
                let m = NSMutableAttributedString(attributedString: textView.attributedText)
                // If user pressed Return on an empty list item, exit the list cleanly
                if stripped.trimmingCharacters(in: .whitespaces).isEmpty {
                    m.replaceCharacters(in: lineRange, with: NSAttributedString(string: "\n", attributes: RichHTML.baseAttributes))
                    textView.attributedText = m
                    textView.selectedRange = NSRange(location: lineRange.location + 1, length: 0)
                } else {
                    let insertStr = "\n" + nextPrefix
                    m.replaceCharacters(in: range, with: NSAttributedString(string: insertStr, attributes: RichHTML.baseAttributes))
                    textView.attributedText = m
                    textView.selectedRange = NSRange(location: range.location + (insertStr as NSString).length, length: 0)
                }
                parent.html = RichHTML.html(from: textView.attributedText)
                return false
            }
            return true
        }

        private static func nextListPrefix(for line: String) -> String? {
            if line.hasPrefix("• ") { return "• " }
            if line.hasPrefix("☐ ") || line.hasPrefix("☑ ") { return "☐ " }
            if let r = line.range(of: #"^(\d+)\.\s"#, options: .regularExpression) {
                let numStr = line[r].dropLast(2)
                if let n = Int(numStr) { return "\(n + 1). " }
            }
            if let r = line.range(of: #"^([ivx]+)\.\s"#, options: .regularExpression) {
                let rom = String(line[r].dropLast(2))
                if let idx = RichTextEditorController.romans.firstIndex(of: rom),
                   idx + 1 < RichTextEditorController.romans.count {
                    return "\(RichTextEditorController.romans[idx + 1]). "
                }
            }
            return nil
        }
    }
}

struct RichTextView: View {
    let html: String
    var emptyText: String = "No content yet."

    var body: some View {
        if html.plainText.isEmpty {
            if !emptyText.isEmpty {
                Text(emptyText)
                    .foregroundStyle(AppTheme.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            Text(AttributedString(RichHTML.attributed(from: html)))
                .lineSpacing(5)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
