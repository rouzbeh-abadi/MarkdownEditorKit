//
//  Style.swift
//  MarkdownEditorKit
//
//  Created by Rouzbeh Abadi on 2026-04-24.
//

import SwiftUI
import UIKit

/// Layout metrics — paddings, spacings, and sizes — that MarkdownEditorKit
/// views use when drawing themselves.
///
/// Centralising these values in one type means visual tweaks propagate
/// consistently through the editor, the formatting toolbar, and the
/// underlying text view. Consumers can pass a custom ``Style`` through
/// ``MarkdownEditorConfiguration/style`` to adjust the look without
/// touching the internals.
///
/// `Style` is a value type: constructing or mutating a local copy never
/// affects other copies. Each nested metric group has its own default so
/// you can override only the parts you care about.
///
/// ```swift
/// var style = Style.default
/// style.toolbar.buttonSize = 44
/// style.toolbar.iconSize = 18
///
/// let configuration = MarkdownEditorConfiguration(style: style)
/// ```
public struct Style: Equatable, Sendable {

    /// Metrics that apply to the text view portion of the editor.
    public var textView: TextView

    /// Metrics that apply to the formatting toolbar.
    public var toolbar: Toolbar

    /// Creates a style.
    ///
    /// - Parameters:
    ///   - textView: Text-view metrics. Defaults to ``TextView/default``.
    ///   - toolbar: Toolbar metrics. Defaults to ``Toolbar/default``.
    public init(textView: TextView = .default,
                toolbar: Toolbar = .default) {
        self.textView = textView
        self.toolbar = toolbar
    }

    /// The default style, matching MarkdownEditorKit's out-of-the-box
    /// look.
    public static let `default` = Style()
}

// MARK: - Style.TextView

extension Style {

    /// Layout metrics for the Markdown text view portion of the editor.
    public struct TextView: Equatable, Sendable {

        /// Padding between the text view's edges and its text content.
        public var contentInsets: UIEdgeInsets

        /// Creates text-view metrics.
        ///
        /// - Parameter contentInsets: Padding inside the text view.
        ///   Defaults to `12pt` on each edge.
        public init(contentInsets: UIEdgeInsets = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)) {
            self.contentInsets = contentInsets
        }

        /// The default text-view metrics.
        public static let `default` = TextView()
    }
}

// MARK: - Style.Toolbar

extension Style {

    /// Layout metrics for the Markdown formatting toolbar.
    public struct Toolbar: Equatable, Sendable {

        /// Overall height of the toolbar strip, in points.
        public var height: CGFloat

        /// Horizontal spacing between adjacent toolbar buttons.
        public var buttonSpacing: CGFloat

        /// Horizontal padding applied to the toolbar's scroll content.
        public var horizontalPadding: CGFloat

        /// Vertical padding applied to the toolbar's scroll content.
        public var verticalPadding: CGFloat

        /// Horizontal inset between the toolbar strip and the edges of
        /// its host container.
        ///
        /// The toolbar uses this inset to sit inside the keyboard
        /// accessory area or the editor's footer with a visible margin,
        /// rather than touching the screen edges.
        public var outerHorizontalPadding: CGFloat

        /// Vertical inset between the toolbar strip and the edges of
        /// its host container.
        public var outerVerticalPadding: CGFloat

        /// Corner radius applied to the toolbar's background pill.
        public var cornerRadius: CGFloat

        /// Width and height of a single toolbar button's hit area, in
        /// points.
        public var buttonSize: CGFloat

        /// Font size used for the toolbar button icons, in points.
        public var iconSize: CGFloat

        /// Font weight used for the toolbar button icons.
        public var iconWeight: Font.Weight

        /// Creates toolbar metrics.
        ///
        /// All parameters have defaults chosen to match the stock
        /// MarkdownEditorKit look.
        public init(height: CGFloat = 52,
                    buttonSpacing: CGFloat = 2,
                    horizontalPadding: CGFloat = 8,
                    verticalPadding: CGFloat = 4,
                    outerHorizontalPadding: CGFloat = 12,
                    outerVerticalPadding: CGFloat = 6,
                    cornerRadius: CGFloat = 12,
                    buttonSize: CGFloat = 36,
                    iconSize: CGFloat = 16,
                    iconWeight: Font.Weight = .medium) {
            self.height = height
            self.buttonSpacing = buttonSpacing
            self.horizontalPadding = horizontalPadding
            self.verticalPadding = verticalPadding
            self.outerHorizontalPadding = outerHorizontalPadding
            self.outerVerticalPadding = outerVerticalPadding
            self.cornerRadius = cornerRadius
            self.buttonSize = buttonSize
            self.iconSize = iconSize
            self.iconWeight = iconWeight
        }

        /// The default toolbar metrics.
        public static let `default` = Toolbar()
    }
}
