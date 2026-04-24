//
//  MarkdownAction.swift
//  MarkdownEditorKit
//
//  Created by Rouzbeh Abadi on 2026-04-24.
//

import Foundation

/// Formatting actions that the Markdown toolbar can apply to the editor.
///
/// Each case represents a distinct Markdown construct. Inline actions such as
/// ``bold`` and ``italic`` wrap the current selection with delimiters. Block
/// actions such as ``heading(level:)`` and ``quote`` prefix each selected line
/// with a syntax marker.
///
/// `MarkdownAction` is the unit of work exchanged between the toolbar and the
/// formatter. Because the enum is `Hashable` and `Sendable`, instances can be
/// freely stored in collections and passed across concurrency boundaries.
public enum MarkdownAction: Hashable, Sendable {

    /// Wraps the current selection in `**` for bold emphasis.
    case bold

    /// Wraps the current selection in `*` for italic emphasis.
    case italic

    /// Wraps the current selection in `~~` for strikethrough.
    case strikethrough

    /// Prefixes each selected line with `#` characters to mark a heading.
    ///
    /// - Parameter level: The heading level. Values are clamped to `1...6` when
    ///   the action is applied.
    case heading(level: Int)

    /// Prefixes each selected line with `- ` to produce an unordered list.
    case bulletList

    /// Prefixes each selected line with an incrementing `N. ` marker to
    /// produce an ordered list.
    case numberedList

    /// Wraps the current selection in single backticks for inline code.
    case inlineCode

    /// Wraps the current selection in a fenced code block using triple
    /// backticks.
    case codeBlock

    /// Inserts a Markdown link (`[title](url)`) around the current selection,
    /// or at the cursor if the selection is empty.
    case link

    /// Inserts a Markdown image reference (`![alt](url)`) around the current
    /// selection, or at the cursor if the selection is empty.
    case image

    /// Prefixes each selected line with `> ` to produce a block quote.
    case quote

    /// Inserts a horizontal rule (`---`) on its own line.
    case horizontalRule
}

// MARK: - Identifiable

extension MarkdownAction: Identifiable {

    /// A stable identifier for the action, suitable for use as a `ForEach`
    /// identifier.
    public var id: String {
        switch self {
        case .bold: "bold"
        case .italic: "italic"
        case .strikethrough: "strikethrough"
        case .heading(let level): "heading-\(level)"
        case .bulletList: "bulletList"
        case .numberedList: "numberedList"
        case .inlineCode: "inlineCode"
        case .codeBlock: "codeBlock"
        case .link: "link"
        case .image: "image"
        case .quote: "quote"
        case .horizontalRule: "horizontalRule"
        }
    }
}

// MARK: - Presentation metadata

extension MarkdownAction {

    /// A short, user-facing label for the action.
    ///
    /// Use this for accessibility labels, tooltips, or alternative UI that
    /// presents actions as text rather than icons.
    public var title: String {
        switch self {
        case .bold: "Bold"
        case .italic: "Italic"
        case .strikethrough: "Strikethrough"
        case .heading(let level): "Heading \(level)"
        case .bulletList: "Bulleted List"
        case .numberedList: "Numbered List"
        case .inlineCode: "Inline Code"
        case .codeBlock: "Code Block"
        case .link: "Link"
        case .image: "Image"
        case .quote: "Quote"
        case .horizontalRule: "Horizontal Rule"
        }
    }

    /// The SF Symbol representing this action in a toolbar.
    ///
    /// The returned value is drawn from the ``SystemImage`` catalog, which
    /// keeps the set of icons used by MarkdownEditorKit discoverable from a
    /// single file. Call ``SystemImage/image`` on the result to get a
    /// SwiftUI `Image`, or ``SystemImage/symbolName`` to get the raw SF
    /// Symbol string.
    public var systemImage: SystemImage {
        switch self {
        case .bold: .bold
        case .italic: .italic
        case .strikethrough: .strikethrough
        case .heading(let level):
            switch level {
            case 1: .heading1
            case 2: .heading2
            case 3: .heading3
            case 4: .heading4
            case 5: .heading5
            case 6: .heading6
            default: .headingGeneric
            }
        case .bulletList: .bulletList
        case .numberedList: .numberedList
        case .inlineCode: .inlineCode
        case .codeBlock: .codeBlock
        case .link: .link
        case .image: .image
        case .quote: .quote
        case .horizontalRule: .horizontalRule
        }
    }
}
