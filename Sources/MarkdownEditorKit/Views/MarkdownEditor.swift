//
//  MarkdownEditor.swift
//  MarkdownEditorKit
//
//  Created by Rouzbeh Abadi on 2026-04-24.
//

import SwiftUI

/// A SwiftUI view that hosts an editable Markdown text buffer.
///
/// `MarkdownEditor` is the primary entry point of MarkdownEditorKit. It
/// wraps a `UITextView` to provide multi-line editing, then layers on
/// Markdown-specific features:
///
/// - **Syntax highlighting**: headings, emphasis, inline code, lists,
///   quotes, and links are visually distinguished while the user types.
/// - **Formatting toolbar**: buttons for common Markdown actions are shown
///   above the keyboard while editing, and at the bottom of the editor
///   when the keyboard is dismissed.
/// - **Selection-aware actions**: toolbar buttons wrap the current
///   selection or insert placeholder text at the cursor as appropriate.
///
/// ## Example
///
/// ```swift
/// struct NoteEditor: View {
///     @State private var markdown = "# Hello\n\nStart writing…"
///
///     var body: some View {
///         MarkdownEditor(text: $markdown)
///             .frame(minHeight: 240)
///     }
/// }
/// ```
///
/// ## Customisation
///
/// Pass a ``MarkdownEditorConfiguration`` to change the toolbar actions,
/// fonts, colors, or layout metrics:
///
/// ```swift
/// let configuration = MarkdownEditorConfiguration(enabledActions: [.bold, .italic, .heading(level: 1), .link],
///                                                 highlightsSyntax: true)
/// MarkdownEditor(text: $markdown, configuration: configuration)
/// ```
public struct MarkdownEditor: View {

    @Binding private var text: String
    private let configuration: MarkdownEditorConfiguration

    @State private var selection: NSRange = NSRange(location: 0, length: 0)
    @State private var isEditing: Bool = false

    /// Creates a Markdown editor.
    ///
    /// - Parameters:
    ///   - text: A binding to the Markdown source the user is editing.
    ///   - configuration: The configuration controlling toolbar contents,
    ///     appearance, and layout metrics. Defaults to
    ///     ``MarkdownEditorConfiguration/init(enabledActions:showsToolbar:highlightsSyntax:font:monospacedFont:textColor:backgroundColor:syntaxColor:style:)``.
    public init(text: Binding<String>,
                configuration: MarkdownEditorConfiguration = MarkdownEditorConfiguration()) {
        self._text = text
        self.configuration = configuration
    }

    public var body: some View {
        VStack(spacing: 0) {
            MarkdownTextView(text: $text,
                             selection: $selection,
                             isEditing: $isEditing,
                             configuration: configuration)

            if configuration.showsToolbar && !isEditing {
                Divider()
                MarkdownToolbar(actions: configuration.enabledActions,
                                style: configuration.style,
                                onAction: performAction)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: isEditing)
    }

    private func performAction(_ action: MarkdownAction) {
        let result = MarkdownFormatter.apply(action, to: text, in: selection)
        text = result.text
        selection = result.selection
    }
}

#Preview("MarkdownEditor") {
    struct Preview: View {
        @State private var text = """
        # MarkdownEditorKit

        Supports **bold**, *italic*, `inline code`, and more.

        - Bulleted lists
        - With multiple items

        > Plus block quotes.
        """

        var body: some View {
            MarkdownEditor(text: $text)
                .frame(minHeight: 400)
        }
    }
    return Preview()
}
