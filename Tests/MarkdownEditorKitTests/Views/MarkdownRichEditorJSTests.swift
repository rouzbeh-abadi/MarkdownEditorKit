//
//  MarkdownRichEditorJSTests.swift
//  MarkdownEditorKit
//
//  Created by Rouzbeh Abadi on 2026-04-25.
//

import Foundation
import Testing
import WebKit
@testable import MarkdownEditorKit

// MARK: - Test harness

/// Loads `MarkdownRichEditorHTML.template` into a real `WKWebView` so the
/// editor's JavaScript can be exercised directly from Swift tests via
/// `evaluateJavaScript`.
@MainActor
private final class JSHarness: NSObject, WKNavigationDelegate {

    let webView: WKWebView
    private var loadContinuation: CheckedContinuation<Void, Never>?

    override init() {
        webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        super.init()
        webView.navigationDelegate = self
    }

    func load() async {
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            self.loadContinuation = cont
            webView.loadHTMLString(MarkdownRichEditorHTML.template, baseURL: nil)
        }
    }

    nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { @MainActor in
            self.loadContinuation?.resume()
            self.loadContinuation = nil
        }
    }

    @discardableResult
    func eval(_ js: String) async throws -> Any? {
        try await webView.evaluateJavaScript(js)
    }

    /// Replace the editor's contents. Uses a JS template literal so most HTML
    /// punctuation passes through untouched.
    func setInnerHTML(_ html: String) async throws {
        let escaped = html
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
        _ = try await eval("editor.innerHTML = `\(escaped)`; null")
    }

    func markdown() async throws -> String {
        (try await eval("getMarkdown()")) as? String ?? ""
    }

    /// Selects the contents of the first element matching `selector`.
    func selectContents(of selector: String) async throws {
        _ = try await eval("""
        (function(){
          const el = document.querySelector('\(selector)');
          const r = document.createRange();
          r.selectNodeContents(el);
          const s = window.getSelection();
          s.removeAllRanges(); s.addRange(r);
        })(); null
        """)
    }

    /// Places a collapsed cursor at the end of the first element matching
    /// `selector` (or the editor itself when `selector` is `nil`).
    func collapseCursorAtEnd(of selector: String? = nil) async throws {
        let target = selector.map { "document.querySelector('\($0)')" } ?? "editor"
        _ = try await eval("""
        (function(){
          const el = \(target);
          const r = document.createRange();
          r.selectNodeContents(el);
          r.collapse(false);
          const s = window.getSelection();
          s.removeAllRanges(); s.addRange(r);
        })(); null
        """)
    }
}

// MARK: - Tests

@Suite("MarkdownRichEditorHTML JS", .serialized)
@MainActor
struct MarkdownRichEditorJSTests {

    private func makeHarness() async -> JSHarness {
        let h = JSHarness()
        await h.load()
        return h
    }

    // MARK: getMarkdown – block elements

    @Test("Heading H1 round-trips")
    func headingH1() async throws {
        let h = await makeHarness()
        try await h.setInnerHTML("<h1>Title</h1>")
        #expect(try await h.markdown() == "# Title")
    }

    @Test("Heading H6 round-trips")
    func headingH6() async throws {
        let h = await makeHarness()
        try await h.setInnerHTML("<h6>Title</h6>")
        #expect(try await h.markdown() == "###### Title")
    }

    @Test("Single paragraph")
    func paragraph() async throws {
        let h = await makeHarness()
        try await h.setInnerHTML("<p>Hello</p>")
        #expect(try await h.markdown() == "Hello")
    }

    @Test("Two paragraphs join with single newline")
    func twoParagraphsSingleNewline() async throws {
        let h = await makeHarness()
        try await h.setInnerHTML("<p>A</p><p>B</p>")
        #expect(try await h.markdown() == "A\nB")
    }

    @Test("Empty paragraph between produces blank line")
    func blankLineParagraph() async throws {
        let h = await makeHarness()
        try await h.setInnerHTML("<p>A</p><p><br></p><p>B</p>")
        #expect(try await h.markdown() == "A\n\nB")
    }

    @Test("HR has no leading newline")
    func hr() async throws {
        let h = await makeHarness()
        try await h.setInnerHTML("<p>A</p><hr><p>B</p>")
        #expect(try await h.markdown() == "A\n---\nB")
    }

    @Test("Blockquote round-trips")
    func blockquote() async throws {
        let h = await makeHarness()
        try await h.setInnerHTML("<blockquote><p>Hello</p></blockquote>")
        #expect(try await h.markdown() == "> Hello")
    }

    @Test("Bullet list round-trips")
    func bulletList() async throws {
        let h = await makeHarness()
        try await h.setInnerHTML("<ul><li>A</li><li>B</li></ul>")
        #expect(try await h.markdown() == "- A\n- B")
    }

    @Test("Numbered list round-trips")
    func numberedList() async throws {
        let h = await makeHarness()
        try await h.setInnerHTML("<ol><li>A</li><li>B</li></ol>")
        #expect(try await h.markdown() == "1. A\n2. B")
    }

    @Test("Task list unchecked")
    func taskListUnchecked() async throws {
        let h = await makeHarness()
        try await h.setInnerHTML("<ul><li><input type=\"checkbox\">Todo</li></ul>")
        #expect(try await h.markdown() == "- [ ] Todo")
    }

    @Test("Task list checked")
    func taskListChecked() async throws {
        let h = await makeHarness()
        try await h.setInnerHTML("<ul><li><input type=\"checkbox\" checked>Done</li></ul>")
        #expect(try await h.markdown() == "- [x] Done")
    }

    @Test("Fenced code block round-trips")
    func fencedCodeBlock() async throws {
        let h = await makeHarness()
        try await h.setInnerHTML("<pre><code>let x = 1</code></pre>")
        #expect(try await h.markdown() == "```\nlet x = 1\n```")
    }

    // MARK: getMarkdown – inline formatting

    @Test("Bold inline")
    func boldInline() async throws {
        let h = await makeHarness()
        try await h.setInnerHTML("<p><b>hello</b></p>")
        #expect(try await h.markdown() == "**hello**")
    }

    @Test("Italic inline")
    func italicInline() async throws {
        let h = await makeHarness()
        try await h.setInnerHTML("<p><i>hello</i></p>")
        #expect(try await h.markdown() == "*hello*")
    }

    @Test("Strikethrough inline")
    func strikethroughInline() async throws {
        let h = await makeHarness()
        try await h.setInnerHTML("<p><del>hello</del></p>")
        #expect(try await h.markdown() == "~~hello~~")
    }

    @Test("Link inline")
    func linkInline() async throws {
        let h = await makeHarness()
        try await h.setInnerHTML("<p><a href=\"https://x.com\">click</a></p>")
        #expect(try await h.markdown() == "[click](https://x.com)")
    }

    // MARK: Zero-width-space marker handling

    @Test("Empty inline format containing only the marker emits nothing")
    func emptyInlineMarkerEmitsNothing() async throws {
        let h = await makeHarness()
        try await h.setInnerHTML("<p>hi<b>\u{200B}</b></p>")
        #expect(try await h.markdown() == "hi")
    }

    @Test("Markers in plain text are stripped")
    func markersInPlainTextStripped() async throws {
        let h = await makeHarness()
        try await h.setInnerHTML("<p>a\u{200B}b\u{200B}c</p>")
        #expect(try await h.markdown() == "abc")
    }

    // MARK: Toolbar actions

    @Test("applyBold on a range wraps the selection")
    func applyBoldOnSelection() async throws {
        let h = await makeHarness()
        try await h.setInnerHTML("<p>hello</p>")
        try await h.selectContents(of: "p")
        _ = try await h.eval("applyBold()")
        #expect(try await h.markdown() == "**hello**")
    }

    @Test("applyItalic on a range wraps the selection")
    func applyItalicOnSelection() async throws {
        let h = await makeHarness()
        try await h.setInnerHTML("<p>hello</p>")
        try await h.selectContents(of: "p")
        _ = try await h.eval("applyItalic()")
        #expect(try await h.markdown() == "*hello*")
    }

    @Test("applyStrikethrough on a range wraps the selection")
    func applyStrikethroughOnSelection() async throws {
        let h = await makeHarness()
        try await h.setInnerHTML("<p>hello</p>")
        try await h.selectContents(of: "p")
        _ = try await h.eval("applyStrikethrough()")
        #expect(try await h.markdown() == "~~hello~~")
    }

    @Test("applyBold on a collapsed cursor outside <b> inserts an empty <b>")
    func applyBoldEntersFormatWithoutSelection() async throws {
        let h = await makeHarness()
        try await h.setInnerHTML("<p>hi</p>")
        try await h.collapseCursorAtEnd(of: "p")
        _ = try await h.eval("applyBold()")
        // Empty bold (only the zero-width marker) emits nothing in Markdown
        #expect(try await h.markdown() == "hi")
        // …but a <b> exists at the cursor position
        let hasBold = try await h.eval("editor.querySelector('b') !== null") as? Bool
        #expect(hasBold == true)
        // …and queryCommandState reports bold so the toolbar lights up
        let state = try await h.eval("document.queryCommandState('bold')") as? Bool
        #expect(state == true)
    }

    @Test("applyBold on a collapsed cursor inside <b> exits the format")
    func applyBoldExitsFormat() async throws {
        let h = await makeHarness()
        try await h.setInnerHTML("<p><b>hi</b></p>")
        try await h.collapseCursorAtEnd(of: "b")
        let before = try await h.eval("document.queryCommandState('bold')") as? Bool
        #expect(before == true)
        _ = try await h.eval("applyBold()")
        let after = try await h.eval("document.queryCommandState('bold')") as? Bool
        #expect(after == false)
        // Bold content itself is preserved
        #expect(try await h.markdown() == "**hi**")
    }

    @Test("applyHeading toggles H1 on and off")
    func applyHeadingToggle() async throws {
        let h = await makeHarness()
        try await h.setInnerHTML("<p>hello</p>")
        try await h.selectContents(of: "p")
        _ = try await h.eval("applyHeading(1)")
        #expect(try await h.markdown() == "# hello")
        _ = try await h.eval("applyHeading(1)")
        #expect(try await h.markdown() == "hello")
    }

    @Test("applyQuote toggles blockquote on and off")
    func applyQuoteToggle() async throws {
        let h = await makeHarness()
        try await h.setInnerHTML("<p>hello</p>")
        try await h.selectContents(of: "p")
        _ = try await h.eval("applyQuote()")
        #expect(try await h.markdown() == "> hello")
        _ = try await h.eval("applyQuote()")
        #expect(try await h.markdown() == "hello")
    }

    @Test("applyBulletList wraps the line in a <ul>")
    func applyBulletListAction() async throws {
        let h = await makeHarness()
        try await h.setInnerHTML("<p>item</p>")
        try await h.selectContents(of: "p")
        _ = try await h.eval("applyBulletList()")
        #expect(try await h.markdown() == "- item")
    }

    @Test("applyNumberedList wraps the line in an <ol>")
    func applyNumberedListAction() async throws {
        let h = await makeHarness()
        try await h.setInnerHTML("<p>item</p>")
        try await h.selectContents(of: "p")
        _ = try await h.eval("applyNumberedList()")
        #expect(try await h.markdown() == "1. item")
    }

    @Test("insertHR places an <hr> in the document")
    func insertHRAction() async throws {
        let h = await makeHarness()
        try await h.setInnerHTML("<p>hi</p>")
        try await h.collapseCursorAtEnd(of: "p")
        _ = try await h.eval("insertHR()")
        let hasHR = try await h.eval("editor.querySelector('hr') !== null") as? Bool
        #expect(hasHR == true)
        #expect(try await h.markdown().contains("---"))
    }
}
