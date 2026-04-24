//
//  MarkdownPreview.swift
//  MarkdownEditorKit
//
//  Created by Rouzbeh Abadi on 2026-04-24.
//

import SwiftUI
import UIKit

/// A read-only SwiftUI view that displays Markdown text with syntax markers
/// hidden and their formatting applied.
///
/// `MarkdownPreview` is the view used by ``MarkdownEditor`` when its mode is
/// ``MarkdownEditorMode/preview``. It is also exposed as a public type so
/// hosts can use the rendered representation in contexts where the source
/// editor is inappropriate — for instance in a detail view that shows the
/// final note verbatim.
///
/// Rendering is delegated to ``MarkdownRenderer``; the view is a thin
/// wrapper that hosts a non-editable `UITextView` and keeps its attributed
/// content in sync with the text and configuration.
///
/// ```swift
/// MarkdownPreview(text: noteBody,
///                 configuration: MarkdownEditorConfiguration())
///     .frame(maxWidth: .infinity, maxHeight: .infinity)
/// ```
public struct MarkdownPreview: UIViewRepresentable {

    private let text: String
    private let configuration: MarkdownEditorConfiguration

    /// Creates a preview.
    ///
    /// - Parameters:
    ///   - text: The Markdown source to render.
    ///   - configuration: The configuration supplying fonts, colors, and
    ///     layout metrics. Toolbar-specific properties are ignored — the
    ///     preview never shows a toolbar.
    public init(text: String,
                configuration: MarkdownEditorConfiguration = MarkdownEditorConfiguration()) {
        self.text = text
        self.configuration = configuration
    }

    public func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.alwaysBounceVertical = true
        textView.dataDetectorTypes = [.link]
        textView.linkTextAttributes = [
            .foregroundColor: UIColor.systemBlue,
            .underlineStyle: NSUnderlineStyle.single.rawValue,
        ]
        apply(to: textView)
        return textView
    }

    public func updateUIView(_ uiView: UITextView, context: Context) {
        apply(to: uiView)
    }

    private func apply(to textView: UITextView) {
        textView.backgroundColor = configuration.backgroundColor
        textView.textContainerInset = configuration.style.textView.contentInsets
        let rendererStyle = MarkdownRenderer.Style(bodyFont: configuration.font,
                                                    monospacedFont: configuration.monospacedFont,
                                                    textColor: configuration.textColor,
                                                    syntaxColor: configuration.syntaxColor)
        let renderer = MarkdownRenderer(style: rendererStyle)
        textView.attributedText = renderer.render(text)
    }
}

#Preview("MarkdownPreview") {
    MarkdownPreview(text: """
    # MarkdownEditorKit

    Supports **bold**, *italic*, ~~strike~~, and `inline code`.

    - Bullet item
    - With *emphasis*

    1. First
    2. Second

    - [ ] Buy milk
    - [x] Pay taxes

    > A short quote, inline-formatted.

    ---

    A [link to somewhere](https://example.com).
    """)
    .frame(maxHeight: 500)
}
