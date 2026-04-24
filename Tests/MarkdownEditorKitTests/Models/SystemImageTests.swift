//
//  SystemImageTests.swift
//  MarkdownEditorKit
//
//  Created by Rouzbeh Abadi on 2026-04-24.
//

import Testing
@testable import MarkdownEditorKit

@Suite("SystemImage")
struct SystemImageTests {

    @Test("Every case has a non-empty symbol name")
    func symbolNamesNonEmpty() {
        for image in SystemImage.allCases {
            #expect(!image.symbolName.isEmpty, "\(image) has empty symbolName")
        }
    }

    @Test("symbolName equals the raw value")
    func symbolNameEqualsRawValue() {
        for image in SystemImage.allCases {
            #expect(image.symbolName == image.rawValue)
        }
    }

    @Test("Symbol names are unique across cases")
    func symbolNamesUnique() {
        let names = SystemImage.allCases.map(\.symbolName)
        #expect(Set(names).count == names.count)
    }

    @Test("Known symbol names match their expected SF Symbol strings")
    func knownSymbolNames() {
        #expect(SystemImage.bold.symbolName == "bold")
        #expect(SystemImage.italic.symbolName == "italic")
        #expect(SystemImage.heading1.symbolName == "1.square")
        #expect(SystemImage.bulletList.symbolName == "list.bullet")
        #expect(SystemImage.inlineCode.symbolName == "chevron.left.forwardslash.chevron.right")
        #expect(SystemImage.quote.symbolName == "text.quote")
    }
}
