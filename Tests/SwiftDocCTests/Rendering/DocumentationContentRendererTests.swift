/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
import SymbolKit
import Markdown
@testable import SwiftDocC

class DocumentationContentRendererTests: XCTestCase {
    func testReplacesTypeIdentifierSubHeadingFragmentWithIdentifierForSwift() throws {
        let subHeadingFragments = documentationContentRenderer
            .subHeadingFragments(for: nodeWithSubheadingAndNavigatorVariants)
        
        XCTAssertEqual(
            subHeadingFragments.defaultValue,
            [
                DeclarationRenderSection.Token(
                    text: "class",
                    kind: .keyword,
                    identifier: nil,
                    preciseIdentifier: nil
                ),
                DeclarationRenderSection.Token(
                    text: " ",
                    kind: .text,
                    identifier: nil,
                    preciseIdentifier: nil
                ),
                DeclarationRenderSection.Token(
                    text: "ClassInSwift",
                    
                    // The 'typeIdentifier' value of the symbol's declaration is replaced with an 'identifier'.
                    kind: .identifier,
                    identifier: nil,
                    preciseIdentifier: nil
                )
            ]
        )
    }
    
    func testDoesNotReplaceSubHeadingFragmentsForOtherLanguagesThanSwift() throws {
        let subHeadingFragments = documentationContentRenderer
            .subHeadingFragments(for: nodeWithSubheadingAndNavigatorVariants)
        
        guard case .replace(let fragments) = subHeadingFragments.variants.first?.patch.first else {
            XCTFail("Unexpected patch")
            return
        }
        
        XCTAssertEqual(
            fragments,
            [
                DeclarationRenderSection.Token(
                    text: "class",
                    kind: .keyword, identifier: nil, preciseIdentifier: nil
                ),
                DeclarationRenderSection.Token(
                    text: " ",
                    kind: .text, identifier: nil, preciseIdentifier: nil
                ),
                DeclarationRenderSection.Token(
                    text: "ClassInAnotherLanguage",
                    kind: .typeIdentifier, identifier: nil, preciseIdentifier: nil
                )
            ]
        )
    }
    
    func testReplacesTypeIdentifierNavigatorFragmentWithIdentifierForSwift() throws {
        let navigatorFragments = documentationContentRenderer
            .navigatorFragments(for: nodeWithSubheadingAndNavigatorVariants)
        
        XCTAssertEqual(
            navigatorFragments.defaultValue,
            [
                DeclarationRenderSection.Token(
                    text: "class",
                    kind: .keyword,
                    identifier: nil,
                    preciseIdentifier: nil
                ),
                DeclarationRenderSection.Token(
                    text: " ",
                    kind: .text,
                    identifier: nil,
                    preciseIdentifier: nil
                ),
                DeclarationRenderSection.Token(
                    text: "ClassInSwift",
                    
                    // The 'typeIdentifier' value of the symbol's declaration is replaced with an 'identifier'.
                    kind: .identifier,
                    identifier: nil,
                    preciseIdentifier: nil
                )
            ]
        )
    }
    
    func testDoesNotReplacesNavigatorFragmentsForOtherLanguagesThanSwift() throws {
        let navigatorFragments = documentationContentRenderer
            .navigatorFragments(for: nodeWithSubheadingAndNavigatorVariants)
        
        guard case .replace(let fragments) = navigatorFragments.variants.first?.patch.first else {
            XCTFail("Unexpected patch")
            return
        }
        
        XCTAssertEqual(
            fragments,
            [
                DeclarationRenderSection.Token(
                    text: "class",
                    kind: .keyword, identifier: nil, preciseIdentifier: nil
                ),
                DeclarationRenderSection.Token(
                    text: " ",
                    kind: .text, identifier: nil, preciseIdentifier: nil
                ),
                DeclarationRenderSection.Token(
                    text: "ClassInAnotherLanguage",
                    kind: .typeIdentifier, identifier: nil, preciseIdentifier: nil
                )
            ]
        )
    }
}

private extension DocumentationDataVariantsTrait {
    static var otherLanguage: DocumentationDataVariantsTrait { .init(interfaceLanguage: "otherLanguage") }
}

private extension DocumentationContentRendererTests {
    var documentationContentRenderer: DocumentationContentRenderer {
        DocumentationContentRenderer(
            documentationContext: try! DocumentationContext(dataProvider: DocumentationWorkspace()),
            bundle: DocumentationBundle(
                info: DocumentationBundle.Info(
                    displayName: "Test",
                    identifier: "org.swift.test",
                    version: "1.2.3"
                ),
                baseURL: URL(string: "https://example.com/example")!,
                symbolGraphURLs: [],
                markupURLs: [],
                miscResourceURLs: []
            )
        )
    }
    
    var nodeWithSubheadingAndNavigatorVariants: DocumentationNode {
        var node = DocumentationNode(
            reference: ResolvedTopicReference(
                bundleIdentifier: "org.swift.example",
                path: "/documentation/class",
                fragment: nil,
                sourceLanguage: .swift
            ),
            kind: .class,
            sourceLanguage: .swift,
            availableSourceLanguages: [
                .swift,
                .init(id: DocumentationDataVariantsTrait.otherLanguage.interfaceLanguage!)
            ],
            name: DocumentationNode.Name.symbol(declaration: AttributedCodeListing.Line()),
            markup: Document(parsing: ""),
            semantic: nil,
            platformNames: nil
        )
        
        node.semantic = Symbol(
            kindVariants: .init(values: [
                .swift: SymbolGraph.Symbol.Kind(parsedIdentifier: .class, displayName: "Class"),
                .otherLanguage: SymbolGraph.Symbol.Kind(parsedIdentifier: .class, displayName: "Class"),
            ]),
            titleVariants: .init(values: [
                .swift: "ClassInSwift",
                .otherLanguage: "ClassInAnotherLanguage",
            ]),
            subHeadingVariants: .init(values: [
                .swift: [
                    .init(kind: .keyword, spelling: "class", preciseIdentifier: nil),
                    .init(kind: .text, spelling: " ", preciseIdentifier: nil),
                    .init(kind: .typeIdentifier, spelling: "ClassInSwift", preciseIdentifier: nil),
                ],
                .otherLanguage: [
                    .init(kind: .keyword, spelling: "class", preciseIdentifier: nil),
                    .init(kind: .text, spelling: " ", preciseIdentifier: nil),
                    .init(kind: .typeIdentifier, spelling: "ClassInAnotherLanguage", preciseIdentifier: nil),
                ],
            ]),
            navigatorVariants: .init(values: [
                .swift: [
                    .init(kind: .keyword, spelling: "class", preciseIdentifier: nil),
                    .init(kind: .text, spelling: " ", preciseIdentifier: nil),
                    .init(kind: .typeIdentifier, spelling: "ClassInSwift", preciseIdentifier: nil),
                ],
                .otherLanguage: [
                    .init(kind: .keyword, spelling: "class", preciseIdentifier: nil),
                    .init(kind: .text, spelling: " ", preciseIdentifier: nil),
                    .init(kind: .typeIdentifier, spelling: "ClassInAnotherLanguage", preciseIdentifier: nil),
                ],
            ]),
            roleHeadingVariants: .init(swiftVariant: ""),
            platformNameVariants: .init(swiftVariant: nil),
            moduleReference: ResolvedTopicReference(bundleIdentifier: "", path: "", sourceLanguage: .swift), // This information isn't used anywhere.
            externalIDVariants: .init(swiftVariant: nil),
            accessLevelVariants: .init(swiftVariant: nil),
            availabilityVariants: .init(swiftVariant: Availability(availability: [])),
            deprecatedSummaryVariants: .init(swiftVariant: nil),
            mixinsVariants: .init(swiftVariant: nil),
            abstractSectionVariants: .init(swiftVariant: nil),
            discussionVariants: .init(swiftVariant: nil),
            topicsVariants: .init(swiftVariant: nil),
            seeAlsoVariants: .init(swiftVariant: nil),
            returnsSectionVariants: .init(swiftVariant: nil),
            parametersSectionVariants: .init(swiftVariant: nil),
            redirectsVariants: .init(swiftVariant: nil)
        )
        
        return node
    }
}
