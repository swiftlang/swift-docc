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
            (.highlightDiff, "highlightDiff"),
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

    func testDecodingTokensWithTokenArray() throws {
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
            (.highlightDiff, "highlightDiff"),
        ]

        for (token, string) in values {
            let jsonData = """
            {
                "text": "",
                "kind": "\(string)",
                "tokens": [
                    {
                        "text": "",
                        "kind": "\(string)"
                    }
                ]
            }
            """.data(using: .utf8)!

            XCTAssertEqual(
                try JSONDecoder().decode(DeclarationRenderSection.Token.self, from: jsonData),
                DeclarationRenderSection.Token(
                    text: "",
                    kind: token,
                    tokens: [.init(text: "", kind: token)])
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
        var translator = RenderNodeTranslator(
            context: context,
            bundle: bundle,
            identifier: reference,
            source: nil
        )
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

        let reference = ResolvedTopicReference(
            bundleIdentifier: bundle.identifier,
            path: "/documentation/FancyOverloads/MyClass/myFunc(param:)-2rd6z",
            sourceLanguage: .swift
        )
        let symbol = try XCTUnwrap(context.entity(with: reference).semantic as? Symbol)
        var translator = RenderNodeTranslator(
            context: context,
            bundle: bundle,
            identifier: reference,
            source: nil
        )
        let renderNode = try XCTUnwrap(translator.visitSymbol(symbol) as? RenderNode)
        let declarationsSection = try XCTUnwrap(renderNode.primaryContentSections.compactMap({ $0 as? DeclarationsRenderSection }).first)
        XCTAssertEqual(declarationsSection.declarations.count, 1)
        let declarations = try XCTUnwrap(declarationsSection.declarations.first)

        XCTAssertEqual(declarations.tokens, [
            .init(text: "func", kind: .keyword),
            .init(text: " ", kind: .text),
            .init(text: "myFunc", kind: .identifier),
            .init(text: "(", kind: .text),
            .init(text: "param", kind: .externalParam),
            .init(text: ": ", kind: .text),
            .init(text: "", kind: .highlightDiff, tokens: [
                .init(text: "Int", kind: .typeIdentifier, preciseIdentifier: "s:Si"),
            ]),
            .init(text: ")", kind: .text),
        ])

        XCTAssertEqual(declarations.otherDeclarations?.declarations.map(\.tokens), [
            [
                .init(text: "func", kind: .keyword),
                .init(text: " ", kind: .text),
                .init(text: "myFunc", kind: .identifier),
                .init(text: "", kind: .highlightDiff, tokens: [
                    .init(text: "<", kind: .text),
                    .init(text: "S", kind: .genericParameter),
                    .init(text: ">", kind: .text),
                ]),
                .init(text: "(", kind: .text),
                .init(text: "param", kind: .externalParam),
                .init(text: ": ", kind: .text),
                .init(text: "", kind: .highlightDiff, tokens: [
                    .init(
                        text: "S",
                        kind: .typeIdentifier,
                        preciseIdentifier: "s:9FancyOverloads7MyClassC6myFunc5paramyx_tSyRzlF1SL_xmfp"),
                ]),
                .init(text: ") ", kind: .text),
                .init(text: "", kind: .highlightDiff, tokens: [
                    .init(text: "where", kind: .keyword),
                    .init(text: " ", kind: .text),
                    .init(text: "S", kind: .typeIdentifier),
                    .init(text: " : ", kind: .text),
                    .init(text: "StringProtocol", kind: .typeIdentifier, preciseIdentifier: "s:Sy"),
                ])
            ],
        ])
    }
}
