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
    @State private var activeActions: Set<MarkdownAction> = []
    @State private var pendingRichAction: MarkdownAction? = nil
    @State private var linkSheetData: LinkSheetData? = nil
    @State private var pendingLinkAction: LinkAction? = nil

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
            case .source:
                MarkdownTextView(text: $text,
                                 selection: $selection,
                                 isEditing: $isEditing,
                                 activeActions: $activeActions,
                                 configuration: configuration,
                                 resolvedActions: resolvedActions,
                                 hidesMarkers: false,
                                 onImagePick: onImagePick)
                if configuration.showsToolbar && !isEditing {
                    Divider()
                    MarkdownToolbar(actions: resolvedActions,
                                    style: configuration.style,
                                    activeActions: activeActions,
                                    onAction: performAction)
                }
            case .rich:
                MarkdownRichWebView(text: $text,
                                    isEditing: $isEditing,
                                    activeActions: $activeActions,
                                    pendingAction: $pendingRichAction,
                                    pendingLinkAction: $pendingLinkAction,
                                    configuration: configuration,
                                    resolvedActions: resolvedActions,
                                    onImagePick: onImagePick,
                                    onLinkRequested: { selectedText, existingURL in
                                        linkSheetData = LinkSheetData(initialText: selectedText,
                                                                      initialURL: existingURL)
                                    })
                if configuration.showsToolbar {
                    Divider()
                    MarkdownToolbar(actions: resolvedActions,
                                    style: configuration.style,
                                    activeActions: activeActions,
                                    onAction: performRichAction)
                }
            case .preview:
                MarkdownPreview(text: text, configuration: configuration)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: isEditing)
        .animation(.easeInOut(duration: 0.18), value: mode)
        .sheet(item: $linkSheetData) { data in
            MarkdownLinkSheet(initialURL: data.initialURL,
                              initialText: data.initialText,
                              isEditing: data.isEditing,
                              onInsert: { url, text in
                                  handleLinkInsertion(url: url, text: text)
                              },
                              onRemove: {
                                  handleLinkRemoval()
                              })
        }
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
        if action == .link {
            linkSheetData = LinkSheetData(initialText: selectedText(),
                                          initialURL: "")
            return
        }
        let result = MarkdownFormatter.apply(action, to: text, in: selection)
        text = result.text
        selection = result.selection
    }

    private func performRichAction(_ action: MarkdownAction) {
        if action == .imagePicker {
            onImagePick?()
            return
        }
        // .link is forwarded to the WebView's coordinator, which queries the
        // current selection text and calls back via `onLinkRequested` to open
        // the sheet with that text pre-filled.
        pendingRichAction = action
    }

    /// Returns the user's currently selected substring in source mode, or
    /// the empty string when the selection is empty or out of range.
    private func selectedText() -> String {
        let nsText = text as NSString
        let location = max(0, selection.location)
        let length = max(0, min(selection.length, nsText.length - location))
        guard length > 0 else { return "" }
        return nsText.substring(with: NSRange(location: location, length: length))
    }

    private func handleLinkInsertion(url: String, text linkText: String) {
        switch mode {
        case .source:
            let display = linkText.isEmpty ? url : linkText
            let markdown = "[\(display)](\(url))"
            let nsText = self.text as NSString
            let location = max(0, selection.location)
            let length = max(0, min(selection.length, nsText.length - location))
            let safeRange = NSRange(location: location, length: length)
            self.text = nsText.replacingCharacters(in: safeRange, with: markdown)
            let newLocation = location + (markdown as NSString).length
            self.selection = NSRange(location: newLocation, length: 0)

        case .rich:
            pendingLinkAction = .insert(url: url, text: linkText)

        case .preview:
            break
        }
    }

    private func handleLinkRemoval() {
        switch mode {
        case .rich:
            pendingLinkAction = .remove
        case .source, .preview:
            // Source mode would need to locate the surrounding [text](url)
            // syntax to strip — not handled in this version. The user can
            // delete the syntax by hand.
            break
        }
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
