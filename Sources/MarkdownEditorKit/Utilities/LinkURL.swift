//
//  LinkURL.swift
//  MarkdownEditorKit
//
//  Created by Rouzbeh Abadi on 2026-04-26.
//

import Foundation

/// Helpers for normalising user-typed link strings into a `URL` the host
/// app can open via `UIApplication.shared.open(_:)`.
///
/// The Markdown editor accepts links written without an explicit scheme
/// (`example.com`, `apple.com/notes`, …). When opening such a link we want
/// the OS to launch the user's browser rather than fail because the
/// `URL` constructor produced a relative URL — so we prepend `https://`
/// unless the string already starts with a recognised scheme.
enum LinkURL {

    /// Returns a `URL` for `string`, prepending `https://` when no
    /// recognised scheme is present. Returns `nil` for empty input.
    static func normalize(_ string: String) -> URL? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let lower = trimmed.lowercased()
        if lower.hasPrefix("http://") || lower.hasPrefix("https://")
            || lower.hasPrefix("mailto:") || lower.hasPrefix("tel:") {
            return URL(string: trimmed)
        }
        return URL(string: "https://" + trimmed)
    }
}
