//
//  MarkdownRenderer.swift
//  MarkdownEditorKit
//
//  Created by Rouzbeh Abadi on 2026-04-24.
//

import Foundation
import UIKit

/// Produces a rendered `NSAttributedString` from Markdown source, with
/// syntax markers hidden.
///
/// Where ``MarkdownSyntaxHighlighter`` keeps the text byte-for-byte
/// identical and only *adds* visual attributes, `MarkdownRenderer`
/// performs a transformation: `**bold**` becomes `bold` in a bold font,
/// `# Heading` becomes `Heading` in a larger bold font, bullet prefixes
/// turn into glyphs, and so on. The resulting attributed string is
/// suitable for read-only display — for example in the ``preview`` mode
/// of ``MarkdownEditor``.
///
/// The renderer deliberately handles only the Markdown constructs the
/// rest of the kit can create. Nested or exotic syntax (footnotes,
/// tables, HTML) is passed through verbatim.
///
/// ```swift
/// let style = MarkdownRenderer.Style(bodyFont: .preferredFont(forTextStyle: .body),
///                                    monospacedFont: .monospacedSystemFont(ofSize: 16, weight: .regular),
///                                    textColor: .label,
///                                    syntaxColor: .secondaryLabel)
/// let attributed = MarkdownRenderer(style: style).render("# Hello\n\nIt's **working**.")
/// ```
public struct MarkdownRenderer {

    /// Visual configuration for the renderer.
    public struct Style {

        /// The font used for plain body text.
        public var bodyFont: UIFont

        /// The font used for inline code and fenced code blocks.
        public var monospacedFont: UIFont

        /// The color applied to body text.
        public var textColor: UIColor

        /// The color applied to secondary chrome such as list markers,
        /// block-quote bars, and horizontal rules.
        public var syntaxColor: UIColor

        /// The color applied to hyperlink text.
        public var linkColor: UIColor

        /// Creates a style.
        public init(bodyFont: UIFont,
                    monospacedFont: UIFont,
                    textColor: UIColor,
                    syntaxColor: UIColor,
                    linkColor: UIColor = .systemBlue) {
            self.bodyFont = bodyFont
            self.monospacedFont = monospacedFont
            self.textColor = textColor
            self.syntaxColor = syntaxColor
            self.linkColor = linkColor
        }
    }

    /// The style applied by this renderer.
    public let style: Style

    /// Creates a renderer with the given `style`.
    public init(style: Style) {
        self.style = style
    }

    /// Renders `text` as an attributed string with Markdown syntax
    /// markers removed and their formatting applied.
    public func render(_ text: String) -> NSAttributedString {
        let output = NSMutableAttributedString()
        var insideFence = false

        for line in text.components(separatedBy: "\n") {
            if line.hasPrefix("```") {
                insideFence.toggle()
                continue
            }
            if output.length > 0 {
                output.append(NSAttributedString(string: "\n"))
            }
            if insideFence {
                output.append(NSAttributedString(string: line, attributes: [
                    .font: style.monospacedFont,
                    .foregroundColor: style.textColor,
                ]))
            } else {
                output.append(renderLine(line))
            }
        }
        return output
    }

    // MARK: - Block rendering

    private func renderLine(_ line: String) -> NSAttributedString {
        if line == "---" || line == "***" || line == "___" {
            return horizontalRuleAttachmentString()
        }
        if let match = line.firstMatch(of: #/^(#{1,6}) (.*)$/#) {
            let level = match.output.1.count
            return renderInline(String(match.output.2), font: headingFont(level: level))
        }
        if let match = line.firstMatch(of: #/^- \[([ xX])\] (.*)$/#) {
            let checked = match.output.1 != " "
            return prefixed(marker: checked ? "☑︎ " : "☐ ",
                            content: String(match.output.2))
        }
        if let match = line.firstMatch(of: #/^[-*+] (.*)$/#) {
            return prefixed(marker: "•  ", content: String(match.output.1))
        }
        if let match = line.firstMatch(of: #/^(\d+)\. (.*)$/#) {
            return prefixed(marker: "\(match.output.1). ", content: String(match.output.2))
        }
        if let match = line.firstMatch(of: #/^> (.*)$/#) {
            let bar = NSAttributedString(string: "│  ",
                                         attributes: [
                                             .font: style.bodyFont,
                                             .foregroundColor: style.syntaxColor,
                                         ])
            let body = renderInline(String(match.output.1),
                                    font: style.bodyFont,
                                    color: style.syntaxColor)
            return join(bar, body)
        }
        return renderInline(line, font: style.bodyFont)
    }

    private func prefixed(marker: String, content: String) -> NSAttributedString {
        let markerAttributed = NSAttributedString(string: marker,
                                                  attributes: [
                                                      .font: style.bodyFont,
                                                      .foregroundColor: style.syntaxColor,
                                                  ])
        return join(markerAttributed, renderInline(content, font: style.bodyFont))
    }

    private func join(_ parts: NSAttributedString...) -> NSAttributedString {
        let out = NSMutableAttributedString()
        for part in parts { out.append(part) }
        return out
    }

    // MARK: - Inline rendering

    /// Renders `text` with inline Markdown markers consumed.
    ///
    /// The method walks the string once and, for each recognised inline
    /// construct, emits the inner content with the appropriate attributes
    /// while dropping the surrounding delimiters. Priority is given to the
    /// more specific patterns first (triple-star before double before
    /// single), so nested delimiters resolve correctly.
    private func renderInline(_ text: String,
                              font: UIFont,
                              color: UIColor? = nil) -> NSAttributedString {
        let baseColor = color ?? style.textColor
        let output = NSMutableAttributedString()

        var index = text.startIndex
        while index < text.endIndex {
            if let token = matchInlineToken(in: text, from: index) {
                output.append(renderInlineToken(token, font: font, color: baseColor))
                index = token.range.upperBound
            } else {
                let char = text[index]
                output.append(NSAttributedString(string: String(char), attributes: [
                    .font: font,
                    .foregroundColor: baseColor,
                ]))
                index = text.index(after: index)
            }
        }
        return output
    }

    private enum InlineTokenKind {
        case boldItalic
        case bold
        case italic
        case strikethrough
        case inlineCode
        case link
        case image
    }

    private struct InlineToken {
        let kind: InlineTokenKind
        let content: String
        let url: String?
        let range: Range<String.Index>
    }

    /// Finds the first inline token (if any) that starts at or immediately
    /// after `index` in `text`.
    ///
    /// A token must *start* at `index` for the walker in ``renderInline`` to
    /// consume it; if nothing starts here we fall through and emit a single
    /// character instead. This keeps the overall pass linear.
    private func matchInlineToken(in text: String,
                                  from index: String.Index) -> InlineToken? {
        let remainder = text[index...]
        if let match = remainder.prefixMatch(of: #/\*\*\*([^\*]+?)\*\*\*/#) {
            return InlineToken(kind: .boldItalic,
                               content: String(match.output.1),
                               url: nil,
                               range: index ..< match.range.upperBound)
        }
        if let match = remainder.prefixMatch(of: #/\*\*([^\*]+?)\*\*/#) {
            return InlineToken(kind: .bold,
                               content: String(match.output.1),
                               url: nil,
                               range: index ..< match.range.upperBound)
        }
        if let match = remainder.prefixMatch(of: #/\*([^\*\n]+?)\*/#) {
            return InlineToken(kind: .italic,
                               content: String(match.output.1),
                               url: nil,
                               range: index ..< match.range.upperBound)
        }
        if let match = remainder.prefixMatch(of: #/~~([^~]+?)~~/#) {
            return InlineToken(kind: .strikethrough,
                               content: String(match.output.1),
                               url: nil,
                               range: index ..< match.range.upperBound)
        }
        if let match = remainder.prefixMatch(of: #/`([^`\n]+?)`/#) {
            return InlineToken(kind: .inlineCode,
                               content: String(match.output.1),
                               url: nil,
                               range: index ..< match.range.upperBound)
        }
        if let match = remainder.prefixMatch(of: #/!\[([^\]]*)\]\(([^\)]+)\)/#) {
            return InlineToken(kind: .image,
                               content: String(match.output.1),
                               url: String(match.output.2),
                               range: index ..< match.range.upperBound)
        }
        if let match = remainder.prefixMatch(of: #/\[([^\]]+)\]\(([^\)]+)\)/#) {
            return InlineToken(kind: .link,
                               content: String(match.output.1),
                               url: String(match.output.2),
                               range: index ..< match.range.upperBound)
        }
        return nil
    }

    private func renderInlineToken(_ token: InlineToken,
                                   font: UIFont,
                                   color: UIColor) -> NSAttributedString {
        switch token.kind {
        case .boldItalic:
            return NSAttributedString(string: token.content, attributes: [
                .font: traitedFont(from: font, bold: true, italic: true),
                .foregroundColor: color,
            ])
        case .bold:
            return NSAttributedString(string: token.content, attributes: [
                .font: traitedFont(from: font, bold: true, italic: false),
                .foregroundColor: color,
            ])
        case .italic:
            return NSAttributedString(string: token.content, attributes: [
                .font: traitedFont(from: font, bold: false, italic: true),
                .foregroundColor: color,
            ])
        case .strikethrough:
            return NSAttributedString(string: token.content, attributes: [
                .font: font,
                .foregroundColor: color,
                .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                .strikethroughColor: color,
            ])
        case .inlineCode:
            return NSAttributedString(string: token.content, attributes: [
                .font: style.monospacedFont,
                .foregroundColor: color,
            ])
        case .link:
            var attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: style.linkColor,
                .underlineStyle: NSUnderlineStyle.single.rawValue,
            ]
            if let url = token.url, let parsed = URL(string: url) {
                attributes[.link] = parsed
            }
            return NSAttributedString(string: token.content, attributes: attributes)
        case .image:
            let label = token.content.isEmpty ? "🖼" : "🖼 \(token.content)"
            return NSAttributedString(string: label, attributes: [
                .font: font,
                .foregroundColor: style.syntaxColor,
            ])
        }
    }

    // MARK: - Font helpers

    private func traitedFont(from font: UIFont, bold: Bool, italic: Bool) -> UIFont {
        var traits: UIFontDescriptor.SymbolicTraits = []
        if bold { traits.insert(.traitBold) }
        if italic { traits.insert(.traitItalic) }
        guard !traits.isEmpty,
              let descriptor = font.fontDescriptor.withSymbolicTraits(traits)
        else {
            return font
        }
        return UIFont(descriptor: descriptor, size: font.pointSize)
    }

    private func headingFont(level: Int) -> UIFont {
        let scale: CGFloat = switch level {
        case 1: 1.6
        case 2: 1.4
        case 3: 1.25
        case 4: 1.15
        case 5: 1.08
        default: 1.0
        }
        let descriptor = style.bodyFont.fontDescriptor.withSymbolicTraits(.traitBold)
            ?? style.bodyFont.fontDescriptor
        return UIFont(descriptor: descriptor, size: style.bodyFont.pointSize * scale)
    }

    // MARK: - Horizontal rule

    /// Returns a one-character attributed string whose text attachment draws
    /// a thin horizontal line across the host text container's width. Using
    /// an attachment instead of a run of `─` glyphs keeps the rule on a
    /// single line at any width and Dynamic Type size.
    private func horizontalRuleAttachmentString() -> NSAttributedString {
        let attachment = HorizontalRuleAttachment(color: style.syntaxColor,
                                                  thickness: 1,
                                                  lineHeight: style.bodyFont.lineHeight)
        return NSAttributedString(attachment: attachment)
    }

    private final class HorizontalRuleAttachment: NSTextAttachment {

        private let ruleColor: UIColor
        private let ruleThickness: CGFloat
        private let lineHeight: CGFloat

        init(color: UIColor, thickness: CGFloat, lineHeight: CGFloat) {
            self.ruleColor = color
            self.ruleThickness = thickness
            self.lineHeight = lineHeight
            super.init(data: nil, ofType: nil)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func attachmentBounds(for textContainer: NSTextContainer?,
                                       proposedLineFragment lineFrag: CGRect,
                                       glyphPosition position: CGPoint,
                                       characterIndex charIndex: Int) -> CGRect {
            let padding = textContainer?.lineFragmentPadding ?? 0
            let width = max((textContainer?.size.width ?? lineFrag.width) - padding * 2, 0)
            return CGRect(x: 0,
                          y: (lineHeight - ruleThickness) / -2,
                          width: width,
                          height: ruleThickness)
        }

        override func image(forBounds imageBounds: CGRect,
                            textContainer: NSTextContainer?,
                            characterIndex charIndex: Int) -> UIImage? {
            let size = CGSize(width: max(imageBounds.width, 1),
                              height: max(imageBounds.height, 1))
            let renderer = UIGraphicsImageRenderer(size: size)
            let color = ruleColor
            return renderer.image { context in
                color.setFill()
                context.fill(CGRect(origin: .zero, size: size))
            }
        }
    }
}
