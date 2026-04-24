//
//  MarkdownToHTML.swift
//  MarkdownEditorKit
//
//  Created by Rouzbeh Abadi on 2026-04-25.
//

import Foundation

/// Converts a limited subset of Markdown — matching the constructs produced
/// by `MarkdownFormatter` — to HTML suitable for loading into the rich editor.
///
/// The conversion is intentionally simple: it handles the same constructs the
/// highlighter and renderer recognise (headings, emphasis, lists, quotes,
/// code, links, HR), and passes everything else through as plain text.
enum MarkdownToHTML {

    static func convert(_ markdown: String) -> String {
        let lines = markdown.components(separatedBy: "\n")
        var html = ""
        var i = 0
        var inFenced = false
        var fenceLines: [String] = []
        var listItems: [String] = []
        var listTag = ""

        func flushList() {
            guard !listItems.isEmpty else { return }
            html += "<\(listTag)>" + listItems.map { "<li>\($0)</li>" }.joined() + "</\(listTag)>\n"
            listItems = []
            listTag = ""
        }

        while i < lines.count {
            let raw = lines[i]
            let trimmed = raw.trimmingCharacters(in: .whitespaces)

            // ── Fenced code ──────────────────────────────────────────────────
            if trimmed.hasPrefix("```") {
                if inFenced {
                    let body = fenceLines.joined(separator: "\n").htmlEscaped
                    html += "<pre><code>\(body)</code></pre>\n"
                    fenceLines = []
                    inFenced = false
                } else {
                    flushList()
                    inFenced = true
                }
                i += 1; continue
            }
            if inFenced { fenceLines.append(raw); i += 1; continue }

            // ── Empty line ───────────────────────────────────────────────────
            if trimmed.isEmpty {
                flushList()
                html += "<p><br></p>\n"
                i += 1; continue
            }

            // ── Heading ──────────────────────────────────────────────────────
            if trimmed.hasPrefix("#") {
                let hashes = trimmed.prefix(while: { $0 == "#" }).count
                let level = min(hashes, 6)
                let content = String(trimmed.dropFirst(hashes)).trimmingCharacters(in: .whitespaces)
                if !content.isEmpty {
                    flushList()
                    html += "<h\(level)>\(inline(content))</h\(level)>\n"
                    i += 1; continue
                }
            }

            // ── Horizontal rule ──────────────────────────────────────────────
            if trimmed.matches("^[-*_]{3,}$") {
                flushList()
                html += "<hr>\n"
                i += 1; continue
            }

            // ── Blockquote ───────────────────────────────────────────────────
            if trimmed.hasPrefix("> ") {
                flushList()
                let content = String(trimmed.dropFirst(2))
                html += "<blockquote><p>\(inline(content))</p></blockquote>\n"
                i += 1; continue
            }

            // ── Task list ────────────────────────────────────────────────────
            if let taskContent = trimmed.taskListContent {
                let (checked, text) = taskContent
                if listTag != "ul" { flushList(); listTag = "ul" }
                let cb = "<input type=\"checkbox\"\(checked ? " checked" : "")>"
                listItems.append("\(cb) \(inline(text))")
                i += 1; continue
            }

            // ── Bullet list ──────────────────────────────────────────────────
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("+ ") {
                if listTag != "ul" { flushList(); listTag = "ul" }
                let content = String(trimmed.dropFirst(2))
                listItems.append(inline(content))
                i += 1; continue
            }

            // ── Numbered list ────────────────────────────────────────────────
            if let numContent = trimmed.numberedListContent {
                if listTag != "ol" { flushList(); listTag = "ol" }
                listItems.append(inline(numContent))
                i += 1; continue
            }

            // ── Paragraph ────────────────────────────────────────────────────
            flushList()
            html += "<p>\(inline(trimmed))</p>\n"
            i += 1
        }

        flushList()
        if inFenced {
            html += "<pre><code>\(fenceLines.joined(separator: "\n").htmlEscaped)</code></pre>\n"
        }
        return html
    }

    // MARK: - Inline conversion

    private static func inline(_ text: String) -> String {
        var s = text.htmlEscaped
        // Bold + italic
        s = s.replacingOccurrences(of: #"\*\*\*(.+?)\*\*\*"#,
                                    with: "<strong><em>$1</em></strong>",
                                    options: .regularExpression)
        // Bold
        s = s.replacingOccurrences(of: #"\*\*(.+?)\*\*"#,
                                    with: "<strong>$1</strong>",
                                    options: .regularExpression)
        // Italic
        s = s.replacingOccurrences(of: #"(?<!\*)\*(?!\*)(.+?)\*(?!\*)"#,
                                    with: "<em>$1</em>",
                                    options: .regularExpression)
        // Strikethrough
        s = s.replacingOccurrences(of: #"~~(.+?)~~"#,
                                    with: "<del>$1</del>",
                                    options: .regularExpression)
        // Inline code — keep content un-escaped inside the backticks:
        // We already escaped the whole string, so backtick content is fine.
        s = s.replacingOccurrences(of: #"`([^`]+?)`"#,
                                    with: "<code>$1</code>",
                                    options: .regularExpression)
        // Links
        s = s.replacingOccurrences(of: #"\[([^\]]+)\]\(([^\)]+)\)"#,
                                    with: "<a href=\"$2\">$1</a>",
                                    options: .regularExpression)
        return s
    }
}

// MARK: - Helpers

private extension String {

    var htmlEscaped: String {
        self
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    func matches(_ pattern: String) -> Bool {
        (try? NSRegularExpression(pattern: pattern))
            .flatMap { $0.firstMatch(in: self, range: NSRange(self.startIndex..., in: self)) } != nil
    }

    /// Returns `(checked, text)` if the line is a task list item, else `nil`.
    var taskListContent: (Bool, String)? {
        let t = self.trimmingCharacters(in: .whitespaces)
        for prefix in ["- [ ] ", "- [x] ", "- [X] "] {
            if t.hasPrefix(prefix) {
                let checked = prefix.contains("x") || prefix.contains("X")
                return (checked, String(t.dropFirst(prefix.count)))
            }
        }
        return nil
    }

    /// Returns the list item text if the line begins with `N. `, else `nil`.
    var numberedListContent: String? {
        guard let dot = self.firstIndex(of: "."),
              self[self.startIndex..<dot].allSatisfy(\.isNumber),
              self.index(after: dot) < self.endIndex,
              self[self.index(after: dot)] == " "
        else { return nil }
        return String(self[self.index(dot, offsetBy: 2)...])
    }
}
