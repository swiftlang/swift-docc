/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024-2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

@testable import SwiftDocC
import XCTest
import SwiftDocCTestUtilities
import SymbolKit

extension XCTestCase {
    /// Creates a test bundle for testing "Mentioned In" features.
    func createMentionedInTestBundle() async throws -> DocumentationContext {
        let catalog = Folder(name: "MentionedIn.docc", content: [
            JSONFile(name: "MentionedIn.symbols.json", content: makeSymbolGraph(
                moduleName: "MentionedIn",
                symbols: [
                    SymbolGraph.Symbol(
                        identifier: .init(precise: "MyClass", interfaceLanguage: "swift"),
                        names: .init(title: "MyClass", navigator: nil, subHeading: nil, prose: nil),
                        pathComponents: ["MyClass"],
                        docComment: nil,
                        accessLevel: .public,
                        kind: .init(parsedIdentifier: .class, displayName: "Class"),
                        mixins: [:]
                    ),
                    SymbolGraph.Symbol(
                        identifier: .init(precise: "myFunction()", interfaceLanguage: "swift"),
                        names: .init(title: "myFunction()", navigator: nil, subHeading: nil, prose: nil),
                        pathComponents: ["MyClass", "myFunction()"],
                        docComment: nil,
                        accessLevel: .public,
                        kind: .init(parsedIdentifier: .func, displayName: "Function"),
                        mixins: [:]
                    )
                ]
            )),

            TextFile(name: "ArticleMentioningSymbol.md", utf8Content: """
                 # Article mentioning a symbol

                 In the abstract, ``MyClass``.

                 ## Other mentions

                 Later, ``MyClass``.
                 """),

            TextFile(name: "APICollectionMentioningSybol.md", utf8Content: """
                 # An API Collection

                 In the abstract, ``MyClass``.

                 ## Other mentions

                 Later, ``MyClass``.

                 This API Collection should not count as an article mention.

                 ## Topics

                 ### Things that don't count as mentions

                 Curation does not count as a significant "mention".

                 - ``MyClass``
                 """),
        ])

        return try await load(catalog: catalog)
    }
}
