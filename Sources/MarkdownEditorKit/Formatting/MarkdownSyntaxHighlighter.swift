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

        /// When `true`, Markdown syntax markers are collapsed to a
        /// near-zero font size and rendered transparently, so the editor
        /// shows only the rendered content while still editing the raw
        /// Markdown source. Use this together with the highlighter's
        /// other attributes to drive a WYSIWYG-style live edit.
        public var hidesMarkers: Bool

        /// Creates a style.
        ///
        /// - Parameters:
        ///   - bodyFont: Font used for plain body text.
        ///   - monospacedFont: Font used for inline code and fenced code blocks.
        ///   - textColor: Color applied to body text.
        ///   - syntaxColor: Color applied to Markdown syntax markers.
        ///   - hidesMarkers: When `true`, Markdown syntax markers are
        ///     collapsed so only rendered content is visible. Defaults to
        ///     `false`.
        public init(bodyFont: UIFont,
                    monospacedFont: UIFont,
                    textColor: UIColor,
                    syntaxColor: UIColor,
                    hidesMarkers: Bool = false) {
            self.bodyFont = bodyFont
            self.monospacedFont = monospacedFont
            self.textColor = textColor
            self.syntaxColor = syntaxColor
            self.hidesMarkers = hidesMarkers
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
        case taskListMarker
        case listMarker
        case quote
        case horizontalRule
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
        // Task-list prefix must come before the generic list marker so its
        // full `- [ ] ` / `- [x] ` span is treated as a single marker span
        // when hiding, rather than only the leading `- ` dash.
        Rule(pattern: "^\\s*-\\s\\[[ xX]\\]\\s",
             kind: .taskListMarker,
             options: [.anchorsMatchLines]),
        Rule(pattern: "^\\s*(?:[-*+]|\\d+\\.) ",
             kind: .listMarker,
             options: [.anchorsMatchLines]),
        Rule(pattern: "^> ",
             kind: .quote,
             options: [.anchorsMatchLines]),
        Rule(pattern: "^-{3,}$",
             kind: .horizontalRule,
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
        case .listMarker, .taskListMarker, .quote:
            attributed.addAttribute(.foregroundColor, value: style.syntaxColor, range: range)
        case .horizontalRule:
            if style.hidesMarkers {
                // In rich mode the raw `---` glyphs are painted
                // transparent so they still occupy a line's vertical
                // space; the visible full-width rule is drawn as a 1 pt
                // overlay by the hosting text view.
                attributed.addAttribute(.foregroundColor, value: UIColor.clear, range: range)
            } else {
                attributed.addAttribute(.foregroundColor, value: style.syntaxColor, range: range)
            }
        case .link:
            var attributes: [NSAttributedString.Key: Any] = [
                .foregroundColor: UIColor.systemBlue,
                .underlineStyle: NSUnderlineStyle.single.rawValue,
            ]
            if let url = extractLinkURL(from: range, in: string) {
                attributes[.link] = url
            }
            attributed.addAttributes(attributes, range: range)
        }

        if style.hidesMarkers {
            for markerRange in markerRanges(for: kind, in: range, within: string) {
                hide(range: markerRange, in: attributed)
            }
        }
    }

    // MARK: - Marker hiding

    /// Collapses `range` visually so its glyphs take near-zero horizontal
    /// space and are rendered transparently. The underlying characters
    /// remain, so edits still round-trip through the raw Markdown source.
    private func hide(range: NSRange, in attributed: NSMutableAttributedString) {
        attributed.addAttributes([
                                     .font: Self.hiddenFont,
                                     .foregroundColor: UIColor.clear,
                                 ],
                                 range: range)
    }

    private static let hiddenFont = UIFont.systemFont(ofSize: 0.01)

    /// Returns the sub-ranges of `range` that hold Markdown syntax markers
    /// (the characters a renderer would strip), so they can be collapsed
    /// in rich-edit mode.
    private func markerRanges(for kind: RuleKind,
                              in range: NSRange,
                              within string: String) -> [NSRange] {
        switch kind {
        case .boldItalic:
            return wrappingMarkers(in: range, openLength: 3, closeLength: 3)
        case .bold, .strikethrough:
            return wrappingMarkers(in: range, openLength: 2, closeLength: 2)
        case .italic, .inlineCode:
            return wrappingMarkers(in: range, openLength: 1, closeLength: 1)
        case .heading:
            let snippet = (string as NSString).substring(with: range)
            let hashes = snippet.prefix { $0 == "#" }.count
            let prefixLength = hashes + (snippet.dropFirst(hashes).first == " " ? 1 : 0)
            return [NSRange(location: range.location, length: prefixLength)]
        case .listMarker, .taskListMarker, .quote, .horizontalRule:
            // Block markers have no visual substitute the way inline markers
            // inherit body font or headings inherit heading font — hiding
            // them leaves bullets/numbers/checkboxes/dividers invisible, so
            // we keep them visible and syntax-coloured in rich mode too.
            return []
        case .link:
            return linkMarkerRanges(in: range, within: string)
        case .fencedCode:
            return fencedCodeMarkerRanges(in: range, within: string)
        }
    }

    private func wrappingMarkers(in range: NSRange,
                                 openLength: Int,
                                 closeLength: Int) -> [NSRange] {
        guard range.length >= openLength + closeLength else { return [] }
        let open = NSRange(location: range.location, length: openLength)
        let close = NSRange(location: range.location + range.length - closeLength,
                            length: closeLength)
        return [open, close]
    }

    private func linkMarkerRanges(in range: NSRange, within string: String) -> [NSRange] {
        // Match `[title](url)` — hide `[`, and the `](url)` tail.
        let snippet = (string as NSString).substring(with: range) as NSString
        let closeBracket = snippet.range(of: "](")
        guard closeBracket.location != NSNotFound else { return [] }
        let open = NSRange(location: range.location, length: 1)
        let tailLocation = range.location + closeBracket.location
        let tailLength = range.length - closeBracket.location
        return [open, NSRange(location: tailLocation, length: tailLength)]
    }

    /// Pulls the URL out of a `[text](url)` match so we can attach it as the
    /// `.link` attribute. UITextView uses that attribute to make the range
    /// tappable in preview mode (auto-handled when `isEditable == false`)
    /// and source mode (handled by an explicit tap gesture recogniser).
    private func extractLinkURL(from range: NSRange, in string: String) -> URL? {
        let snippet = (string as NSString).substring(with: range) as NSString
        let bracket = snippet.range(of: "](")
        guard bracket.location != NSNotFound else { return nil }
        let urlStart = bracket.location + bracket.length
        let urlLength = snippet.length - urlStart - 1   // strip trailing ')'
        guard urlLength > 0 else { return nil }
        let urlString = snippet.substring(with: NSRange(location: urlStart, length: urlLength))
        return LinkURL.normalize(urlString)
    }

    private func fencedCodeMarkerRanges(in range: NSRange, within string: String) -> [NSRange] {
        // Hide the opening fence line and the closing fence line but keep the
        // body visible and monospaced.
        let snippet = (string as NSString).substring(with: range) as NSString
        var markers: [NSRange] = []

        let firstNewline = snippet.range(of: "\n")
        if firstNewline.location != NSNotFound {
            markers.append(NSRange(location: range.location, length: firstNewline.location + 1))
        } else {
            markers.append(range)
            return markers
        }

        let trailingFence = snippet.range(of: "\n```", options: .backwards)
        if trailingFence.location != NSNotFound {
            let tailLocation = range.location + trailingFence.location
            let tailLength = range.length - trailingFence.location
            markers.append(NSRange(location: tailLocation, length: tailLength))
        }

        return markers
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
