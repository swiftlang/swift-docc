/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Testing
import SymbolKit
import Markdown
@testable import SwiftDocC
import DocCCommon

struct DocumentationContentRendererTests {
    @Test
    func replacesTypeIdentifierSubHeadingFragmentWithIdentifierForSwift() async throws {
        let subHeadingFragments = try await makeDocumentationContentRenderer()
            .subHeadingFragments(for: nodeWithSubheadingAndNavigatorVariants)

        #expect(subHeadingFragments.defaultValue == [
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
            ),
        ])
    }

    @Test
    func doesNotReplaceSubHeadingFragmentsForNonSwiftLanguages() async throws {
        let subHeadingFragments = try await makeDocumentationContentRenderer()
            .subHeadingFragments(for: nodeWithSubheadingAndNavigatorVariants)

        guard case .replace(let fragments) = subHeadingFragments.variants.first?.patch.first else {
            Issue.record("Unexpected patch")
            return
        }

        #expect(fragments == [
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
            ),
        ])
    }

    @Test
    func replacesTypeIdentifierNavigatorFragmentWithIdentifierForSwift() async throws {
        let navigatorFragments = try await makeDocumentationContentRenderer()
            .navigatorFragments(for: nodeWithSubheadingAndNavigatorVariants)

        #expect(navigatorFragments.defaultValue == [
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
            ),
        ])
    }

    @Test
    func doesNotReplaceNavigatorFragmentsForNonSwiftLanguages() async throws {
        let navigatorFragments = try await makeDocumentationContentRenderer()
            .navigatorFragments(for: nodeWithSubheadingAndNavigatorVariants)

        guard case .replace(let fragments) = navigatorFragments.variants.first?.patch.first else {
            Issue.record("Unexpected patch")
            return
        }

        #expect(fragments == [
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
            ),
        ])
    }

    private func makeDocumentationContentRenderer() async throws -> DocumentationContentRenderer {
        let context = try await makeEmptyContext()
        return DocumentationContentRenderer(context: context)
    }

    private var nodeWithSubheadingAndNavigatorVariants: DocumentationNode {
        var node = DocumentationNode(
            reference: ResolvedTopicReference(
                bundleID: "org.swift.example",
                path: "/documentation/class",
                fragment: nil,
                sourceLanguage: .swift
            ),
            kind: .class,
            sourceLanguage: .swift,
            availableSourceLanguages: [
                .swift,
                DocumentationDataVariantsTrait.otherLanguage.sourceLanguage!
            ],
            name: .symbol(name: ""),
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
            moduleReference: ResolvedTopicReference(bundleID: "", path: "", sourceLanguage: .swift), // This information isn't used anywhere.
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
            dictionaryKeysSection: nil,
            possibleValuesSection: nil,
            httpEndpointSection: nil,
            httpBodySection: nil,
            httpParametersSection: nil,
            httpResponsesSection: nil,
            redirects: nil
        )

        return node
    }
}

private extension DocumentationDataVariantsTrait {
    static var otherLanguage: DocumentationDataVariantsTrait { .init(interfaceLanguage: "otherLanguage") }
}
