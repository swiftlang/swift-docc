/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import XCTest
@testable import SwiftDocC
import SwiftDocCTestUtilities
import SymbolKit

class DeclarationsRenderSectionTests: XCTestCase {
    func testDecodingTokens() throws {
        let values: [(DeclarationRenderSection.Token.Kind, String)] = [
            (.keyword, "keyword"),
            (.attribute, "attribute"),
            (.number, "number"),
            (.string, "string"),
            (.identifier, "identifier"),
            (.typeIdentifier, "typeIdentifier"),
            (.genericParameter, "genericParameter"),
            (.text, "text"),
            (.internalParam, "internalParam"),
            (.externalParam, "externalParam"),
            (.label, "label"),
        ]

        for (token, string) in values {
            let jsonData = """
            {
                "kind": "declarations",
                "declarations": [
                    {
                        "platforms": [],
                        "tokens": [
                            {
                                "text": "",
                                "kind": "\(string)"
                            }
                        ],
                        "otherDeclarations": {
                            "declarations": [
                                {
                                    "identifier": "identifier",
                                    "tokens": [
                                        {
                                            "text": "",
                                            "kind": "\(string)"
                                        }
                                    ]
                                }
                            ],
                            "displayIndex": 0
                        }
                    }
                ]
            }
            """.data(using: .utf8)!

            XCTAssertEqual(
                try JSONDecoder().decode(DeclarationsRenderSection.self, from: jsonData),
                DeclarationsRenderSection(declarations: [
                    DeclarationRenderSection(
                        languages: nil,
                        platforms: [],
                        tokens: [.init(text: "", kind: token)],
                        otherDeclarations: DeclarationRenderSection.OtherDeclarations(
                            declarations: [.init(tokens: [.init(text: "", kind: token)], identifier: "identifier")],
                            displayIndex: 0
                        )
                    ),
                ])
            )
        }
    }

    func testDoNotEmitOtherDeclarationsIfEmpty() throws {

        let encoder = RenderJSONEncoder.makeEncoder(prettyPrint: true)
        let encodedData = try encoder.encode(
            DeclarationsRenderSection(declarations: [
                DeclarationRenderSection(
                    languages: nil,
                    platforms: [],
                    tokens: [.init(text: "", kind: .string)]
                )]
            )
        )
        
        let encodedJsonString = try XCTUnwrap(String(data: encodedData, encoding: .utf8))
        XCTAssertFalse(encodedJsonString.contains("otherDeclarations"))
        XCTAssertFalse(encodedJsonString.contains("indexInOtherDeclarations"))
    }

    func testRoundTrip() throws {
        let jsonData = """
        {
            "kind": "declarations",
            "declarations": [
                {
                    "platforms": [],
                    "tokens": [
                        {
                            "text": "",
                            "kind": "label"
                        }
                    ],
                    "otherDeclarations": {
                        "declarations": [
                            {
                                "identifier": "identifier",
                                "tokens": [
                                    {
                                        "text": "",
                                        "kind": "label"
                                    }
                                ]
                            }
                        ],
                        "displayIndex": 0
                    }
                }
            ]
        }
        """.data(using: .utf8)!

        let value = try JSONDecoder().decode(DeclarationsRenderSection.self, from: jsonData)
        try assertRoundTripCoding(value)
    }

    func testAlternateDeclarations() async throws {
        let (_, context) = try await testBundleAndContext(named: "AlternateDeclarations")
        let reference = ResolvedTopicReference(
            bundleID: context.inputs.id,
            path: "/documentation/AlternateDeclarations/MyClass/present(completion:)",
            sourceLanguage: .swift
        )
        let symbol = try XCTUnwrap(context.entity(with: reference).semantic as? Symbol)
        // Verify that the symbol has the expected data
        XCTAssertEqual(symbol.alternateDeclarationVariants.allValues.count, 2)
        XCTAssert(symbol.alternateDeclarationVariants.allValues.allSatisfy({
            $0.trait == .fallback || Set($0.variant.keys) == [[.iOS, .macOS]]
        }))
        XCTAssertEqual(symbol.alternateSignatureVariants.allValues.count, 2)
        XCTAssert(symbol.alternateSignatureVariants.allValues.allSatisfy({
            $0.trait == .fallback || Set($0.variant.keys) == [[.iOS, .macOS]]
        }))
        
        // Verify that the rendered symbol displays both signatures
        var translator = RenderNodeTranslator(context: context, identifier: reference)
        let renderNode = try XCTUnwrap(translator.visitSymbol(symbol) as? RenderNode)
        let declarationsSection = try XCTUnwrap(renderNode.primaryContentSections.compactMap({ $0 as? DeclarationsRenderSection }).first)

        XCTAssertEqual(declarationsSection.declarations.count, 2)
        XCTAssert(declarationsSection.declarations.allSatisfy({ Set($0.platforms) == Set([.iOS, .iPadOS, .macOS, .catalyst]) }))
    }

    func testPlatformSpecificDeclarations() async throws {
        // init(_ content: MyClass) throws
        let declaration1: SymbolGraph.Symbol.DeclarationFragments = .init(declarationFragments: [
            .init(kind: .keyword, spelling: "init", preciseIdentifier: nil),
            .init(kind: .text, spelling: "(", preciseIdentifier: nil),
            .init(kind: .externalParameter, spelling: "_", preciseIdentifier: nil),
            .init(kind: .text, spelling: " ", preciseIdentifier: nil),
            .init(kind: .internalParameter, spelling: "content", preciseIdentifier: nil),
            .init(kind: .text, spelling: ": ", preciseIdentifier: nil),
            .init(kind: .typeIdentifier, spelling: "MyClass", preciseIdentifier: "s:MyClass"),
            .init(kind: .text, spelling: ") ", preciseIdentifier: nil),
            .init(kind: .keyword, spelling: "throws", preciseIdentifier: nil),
        ])

        // init(_ content: OtherClass) throws
        let declaration2: SymbolGraph.Symbol.DeclarationFragments = .init(declarationFragments: [
            .init(kind: .keyword, spelling: "init", preciseIdentifier: nil),
            .init(kind: .text, spelling: "(", preciseIdentifier: nil),
            .init(kind: .externalParameter, spelling: "_", preciseIdentifier: nil),
            .init(kind: .text, spelling: " ", preciseIdentifier: nil),
            .init(kind: .internalParameter, spelling: "content", preciseIdentifier: nil),
            .init(kind: .text, spelling: ": ", preciseIdentifier: nil),
            .init(kind: .typeIdentifier, spelling: "OtherClass", preciseIdentifier: "s:OtherClass"),
            .init(kind: .text, spelling: ") ", preciseIdentifier: nil),
            .init(kind: .keyword, spelling: "throws", preciseIdentifier: nil),
        ])
        let symbol1 = makeSymbol(
            id: "myInit",
            kind: .func,
            pathComponents: ["myInit"],
            otherMixins: [declaration1])
        let symbol2 = makeSymbol(
            id: "myInit",
            kind: .func,
            pathComponents: ["myInit"],
            otherMixins: [declaration2])
        let symbolGraph1 = makeSymbolGraph(moduleName: "PlatformSpecificDeclarations", platform: .init(operatingSystem: .init(name: "macos")), symbols: [symbol1])
        let symbolGraph2 = makeSymbolGraph(moduleName: "PlatformSpecificDeclarations", platform: .init(operatingSystem: .init(name: "ios")), symbols: [symbol2])

        func runAssertions(forwards: Bool) async throws {
            // Toggling the order of platforms here doesn't necessarily _enforce_ a
            // nondeterminism failure in a unit-test environment, but it does make it
            // much more likely. Make sure that the order of the platform-specific
            // declarations is consistent between runs.
            let catalog = Folder(name: "unit-test.docc", content: [
                InfoPlist(displayName: "PlatformSpecificDeclarations", identifier: "com.test.example"),
                JSONFile(name: "symbols\(forwards ? "1" : "2").symbols.json", content: symbolGraph1),
                JSONFile(name: "symbols\(forwards ? "2" : "1").symbols.json", content: symbolGraph2),
            ])

            let (bundle, context) = try await loadBundle(catalog: catalog)

            let reference = ResolvedTopicReference(
                bundleID: bundle.id,
                path: "/documentation/PlatformSpecificDeclarations/myInit",
                sourceLanguage: .swift
            )
            let symbol = try XCTUnwrap(context.entity(with: reference).semantic as? Symbol)
            var translator = RenderNodeTranslator(context: context, identifier: reference)
            let renderNode = try XCTUnwrap(translator.visitSymbol(symbol) as? RenderNode)
            let declarationsSection = try XCTUnwrap(renderNode.primaryContentSections.compactMap({ $0 as? DeclarationsRenderSection }).first)
            XCTAssertEqual(declarationsSection.declarations.count, 2)

            XCTAssertEqual(Set(declarationsSection.declarations[0].platforms), Set([.iOS, .iPadOS, .catalyst]))
            XCTAssertEqual(declarationsSection.declarations[0].tokens.map(\.text).joined(),
                           "init(_ content: OtherClass) throws")
            XCTAssertEqual(declarationsSection.declarations[1].platforms, [.macOS])
            XCTAssertEqual(declarationsSection.declarations[1].tokens.map(\.text).joined(),
                           "init(_ content: MyClass) throws")
        }

        try await runAssertions(forwards: true)
        try await runAssertions(forwards: false)
    }

    func testHighlightDiff() async throws {
        enableFeatureFlag(\.isExperimentalOverloadedSymbolPresentationEnabled)

        let symbolGraphFile = Bundle.module.url(
            forResource: "FancyOverloads",
            withExtension: "symbols.json",
            subdirectory: "Test Resources"
        )!

        let catalog = Folder(name: "unit-test.docc", content: [
            InfoPlist(displayName: "FancyOverloads", identifier: "com.test.example"),
            CopyOfFile(original: symbolGraphFile),
        ])

        let (bundle, context) = try await loadBundle(catalog: catalog)

        // Make sure that type decorators like arrays, dictionaries, and optionals are correctly highlighted.
        do {
            // func overload1(param: Int) {} // <- overload group
            // func overload1(param: Int?) {}
            // func overload1(param: [Int]) {}
            // func overload1(param: [Int]?) {}
            // func overload1(param: Set<Int>) {}
            // func overload1(param: [Int: Int]) {}
            let reference = ResolvedTopicReference(
                bundleID: bundle.id,
                path: "/documentation/FancyOverloads/overload1(param:)",
                sourceLanguage: .swift
            )
            let symbol = try XCTUnwrap(context.entity(with: reference).semantic as? Symbol)
            var translator = RenderNodeTranslator(context: context, identifier: reference)
            let renderNode = try XCTUnwrap(translator.visitSymbol(symbol) as? RenderNode)
            let declarationsSection = try XCTUnwrap(renderNode.primaryContentSections.compactMap({ $0 as? DeclarationsRenderSection }).first)
            XCTAssertEqual(declarationsSection.declarations.count, 1)
            let declarations = try XCTUnwrap(declarationsSection.declarations.first)

            XCTAssertEqual(
                declarationAndHighlights(for: declarations.tokens),
                [
                    "func overload1(param: Int)",
                    "                          ",
                ]
            )

            XCTAssertEqual(
                declarations.otherDeclarations?.declarations.flatMap({ declarationAndHighlights(for: $0.tokens) }),
                [
                    "func overload1(param: Int?)",
                    "                         ~ ",

                    "func overload1(param: Set<Int>)",
                    "                      ~~~~   ~ ",

                    "func overload1(param: [Int : Int])",
                    "                      ~    ~~~~~~ ",

                    "func overload1(param: [Int])",
                    "                      ~   ~ ",

                    "func overload1(param: [Int]?)",
                    "                      ~   ~~ ",
                ]
            )
        }

        // Verify the behavior of the highlighter in the face of tuples and closures, which can
        // confuse the differencing code with excess parentheses and commas.
        do {
            // func overload2(p1: Int, p2: Int) {}
            // func overload2(p1: (Int, Int), p2: Int) {}
            // func overload2(p1: Int, p2: (Int, Int)) {}
            // func overload2(p1: (Int) -> (), p2: Int) {}
            // func overload2(p1: (Int) -> Int, p2: Int) {}
            // func overload2(p1: (Int) -> Int?, p2: Int) {}
            // func overload2(p1: ((Int) -> Int)?, p2: Int) {} // <- overload group
            let reference = ResolvedTopicReference(
                bundleID: bundle.id,
                path: "/documentation/FancyOverloads/overload2(p1:p2:)",
                sourceLanguage: .swift
            )
            let symbol = try XCTUnwrap(context.entity(with: reference).semantic as? Symbol)
            var translator = RenderNodeTranslator(context: context, identifier: reference)
            let renderNode = try XCTUnwrap(translator.visitSymbol(symbol) as? RenderNode)
            let declarationsSection = try XCTUnwrap(renderNode.primaryContentSections.compactMap({ $0 as? DeclarationsRenderSection }).first)
            XCTAssertEqual(declarationsSection.declarations.count, 1)
            let declarations = try XCTUnwrap(declarationsSection.declarations.first)

            XCTAssertEqual(
                declarationAndHighlights(for: declarations.tokens),
                [
                    "func overload2(p1: ((Int) -> Int)?, p2: Int)",
                    "                   ~~   ~~~~~~~~~~          "
                ]
            )

            XCTAssertEqual(
                declarations.otherDeclarations?.declarations.flatMap({ declarationAndHighlights(for: $0.tokens) }),
                [
                    "func overload2(p1: (Int) -> (), p2: Int)",
                    "                   ~   ~~~~~~~          ",

                    "func overload2(p1: (Int) -> Int, p2: Int)",
                    "                   ~   ~~~~~~~~          ",

                    "func overload2(p1: (Int) -> Int?, p2: Int)",
                    "                   ~   ~~~~~~~~~          ",

                    // FIXME: adjust the token processing so that the comma inside the tuple isn't treated as common?
                    // (it breaks the declaration pretty-printer in Swift-DocC-Render and causes it to skip pretty-printing)
                    "func overload2(p1: (Int, Int), p2: Int)",
                    "                   ~     ~~~~~         ",

                    // FIXME: adjust the token processing so that the common parenthesis is always the final one
                    "func overload2(p1: Int, p2: (Int, Int))",
                    "                            ~   ~~~~~ ~",

                    "func overload2(p1: Int, p2: Int)",
                    "                                ",
                ]
            )
        }

        // Verify that the presence of type parameters doesn't cause the opening parenthesis of an
        // argument list to also be highlighted, since it is combined into the same token as the
        // closing angle bracket in the symbol graph. Also ensure that the leading space of the
        // rendered where clause is not highlighted.
        do {
            // func overload3(_ p: [Int: Int]) {} // <- overload group
            // func overload3<T: Hashable>(_ p: [T: T]) {}
            // func overload3<K: Hashable, V>(_ p: [K: V]) {}
            let reference = ResolvedTopicReference(
                bundleID: bundle.id,
                path: "/documentation/FancyOverloads/overload3(_:)",
                sourceLanguage: .swift
            )
            let symbol = try XCTUnwrap(context.entity(with: reference).semantic as? Symbol)
            var translator = RenderNodeTranslator(context: context, identifier: reference)
            let renderNode = try XCTUnwrap(translator.visitSymbol(symbol) as? RenderNode)
            let declarationsSection = try XCTUnwrap(renderNode.primaryContentSections.compactMap({ $0 as? DeclarationsRenderSection }).first)
            XCTAssertEqual(declarationsSection.declarations.count, 1)
            let declarations = try XCTUnwrap(declarationsSection.declarations.first)

            XCTAssertEqual(
                declarationAndHighlights(for: declarations.tokens),
                [
                    "func overload3(_ p: [Int : Int])",
                    "                     ~~~   ~~~  ",
                ]
            )

            XCTAssertEqual(
                declarations.otherDeclarations?.declarations.flatMap({ declarationAndHighlights(for: $0.tokens) }),
                [
                    "func overload3<K, V>(_ p: [K : V]) where K : Hashable",
                    "              ~~~~~~       ~   ~   ~~~~~~~~~~~~~~~~~~",

                    "func overload3<T>(_ p: [T : T]) where T : Hashable",
                    "              ~~~       ~   ~   ~~~~~~~~~~~~~~~~~~",
                ]
            )
        }
    }

    func testInconsistentHighlightDiff() async throws {
        enableFeatureFlag(\.isExperimentalOverloadedSymbolPresentationEnabled)

        // Generate a symbol graph with many overload groups that share declarations.
        // The overloaded declarations have two legitimate solutions for their longest common subsequence:
        // one that ends in a close-parenthesis, and one that ends in a space.
        // By alternating the order in which these declarations appear,
        // the computed difference highlighting can differ
        // unless the declarations are sorted prior to the calculation.
        // Ensure that the overload difference highlighting is consistent for these declarations.

        // init(_ content: MyClass) throws
        let declaration1: SymbolGraph.Symbol.DeclarationFragments = .init(declarationFragments: [
            .init(kind: .keyword, spelling: "init", preciseIdentifier: nil),
            .init(kind: .text, spelling: "(", preciseIdentifier: nil),
            .init(kind: .externalParameter, spelling: "_", preciseIdentifier: nil),
            .init(kind: .text, spelling: " ", preciseIdentifier: nil),
            .init(kind: .internalParameter, spelling: "content", preciseIdentifier: nil),
            .init(kind: .text, spelling: ": ", preciseIdentifier: nil),
            .init(kind: .typeIdentifier, spelling: "MyClass", preciseIdentifier: "s:MyClass"),
            .init(kind: .text, spelling: ") ", preciseIdentifier: nil),
            .init(kind: .keyword, spelling: "throws", preciseIdentifier: nil),
        ])

        // init(_ content: some ConvertibleToMyClass)
        let declaration2: SymbolGraph.Symbol.DeclarationFragments = .init(declarationFragments: [
            .init(kind: .keyword, spelling: "init", preciseIdentifier: nil),
            .init(kind: .text, spelling: "(", preciseIdentifier: nil),
            .init(kind: .externalParameter, spelling: "_", preciseIdentifier: nil),
            .init(kind: .text, spelling: " ", preciseIdentifier: nil),
            .init(kind: .internalParameter, spelling: "content", preciseIdentifier: nil),
            .init(kind: .text, spelling: ": ", preciseIdentifier: nil),
            .init(kind: .keyword, spelling: "some", preciseIdentifier: nil),
            .init(kind: .text, spelling: " ", preciseIdentifier: nil),
            .init(kind: .typeIdentifier, spelling: "ConvertibleToMyClass", preciseIdentifier: "s:ConvertibleToMyClass"),
            .init(kind: .text, spelling: ")", preciseIdentifier: nil),
        ])
        let overloadsCount = 10
        let symbols = (0...overloadsCount).flatMap({ index in
            let reverseDeclarations = index % 2 != 0
            return [
                makeSymbol(
                    id: "overload-\(index)-1",
                    kind: .func,
                    pathComponents: ["overload-\(index)"],
                    otherMixins: [reverseDeclarations ? declaration2 : declaration1]),
                makeSymbol(
                    id: "overload-\(index)-2",
                    kind: .func,
                    pathComponents: ["overload-\(index)"],
                    otherMixins: [reverseDeclarations ? declaration1 : declaration2]),
            ]
        })
        let symbolGraph = makeSymbolGraph(moduleName: "FancierOverloads", symbols: symbols)

        let catalog = Folder(name: "unit-test.docc", content: [
            InfoPlist(displayName: "FancierOverloads", identifier: "com.test.example"),
            JSONFile(name: "FancierOverloads.symbols.json", content: symbolGraph),
        ])

        let (_, context) = try await loadBundle(catalog: catalog)

        func assertDeclarations(for USR: String, file: StaticString = #filePath, line: UInt = #line) throws {
            let reference = try XCTUnwrap(context.documentationCache.reference(symbolID: USR), file: file, line: line)
            let symbol = try XCTUnwrap(context.entity(with: reference).semantic as? Symbol, file: file, line: line)
            var translator = RenderNodeTranslator(context: context, identifier: reference)
            let renderNode = try XCTUnwrap(translator.visitSymbol(symbol) as? RenderNode, file: file, line: line)
            let declarationsSection = try XCTUnwrap(renderNode.primaryContentSections.compactMap({ $0 as? DeclarationsRenderSection }).first, file: file, line: line)
            XCTAssertEqual(declarationsSection.declarations.count, 1, file: file, line: line)
            let declarations = try XCTUnwrap(declarationsSection.declarations.first, file: file, line: line)

            XCTAssertEqual(declarationsAndHighlights(for: declarations), [
                "init(_ content: MyClass) throws",
                "                ~~~~~~~~ ~~~~~~",
                "init(_ content: some ConvertibleToMyClass)",
                "                ~~~~ ~~~~~~~~~~~~~~~~~~~~~",
            ], file: file, line: line)
        }

        for i in 0...overloadsCount {
            try assertDeclarations(for: "overload-\(i)-1")
            try assertDeclarations(for: "overload-\(i)-2")
        }
    }

    func testDontHighlightWhenOverloadsAreDisabled() async throws {
        let symbolGraphFile = Bundle.module.url(
            forResource: "FancyOverloads",
            withExtension: "symbols.json",
            subdirectory: "Test Resources"
        )!

        let catalog = Folder(name: "unit-test.docc", content: [
            InfoPlist(displayName: "FancyOverloads", identifier: "com.test.example"),
            CopyOfFile(original: symbolGraphFile),
        ])

        let (bundle, context) = try await loadBundle(catalog: catalog)

        for hash in ["7eht8", "8p1lo", "858ja"] {
            let reference = ResolvedTopicReference(
                bundleID: bundle.id,
                path: "/documentation/FancyOverloads/overload3(_:)-\(hash)",
                sourceLanguage: .swift
            )
            let symbol = try XCTUnwrap(context.entity(with: reference).semantic as? Symbol)
            var translator = RenderNodeTranslator(context: context, identifier: reference)
            let renderNode = try XCTUnwrap(translator.visitSymbol(symbol) as? RenderNode)
            let declarationsSection = try XCTUnwrap(renderNode.primaryContentSections.compactMap({ $0 as? DeclarationsRenderSection }).first)
            XCTAssertEqual(declarationsSection.declarations.count, 1)
            let declarations = try XCTUnwrap(declarationsSection.declarations.first)

            XCTAssert(declarations.tokens.allSatisfy({ $0.highlight == nil }))
        }
    }

    func testOverloadConformanceDataIsSavedWithDeclarations() async throws {
        enableFeatureFlag(\.isExperimentalOverloadedSymbolPresentationEnabled)

        let symbolGraphFile = Bundle.module.url(
            forResource: "ConformanceOverloads",
            withExtension: "symbols.json",
            subdirectory: "Test Resources"
        )!

        let catalog = Folder(name: "unit-test.docc", content: [
            InfoPlist(displayName: "ConformanceOverloads", identifier: "com.test.example"),
            CopyOfFile(original: symbolGraphFile),
        ])

        let (bundle, context) = try await loadBundle(catalog: catalog)

        // MyClass<T>
        // - myFunc() where T: Equatable
        // - myFunc() where T: Hashable // <- overload group
        let reference = ResolvedTopicReference(
            bundleID: bundle.id,
            path: "/documentation/ConformanceOverloads/MyClass/myFunc()",
            sourceLanguage: .swift
        )
        let symbol = try XCTUnwrap(context.entity(with: reference).semantic as? Symbol)
        var translator = RenderNodeTranslator(context: context, identifier: reference)
        let renderNode = try XCTUnwrap(translator.visitSymbol(symbol) as? RenderNode)
        let declarationsSection = try XCTUnwrap(renderNode.primaryContentSections.compactMap({ $0 as? DeclarationsRenderSection }).first)
        XCTAssertEqual(declarationsSection.declarations.count, 1)
        let declarations = try XCTUnwrap(declarationsSection.declarations.first)

        let otherDeclarations = try XCTUnwrap(declarations.otherDeclarations)
        XCTAssertEqual(otherDeclarations.declarations.count, 1)

        XCTAssertEqual(otherDeclarations.declarations.first?.conformance?.constraints, [
            .codeVoice(code: "T"),
            .text(" conforms to "),
            .codeVoice(code: "Equatable"),
            .text("."),
        ])
    }
}

/// Render a list of declaration tokens as a plain-text decoration and as a plain-text rendering of which characters are highlighted.
func declarationAndHighlights(for tokens: [DeclarationRenderSection.Token]) -> [String] {
    [
        tokens.map({ $0.text }).joined(),
        tokens.map({ String(repeating: $0.highlight == .changed ? "~" : " ", count: $0.text.count) }).joined()
    ]
}

private func declarationsAndHighlights(for section: DeclarationRenderSection) -> [String] {
    guard let otherDeclarations = section.otherDeclarations else {
        return []
    }
    var declarations = otherDeclarations.declarations.map(\.tokens)
    declarations.insert(section.tokens, at: otherDeclarations.displayIndex)
    return declarations.flatMap(declarationAndHighlights(for:))
}
