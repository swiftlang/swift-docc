/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Testing
import Markdown
import SymbolKit
@testable import SwiftDocC
import DocCTestUtilities

struct MixedTermListDiagnosticTests {
    @Test
    func warnsAboutListItemsWithoutTermsInListWithTerms() async throws {
        let catalog = Folder(name: "unit-test.docc", content: [
            TextFile(name: "Article.md", utf8Content: """
            # Article

            An abstract.

            - term First: The first definition.
            - termSecond: The second definition.
            - term Third: The third definition.
            - An item that doesn't define a term.
            """),
        ])

        let context = try await load(catalog: catalog)
        let diagnostics = context.diagnostics.filter { $0.identifier == "org.swift.docc.MixedTermList" }
        #expect(diagnostics.map(\.summary) == ["List item doesn't define a term, but other items in the same list do"])

        let diagnostic = try #require(diagnostics.first)
        #expect(diagnostic.range?.lowerBound.line == 6)
        #expect(diagnostic.notes.map { $0.range.lowerBound.line } == [8])
    }

    @Test
    func doesNotWarnAboutListsWhereAllItemsOrNoItemsDefineTerms() async throws {
        let catalog = Folder(name: "unit-test.docc", content: [
            TextFile(name: "Article.md", utf8Content: """
            # Article

            An abstract.

            - term First: The first definition.
              - A nested item.
            - term Second: The second definition.

            * An item.
            * Another item.
            """),
        ])

        let context = try await load(catalog: catalog)
        #expect(!context.diagnostics.contains { $0.identifier == "org.swift.docc.MixedTermList" })
    }

    @Test
    func doesNotWarnAboutAsideItemsNextToTermsInDocComment() async throws {
        let catalog = Folder(name: "unit-test.docc", content: [
            JSONFile(name: "ModuleName.symbols.json", content: makeSymbolGraph(
                moduleName: "ModuleName",
                symbols: [
                    makeSymbol(
                        id: "some-symbol-id",
                        kind: .class,
                        pathComponents: ["SomeClass"],
                        docComment: """
                        The symbol's abstract.

                        - term First: The first definition.
                        - Note: A note that becomes an aside.
                        - term Second: The second definition.
                        """
                    ),
                ]
            )),
        ])

        let context = try await load(catalog: catalog)
        #expect(context.diagnostics.isEmpty, "Unexpected diagnostics: \(context.diagnostics.map(\.summary))")
    }

    @Test
    func warnsOnceAboutListItemWithoutTermInDocComment() async throws {
        let catalog = Folder(name: "unit-test.docc", content: [
            JSONFile(name: "ModuleName.symbols.json", content: makeSymbolGraph(
                moduleName: "ModuleName",
                symbols: [
                    makeSymbol(
                        id: "some-symbol-id",
                        kind: .class,
                        pathComponents: ["SomeClass"],
                        docComment: """
                        The symbol's abstract.

                        - term First: The first definition.
                        - termSecond: The second definition.
                        """,
                        location: (position: .init(line: 0, character: 0), url: URL(fileURLWithPath: "/path/to/SomeFile.swift"))
                    ),
                ]
            )),
        ])

        let context = try await load(catalog: catalog)
        let diagnostics = context.diagnostics.filter { $0.identifier == "org.swift.docc.MixedTermList" }
        #expect(diagnostics.map { $0.range?.lowerBound.line } == [4])
        #expect(diagnostics.map { $0.source?.path } == ["/path/to/SomeFile.swift"])
    }
}
