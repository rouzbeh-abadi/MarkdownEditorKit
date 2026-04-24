//
//  SystemImage.swift
//  MarkdownEditorKit
//
//  Created by Rouzbeh Abadi on 2026-04-24.
//

import SwiftUI

/// The catalog of SF Symbols used by MarkdownEditorKit.
///
/// Every icon the library renders is declared here so the set of symbols
/// consumed by the package is discoverable in one place. Code inside the
/// module — and code built on top of it — should reach for a case on this
/// enum rather than hard-coding SF Symbol strings.
///
/// Each case carries the SF Symbol name as its raw value, so the enum
/// interoperates directly with both UIKit and SwiftUI:
///
/// ```swift
/// // UIKit: pass the name to `UIImage(systemName:)`.
/// UIImage(systemName: SystemImage.bold.symbolName)
///
/// // SwiftUI: drop the pre-built `Image` directly into a view.
/// SystemImage.italic.image
///     .font(.system(size: 16, weight: .medium))
/// ```
public enum SystemImage: String, CaseIterable, Sendable {

    // MARK: Inline emphasis
    case bold
    case italic
    case strikethrough

    // MARK: Headings
    case heading1 = "1.square"
    case heading2 = "2.square"
    case heading3 = "3.square"
    case heading4 = "4.square"
    case heading5 = "5.square"
    case heading6 = "6.square"
    case headingGeneric = "number.square"

    // MARK: Lists
    case bulletList = "list.bullet"
    case numberedList = "list.number"
    case taskList = "checklist"

    // MARK: Code
    case inlineCode = "chevron.left.forwardslash.chevron.right"
    case codeBlock = "curlybraces"

    // MARK: Media & structure
    case link
    case image = "photo"
    case imagePicker = "photo.badge.plus"
    case quote = "text.quote"
    case horizontalRule = "rectangle.split.1x2"

    /// The SF Symbol name, suitable for `UIImage(systemName:)` and
    /// `Image(systemName:)`.
    public var symbolName: String { rawValue }

    /// A SwiftUI `Image` of this symbol, ready to be placed in a view
    /// hierarchy.
    ///
    /// Call sites should prefer this property over constructing an
    /// `Image(systemName:)` themselves, so the set of icons used by
    /// MarkdownEditorKit remains greppable from one file.
    public var image: Image { Image(systemName: rawValue) }
}
