//
//  MarkdownEditorMode.swift
//  MarkdownEditorKit
//
//  Created by Rouzbeh Abadi on 2026-04-24.
//

import Foundation

/// The two display modes supported by ``MarkdownEditor``.
///
/// A mode controls whether the editor shows the raw Markdown source with
/// live syntax highlighting, or a read-only rendered preview where the
/// syntax markers are hidden and formatting is applied inline. The host
/// app drives the mode — for example from a toggle in a navigation bar —
/// so the same bound text can be inspected in either form without losing
/// edits.
///
/// ```swift
/// @State private var mode: MarkdownEditorMode = .source
/// @State private var markdown = "# Hello"
///
/// MarkdownEditor(text: $markdown, mode: mode)
///     .toolbar {
///         Picker("Mode", selection: $mode) {
///             Text("Write").tag(MarkdownEditorMode.source)
///             Text("Preview").tag(MarkdownEditorMode.preview)
///         }
///         .pickerStyle(.segmented)
///     }
/// ```
public enum MarkdownEditorMode: Hashable, Sendable {

    /// The editor displays the raw Markdown source with live syntax
    /// highlighting and a formatting toolbar. This is the default.
    case source

    /// The editor displays a read-only rendered preview: Markdown syntax
    /// markers are hidden, and their formatting is applied to the
    /// surrounding text. The formatting toolbar is not shown.
    case preview
}
