//
//  MarkdownSyntaxHighlighter.swift
//  MarkdownEditorKit
//
//  Created by Rouzbeh Abadi on 2026-04-24.
//

import Foundation
import UIKit

/// Applies visual styling to Markdown syntax in a string.
///
/// `MarkdownSyntaxHighlighter` is used by ``MarkdownTextView`` to colorize
/// Markdown constructs while the user is editing. It is also useful on its
/// own — for example, to render a cached preview of a Markdown document
/// without pulling in a full renderer.
///
/// The highlighter does not modify the underlying text; it simply produces
/// an `NSAttributedString` with fonts, colors, and strikethrough attributes
/// applied to matched ranges.
///
/// ```swift
/// let style = MarkdownSyntaxHighlighter.Style(bodyFont: .preferredFont(forTextStyle: .body),
///                                             monospacedFont: .monospacedSystemFont(ofSize: 16, weight: .regular),
///                                             textColor: .label,
///                                             syntaxColor: .secondaryLabel)
/// let attributed = MarkdownSyntaxHighlighter(style: style).highlight("Hello **world**")
/// ```
public struct MarkdownSyntaxHighlighter {

    /// Visual configuration for the highlighter.
    public struct Style {

        /// The font used for plain body text.
        public var bodyFont: UIFont

        /// The font used for inline code and fenced code blocks.
        public var monospacedFont: UIFont

        /// The color applied to body text.
        public var textColor: UIColor

        /// The color applied to Markdown syntax characters.
        public var syntaxColor: UIColor

        /// Creates a style.
        ///
        /// - Parameters:
        ///   - bodyFont: Font used for plain body text.
        ///   - monospacedFont: Font used for inline code and fenced code blocks.
        ///   - textColor: Color applied to body text.
        ///   - syntaxColor: Color applied to Markdown syntax markers.
        public init(bodyFont: UIFont,
                    monospacedFont: UIFont,
                    textColor: UIColor,
                    syntaxColor: UIColor) {
            self.bodyFont = bodyFont
            self.monospacedFont = monospacedFont
            self.textColor = textColor
            self.syntaxColor = syntaxColor
        }
    }

    /// The style applied by this highlighter.
    public let style: Style

    /// Creates a highlighter with the given `style`.
    public init(style: Style) {
        self.style = style
    }

    /// Returns an attributed representation of `text` with Markdown syntax
    /// highlighted according to ``style``.
    ///
    /// The returned string is suitable for direct assignment to a
    /// `UITextView`'s `attributedText` or a SwiftUI `Text(AttributedString(…))`.
    public func highlight(_ text: String) -> NSAttributedString {
        let attributed = NSMutableAttributedString(string: text,
                                                   attributes: [
                                                       .font: style.bodyFont,
                                                       .foregroundColor: style.textColor,
                                                   ])
        for rule in Self.rules {
            apply(rule: rule, to: attributed)
        }
        return attributed
    }

    // MARK: - Rules

    private enum RuleKind {
        case boldItalic
        case bold
        case italic
        case strikethrough
        case inlineCode
        case heading
        case fencedCode
        case listMarker
        case quote
        case link
    }

    private struct Rule {
        let pattern: String
        let kind: RuleKind
        let options: NSRegularExpression.Options
    }

    private static let rules: [Rule] = [
        Rule(pattern: "\\*\\*\\*[^\\*]+?\\*\\*\\*",
             kind: .boldItalic,
             options: []),
        Rule(pattern: "\\*\\*[^\\*]+?\\*\\*",
             kind: .bold,
             options: []),
        Rule(pattern: "(?<!\\*)\\*(?!\\*)[^\\*\\n]+?\\*(?!\\*)",
             kind: .italic,
             options: []),
        Rule(pattern: "~~[^~]+?~~",
             kind: .strikethrough,
             options: []),
        Rule(pattern: "`[^`\\n]+?`",
             kind: .inlineCode,
             options: []),
        Rule(pattern: "^#{1,6} .*$",
             kind: .heading,
             options: [.anchorsMatchLines]),
        Rule(pattern: "```[\\s\\S]*?```",
             kind: .fencedCode,
             options: []),
        Rule(pattern: "^\\s*(?:[-*+]|\\d+\\.) ",
             kind: .listMarker,
             options: [.anchorsMatchLines]),
        Rule(pattern: "^> .*$",
             kind: .quote,
             options: [.anchorsMatchLines]),
        Rule(pattern: "\\[[^\\]]+\\]\\([^\\)]+\\)",
             kind: .link,
             options: []),
    ]

    private func apply(rule: Rule, to attributed: NSMutableAttributedString) {
        let fullRange = NSRange(location: 0, length: attributed.length)
        guard let regex = try? NSRegularExpression(pattern: rule.pattern, options: rule.options) else {
            return
        }
        regex.enumerateMatches(in: attributed.string, range: fullRange) { match, _, _ in
            guard let match else { return }
            apply(kind: rule.kind, range: match.range, string: attributed.string, to: attributed)
        }
    }

    private func apply(kind: RuleKind,
                       range: NSRange,
                       string: String,
                       to attributed: NSMutableAttributedString) {
        switch kind {
        case .boldItalic:
            attributed.addAttribute(.font, value: font(bold: true, italic: true), range: range)
        case .bold:
            attributed.addAttribute(.font, value: font(bold: true, italic: false), range: range)
        case .italic:
            attributed.addAttribute(.font, value: font(bold: false, italic: true), range: range)
        case .strikethrough:
            attributed.addAttributes([
                                         .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                                         .strikethroughColor: style.textColor,
                                     ],
                                     range: range)
        case .inlineCode, .fencedCode:
            attributed.addAttribute(.font, value: style.monospacedFont, range: range)
        case .heading:
            let snippet = (string as NSString).substring(with: range)
            let level = snippet.prefix { $0 == "#" }.count
            attributed.addAttribute(.font, value: headingFont(for: level), range: range)
        case .listMarker, .quote:
            attributed.addAttribute(.foregroundColor, value: style.syntaxColor, range: range)
        case .link:
            attributed.addAttributes([
                                         .foregroundColor: UIColor.systemBlue,
                                         .underlineStyle: NSUnderlineStyle.single.rawValue,
                                     ],
                                     range: range)
        }
    }

    // MARK: - Font helpers

    private func font(bold: Bool, italic: Bool) -> UIFont {
        var traits: UIFontDescriptor.SymbolicTraits = []
        if bold { traits.insert(.traitBold) }
        if italic { traits.insert(.traitItalic) }
        guard !traits.isEmpty,
              let descriptor = style.bodyFont.fontDescriptor.withSymbolicTraits(traits)
        else {
            return style.bodyFont
        }
        return UIFont(descriptor: descriptor, size: style.bodyFont.pointSize)
    }

    private func headingFont(for level: Int) -> UIFont {
        let scale: CGFloat = switch level {
        case 1: 1.6
        case 2: 1.4
        case 3: 1.25
        case 4: 1.15
        case 5: 1.08
        default: 1.0
        }
        let size = style.bodyFont.pointSize * scale
        let descriptor = style.bodyFont.fontDescriptor.withSymbolicTraits(.traitBold)
            ?? style.bodyFont.fontDescriptor
        return UIFont(descriptor: descriptor, size: size)
    }
}
