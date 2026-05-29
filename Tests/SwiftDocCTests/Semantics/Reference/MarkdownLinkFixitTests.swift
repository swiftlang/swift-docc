/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Testing
@testable import SwiftDocC
import DocCTestUtilities
import SymbolKit

struct MarkdownLinkFixitTests {
    @Test
    func suggestedReplacementsAnchorToTheLinkDestinationForMarkdownLinkSyntax() async throws {
        // Two overloaded top-level functions that share the same path. Linking to that path without a disambiguation
        // is ambiguous, which is what produces the different kinds of suggested replacements being verified below.
        let catalog = Folder(name: "unit-test.docc", content: [
            JSONFile(name: "MyKit.symbols.json", content: makeSymbolGraph(
                moduleName: "MyKit",
                symbols: [
                    makeSymbol(id: "some-overload-id",  kind: .func, pathComponents: ["doSomething()"]),
                    makeSymbol(id: "other-overload-id", kind: .func, pathComponents: ["doSomething()"]),
                ]
            )),
            TextFile(name: "MyKit.md", utf8Content: markdownSource),
        ])
        let context = try await load(catalog: catalog)

        // These inputs should only produce one unresolved-reference diagnostic per link, so any unexpected diagnostic
        // should fail the test instead of being filtered away.
        #expect(
            context.diagnostics.map(\.identifier) == Array(repeating: "org.swift.docc.unresolvedTopicReference", count: 3),
            "Encountered unexpected problems: \(context.diagnostics.map(\.summary))"
        )

        // A near miss replaces only the misspelled path, keeping the rest of the markdown link intact.
        var diagnostic = try #require(context.diagnostics.first(where: { $0.summary == "'doSomethign()' doesn't exist at '/MyKit'" }))
        #expect(diagnostic.solutions.map { [$0.summary, $0.replacements.first?.replacement] } == [
            ["Replace 'doSomethign()' with 'doSomething()'", "doSomething()"],
        ])
        #expect(try #require(diagnostic.solutions.first).applyTo(markdownSource) == """
        # ``MyKit``

        Three links with different issues. Their solutions should only modify the link's destination.

        - [a near miss](doc:doSomething())
        - [an ambiguous reference](doc:doSomething())
        - [a wrong disambiguation](doc:doSomething()-class)
        """)

        // An ambiguous reference inserts a disambiguation suffix immediately after the path, not before it.
        diagnostic = try #require(context.diagnostics.first(where: { $0.summary == "'doSomething()' is ambiguous at '/MyKit'" }))
        #expect(diagnostic.solutions.map { [$0.summary, $0.replacements.first?.replacement] } == [
            ["Insert '-1j23c' for \n'doSomething()'", "-1j23c"],
            ["Insert '-7bbou' for \n'doSomething()'", "-7bbou"],
        ])
        #expect(try #require(diagnostic.solutions.first).applyTo(markdownSource) == """
        # ``MyKit``

        Three links with different issues. Their solutions should only modify the link's destination.

        - [a near miss](doc:doSomethign())
        - [an ambiguous reference](doc:doSomething()-1j23c)
        - [a wrong disambiguation](doc:doSomething()-class)
        """)

        // A wrong disambiguation replaces just the disambiguation suffix, keeping the rest of the markdown link intact.
        diagnostic = try #require(context.diagnostics.first(where: { $0.summary == "'class' isn't a disambiguation for 'doSomething()' at '/MyKit'" }))
        #expect(diagnostic.solutions.map { [$0.summary, $0.replacements.first?.replacement] } == [
            ["Replace 'class' with '1j23c' for \n'doSomething()'", "-1j23c"],
            ["Replace 'class' with '7bbou' for \n'doSomething()'", "-7bbou"],
        ])
        #expect(try #require(diagnostic.solutions.first).applyTo(markdownSource) == """
        # ``MyKit``

        Three links with different issues. Their solutions should only modify the link's destination.

        - [a near miss](doc:doSomethign())
        - [an ambiguous reference](doc:doSomething())
        - [a wrong disambiguation](doc:doSomething()-1j23c)
        """)
    }

    // The documentation extension content shared by the assertions. Applying each suggested replacement to this source
    // is what verifies that the replacement's range is anchored to the link's destination and not its display text.
    private let markdownSource = """
    # ``MyKit``

    Three links with different issues. Their solutions should only modify the link's destination.

    - [a near miss](doc:doSomethign())
    - [an ambiguous reference](doc:doSomething())
    - [a wrong disambiguation](doc:doSomething()-class)
    """
}
