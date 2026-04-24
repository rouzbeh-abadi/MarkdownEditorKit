//
//  MarkdownActionTests.swift
//  MarkdownEditorKit
//
//  Created by Rouzbeh Abadi on 2026-04-24.
//

import Testing
@testable import MarkdownEditorKit

@Suite("MarkdownAction")
struct MarkdownActionTests {

    private static let allActions: [MarkdownAction] = [
        .bold,
        .italic,
        .strikethrough,
        .heading(level: 1),
        .heading(level: 2),
        .heading(level: 3),
        .heading(level: 6),
        .bulletList,
        .numberedList,
        .taskList,
        .inlineCode,
        .codeBlock,
        .link,
        .image,
        .imagePicker,
        .quote,
        .horizontalRule,
    ]

    @Test("Each action has a unique, stable identifier")
    func identifiersUnique() {
        let ids = Self.allActions.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test("Heading identifiers differ by level")
    func headingIdsDifferByLevel() {
        #expect(MarkdownAction.heading(level: 1).id == "heading-1")
        #expect(MarkdownAction.heading(level: 2).id == "heading-2")
        #expect(MarkdownAction.heading(level: 1).id != MarkdownAction.heading(level: 2).id)
    }

    @Test("Every action maps to a SystemImage with a non-empty name")
    func systemImageNamesNonEmpty() {
        for action in Self.allActions {
            #expect(!action.systemImage.symbolName.isEmpty, "\(action) has empty symbolName")
        }
    }

    @Test("Heading SystemImage varies with level")
    func headingSystemImageByLevel() {
        #expect(MarkdownAction.heading(level: 1).systemImage == .heading1)
        #expect(MarkdownAction.heading(level: 2).systemImage == .heading2)
        #expect(MarkdownAction.heading(level: 6).systemImage == .heading6)
        #expect(MarkdownAction.heading(level: 99).systemImage == .headingGeneric)
    }

    @Test("Every action has a non-empty title")
    func titlesNonEmpty() {
        for action in Self.allActions {
            #expect(!action.title.isEmpty, "\(action) has empty title")
        }
    }

    @Test("Actions with the same payload compare equal")
    func equality() {
        #expect(MarkdownAction.bold == .bold)
        #expect(MarkdownAction.heading(level: 2) == .heading(level: 2))
        #expect(MarkdownAction.heading(level: 2) != .heading(level: 3))
    }
}
