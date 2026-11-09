//
//  RichTextEditor.swift
//  Smart_Notes_App_ios
//
//  Created by M_Salik_Amin_Kayani on 09/11/2026.
//

import SwiftUI
import UIKit
import Combine

@MainActor
final class RichTextEditorController: ObservableObject {
    weak var textView: UITextView?
    var onHTMLChange: ((String) -> Void)?

    func toggleTrait(_ trait: UIFontDescriptor.SymbolicTraits) {
        guard let view = textView else { return }

        let range = view.selectedRange
        if range.length == 0 {
            var attributes = view.typingAttributes
            let font = attributes[.font] as? UIFont ?? .systemFont(ofSize: 16)
            let traits = font.fontDescriptor.symbolicTraits
            let updated = traits.contains(trait)
                ? traits.subtracting(trait)
                : traits.union(trait)
            let descriptor = font.fontDescriptor.withSymbolicTraits(updated)
                ?? font.fontDescriptor
            attributes[.font] = UIFont(descriptor: descriptor, size: font.pointSize)
            view.typingAttributes = attributes
        } else {
            let attributed = NSMutableAttributedString(attributedString: view.attributedText)
            attributed.enumerateAttribute(.font, in: range) { value, subrange, _ in
                let font = value as? UIFont ?? .systemFont(ofSize: 16)
                let traits = font.fontDescriptor.symbolicTraits
                let updated = traits.contains(trait)
                    ? traits.subtracting(trait)
                    : traits.union(trait)
                let descriptor = font.fontDescriptor.withSymbolicTraits(updated)
                    ?? font.fontDescriptor
                attributed.addAttribute(
                    .font,
                    value: UIFont(descriptor: descriptor, size: font.pointSize),
                    range: subrange
                )
            }
            view.attributedText = attributed
            view.selectedRange = range
        }
        updateHTML()
    }

    func toggleUnderline() {
        guard let view = textView else { return }
        let range = view.selectedRange

        if range.length == 0 {
            var attributes = view.typingAttributes
            let current = attributes[.underlineStyle] as? Int ?? 0
            attributes[.underlineStyle] = current == 0 ? NSUnderlineStyle.single.rawValue : 0
            view.typingAttributes = attributes
        } else {
            let attributed = NSMutableAttributedString(attributedString: view.attributedText)
            let current = attributed.attribute(
                .underlineStyle,
                at: range.location,
                effectiveRange: nil
            ) as? Int ?? 0
            attributed.addAttribute(
                .underlineStyle,
                value: current == 0 ? NSUnderlineStyle.single.rawValue : 0,
                range: range
            )
            view.attributedText = attributed
            view.selectedRange = range
        }
        updateHTML()
    }

    func setFontSize(_ size: CGFloat) {
        guard let view = textView else { return }
        let range = view.selectedRange

        if range.length == 0 {
            var attributes = view.typingAttributes
            let old = attributes[.font] as? UIFont ?? .systemFont(ofSize: 16)
            attributes[.font] = old.withSize(size)
            view.typingAttributes = attributes
        } else {
            let attributed = NSMutableAttributedString(attributedString: view.attributedText)
            attributed.enumerateAttribute(.font, in: range) { value, subrange, _ in
                let old = value as? UIFont ?? .systemFont(ofSize: 16)
                attributed.addAttribute(.font, value: old.withSize(size), range: subrange)
            }
            view.attributedText = attributed
            view.selectedRange = range
        }
        updateHTML()
    }

    func setFontFamily(_ family: String) {
        guard let view = textView else { return }
        let range = view.selectedRange

        func replacingFont(_ old: UIFont) -> UIFont {
            UIFont(name: family, size: old.pointSize) ?? old
        }

        if range.length == 0 {
            var attributes = view.typingAttributes
            let old = attributes[.font] as? UIFont ?? .systemFont(ofSize: 16)
            attributes[.font] = replacingFont(old)
            view.typingAttributes = attributes
        } else {
            let attributed = NSMutableAttributedString(attributedString: view.attributedText)
            attributed.enumerateAttribute(.font, in: range) { value, subrange, _ in
                let old = value as? UIFont ?? .systemFont(ofSize: 16)
                attributed.addAttribute(.font, value: replacingFont(old), range: subrange)
            }
            view.attributedText = attributed
            view.selectedRange = range
        }
        updateHTML()
    }

    func setAlignment(_ alignment: NSTextAlignment) {
        guard let view = textView else { return }
        let range = view.selectedRange
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment

        let attributed = NSMutableAttributedString(attributedString: view.attributedText)
        let target = range.length == 0
            ? NSRange(location: 0, length: attributed.length)
            : range

        guard target.length > 0 else { return }
        attributed.addAttribute(.paragraphStyle, value: paragraph, range: target)
        view.attributedText = attributed
        view.selectedRange = range
        updateHTML()
    }

    func insertBullet() {
        guard let view = textView else { return }
        view.insertText("• ")
        updateHTML()
    }

    func updateHTML() {
        guard let view = textView else { return }

        let range = NSRange(location: 0, length: view.attributedText.length)
        let html: String

        do {
            let data = try view.attributedText.data(
                from: range,
                documentAttributes: [.documentType: NSAttributedString.DocumentType.html]
            )
            html = String(data: data, encoding: .utf8) ?? view.text
        } catch {
            html = view.text
        }

        onHTMLChange?(html)
    }
}

struct RichTextEditor: UIViewRepresentable {
    @Binding var html: String
    let controller: RichTextEditorController

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.backgroundColor = .clear
        view.font = .systemFont(ofSize: 16)
        view.textColor = UIColor(
            red: 23 / 255,
            green: 35 / 255,
            blue: 38 / 255,
            alpha: 1
        )
        view.isScrollEnabled = true
        view.textContainerInset = UIEdgeInsets(top: 16, left: 14, bottom: 16, right: 14)
        view.delegate = context.coordinator

        controller.textView = view
        connectController(context.coordinator)
        context.coordinator.applyHTML(html, to: view)
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        context.coordinator.parent = self
        controller.textView = view
        connectController(context.coordinator)

        if context.coordinator.lastHTML != html {
            context.coordinator.applyHTML(html, to: view)
        }
    }

    private func connectController(_ coordinator: Coordinator) {
        controller.onHTMLChange = { [weak coordinator] value in
            guard let coordinator else { return }
            coordinator.lastHTML = value
            coordinator.parent.html = value
        }
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: RichTextEditor
        var lastHTML = ""

        init(_ parent: RichTextEditor) {
            self.parent = parent
        }

        func applyHTML(_ html: String, to view: UITextView) {
            lastHTML = html

            guard !html.isEmpty else {
                view.attributedText = NSAttributedString(
                    string: "",
                    attributes: [.font: UIFont.systemFont(ofSize: 16)]
                )
                return
            }

            if let data = html.data(using: .utf8),
               let attributed = try? NSAttributedString(
                    data: data,
                    options: [
                        .documentType: NSAttributedString.DocumentType.html,
                        .characterEncoding: String.Encoding.utf8.rawValue
                    ],
                    documentAttributes: nil
               ) {
                view.attributedText = attributed
            } else {
                view.text = html
            }
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.controller.updateHTML()
        }
    }
}
