/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
import Markdown
import SymbolKit
import SwiftDocCTestUtilities
@_spi(ExternalLinks) @testable import SwiftDocC

class AutoCapitalizationTests: XCTestCase {
    
    class TestCapitalizationResolver: ExternalDocumentationSource {
        var bundleIdentifier = "com.external.testbundle"
        var expectedReferencePath = "/externally/resolved/path"
        var expectedFragment: String? = nil
        var resolvedEntityTitle = "Externally Resolved Title"
        var resolvedEntityKind = DocumentationNode.Kind.article
        var resolvedEntityLanguage = SourceLanguage.swift
        var resolvedEntityDeclarationFragments: SymbolGraph.Symbol.DeclarationFragments? = nil
   
        var resolvedExternalPaths = [String]()
        
        func resolve(_ reference: TopicReference) -> TopicReferenceResolutionResult {
            if let path = reference.url?.path {
                resolvedExternalPaths.append(path)
            }
            return .success(ResolvedTopicReference(bundleIdentifier: bundleIdentifier, path: expectedReferencePath, fragment: expectedFragment, sourceLanguage: resolvedEntityLanguage))
        }
        
        func entity(with reference: ResolvedTopicReference) -> LinkResolver.ExternalEntity {
            guard reference.bundleIdentifier == bundleIdentifier else {
                fatalError("It is a programming mistake to retrieve an entity for a reference that the external resolver didn't resolve.")
            }
            
            let (kind, role) = DocumentationContentRenderer.renderKindAndRole(resolvedEntityKind, semantic: nil)
            return LinkResolver.ExternalEntity(
                topicRenderReference: TopicRenderReference(
                    identifier: .init(reference.absoluteString),
                    title: resolvedEntityTitle,
                    abstract: [.text("Externally Resolved Markup Content")],
                    url: "/example" + reference.path + (reference.fragment.map { "#\($0)" } ?? ""),
                    kind: kind,
                    role: role,
                    fragments: resolvedEntityDeclarationFragments?.declarationFragments.map { fragment in
                        return DeclarationRenderSection.Token(fragment: fragment, identifier: nil)
                    },
                    estimatedTime: nil,
                    titleStyle: resolvedEntityKind.isSymbol ? .symbol : .title
                ),
                renderReferenceDependencies: RenderReferenceDependencies(),
                sourceLanguages: [resolvedEntityLanguage]
            )
        }
    }
    
    func exampleDocumentation(copying bundleName: String, documentationExtension: TextFile, path: String, file: StaticString = #file, line: UInt = #line) throws -> Symbol {
        let capitalizationResolver = TestCapitalizationResolver()
        let (_, bundle, context) = try testBundleAndContext(
            copying: bundleName,
            externalResolvers: [capitalizationResolver.bundleIdentifier: capitalizationResolver]
        ) { url in
            try documentationExtension.utf8Content.write(
                to: url.appendingPathComponent(documentationExtension.name),
                atomically: true,
                encoding: .utf8
            )
        }
        XCTAssert(context.problems.isEmpty, "Unexpected problems:\n\(context.problems.map(\.diagnostic.summary).joined(separator: "\n"))", file: file, line: line)

        // Load the DocumentationNode for the artist dictionary keys symbol.
        let reference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: path, sourceLanguage: .swift)
        let node = try context.entity(with: reference)

        // Get the semantic symbol and the variants of the dictionary keys section.
        // Use the variant with no interface language, corresponding to the markup
        // above.
        let symbol = try XCTUnwrap(node.semantic as? Symbol, file: file, line: line)
        return symbol
    }
    
    func testParametersWithCapitalization() throws {
        let exampleDocumentation = Folder(name: "unit-test.docc", content: [
            JSONFile(name: "ModuleName.symbols.json", content: makeSymbolGraph(
                moduleName: "ModuleName",
                symbols: [
                    SymbolGraph.Symbol(
                        identifier: .init(precise: "symbol-id", interfaceLanguage: "swift"),
                        names: .init(title: "SymbolName", navigator: nil, subHeading: nil, prose: nil),
                        pathComponents: ["SymbolName"],
                        docComment: nil,
                        accessLevel: .public,
                        kind: .init(parsedIdentifier: .class, displayName: "Kind Display Name"),
                        mixins: [:]
                    )
                ]
            )),

            TextFile(name: "Extension.md", utf8Content: """
            # ``SymbolName``

            This is about some symbol.

            - Parameters:
                - one: upper-cased first parameter description.
                - two:     the second parameter has extra white spaces
                - three: inValid third parameter will not be capitalized
                - four: `code block` will not be capitalized
                - five: a`nother invalid capitalization
                      
            """),
        ])

        let resolver = TestCapitalizationResolver()
        let bundleIdentifier = "com.external.testbundle"

        let tempURL = try createTempFolder(content: [exampleDocumentation])
        let (_, bundle, context) = try loadBundle(from: tempURL, externalResolvers: [resolver.bundleIdentifier: resolver])

        XCTAssert(context.problems.isEmpty, "Unexpected problems:\n\(context.problems.map(\.diagnostic.summary).joined(separator: "\n"))")

        // Load the DocumentationNode for the artist dictionary keys symbol.
        let reference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/ModuleName/SymbolName", sourceLanguage: .swift)
        let node = try context.entity(with: reference)

        // Get the semantic symbol and the variants of the dictionary keys section.
        // Use the variant with no interface language, corresponding to the markup above.
        let symbol = try XCTUnwrap(node.semantic as? Symbol)

        // Get the variant of the example symbol that has no interface language, meaning it was generated by the markup above.
        let variant = symbol.parametersSectionVariants.allValues.first(
            where: { $0.trait == .init(interfaceLanguage: nil) }
        )
        let section = try XCTUnwrap(variant?.variant)
        XCTAssertEqual(section.parameters.count, 5)

        // Test that the parameters are all correct.
        for param in section.parameters {
            let value = param.contents.first?.format().trimmingCharacters(in: .whitespaces)
            if param.name == "one" {
                let stringValue = try XCTUnwrap(value)
                XCTAssertEqual(stringValue, "Upper-cased first parameter description.")
            } else if param.name == "two" {
                let stringValue = try XCTUnwrap(value)
                XCTAssertEqual(stringValue, "The second parameter has extra white spaces")
            } else if param.name == "three" {
                let stringValue = try XCTUnwrap(value)
                XCTAssertEqual(stringValue, "inValid third parameter will not be capitalized")
            } else if param.name == "four" {
                let stringValue = try XCTUnwrap(value)
                XCTAssertEqual(stringValue, "`code block` will not be capitalized")
            } else if param.name == "five" {
                let stringValue = try XCTUnwrap(value)
                XCTAssertEqual(stringValue, "a`nother invalid capitalization")
            }
        }
    }
    
    func testDictionaryKeysWithCapitalization() throws {

        // Create some example documentation using the symbol graph file located under
        // Tests/SwiftDocCTests/Test Bundles/DictionaryData.docc, and the following
        // documentation extension markup.
        let documentationExtension = TextFile(
            name: "Artist.md",
            utf8Content: """
                    # ``DictionaryData/Artist``

                    Artist object.

                    The artist discussion.

                    - DictionaryKeys:
                      - age: artist's age.
                      - name: abstract for artist name.
                      - monthOfBirth: one
                      - genre:   many spaces before description.
                    """)
        let symbol = try exampleDocumentation(
            copying: "DictionaryData",
            documentationExtension: documentationExtension,
            path: "/documentation/DictionaryData/Artist"
        )

        // Get the variant of the example symbol that has no interface language, meaning it was generated by the markup above.
        let variant = symbol.dictionaryKeysSectionVariants.allValues.first(
            where: { $0.trait == .init(interfaceLanguage: nil) }
        )
        let section = try XCTUnwrap(variant?.variant)
        XCTAssertEqual(section.dictionaryKeys.count, 4)

        // Check that the two keys with external links in the markup above were found and processed by the test external reference resolver.
        for dictionaryKey in section.dictionaryKeys {
            let value = dictionaryKey.contents.first?.format().trimmingCharacters(in: .whitespaces)
            if dictionaryKey.name == "age" {
                let stringValue = try XCTUnwrap(value)
                XCTAssertEqual(stringValue, "Artist’s age.")
            } else if dictionaryKey.name == "name" {
                let stringValue = try XCTUnwrap(value)
                XCTAssertEqual(stringValue, "Abstract for artist name.")
            } else if dictionaryKey.name == "monthOfBirth" {
                let stringValue = try XCTUnwrap(value)
                XCTAssertEqual(stringValue, "One")
            } else if dictionaryKey.name == "genre" {
                let stringValue = try XCTUnwrap(value)
                XCTAssertEqual(stringValue, "Many spaces before description.")
            }
        }
    }
    
}
