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
///   task items, quotes, and links are visually distinguished while the
///   user types.
/// - **Formatting toolbar**: buttons for common Markdown actions are shown
///   above the keyboard while editing, and at the bottom of the editor
///   when the keyboard is dismissed. The toolbar floats inside its host
///   with a rounded background.
/// - **Selection-aware actions**: toolbar buttons wrap the current
///   selection or insert placeholder text at the cursor as appropriate.
/// - **Source, rich, and preview modes**: the same bound text can be
///   edited as raw Markdown (the default), edited in a WYSIWYG-style
///   view where the syntax markers are hidden and their formatting is
///   applied inline, or viewed as a read-only rendered preview; the
///   host app drives the mode.
/// - **Host-handled image picking**: when a host supplies an
///   ``onImagePick`` closure, the ``MarkdownAction/imagePicker`` toolbar
///   button invokes it rather than inserting Markdown syntax, so the app
///   can present its own picker.
///
/// ## Example
///
/// ```swift
/// struct NoteEditor: View {
///     @State private var markdown = "# Hello\n\nStart writing…"
///     @State private var mode: MarkdownEditorMode = .source
///
///     var body: some View {
///         MarkdownEditor(text: $markdown, mode: mode)
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
/// let configuration = MarkdownEditorConfiguration(enabledActions: [.bold, .italic, .heading(level: 1), .imagePicker, .link],
///                                                 highlightsSyntax: true)
/// MarkdownEditor(text: $markdown,
///                configuration: configuration,
///                onImagePick: { presentPhotoPicker() })
/// ```
public struct MarkdownEditor: View {

    @Binding private var text: String
    private let mode: MarkdownEditorMode
    private let configuration: MarkdownEditorConfiguration
    private let onImagePick: (() -> Void)?

    @State private var selection: NSRange = NSRange(location: 0, length: 0)
    @State private var isEditing: Bool = false

    /// Creates a Markdown editor.
    ///
    /// - Parameters:
    ///   - text: A binding to the Markdown source the user is editing.
    ///   - mode: The display mode. Pass ``MarkdownEditorMode/source`` for
    ///     the editable source view (the default),
    ///     ``MarkdownEditorMode/rich`` for an editable view where syntax
    ///     markers are visually hidden, or ``MarkdownEditorMode/preview``
    ///     for a read-only rendered preview.
    ///   - configuration: The configuration controlling toolbar contents,
    ///     appearance, and layout metrics.
    ///   - onImagePick: An optional closure invoked when the user taps the
    ///     ``MarkdownAction/imagePicker`` toolbar button. Supply this when
    ///     your app wants to present its own image picker rather than
    ///     relying on raw Markdown image syntax. When `nil`, the picker
    ///     button is hidden from the toolbar.
    public init(text: Binding<String>,
                mode: MarkdownEditorMode = .source,
                configuration: MarkdownEditorConfiguration = MarkdownEditorConfiguration(),
                onImagePick: (() -> Void)? = nil) {
        self._text = text
        self.mode = mode
        self.configuration = configuration
        self.onImagePick = onImagePick
    }

    public var body: some View {
        VStack(spacing: 0) {
            switch mode {
            case .source, .rich:
                MarkdownTextView(text: $text,
                                 selection: $selection,
                                 isEditing: $isEditing,
                                 configuration: configuration,
                                 resolvedActions: resolvedActions,
                                 hidesMarkers: mode == .rich,
                                 onImagePick: onImagePick)
                if configuration.showsToolbar && !isEditing {
                    Divider()
                    MarkdownToolbar(actions: resolvedActions,
                                    style: configuration.style,
                                    onAction: performAction)
                }
            case .preview:
                MarkdownPreview(text: text, configuration: configuration)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: isEditing)
        .animation(.easeInOut(duration: 0.18), value: mode)
    }

    /// The actions that should actually appear in the toolbar, given the
    /// host's configuration and callbacks.
    ///
    /// The filter hides the picker action when no handler is wired up,
    /// so the button never appears as a no-op.
    private var resolvedActions: [MarkdownAction] {
        guard onImagePick == nil else { return configuration.enabledActions }
        return configuration.enabledActions.filter { $0 != .imagePicker }
    }

    private func performAction(_ action: MarkdownAction) {
        if action == .imagePicker {
            onImagePick?()
            return
        }
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

        - [ ] A task
        - [x] A completed task

        > Plus block quotes.
        
        Divider
        ---
        """
        @State private var mode: MarkdownEditorMode = .source

        var body: some View {
            VStack {
                Picker("Mode", selection: $mode) {
                    Text("Source").tag(MarkdownEditorMode.source)
                    Text("Rich").tag(MarkdownEditorMode.rich)
                    Text("Preview").tag(MarkdownEditorMode.preview)
                }
                .pickerStyle(.segmented)
                .padding()

                MarkdownEditor(text: $text, mode: mode)
                    .frame(minHeight: 400)
            }
        }
    }
    return Preview()
}
