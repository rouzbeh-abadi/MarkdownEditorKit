//
//  MarkdownEditorMode.swift
//  MarkdownEditorKit
//
//  Created by Rouzbeh Abadi on 2026-04-24.
//

import Foundation

/// The display modes supported by ``MarkdownEditor``.
///
/// A mode controls how the editor presents its bound text: the raw
/// Markdown source with live syntax highlighting, an editable rich-text
/// view where syntax markers are visually hidden, or a read-only
/// rendered preview. The host app drives the mode — for example from a
/// segmented control in a navigation bar — so the same bound text can
/// be inspected in any form without losing edits.
///
/// ```swift
/// @State private var mode: MarkdownEditorMode = .source
/// @State private var markdown = "# Hello"
///
/// MarkdownEditor(text: $markdown, mode: mode)
///     .toolbar {
///         Picker("Mode", selection: $mode) {
///             Text("Source").tag(MarkdownEditorMode.source)
///             Text("Rich").tag(MarkdownEditorMode.rich)
///             Text("Preview").tag(MarkdownEditorMode.preview)
///         }
///         .pickerStyle(.segmented)
///     }
/// ```
public enum MarkdownEditorMode: Hashable, Sendable {

    /// The editor displays the raw Markdown source with live syntax
    /// highlighting and a formatting toolbar. This is the default.
    case source

    /// The editor is editable, but Markdown syntax markers are visually
    /// hidden and their formatting is applied inline — a WYSIWYG-style
    /// live edit. The underlying text remains raw Markdown, so the
    /// bound source round-trips cleanly. The formatting toolbar is
    /// shown, so the user can insert and toggle formatting without
    /// typing marker characters.
    case rich

    /// The editor displays a read-only rendered preview: Markdown syntax
    /// markers are hidden, and their formatting is applied to the
    /// surrounding text. The formatting toolbar is not shown.
    case preview
}
