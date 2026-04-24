//
//  MarkdownFormatterTests.swift
//  MarkdownEditorKit
//
//  Created by Rouzbeh Abadi on 2026-04-24.
//

import Foundation
import Testing
@testable import MarkdownEditorKit

@Suite("MarkdownFormatter")
struct MarkdownFormatterTests {

    // MARK: - Bold

    @Test("Bold wraps a non-empty selection with **")
    func boldWrapsSelection() {
        let result = MarkdownFormatter.apply(.bold,
                                             to: "hello world",
                                             in: NSRange(location: 0, length: 5))
        #expect(result.text == "**hello** world")
        #expect(result.selection == NSRange(location: 2, length: 5))
    }

    @Test("Bold inserts a placeholder when the selection is empty")
    func boldInsertsPlaceholder() {
        let result = MarkdownFormatter.apply(.bold,
                                             to: "",
                                             in: NSRange(location: 0, length: 0))
        #expect(result.text == "**bold**")
        #expect(result.selection == NSRange(location: 2, length: 4))
    }

    @Test("Bold toggles off when the selection is already wrapped")
    func boldToggles() {
        let result = MarkdownFormatter.apply(.bold,
                                             to: "**hello** world",
                                             in: NSRange(location: 2, length: 5))
        #expect(result.text == "hello world")
        #expect(result.selection == NSRange(location: 0, length: 5))
    }

    // MARK: - Italic

    @Test("Italic wraps a non-empty selection with *")
    func italicWraps() {
        let result = MarkdownFormatter.apply(.italic,
                                             to: "hello",
                                             in: NSRange(location: 0, length: 5))
        #expect(result.text == "*hello*")
        #expect(result.selection == NSRange(location: 1, length: 5))
    }

    @Test("Italic on text that is already bold produces bold + italic")
    func italicInsideBoldWraps() {
        // "**hello**" → select "hello" → italic should produce "***hello***"
        // (not accidentally unwrap the surrounding bold).
        let result = MarkdownFormatter.apply(.italic,
                                             to: "**hello**",
                                             in: NSRange(location: 2, length: 5))
        #expect(result.text == "***hello***")
        #expect(result.selection == NSRange(location: 3, length: 5))
    }

    // MARK: - Strikethrough

    @Test("Strikethrough wraps selection with ~~")
    func strikethroughWraps() {
        let result = MarkdownFormatter.apply(.strikethrough,
                                             to: "hello",
                                             in: NSRange(location: 0, length: 5))
        #expect(result.text == "~~hello~~")
        #expect(result.selection == NSRange(location: 2, length: 5))
    }

    // MARK: - Inline code

    @Test("Inline code wraps selection with backticks")
    func inlineCode() {
        let result = MarkdownFormatter.apply(.inlineCode,
                                             to: "hello",
                                             in: NSRange(location: 0, length: 5))
        #expect(result.text == "`hello`")
        #expect(result.selection == NSRange(location: 1, length: 5))
    }

    // MARK: - Headings

    @Test("Heading level 1 prefixes a line with '# '")
    func heading1() {
        let result = MarkdownFormatter.apply(.heading(level: 1),
                                             to: "Title",
                                             in: NSRange(location: 0, length: 0))
        #expect(result.text == "# Title")
    }

    @Test("Heading level is clamped to 1...6")
    func headingClamped() {
        let low = MarkdownFormatter.apply(.heading(level: 0),
                                          to: "a",
                                          in: NSRange(location: 0, length: 0))
        let high = MarkdownFormatter.apply(.heading(level: 9),
                                           to: "a",
                                           in: NSRange(location: 0, length: 0))
        #expect(low.text == "# a")
        #expect(high.text == "###### a")
    }

    @Test("Re-applying the same heading removes the prefix")
    func headingToggles() {
        let result = MarkdownFormatter.apply(.heading(level: 1),
                                             to: "# Title",
                                             in: NSRange(location: 0, length: 0))
        #expect(result.text == "Title")
    }

    // MARK: - Lists

    @Test("Bullet list prefixes each selected line")
    func bulletListMultiline() {
        let text = "one\ntwo\nthree"
        let selection = NSRange(location: 0, length: (text as NSString).length)
        let result = MarkdownFormatter.apply(.bulletList, to: text, in: selection)
        #expect(result.text == "- one\n- two\n- three")
    }

    @Test("Numbered list numbers each selected line sequentially")
    func numberedListMultiline() {
        let text = "one\ntwo\nthree"
        let selection = NSRange(location: 0, length: (text as NSString).length)
        let result = MarkdownFormatter.apply(.numberedList, to: text, in: selection)
        #expect(result.text == "1. one\n2. two\n3. three")
    }

    @Test("Numbered list toggles off when every line is already numbered")
    func numberedListToggles() {
        let text = "1. one\n2. two"
        let selection = NSRange(location: 0, length: (text as NSString).length)
        let result = MarkdownFormatter.apply(.numberedList, to: text, in: selection)
        #expect(result.text == "one\ntwo")
    }

    // MARK: - Quote

    @Test("Quote prefixes the current line with '> '")
    func quote() {
        let result = MarkdownFormatter.apply(.quote,
                                             to: "line",
                                             in: NSRange(location: 0, length: 0))
        #expect(result.text == "> line")
    }

    // MARK: - Code block

    @Test("Code block wraps selection in triple backticks on their own lines")
    func codeBlock() {
        let result = MarkdownFormatter.apply(.codeBlock,
                                             to: "print(\"hi\")",
                                             in: NSRange(location: 0, length: 11))
        #expect(result.text == "```\nprint(\"hi\")\n```")
        #expect(result.selection == NSRange(location: 4, length: 11))
    }

    // MARK: - Link

    @Test("Link with a selection uses it as the title and selects the URL placeholder")
    func linkWithSelection() {
        let result = MarkdownFormatter.apply(.link,
                                             to: "click me",
                                             in: NSRange(location: 0, length: 8))
        #expect(result.text == "[click me](https://)")
        #expect(result.selection == NSRange(location: 11, length: 8))
    }

    @Test("Link with no selection selects the title placeholder")
    func linkWithoutSelection() {
        let result = MarkdownFormatter.apply(.link,
                                             to: "",
                                             in: NSRange(location: 0, length: 0))
        #expect(result.text == "[title](https://)")
        #expect(result.selection == NSRange(location: 1, length: 5))
    }

    // MARK: - Image

    @Test("Image with no selection produces an image reference with an alt-text placeholder")
    func imageWithoutSelection() {
        let result = MarkdownFormatter.apply(.image,
                                             to: "",
                                             in: NSRange(location: 0, length: 0))
        #expect(result.text == "![alt text](https://)")
        #expect(result.selection == NSRange(location: 2, length: 8))
    }

    // MARK: - Horizontal rule

    @Test("Horizontal rule inserts '---' at the caret")
    func horizontalRuleAtStart() {
        let result = MarkdownFormatter.apply(.horizontalRule,
                                             to: "",
                                             in: NSRange(location: 0, length: 0))
        #expect(result.text == "---\n")
    }

    @Test("Horizontal rule inserts a leading newline when mid-line")
    func horizontalRuleMidLine() {
        let result = MarkdownFormatter.apply(.horizontalRule,
                                             to: "abc",
                                             in: NSRange(location: 3, length: 0))
        #expect(result.text == "abc\n---\n")
    }

    // MARK: - Clamping

    @Test("Out-of-bounds selections are clamped and still produce a valid edit")
    func outOfBoundsSelection() {
        let result = MarkdownFormatter.apply(.bold,
                                             to: "hello",
                                             in: NSRange(location: 100, length: 50))
        #expect(result.text == "hello**bold**")
    }
}
