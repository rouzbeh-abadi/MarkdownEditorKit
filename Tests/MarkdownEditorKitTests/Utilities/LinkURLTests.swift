//
//  LinkURLTests.swift
//  MarkdownEditorKit
//
//  Created by Rouzbeh Abadi on 2026-04-26.
//

import Foundation
import Testing
@testable import MarkdownEditorKit

@Suite("LinkURL")
struct LinkURLTests {

    @Test("Empty input returns nil")
    func emptyReturnsNil() {
        #expect(LinkURL.normalize("") == nil)
        #expect(LinkURL.normalize("   ") == nil)
    }

    @Test("https URL is preserved")
    func httpsPreserved() {
        #expect(LinkURL.normalize("https://example.com")?.absoluteString == "https://example.com")
    }

    @Test("http URL is preserved")
    func httpPreserved() {
        #expect(LinkURL.normalize("http://example.com")?.absoluteString == "http://example.com")
    }

    @Test("Schemeless host gets https prefix")
    func schemelessGetsHTTPS() {
        #expect(LinkURL.normalize("example.com")?.absoluteString == "https://example.com")
    }

    @Test("Schemeless host with path gets https prefix")
    func schemelessHostWithPathGetsHTTPS() {
        #expect(LinkURL.normalize("apple.com/notes")?.absoluteString == "https://apple.com/notes")
    }

    @Test("mailto URL is preserved")
    func mailtoPreserved() {
        #expect(LinkURL.normalize("mailto:hi@example.com")?.absoluteString == "mailto:hi@example.com")
    }

    @Test("tel URL is preserved")
    func telPreserved() {
        #expect(LinkURL.normalize("tel:+15551234")?.absoluteString == "tel:+15551234")
    }

    @Test("Whitespace is trimmed")
    func whitespaceTrimmed() {
        #expect(LinkURL.normalize("  https://x.com  ")?.absoluteString == "https://x.com")
    }
}
