/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Testing
import SymbolKit
import Markdown
@_spi(ExternalLinks) @testable import SwiftDocC
import DocCTestUtilities
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

    @Test
    func trivialConformanceFilterUsesShortestPathParent() async throws {
        let selfIsBar = SymbolGraph.Symbol.Swift.Extension(
            extendedModule: "SomeModule",
            typeKind: .struct,
            constraints: [.init(kind: .sameType, leftTypeName: "Self", rightTypeName: "Bar")]
        )

        let catalog = Folder(name: "unit-test.docc", content: [
            JSONFile(name: "SomeModule.symbols.json", content: makeSymbolGraph(
                moduleName: "SomeModule",
                symbols: [
                    makeSymbol(id: "s:Foo", kind: .struct, pathComponents: ["Foo"]),
                    makeSymbol(id: "s:Outer", kind: .struct, pathComponents: ["Outer"]),
                    makeSymbol(id: "s:Bar", kind: .struct, pathComponents: ["Outer", "Bar"]),
                    makeSymbol(id: "s:member", kind: .method, pathComponents: ["Outer", "Bar", "member"], otherMixins: [selfIsBar]),
                ],
                relationships: [
                    .init(source: "s:Bar", target: "s:Outer", kind: .memberOf, targetFallback: nil),
                    .init(source: "s:member", target: "s:Bar", kind: .memberOf, targetFallback: nil),
                ]
            )),
        ])

        let context = try await load(catalog: catalog)
        let bundleID = context.inputs.id
        let memberReference = ResolvedTopicReference(bundleID: bundleID, path: "/documentation/SomeModule/Outer/Bar/member", sourceLanguage: .swift)
        let shorterParentReference = ResolvedTopicReference(bundleID: bundleID, path: "/documentation/SomeModule/Foo", sourceLanguage: .swift)

        // Add `Foo` as a second parent of `member` with a shorter path than the original parent `Bar`.
        let memberNode = try #require(context.topicGraph.nodeWithReference(memberReference))
        let shorterParentNode = try #require(context.topicGraph.nodeWithReference(shorterParentReference))
        context.topicGraph.addEdge(from: shorterParentNode, to: memberNode)

        #expect(context.parents(of: memberReference).count == 2)
        #expect(context.shortestFinitePath(to: memberReference)?.last?.path == "/documentation/SomeModule/Foo")

        // The shortest path parent is `Foo`, so the `Self is Bar` constraint is non-trivial and must be retained.
        let section = DocumentationContentRenderer(context: context)
            .conformanceSectionFor(memberReference, collectedConstraints: [:])
        #expect(section?.constraints.plainText == "Self is Bar.")
    }

    @Test
    func rendersConformanceConstraintsForProtocolFromAnotherModule() async throws {
        struct ExternalProtocolResolver: GlobalExternalSymbolResolver {
            func symbolReferenceAndEntity(withPreciseIdentifier preciseIdentifier: String) -> (ResolvedTopicReference, LinkResolver.ExternalEntity)? {
                guard preciseIdentifier == "s:Other.Q" else {
                    return nil
                }
                let reference = ResolvedTopicReference(bundleID: "com.example.other", path: "/documentation/Other/Q", sourceLanguage: .swift)
                let entity = LinkResolver.ExternalEntity(
                    kind: .protocol,
                    language: .swift,
                    relativePresentationURL: URL(string: "/documentation/other/q")!,
                    referenceIdentifier: .init(reference.absoluteString),
                    title: "Q",
                    availableLanguages: [.swift],
                    variants: []
                )
                return (reference, entity)
            }
        }

        // extension Box: Other.Q where T: Other.Q {}
        var conformance = SymbolGraph.Relationship(source: "s:Box", target: "s:Other.Q", kind: .conformsTo, targetFallback: "Other.Q")
        conformance.mixins = makeMixins([
            SymbolGraph.Relationship.Swift.GenericConstraints(constraints: [
                .init(kind: .conformance, leftTypeName: "T", rightTypeName: "Other.Q")
            ])
        ])

        let catalog = Folder(name: "unit-test.docc", content: [
            JSONFile(name: "SomeModule.symbols.json", content: makeSymbolGraph(
                moduleName: "SomeModule",
                symbols: [
                    makeSymbol(id: "s:Box", kind: .struct, pathComponents: ["Box"]),
                ],
                relationships: [conformance]
            )),
        ])

        var configuration = DocumentationContext.Configuration()
        configuration.externalDocumentationConfiguration.globalSymbolResolver = ExternalProtocolResolver()
        let context = try await load(catalog: catalog, configuration: configuration)

        let boxReference = ResolvedTopicReference(bundleID: context.inputs.id, path: "/documentation/SomeModule/Box", sourceLanguage: .swift)
        let boxNode = try context.entity(with: boxReference)
        var translator = RenderNodeTranslator(context: context, identifier: boxReference)
        let renderNode = try #require(translator.visit(boxNode.semantic) as? RenderNode)

        let protocolReference = try #require(renderNode.references["doc://com.example.other/documentation/Other/Q"] as? TopicRenderReference)
        #expect(protocolReference.conformance?.constraints.plainText == "T conforms to Other.Q.")
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
            semantic: nil
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
            consolidatedAvailabilityVariants: .empty,
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
