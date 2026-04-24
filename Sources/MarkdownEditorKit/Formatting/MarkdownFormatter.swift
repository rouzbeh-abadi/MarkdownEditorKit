//
//  MarkdownFormatter.swift
//  MarkdownEditorKit
//
//  Created by Rouzbeh Abadi on 2026-04-24.
//

import Foundation

/// A pure, stateless utility that applies ``MarkdownAction``s to a string.
///
/// `MarkdownFormatter` is deliberately decoupled from `UITextView` and
/// SwiftUI. Every method takes a text and an `NSRange` selection, and returns
/// a ``Result`` containing the transformed text together with the selection to
/// apply back to the text view. This makes the formatter trivial to
/// unit-test, and makes it equally suitable for driving your own UI.
///
/// ```swift
/// let result = MarkdownFormatter.apply(.bold,
///                                      to: "Hello, world!",
///                                      in: NSRange(location: 0, length: 5))
/// // result.text      → "**Hello**, world!"
/// // result.selection → NSRange(location: 2, length: 5)
/// ```
public enum MarkdownFormatter {

    /// The outcome of applying a formatting action.
    public struct Result: Equatable, Sendable {

        /// The transformed source text.
        public let text: String

        /// The selection range, in UTF-16 code units, to assign back to the
        /// text view after applying the action.
        public let selection: NSRange

        /// Creates a result.
        public init(text: String, selection: NSRange) {
            self.text = text
            self.selection = selection
        }
    }

    /// Applies `action` to `text` at the given `selection`.
    ///
    /// Out-of-bounds selections are clamped to the length of the text, so the
    /// method is safe to call with a stale selection.
    ///
    /// - Parameters:
    ///   - action: The action to apply.
    ///   - text: The current Markdown source.
    ///   - selection: The user's current selection, in UTF-16 code units.
    /// - Returns: A ``Result`` containing the transformed text and the
    ///   selection to assign back.
    public static func apply(_ action: MarkdownAction,
                             to text: String,
                             in selection: NSRange) -> Result {
        switch action {
        case .bold:
            wrapInline(in: text, selection: selection, delimiter: "**", placeholder: "bold")
        case .italic:
            wrapInline(in: text, selection: selection, delimiter: "*", placeholder: "italic")
        case .strikethrough:
            wrapInline(in: text, selection: selection, delimiter: "~~", placeholder: "strikethrough")
        case .inlineCode:
            wrapInline(in: text, selection: selection, delimiter: "`", placeholder: "code")
        case .heading(let level):
            prefixBlock(in: text, selection: selection, prefix: headingPrefix(for: level))
        case .bulletList:
            prefixBlock(in: text, selection: selection, prefix: "- ")
        case .numberedList:
            prefixNumberedBlock(in: text, selection: selection)
        case .taskList:
            prefixTaskBlock(in: text, selection: selection)
        case .quote:
            prefixBlock(in: text, selection: selection, prefix: "> ")
        case .codeBlock:
            wrapCodeBlock(in: text, selection: selection)
        case .link:
            insertLink(in: text, selection: selection)
        case .image:
            insertImage(in: text, selection: selection)
        case .imagePicker:
            // The picker action is handled by the host via its
            // `onImagePick` callback; the formatter never mutates the
            // text for this action. Returning the input unchanged keeps
            // the method total.
            Result(text: text, selection: clamp(selection, length: (text as NSString).length))
        case .horizontalRule:
            insertHorizontalRule(in: text, selection: selection)
        }
    }

    // MARK: - Inline wrapping

    static func wrapInline(in text: String,
                           selection: NSRange,
                           delimiter: String,
                           placeholder: String) -> Result {
        let ns = text as NSString
        let clamped = clamp(selection, length: ns.length)
        let selected = ns.substring(with: clamped)

        if isInlineWrapped(selection: clamped, in: ns, with: delimiter) {
            return unwrapInline(in: text, selection: clamped, delimiter: delimiter)
        }

        let content = selected.isEmpty ? placeholder : selected
        let insertion = delimiter + content + delimiter
        let newText = ns.replacingCharacters(in: clamped, with: insertion)
        let delimiterLength = (delimiter as NSString).length
        let contentLength = (content as NSString).length
        let newSelection = NSRange(location: clamped.location + delimiterLength,
                                   length: contentLength)
        return Result(text: newText, selection: newSelection)
    }

    static func isInlineWrapped(selection: NSRange,
                                in ns: NSString,
                                with delimiter: String) -> Bool {
        let delimiterLength = (delimiter as NSString).length
        guard selection.location >= delimiterLength,
              selection.location + selection.length + delimiterLength <= ns.length
        else {
            return false
        }
        let leftRange = NSRange(location: selection.location - delimiterLength, length: delimiterLength)
        let rightRange = NSRange(location: selection.location + selection.length, length: delimiterLength)
        guard ns.substring(with: leftRange) == delimiter,
              ns.substring(with: rightRange) == delimiter
        else {
            return false
        }

        // Disambiguate single `*` from part of a larger `**` delimiter.
        if delimiter == "*" {
            let beforeIndex = selection.location - delimiterLength - 1
            let afterIndex = selection.location + selection.length + delimiterLength
            if beforeIndex >= 0,
               ns.substring(with: NSRange(location: beforeIndex, length: 1)) == "*" {
                return false
            }
            if afterIndex < ns.length,
               ns.substring(with: NSRange(location: afterIndex, length: 1)) == "*" {
                return false
            }
        }
        return true
    }

    static func unwrapInline(in text: String,
                             selection: NSRange,
                             delimiter: String) -> Result {
        let ns = text as NSString
        let delimiterLength = (delimiter as NSString).length
        let expanded = NSRange(location: selection.location - delimiterLength,
                               length: selection.length + 2 * delimiterLength)
        let content = ns.substring(with: selection)
        let newText = ns.replacingCharacters(in: expanded, with: content)
        let newSelection = NSRange(location: selection.location - delimiterLength,
                                   length: selection.length)
        return Result(text: newText, selection: newSelection)
    }

    // MARK: - Block prefixing

    static func prefixBlock(in text: String,
                            selection: NSRange,
                            prefix: String) -> Result {
        let ns = text as NSString
        let clamped = clamp(selection, length: ns.length)
        let lineRange = ns.lineRange(for: clamped)
        let block = ns.substring(with: lineRange)

        let endsInNewline = block.hasSuffix("\n")
        let body = endsInNewline ? String(block.dropLast()) : block
        let lines = body.components(separatedBy: "\n")
        let firstLineHadPrefix = lines.first?.hasPrefix(prefix) ?? false

        let updated = lines.map { line -> String in
            if line.hasPrefix(prefix) {
                return String(line.dropFirst(prefix.count))
            } else {
                return prefix + line
            }
        }.joined(separator: "\n")

        let replacement = endsInNewline ? updated + "\n" : updated
        let newText = ns.replacingCharacters(in: lineRange, with: replacement)

        let updatedLength = (updated as NSString).length
        let newSelection = selectionForBlockEdit(originalSelection: clamped,
                                                  lineRange: lineRange,
                                                  updatedLength: updatedLength,
                                                  shift: firstLineHadPrefix ? -(prefix as NSString).length : (prefix as NSString).length)
        return Result(text: newText, selection: newSelection)
    }

    static func prefixNumberedBlock(in text: String,
                                    selection: NSRange) -> Result {
        let ns = text as NSString
        let clamped = clamp(selection, length: ns.length)
        let lineRange = ns.lineRange(for: clamped)
        let block = ns.substring(with: lineRange)

        let endsInNewline = block.hasSuffix("\n")
        let body = endsInNewline ? String(block.dropLast()) : block
        let lines = body.components(separatedBy: "\n")

        let numberedPrefix = #/^\d+\.\s/#
        let allNumbered = !lines.isEmpty && lines.allSatisfy { line in
            line.firstMatch(of: numberedPrefix) != nil
        }

        let updatedLines: [String]
        let firstLineShift: Int
        if allNumbered {
            updatedLines = lines.map { line in
                line.replacing(numberedPrefix, with: "")
            }
            let firstOriginalLen = ((lines.first ?? "") as NSString).length
            let firstUpdatedLen = ((updatedLines.first ?? "") as NSString).length
            firstLineShift = firstUpdatedLen - firstOriginalLen
        } else {
            updatedLines = lines.enumerated().map { offset, line in
                "\(offset + 1). \(line)"
            }
            firstLineShift = ("1. " as NSString).length
        }

        let updated = updatedLines.joined(separator: "\n")
        let replacement = endsInNewline ? updated + "\n" : updated
        let newText = ns.replacingCharacters(in: lineRange, with: replacement)
        let updatedLength = (updated as NSString).length
        let newSelection = selectionForBlockEdit(originalSelection: clamped,
                                                  lineRange: lineRange,
                                                  updatedLength: updatedLength,
                                                  shift: firstLineShift)
        return Result(text: newText, selection: newSelection)
    }

    // MARK: - Task list

    /// Prefixes each selected line with `- [ ] ` to produce a GitHub-flavoured
    /// Markdown task list, or removes the marker when every selected line is
    /// already a task item.
    ///
    /// Lines that are already task items — either checked (`- [x] `) or
    /// unchecked (`- [ ] `) — are recognised and stripped. Lines that are
    /// plain bullets (`- `) are *not* treated as task items; the action adds
    /// a separate `- [ ] ` prefix in front of them.
    static func prefixTaskBlock(in text: String,
                                selection: NSRange) -> Result {
        let ns = text as NSString
        let clamped = clamp(selection, length: ns.length)
        let lineRange = ns.lineRange(for: clamped)
        let block = ns.substring(with: lineRange)

        let endsInNewline = block.hasSuffix("\n")
        let body = endsInNewline ? String(block.dropLast()) : block
        let lines = body.components(separatedBy: "\n")

        let taskPattern = #/^- \[[ xX]\] /#
        let allTasks = !lines.isEmpty && lines.allSatisfy { line in
            line.firstMatch(of: taskPattern) != nil
        }

        let updatedLines: [String]
        let firstLineShift: Int
        if allTasks {
            updatedLines = lines.map { line in
                line.replacing(taskPattern, with: "")
            }
            let firstOriginalLen = ((lines.first ?? "") as NSString).length
            let firstUpdatedLen = ((updatedLines.first ?? "") as NSString).length
            firstLineShift = firstUpdatedLen - firstOriginalLen
        } else {
            updatedLines = lines.map { "- [ ] \($0)" }
            firstLineShift = ("- [ ] " as NSString).length
        }

        let updated = updatedLines.joined(separator: "\n")
        let replacement = endsInNewline ? updated + "\n" : updated
        let newText = ns.replacingCharacters(in: lineRange, with: replacement)
        let updatedLength = (updated as NSString).length
        let newSelection = selectionForBlockEdit(originalSelection: clamped,
                                                  lineRange: lineRange,
                                                  updatedLength: updatedLength,
                                                  shift: firstLineShift)
        return Result(text: newText, selection: newSelection)
    }

    // MARK: - Block selection helper

    /// Computes the post-edit selection for a block-level prefix operation.
    ///
    /// For caret inputs (zero-length selections) the caret is shifted by
    /// `shift` — the same amount the first line grew or shrank — so the
    /// cursor ends up at the same logical position within the edited line.
    /// This avoids the "the inserted prefix is selected and typing replaces
    /// it" bug that plagues naive block-prefix implementations on empty
    /// lines.
    ///
    /// For range inputs the selection is expanded to cover the full updated
    /// block, which matches what editors like iA Writer and Typora do when
    /// you tap a list-ish action while a paragraph is selected.
    static func selectionForBlockEdit(originalSelection: NSRange,
                                      lineRange: NSRange,
                                      updatedLength: Int,
                                      shift: Int) -> NSRange {
        if originalSelection.length == 0 {
            let upperBound = lineRange.location + updatedLength
            let shifted = originalSelection.location + shift
            let clamped = min(max(shifted, lineRange.location), upperBound)
            return NSRange(location: clamped, length: 0)
        }
        return NSRange(location: lineRange.location, length: updatedLength)
    }

    // MARK: - Code block

    static func wrapCodeBlock(in text: String,
                              selection: NSRange) -> Result {
        let ns = text as NSString
        let clamped = clamp(selection, length: ns.length)
        let selected = ns.substring(with: clamped)
        let body = selected.isEmpty ? "code" : selected
        let insertion = "```\n\(body)\n```"
        let newText = ns.replacingCharacters(in: clamped, with: insertion)

        let openingLength = 4 // "```\n"
        let bodyLength = (body as NSString).length
        return Result(text: newText,
                      selection: NSRange(location: clamped.location + openingLength, length: bodyLength))
    }

    // MARK: - Link and image

    static func insertLink(in text: String,
                           selection: NSRange) -> Result {
        insertLinkLike(in: text,
                       selection: selection,
                       prefix: "[",
                       placeholderTitle: "title")
    }

    static func insertImage(in text: String,
                            selection: NSRange) -> Result {
        insertLinkLike(in: text,
                       selection: selection,
                       prefix: "![",
                       placeholderTitle: "alt text")
    }

    private static func insertLinkLike(in text: String,
                                       selection: NSRange,
                                       prefix: String,
                                       placeholderTitle: String) -> Result {
        let ns = text as NSString
        let clamped = clamp(selection, length: ns.length)
        let selected = ns.substring(with: clamped)
        let title = selected.isEmpty ? placeholderTitle : selected
        let urlPlaceholder = "https://"
        let insertion = "\(prefix)\(title)](\(urlPlaceholder))"
        let newText = ns.replacingCharacters(in: clamped, with: insertion)

        let prefixLength = (prefix as NSString).length
        let titleLength = (title as NSString).length
        let urlLength = (urlPlaceholder as NSString).length

        if selected.isEmpty {
            // Select the placeholder title so the user can type over it first.
            return Result(text: newText,
                          selection: NSRange(location: clamped.location + prefixLength, length: titleLength))
        } else {
            // Select the URL placeholder so the user can paste or type the URL.
            let urlStart = clamped.location + prefixLength + titleLength + 2 // "](
            return Result(text: newText,
                          selection: NSRange(location: urlStart, length: urlLength))
        }
    }

    // MARK: - Horizontal rule

    static func insertHorizontalRule(in text: String,
                                     selection: NSRange) -> Result {
        let ns = text as NSString
        let clamped = clamp(selection, length: ns.length)

        let atLineStart = clamped.location == 0
            || ns.substring(with: NSRange(location: clamped.location - 1, length: 1)) == "\n"
        let leading = atLineStart ? "" : "\n"
        let insertion = "\(leading)---\n"

        let newText = ns.replacingCharacters(in: clamped, with: insertion)
        let cursor = clamped.location + (insertion as NSString).length
        return Result(text: newText, selection: NSRange(location: cursor, length: 0))
    }

    // MARK: - Utilities

    /// Clamps an `NSRange` to `[0, length]` and truncates a trailing length
    /// that would run past the end of the text.
    ///
    /// This is useful whenever an external selection might be stale relative
    /// to the text the formatter is asked to transform.
    static func clamp(_ range: NSRange, length: Int) -> NSRange {
        let location = max(0, min(range.location, length))
        let maxRangeLength = length - location
        let rangeLength = max(0, min(range.length, maxRangeLength))
        return NSRange(location: location, length: rangeLength)
    }

    /// Returns the heading prefix for a given level, clamped to `1...6`.
    static func headingPrefix(for level: Int) -> String {
        let clampedLevel = max(1, min(6, level))
        return String(repeating: "#", count: clampedLevel) + " "
    }
}
