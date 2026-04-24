//
//  MarkdownToHTMLTests.swift
//  MarkdownEditorKit
//
//  Created by Rouzbeh Abadi on 2026-04-24.
//

import Testing
@testable import MarkdownEditorKit

@Suite("MarkdownToHTML")
struct MarkdownToHTMLTests {

    // MARK: - Empty input

    @Test("Empty string produces a blank paragraph")
    func emptyInput() {
        let html = MarkdownToHTML.convert("")
        #expect(html.contains("<p><br></p>"))
    }

    // MARK: - Headings

    @Test("H1 heading")
    func headingH1() {
        #expect(MarkdownToHTML.convert("# Title") == "<h1>Title</h1>\n")
    }

    @Test("H2 heading")
    func headingH2() {
        #expect(MarkdownToHTML.convert("## Title") == "<h2>Title</h2>\n")
    }

    @Test("H3 heading")
    func headingH3() {
        #expect(MarkdownToHTML.convert("### Title") == "<h3>Title</h3>\n")
    }

    @Test("H4 heading")
    func headingH4() {
        #expect(MarkdownToHTML.convert("#### Title") == "<h4>Title</h4>\n")
    }

    @Test("H5 heading")
    func headingH5() {
        #expect(MarkdownToHTML.convert("##### Title") == "<h5>Title</h5>\n")
    }

    @Test("H6 heading")
    func headingH6() {
        #expect(MarkdownToHTML.convert("###### Title") == "<h6>Title</h6>\n")
    }

    @Test("Heading with inline bold")
    func headingWithBold() {
        #expect(MarkdownToHTML.convert("# Hello **world**") == "<h1>Hello <strong>world</strong></h1>\n")
    }

    @Test("More than six hashes clamps to H6")
    func headingClampedToH6() {
        #expect(MarkdownToHTML.convert("####### Too deep") == "<h6>Too deep</h6>\n")
    }

    // MARK: - Paragraphs

    @Test("Plain text becomes a paragraph")
    func plainParagraph() {
        #expect(MarkdownToHTML.convert("Hello world") == "<p>Hello world</p>\n")
    }

    @Test("Blank line produces empty paragraph")
    func blankLineParagraph() {
        #expect(MarkdownToHTML.convert("a\n\nb") == "<p>a</p>\n<p><br></p>\n<p>b</p>\n")
    }

    // MARK: - Horizontal rule

    @Test("Three dashes produce HR")
    func hrDashes() {
        #expect(MarkdownToHTML.convert("---") == "<hr>\n")
    }

    @Test("Three asterisks produce HR")
    func hrAsterisks() {
        #expect(MarkdownToHTML.convert("***") == "<hr>\n")
    }

    @Test("Three underscores produce HR")
    func hrUnderscores() {
        #expect(MarkdownToHTML.convert("___") == "<hr>\n")
    }

    @Test("More than three dashes produce HR")
    func hrLong() {
        #expect(MarkdownToHTML.convert("------") == "<hr>\n")
    }

    // MARK: - Blockquote

    @Test("Blockquote line")
    func blockquote() {
        #expect(MarkdownToHTML.convert("> Hello") == "<blockquote><p>Hello</p></blockquote>\n")
    }

    @Test("Blockquote with inline formatting")
    func blockquoteWithBold() {
        #expect(MarkdownToHTML.convert("> **Bold**") == "<blockquote><p><strong>Bold</strong></p></blockquote>\n")
    }

    // MARK: - Bullet list

    @Test("Single bullet item with dash")
    func bulletSingleDash() {
        #expect(MarkdownToHTML.convert("- Item") == "<ul><li>Item</li></ul>\n")
    }

    @Test("Single bullet item with asterisk")
    func bulletSingleAsterisk() {
        #expect(MarkdownToHTML.convert("* Item") == "<ul><li>Item</li></ul>\n")
    }

    @Test("Single bullet item with plus")
    func bulletSinglePlus() {
        #expect(MarkdownToHTML.convert("+ Item") == "<ul><li>Item</li></ul>\n")
    }

    @Test("Multiple bullet items")
    func bulletMultiple() {
        let html = MarkdownToHTML.convert("- A\n- B\n- C")
        #expect(html == "<ul><li>A</li><li>B</li><li>C</li></ul>\n")
    }

    @Test("Bullet list flushes on blank line")
    func bulletFlushedOnBlankLine() {
        let html = MarkdownToHTML.convert("- A\n\n- B")
        #expect(html == "<ul><li>A</li></ul>\n<p><br></p>\n<ul><li>B</li></ul>\n")
    }

    // MARK: - Numbered list

    @Test("Single numbered item")
    func numberedSingle() {
        #expect(MarkdownToHTML.convert("1. Item") == "<ol><li>Item</li></ol>\n")
    }

    @Test("Multiple numbered items")
    func numberedMultiple() {
        let html = MarkdownToHTML.convert("1. A\n2. B\n3. C")
        #expect(html == "<ol><li>A</li><li>B</li><li>C</li></ol>\n")
    }

    @Test("Numbered list with arbitrary start number")
    func numberedArbitraryStart() {
        #expect(MarkdownToHTML.convert("5. Item") == "<ol><li>Item</li></ol>\n")
    }

    // MARK: - Task list

    @Test("Unchecked task item")
    func taskUnchecked() {
        let html = MarkdownToHTML.convert("- [ ] Task")
        #expect(html.contains("<input type=\"checkbox\">"))
        #expect(html.contains("Task"))
        #expect(html.contains("<ul>"))
    }

    @Test("Checked task item with lowercase x")
    func taskCheckedLower() {
        let html = MarkdownToHTML.convert("- [x] Task")
        #expect(html.contains("<input type=\"checkbox\" checked>"))
        #expect(html.contains("Task"))
    }

    @Test("Checked task item with uppercase X")
    func taskCheckedUpper() {
        let html = MarkdownToHTML.convert("- [X] Task")
        #expect(html.contains("<input type=\"checkbox\" checked>"))
    }

    @Test("Mixed task list")
    func taskMixed() {
        let html = MarkdownToHTML.convert("- [ ] Todo\n- [x] Done")
        #expect(html.contains("<input type=\"checkbox\">"))
        #expect(html.contains("<input type=\"checkbox\" checked>"))
    }

    // MARK: - Fenced code block

    @Test("Fenced code block wraps in pre/code")
    func fencedCode() {
        let html = MarkdownToHTML.convert("```\nlet x = 1\n```")
        #expect(html == "<pre><code>let x = 1</code></pre>\n")
    }

    @Test("Fenced code block HTML-escapes content")
    func fencedCodeEscapes() {
        let html = MarkdownToHTML.convert("```\n<div>&\n```")
        #expect(html.contains("&lt;div&gt;&amp;"))
    }

    @Test("Fenced code block does not apply inline formatting")
    func fencedCodeNoInline() {
        let html = MarkdownToHTML.convert("```\n**not bold**\n```")
        #expect(html.contains("**not bold**"))
        #expect(!html.contains("<strong>"))
    }

    @Test("Fenced code block with language tag strips the tag")
    func fencedCodeWithLanguage() {
        let html = MarkdownToHTML.convert("```swift\nlet x = 1\n```")
        #expect(html.contains("<pre><code>"))
        #expect(html.contains("let x = 1"))
    }

    // MARK: - Inline formatting

    @Test("Bold with double asterisks")
    func inlineBold() {
        #expect(MarkdownToHTML.convert("**hello**") == "<p><strong>hello</strong></p>\n")
    }

    @Test("Italic with single asterisk")
    func inlineItalic() {
        #expect(MarkdownToHTML.convert("*hello*") == "<p><em>hello</em></p>\n")
    }

    @Test("Bold italic with triple asterisks")
    func inlineBoldItalic() {
        #expect(MarkdownToHTML.convert("***hello***") == "<p><strong><em>hello</em></strong></p>\n")
    }

    @Test("Strikethrough with double tildes")
    func inlineStrikethrough() {
        #expect(MarkdownToHTML.convert("~~hello~~") == "<p><del>hello</del></p>\n")
    }

    @Test("Inline code with backticks")
    func inlineCode() {
        #expect(MarkdownToHTML.convert("`code`") == "<p><code>code</code></p>\n")
    }

    @Test("Link syntax")
    func inlineLink() {
        #expect(MarkdownToHTML.convert("[Click](https://example.com)") == "<p><a href=\"https://example.com\">Click</a></p>\n")
    }

    @Test("Mixed inline formatting in one line")
    func inlineMixed() {
        let html = MarkdownToHTML.convert("**bold** and *italic*")
        #expect(html.contains("<strong>bold</strong>"))
        #expect(html.contains("<em>italic</em>"))
    }

    // MARK: - HTML escaping

    @Test("Less-than sign is escaped")
    func escapeLessThan() {
        #expect(MarkdownToHTML.convert("a < b") == "<p>a &lt; b</p>\n")
    }

    @Test("Greater-than sign is escaped")
    func escapeGreaterThan() {
        #expect(MarkdownToHTML.convert("a > b") == "<p>a &gt; b</p>\n")
    }

    @Test("Ampersand is escaped")
    func escapeAmpersand() {
        #expect(MarkdownToHTML.convert("a & b") == "<p>a &amp; b</p>\n")
    }

    @Test("Double quote is escaped")
    func escapeDoubleQuote() {
        let html = MarkdownToHTML.convert("say \"hi\"")
        #expect(html.contains("&quot;hi&quot;"))
    }

    // MARK: - Full document

    @Test("Full document round-trips block types")
    func fullDocument() {
        let md = """
        # Title

        A **bold** paragraph.

        - Bullet
        - List

        1. Numbered
        2. List

        - [ ] Task
        - [x] Done

        > Quote

        ---

        ```
        code block
        ```
        """
        let html = MarkdownToHTML.convert(md)
        #expect(html.contains("<h1>Title</h1>"))
        #expect(html.contains("<strong>bold</strong>"))
        #expect(html.contains("<ul>"))
        #expect(html.contains("<ol>"))
        #expect(html.contains("<input type=\"checkbox\">"))
        #expect(html.contains("<input type=\"checkbox\" checked>"))
        #expect(html.contains("<blockquote>"))
        #expect(html.contains("<hr>"))
        #expect(html.contains("<pre><code>"))
    }
}
