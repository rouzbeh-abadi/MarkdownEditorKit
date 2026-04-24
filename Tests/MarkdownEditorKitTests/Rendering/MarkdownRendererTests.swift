//
//  MarkdownRendererTests.swift
//  MarkdownEditorKit
//
//  Created by Rouzbeh Abadi on 2026-04-24.
//

import Foundation
import Testing
import UIKit
@testable import MarkdownEditorKit

@Suite("MarkdownRenderer")
@MainActor
struct MarkdownRendererTests {

    private static let baseSize: CGFloat = 16

    private static func makeRenderer() -> MarkdownRenderer {
        let style = MarkdownRenderer.Style(bodyFont: .systemFont(ofSize: baseSize),
                                           monospacedFont: .monospacedSystemFont(ofSize: baseSize, weight: .regular),
                                           textColor: .black,
                                           syntaxColor: .gray)
        return MarkdownRenderer(style: style)
    }

    @Test("Bold markers are removed from the rendered string")
    func boldStripsMarkers() {
        let rendered = Self.makeRenderer().render("Hello **world**")
        #expect(rendered.string == "Hello world")
    }

    @Test("Italic markers are removed from the rendered string")
    func italicStripsMarkers() {
        let rendered = Self.makeRenderer().render("before *word* after")
        #expect(rendered.string == "before word after")
    }

    @Test("Inline code backticks are removed and the content is monospaced")
    func inlineCodeMonospaced() {
        let renderer = Self.makeRenderer()
        let rendered = renderer.render("call `foo()` now")
        #expect(rendered.string == "call foo() now")
        let codeRange = (rendered.string as NSString).range(of: "foo()")
        let font = rendered.attribute(.font, at: codeRange.location, effectiveRange: nil) as? UIFont
        let isMonospaced = font?.fontDescriptor.symbolicTraits.contains(.traitMonoSpace) == true
            || font?.familyName.lowercased().contains("mono") == true
        #expect(isMonospaced)
    }

    @Test("Heading markers are replaced and the line becomes larger and bold")
    func headingIsScaled() {
        let renderer = Self.makeRenderer()
        let rendered = renderer.render("# Hello")
        #expect(rendered.string == "Hello")
        let font = rendered.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        #expect((font?.pointSize ?? 0) > Self.baseSize)
        #expect(font?.fontDescriptor.symbolicTraits.contains(.traitBold) == true)
    }

    @Test("Bullet list marker is replaced with a bullet glyph")
    func bulletReplaced() {
        let rendered = Self.makeRenderer().render("- one")
        #expect(rendered.string.hasPrefix("•"))
        #expect(rendered.string.hasSuffix("one"))
    }

    @Test("Task list markers render as ballot boxes with the correct check state")
    func taskListCheckboxes() {
        let rendered = Self.makeRenderer().render("- [ ] todo\n- [x] done")
        #expect(rendered.string.contains("☐"))
        #expect(rendered.string.contains("☑︎"))
        #expect(rendered.string.contains("todo"))
        #expect(rendered.string.contains("done"))
    }

    @Test("Fenced code block fences are removed and the body keeps monospace")
    func fencedCode() {
        let rendered = Self.makeRenderer().render("```\nprint(\"hi\")\n```")
        #expect(rendered.string == "print(\"hi\")")
        let font = rendered.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        let isMono = font?.fontDescriptor.symbolicTraits.contains(.traitMonoSpace) == true
            || font?.familyName.lowercased().contains("mono") == true
        #expect(isMono)
    }

    @Test("Links render as their title, with a URL attached")
    func linksAreNavigable() {
        let rendered = Self.makeRenderer().render("See [the docs](https://example.com).")
        #expect(rendered.string == "See the docs.")
        let linkRange = (rendered.string as NSString).range(of: "the docs")
        let link = rendered.attribute(.link, at: linkRange.location, effectiveRange: nil) as? URL
        #expect(link == URL(string: "https://example.com"))
    }

    @Test("Horizontal rules render as a single-line attachment, not raw dashes")
    func horizontalRule() {
        let rendered = Self.makeRenderer().render("---")
        #expect(!rendered.string.contains("---"))
        #expect(!rendered.string.contains("─"))
        let attachment = rendered.attribute(.attachment, at: 0, effectiveRange: nil) as? NSTextAttachment
        #expect(attachment != nil)
    }
}
