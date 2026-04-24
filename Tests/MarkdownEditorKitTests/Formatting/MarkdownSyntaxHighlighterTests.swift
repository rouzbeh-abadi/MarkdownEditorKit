//
//  MarkdownSyntaxHighlighterTests.swift
//  MarkdownEditorKit
//
//  Created by Rouzbeh Abadi on 2026-04-24.
//

import Foundation
import Testing
import UIKit
@testable import MarkdownEditorKit

@Suite("MarkdownSyntaxHighlighter")
@MainActor
struct MarkdownSyntaxHighlighterTests {

    private static let baseSize: CGFloat = 16

    private static func makeHighlighter() -> MarkdownSyntaxHighlighter {
        let style = MarkdownSyntaxHighlighter.Style(bodyFont: .systemFont(ofSize: baseSize),
                                                    monospacedFont: .monospacedSystemFont(ofSize: baseSize, weight: .regular),
                                                    textColor: .black,
                                                    syntaxColor: .gray)
        return MarkdownSyntaxHighlighter(style: style)
    }

    @Test("The plain string is preserved byte-for-byte")
    func preservesPlainText() {
        let input = "hello **world**"
        let result = Self.makeHighlighter().highlight(input)
        #expect(result.string == input)
    }

    @Test("A bold span receives a bold font attribute")
    func boldIsBold() {
        let input = "a **hey** b"
        let result = Self.makeHighlighter().highlight(input)
        let boldRange = (input as NSString).range(of: "**hey**")
        let font = result.attribute(.font, at: boldRange.location, effectiveRange: nil) as? UIFont
        #expect(font?.fontDescriptor.symbolicTraits.contains(.traitBold) == true)
    }

    @Test("An italic span receives an italic font attribute")
    func italicIsItalic() {
        let input = "before *word* after"
        let result = Self.makeHighlighter().highlight(input)
        let italicRange = (input as NSString).range(of: "*word*")
        let font = result.attribute(.font, at: italicRange.location, effectiveRange: nil) as? UIFont
        #expect(font?.fontDescriptor.symbolicTraits.contains(.traitItalic) == true)
    }

    @Test("Inline code uses the monospaced font")
    func inlineCodeMonospaced() {
        let input = "call `foo()` now"
        let result = Self.makeHighlighter().highlight(input)
        let codeRange = (input as NSString).range(of: "`foo()`")
        let font = result.attribute(.font, at: codeRange.location, effectiveRange: nil) as? UIFont
        // Accept either an explicit monospace trait or a font family whose
        // name contains "mono" — system monospaced fonts don't always set
        // the symbolic trait on every platform.
        let isMonospaced = font?.fontDescriptor.symbolicTraits.contains(.traitMonoSpace) == true
            || font?.familyName.lowercased().contains("mono") == true
        #expect(isMonospaced)
    }

    @Test("A heading line gets a bold, larger font")
    func headingScaled() {
        let highlighter = Self.makeHighlighter()
        let input = "# Heading"
        let result = highlighter.highlight(input)
        let font = result.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        #expect(font != nil)
        #expect((font?.pointSize ?? 0) > Self.baseSize)
        #expect(font?.fontDescriptor.symbolicTraits.contains(.traitBold) == true)
    }

    @Test("Strikethrough span receives the strikethrough attribute")
    func strikethroughApplied() {
        let input = "~~gone~~"
        let result = Self.makeHighlighter().highlight(input)
        let style = result.attribute(.strikethroughStyle, at: 0, effectiveRange: nil) as? Int
        #expect(style == NSUnderlineStyle.single.rawValue)
    }

    @Test("List marker is tinted with the syntax color")
    func listMarkerSyntaxColor() {
        let input = "- one\n- two"
        let result = Self.makeHighlighter().highlight(input)
        let color = result.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor
        #expect(color == .gray)
    }

    // MARK: - hidesMarkers

    private static func makeHidingHighlighter() -> MarkdownSyntaxHighlighter {
        let style = MarkdownSyntaxHighlighter.Style(bodyFont: .systemFont(ofSize: baseSize),
                                                    monospacedFont: .monospacedSystemFont(ofSize: baseSize, weight: .regular),
                                                    textColor: .black,
                                                    syntaxColor: .gray,
                                                    hidesMarkers: true)
        return MarkdownSyntaxHighlighter(style: style)
    }

    @Test("Underlying string is unchanged when markers are hidden")
    func hidingPreservesString() {
        let input = "hello **world**"
        let result = Self.makeHidingHighlighter().highlight(input)
        #expect(result.string == input)
    }

    @Test("Bold markers collapse when hidesMarkers is on")
    func bothBoldMarkersCollapse() {
        let input = "a **hey** b"
        let result = Self.makeHidingHighlighter().highlight(input)
        let openLocation = (input as NSString).range(of: "**hey**").location
        let closeLocation = openLocation + 5 // start of trailing "**"
        let openFont = result.attribute(.font, at: openLocation, effectiveRange: nil) as? UIFont
        let closeFont = result.attribute(.font, at: closeLocation, effectiveRange: nil) as? UIFont
        #expect((openFont?.pointSize ?? 99) < 1)
        #expect((closeFont?.pointSize ?? 99) < 1)
    }

    @Test("Bold content keeps bold styling when markers are hidden")
    func hiddenBoldKeepsContentStyling() {
        let input = "a **hey** b"
        let result = Self.makeHidingHighlighter().highlight(input)
        let contentLocation = (input as NSString).range(of: "hey").location
        let font = result.attribute(.font, at: contentLocation, effectiveRange: nil) as? UIFont
        #expect(font?.fontDescriptor.symbolicTraits.contains(.traitBold) == true)
    }

    @Test("Heading hash prefix collapses when markers are hidden")
    func hiddenHeadingPrefix() {
        let input = "## Title"
        let result = Self.makeHidingHighlighter().highlight(input)
        let prefixFont = result.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        let titleFont = result.attribute(.font, at: 3, effectiveRange: nil) as? UIFont
        #expect((prefixFont?.pointSize ?? 99) < 1)
        #expect((titleFont?.pointSize ?? 0) > Self.baseSize)
    }

    @Test("Link URL tail collapses, title stays visible")
    func hiddenLinkMarkers() {
        let input = "see [docs](https://example.com) now"
        let result = Self.makeHidingHighlighter().highlight(input)
        let bracketLocation = (input as NSString).range(of: "[").location
        let tailLocation = (input as NSString).range(of: "](").location
        let titleLocation = (input as NSString).range(of: "docs").location
        let bracketFont = result.attribute(.font, at: bracketLocation, effectiveRange: nil) as? UIFont
        let tailFont = result.attribute(.font, at: tailLocation, effectiveRange: nil) as? UIFont
        let titleFont = result.attribute(.font, at: titleLocation, effectiveRange: nil) as? UIFont
        #expect((bracketFont?.pointSize ?? 99) < 1)
        #expect((tailFont?.pointSize ?? 99) < 1)
        #expect((titleFont?.pointSize ?? 0) >= Self.baseSize)
    }
}
