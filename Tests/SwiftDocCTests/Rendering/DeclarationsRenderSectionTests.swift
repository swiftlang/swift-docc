/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import XCTest
@testable import SwiftDocC
import SwiftDocCTestUtilities

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

    func testAlternateDeclarations() throws {
        let (bundle, context) = try testBundleAndContext(named: "AlternateDeclarations")
        let reference = ResolvedTopicReference(
            bundleIdentifier: bundle.identifier,
            path: "/documentation/AlternateDeclarations/MyClass/present(completion:)",
            sourceLanguage: .swift
        )
        let symbol = try XCTUnwrap(context.entity(with: reference).semantic as? Symbol)
        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: reference)
        let renderNode = try XCTUnwrap(translator.visitSymbol(symbol) as? RenderNode)
        let declarationsSection = try XCTUnwrap(renderNode.primaryContentSections.compactMap({ $0 as? DeclarationsRenderSection }).first)

        XCTAssertEqual(declarationsSection.declarations.count, 2)
        XCTAssert(declarationsSection.declarations.allSatisfy({ $0.platforms == [.iOS, .macOS] }))
    }

    func testHighlightDiff() throws {
        enableFeatureFlag(\.isExperimentalOverloadedSymbolPresentationEnabled)

        let symbolGraphFile = Bundle.module.url(
            forResource: "FancyOverloads",
            withExtension: "symbols.json",
            subdirectory: "Test Resources"
        )!

        let tempURL = try createTempFolder(content: [
            Folder(name: "unit-test.docc", content: [
                InfoPlist(displayName: "FancyOverloads", identifier: "com.test.example"),
                CopyOfFile(original: symbolGraphFile),
            ])
        ])

        let (_, bundle, context) = try loadBundle(from: tempURL)

        // Make sure that type decorators like arrays, dictionaries, and optionals are correctly highlighted.
        do {
            // func overload1(param: Int) {} // <- overload group
            // func overload1(param: Int?) {}
            // func overload1(param: [Int]) {}
            // func overload1(param: [Int]?) {}
            // func overload1(param: Set<Int>) {}
            // func overload1(param: [Int: Int]) {}
            let reference = ResolvedTopicReference(
                bundleIdentifier: bundle.identifier,
                path: "/documentation/FancyOverloads/overload1(param:)-8nk5z",
                sourceLanguage: .swift
            )
            let symbol = try XCTUnwrap(context.entity(with: reference).semantic as? Symbol)
            var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: reference)
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
                bundleIdentifier: bundle.identifier,
                path: "/documentation/FancyOverloads/overload2(p1:p2:)-4p1sq",
                sourceLanguage: .swift
            )
            let symbol = try XCTUnwrap(context.entity(with: reference).semantic as? Symbol)
            var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: reference)
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
                bundleIdentifier: bundle.identifier,
                path: "/documentation/FancyOverloads/overload3(_:)-xql2",
                sourceLanguage: .swift
            )
            let symbol = try XCTUnwrap(context.entity(with: reference).semantic as? Symbol)
            var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: reference)
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

    func testDontHighlightWhenOverloadsAreDisabled() throws {
        let symbolGraphFile = Bundle.module.url(
            forResource: "FancyOverloads",
            withExtension: "symbols.json",
            subdirectory: "Test Resources"
        )!

        let tempURL = try createTempFolder(content: [
            Folder(name: "unit-test.docc", content: [
                InfoPlist(displayName: "FancyOverloads", identifier: "com.test.example"),
                CopyOfFile(original: symbolGraphFile),
            ])
        ])

        let (_, bundle, context) = try loadBundle(from: tempURL)

        for hash in ["7eht8", "8p1lo", "858ja"] {
            let reference = ResolvedTopicReference(
                bundleIdentifier: bundle.identifier,
                path: "/documentation/FancyOverloads/overload3(_:)-\(hash)",
                sourceLanguage: .swift
            )
            let symbol = try XCTUnwrap(context.entity(with: reference).semantic as? Symbol)
            var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: reference)
            let renderNode = try XCTUnwrap(translator.visitSymbol(symbol) as? RenderNode)
            let declarationsSection = try XCTUnwrap(renderNode.primaryContentSections.compactMap({ $0 as? DeclarationsRenderSection }).first)
            XCTAssertEqual(declarationsSection.declarations.count, 1)
            let declarations = try XCTUnwrap(declarationsSection.declarations.first)

            XCTAssert(declarations.tokens.allSatisfy({ $0.highlight == nil }))
        }
    }

    func testOverloadConformanceDataIsSavedWithDeclarations() throws {
        enableFeatureFlag(\.isExperimentalOverloadedSymbolPresentationEnabled)

        let symbolGraphFile = Bundle.module.url(
            forResource: "ConformanceOverloads",
            withExtension: "symbols.json",
            subdirectory: "Test Resources"
        )!

        let tempURL = try createTempFolder(content: [
            Folder(name: "unit-test.docc", content: [
                InfoPlist(displayName: "ConformanceOverloads", identifier: "com.test.example"),
                CopyOfFile(original: symbolGraphFile),
            ])
        ])

        let (_, bundle, context) = try loadBundle(from: tempURL)

        // MyClass<T>
        // - myFunc() where T: Equatable
        // - myFunc() where T: Hashable // <- overload group
        let reference = ResolvedTopicReference(
            bundleIdentifier: bundle.identifier,
            path: "/documentation/ConformanceOverloads/MyClass/myFunc()-6gquc",
            sourceLanguage: .swift
        )
        let symbol = try XCTUnwrap(context.entity(with: reference).semantic as? Symbol)
        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: reference)
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
