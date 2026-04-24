//
//  MarkdownEditorConfiguration.swift
//  MarkdownEditorKit
//
//  Created by Rouzbeh Abadi on 2026-04-24.
//

import UIKit

/// Configures the appearance and behaviour of ``MarkdownEditor``.
///
/// Pass an instance to ``MarkdownEditor/init(text:configuration:)`` to
/// customise the toolbar actions, fonts, colors, and layout metrics used by
/// the editor. All properties have sensible defaults, so the configuration
/// can be constructed with no arguments:
///
/// ```swift
/// MarkdownEditor(text: $markdown, configuration: MarkdownEditorConfiguration())
/// ```
///
/// Configurations are value types; mutating a property on a local copy never
/// affects other copies.
public struct MarkdownEditorConfiguration: Equatable {

    /// The toolbar actions, in the order they appear.
    public var enabledActions: [MarkdownAction]

    /// A Boolean value indicating whether the formatting toolbar is shown.
    ///
    /// When `true`, the toolbar is displayed above the keyboard while the user
    /// is editing, and at the bottom of the editor when the keyboard is
    /// dismissed. When `false`, the editor is toolbar-less and formatting can
    /// only be inserted by typing Markdown manually.
    public var showsToolbar: Bool

    /// A Boolean value indicating whether Markdown syntax is highlighted while
    /// the user types.
    ///
    /// Highlighting is cosmetic only; the underlying text is unchanged.
    public var highlightsSyntax: Bool

    /// The font used for body text.
    public var font: UIFont

    /// The font used for inline code and fenced code blocks.
    public var monospacedFont: UIFont

    /// The color used for body text.
    public var textColor: UIColor

    /// The background color of the editor.
    public var backgroundColor: UIColor

    /// The color used to tint Markdown syntax characters (`*`, `#`, `>`, …).
    public var syntaxColor: UIColor

    /// Layout metrics (paddings, sizes, spacings) used across the editor's
    /// text view and toolbar.
    public var style: Style

    /// Creates a configuration.
    ///
    /// Any parameter left as `nil` falls back to a UIKit system default, so the
    /// editor adapts automatically to dynamic type and light/dark mode.
    ///
    /// - Parameters:
    ///   - enabledActions: The actions surfaced in the toolbar, in order.
    ///     Defaults to ``defaultActions``.
    ///   - showsToolbar: Whether to show the formatting toolbar.
    ///   - highlightsSyntax: Whether to syntax-highlight Markdown while typing.
    ///   - font: The body font. Defaults to `.preferredFont(forTextStyle: .body)`.
    ///   - monospacedFont: The font used for inline code and fenced code
    ///     blocks. Defaults to a monospaced font matching `font`'s size.
    ///   - textColor: The body text color. Defaults to `.label`.
    ///   - backgroundColor: The editor's background color. Defaults to
    ///     `.systemBackground`.
    ///   - syntaxColor: The color used for Markdown syntax characters.
    ///     Defaults to `.secondaryLabel`.
    ///   - style: Layout metrics for the editor. Defaults to
    ///     ``Style/default``.
    public init(enabledActions: [MarkdownAction] = MarkdownEditorConfiguration.defaultActions,
                showsToolbar: Bool = true,
                highlightsSyntax: Bool = true,
                font: UIFont? = nil,
                monospacedFont: UIFont? = nil,
                textColor: UIColor? = nil,
                backgroundColor: UIColor? = nil,
                syntaxColor: UIColor? = nil,
                style: Style = .default) {
        let bodyFont = font ?? .preferredFont(forTextStyle: .body)
        self.enabledActions = enabledActions
        self.showsToolbar = showsToolbar
        self.highlightsSyntax = highlightsSyntax
        self.font = bodyFont
        self.monospacedFont = monospacedFont
            ?? .monospacedSystemFont(ofSize: bodyFont.pointSize, weight: .regular)
        self.textColor = textColor ?? .label
        self.backgroundColor = backgroundColor ?? .systemBackground
        self.syntaxColor = syntaxColor ?? .secondaryLabel
        self.style = style
    }

    /// The default set of actions surfaced in the toolbar.
    ///
    /// This list covers the Markdown constructs encountered in typical writing:
    /// emphasis, headings, lists, inline and fenced code, quotes, and links.
    public static let defaultActions: [MarkdownAction] = [
        .bold,
        .italic,
        .strikethrough,
        .heading(level: 1),
        .heading(level: 2),
        .bulletList,
        .numberedList,
        .inlineCode,
        .codeBlock,
        .link,
        .quote,
    ]
}
