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
    /// Verifies that suggested replacements (fixits) for unresolved references are anchored correctly when the
    /// reference is authored using the `[link text](doc:my/reference)` markdown link syntax instead of the
    /// `<doc:my/reference>` autolink syntax.
    ///
    /// Because the markdown link syntax has more characters before the reference's path than the autolink syntax, a
    /// fixit that's anchored as if the reference used the autolink syntax would be offset into the link's display text.
    /// See https://github.com/swiftlang/swift-docc/issues/470
    @Test
    func anchorsFixitsToReferencePathForMarkdownLinkSyntax() async throws {
        // A class with one method and two initializers that share the same path. The two initializers make `init()`
        // an ambiguous reference, and the specific symbol identifiers are reused so that the disambiguation suffixes
        // are the deterministic "-33vaw" and "-3743d" hashes that the assertions below expect.
        let catalog = Folder(name: "unit-test.docc", content: [
            JSONFile(name: "MyKit.symbols.json", content: makeSymbolGraph(
                moduleName: "MyKit",
                symbols: [
                    makeSymbol(id: "s:5MyKit0A5ClassC",                 kind: .class, pathComponents: ["MyClass"]),
                    makeSymbol(id: "s:5MyKit0A5ClassC10myFunctionyyF",  kind: .method, pathComponents: ["MyClass", "myFunction()"]),
                    makeSymbol(id: "s:5MyKit0A5ClassCACycfc",           kind: .`init`, pathComponents: ["MyClass", "init()"]),
                    makeSymbol(id: "s:5MyKit0A5ClassCACycfcDUPLICATE",  kind: .`init`, pathComponents: ["MyClass", "init()"]),
                ],
                relationships: [
                    SymbolGraph.Relationship(source: "s:5MyKit0A5ClassC10myFunctionyyF", target: "s:5MyKit0A5ClassC", kind: .memberOf, targetFallback: nil),
                    SymbolGraph.Relationship(source: "s:5MyKit0A5ClassCACycfc",          target: "s:5MyKit0A5ClassC", kind: .memberOf, targetFallback: nil),
                    SymbolGraph.Relationship(source: "s:5MyKit0A5ClassCACycfcDUPLICATE", target: "s:5MyKit0A5ClassC", kind: .memberOf, targetFallback: nil),
                ]
            )),

            // A documentation extension that curates three references using the markdown link syntax. Each reference is
            // unresolvable in a different way so that it exercises a different kind of suggested replacement.
            TextFile(name: "MyClass.md", utf8Content: markdownSource),
        ])
        let context = try await load(catalog: catalog)

        let unresolvedTopicDiagnostics = context.diagnostics.filter { $0.identifier == "org.swift.docc.unresolvedTopicReference" }

        // A near miss replaces only the misspelled path component, keeping the surrounding markdown link intact.
        var diagnostic = try #require(unresolvedTopicDiagnostics.first(where: { $0.summary == "'otherFunction()' doesn't exist at '/MyKit/MyClass'" }))
        #expect(diagnostic.solutions.count == 1)
        #expect(diagnostic.solutions.map { [$0.summary, $0.replacements.first!.replacement] } == [
            ["Replace 'otherFunction()' with 'myFunction()'", "myFunction()"],
        ])
        #expect(try diagnostic.solutions.first!.applyTo(markdownSource) == """
        # ``MyKit/MyClass``

        @Metadata {
           @DocumentationExtension(mergeBehavior: override)
        }

        A cool API to call.

        ## Topics

        ### Near Miss

        - [a near miss](doc:myFunction())

        ### Ambiguous curation

        - [an ambiguous reference](doc:MyClass/init())
        - [a wrong disambiguation](doc:MyClass/init()-swift.init)
        """)

        // An ambiguous reference inserts a disambiguation suffix immediately after the path, not before it.
        diagnostic = try #require(unresolvedTopicDiagnostics.first(where: { $0.summary == "'init()' is ambiguous at '/MyKit/MyClass'" }))
        #expect(diagnostic.solutions.count == 2)
        #expect(diagnostic.solutions.map { [$0.summary, $0.replacements.first!.replacement] } == [
            ["Insert '-33vaw' for \n'init()'", "-33vaw"],
            ["Insert '-3743d' for \n'init()'", "-3743d"],
        ])
        #expect(try diagnostic.solutions.first!.applyTo(markdownSource) == """
        # ``MyKit/MyClass``

        @Metadata {
           @DocumentationExtension(mergeBehavior: override)
        }

        A cool API to call.

        ## Topics

        ### Near Miss

        - [a near miss](doc:otherFunction())

        ### Ambiguous curation

        - [an ambiguous reference](doc:MyClass/init()-33vaw)
        - [a wrong disambiguation](doc:MyClass/init()-swift.init)
        """)

        // A wrong disambiguation replaces just the disambiguation suffix, keeping the markdown link intact.
        diagnostic = try #require(unresolvedTopicDiagnostics.first(where: { $0.summary == "'init()-swift.init' is ambiguous at '/MyKit/MyClass'" }))
        #expect(diagnostic.solutions.count == 2)
        #expect(diagnostic.solutions.map { [$0.summary, $0.replacements.first!.replacement] } == [
            ["Replace 'swift.init' with '33vaw' for \n'init()'", "-33vaw"],
            ["Replace 'swift.init' with '3743d' for \n'init()'", "-3743d"],
        ])
        #expect(try diagnostic.solutions.first!.applyTo(markdownSource) == """
        # ``MyKit/MyClass``

        @Metadata {
           @DocumentationExtension(mergeBehavior: override)
        }

        A cool API to call.

        ## Topics

        ### Near Miss

        - [a near miss](doc:otherFunction())

        ### Ambiguous curation

        - [an ambiguous reference](doc:MyClass/init())
        - [a wrong disambiguation](doc:MyClass/init()-33vaw)
        """)
    }

    /// The documentation extension content shared by the assertions above. Applying each suggested replacement to this
    /// source is what verifies that the fixit's source range is anchored to the reference's path.
    private let markdownSource = """
    # ``MyKit/MyClass``

    @Metadata {
       @DocumentationExtension(mergeBehavior: override)
    }

    A cool API to call.

    ## Topics

    ### Near Miss

    - [a near miss](doc:otherFunction())

    ### Ambiguous curation

    - [an ambiguous reference](doc:MyClass/init())
    - [a wrong disambiguation](doc:MyClass/init()-swift.init)
    """
}
