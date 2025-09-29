/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import XCTest
import SwiftDocCTestUtilities
import SymbolKit

@testable import SwiftDocC

final class MarkdownOutputTests: XCTestCase {
    
    // MARK: - Test conveniences
    
    private func markdownOutput(catalog: Folder, path: String) async throws -> (MarkdownOutputNode, MarkdownOutputManifest) {
        let (bundle, context) = try await loadBundle(catalog: catalog)
        var path = path
        if !path.hasPrefix("/") {
            path = "/documentation/MarkdownOutput/\(path)"
        }
        let reference = ResolvedTopicReference(bundleID: bundle.id, path: path, sourceLanguage: .swift)
        let node = try XCTUnwrap(context.entity(with: reference))
        var translator = MarkdownOutputNodeTranslator(context: context, bundle: bundle, node: node)
        let output = try XCTUnwrap(translator.createOutput())
        let manifest = try XCTUnwrap(output.manifest)
        return (output.node, manifest)
    }
    
    private func catalog(files: [any File] = []) -> Folder {
        Folder(name: "MarkdownOutput.docc", content: [
            TextFile(name: "Article.md", utf8Content: """
                # Article

                A mostly empty article to make sure paths are formatted correctly
                
                ## Overview
                
                Nothing to see here
                """)
            ] + files
        )
    }
    
    // MARK: Directive special processing
    
    func testRowsAndColumns() async throws {
        
        let catalog = catalog(files: [
            TextFile(name: "RowsAndColumns.md", utf8Content: """
                # Rows and Columns

                Demonstrates how row and column directives are rendered as markdown

                ## Overview

                @Row {
                    @Column {
                        I am the content of column one
                    }
                    @Column {
                        I am the content of column two
                    }
                }
                """)
        ])
        
        let (node, _) = try await markdownOutput(catalog: catalog, path: "RowsAndColumns")
        let expected = "I am the content of column one\n\nI am the content of column two"
        XCTAssert(node.markdown.contains(expected))
    }
    
    func testLinkArticleFormatting() async throws {
        let catalog = catalog(files: [
            TextFile(name: "RowsAndColumns.md", utf8Content: """
                # Rows and Columns
                
                Just here for the links
                """),
            TextFile(name: "Links.md", utf8Content: """
                # Links

                Tests the appearance of inline and linked lists

                ## Overview

                This is an inline link: <doc:RowsAndColumns>

                ## Topics

                ### Links with abstracts

                - <doc:RowsAndColumns>
                """)
            ])
        
        let (node, _) = try await markdownOutput(catalog: catalog, path: "Links")
        let expectedInline = "inline link: [Rows and Columns](doc://MarkdownOutput/documentation/MarkdownOutput/RowsAndColumns)"
        XCTAssert(node.markdown.contains(expectedInline))
        
        let expectedLinkList = "[Rows and Columns](doc://MarkdownOutput/documentation/MarkdownOutput/RowsAndColumns)\n\nJust here for the links"
        XCTAssert(node.markdown.contains(expectedLinkList))
    }
       
    func testLinkSymbolFormatting() async throws {
        let catalog = catalog(files: [
            TextFile(name: "Links.md", utf8Content: """
                # Links

                Tests the appearance of inline and linked lists

                ## Overview

                This is an inline link: ``MarkdownSymbol``

                ## Topics

                ### Links with abstracts

                - ``MarkdownSymbol``
                """),
            JSONFile(name: "MarkdownOutput.symbols.json", content: makeSymbolGraph(moduleName: "MarkdownOutput", symbols: [
                makeSymbol(id: "MarkdownSymbol", kind: .struct, pathComponents: ["MarkdownSymbol"], docComment: "A basic symbol to test markdown output")
            ]))
        ])
        
        let (node, _) = try await markdownOutput(catalog: catalog, path: "Links")
        let expectedInline = "inline link: [`MarkdownSymbol`](doc://MarkdownOutput/documentation/MarkdownOutput/MarkdownSymbol)"
        XCTAssert(node.markdown.contains(expectedInline))
        
        let expectedLinkList = "[`MarkdownSymbol`](doc://MarkdownOutput/documentation/MarkdownOutput/MarkdownSymbol)\n\nA basic symbol to test markdown output"
        XCTAssert(node.markdown.contains(expectedLinkList))
    }
        
    func testLanguageTabOnlyIncludesPrimaryLanguage() async throws {
        let catalog = catalog(files: [
            TextFile(name: "Tabs.md", utf8Content: """
                # Tabs

                Showing how language tabs only render the primary language

                ## Overview

                @TabNavigator {
                    @Tab("Objective-C") {
                        ```objc
                        I am an Objective-C code block
                        ```
                    }
                    @Tab("Swift") {
                        ```swift
                        I am a Swift code block
                        ```
                    }
                }
                """)
        ])

        let (node, _) = try await markdownOutput(catalog: catalog, path: "Tabs")
        XCTAssertFalse(node.markdown.contains("I am an Objective-C code block"))
        XCTAssertTrue(node.markdown.contains("I am a Swift code block"))
    }
    
    func testNonLanguageTabIncludesAllEntries() async throws {
        let catalog = catalog(files: [
            TextFile(name: "Tabs.md", utf8Content: """
                # Tabs

                Showing how non-language tabs render all instances.

                ## Overview

                @TabNavigator {
                    @Tab("Left") {
                        Left text
                    }
                    @Tab("Right") {
                        Right text
                    }
                }
                """)
        ])

        let (node, _) = try await markdownOutput(catalog: catalog, path: "Tabs")
        XCTAssertTrue(node.markdown.contains("**Left:**\n\nLeft text"))
        XCTAssertTrue(node.markdown.contains("**Right:**\n\nRight text"))
    }
    
    func testTutorialCode() async throws {
        
        let tutorial = TextFile(name: "Tutorial.tutorial", utf8Content: """
            @Tutorial(time: 30) {
                @Intro(title: "Tutorial Title") {
                    A tutorial for testing markdown output.
                    
                    @Image(source: placeholder.png, alt: "Alternative text")
                }
                
                @Section(title: "The first section") {
                    
                    Here is some free floating content
                    
                    @Steps {
                        @Step {
                            Do the first set of things
                            @Code(name: "File.swift", file: 01-step-01.swift)
                        }
                        
                        Inter-step content 
                        
                        @Step {
                            Do the second set of things
                            @Code(name: "File.swift", file: 01-step-02.swift)
                        }
                        
                        @Step {
                            Do the third set of things
                            @Code(name: "File.swift", file: 01-step-03.swift)
                        }
                        
                        @Step {
                            Do the fourth set of things
                            @Code(name: "File2.swift", file: 02-step-01.swift)
                        }
                    }
                }
            }
            """
        )
        
        let codeOne = TextFile(name: "01-step-01.swift", utf8Content: """
            struct StartCode {
                // STEP ONE
            }
            """)
        
        let codeTwo = TextFile(name: "01-step-02.swift", utf8Content: """
            struct StartCode {
                // STEP TWO
                let property1: Int
            }
            """)
        
        let codeThree = TextFile(name: "01-step-03.swift", utf8Content: """
            struct StartCode {
                // STEP THREE
                let property1: Int
                let property2: Int
            }
            """)
        
        let codeFour = TextFile(name: "02-step-01.swift", utf8Content: """
            struct StartCodeAgain {
                
            }
            """)
        
        let codeFolder = Folder(name: "code-files", content: [codeOne, codeTwo, codeThree, codeFour])
        let resourceFolder = Folder(name: "Resources", content: [codeFolder])
                
        let catalog = catalog(files: [
            tutorial,
            resourceFolder
        ])
        
        let (node, _) = try await markdownOutput(catalog: catalog, path: "/tutorials/MarkdownOutput/Tutorial")
        XCTAssertFalse(node.markdown.contains("// STEP ONE"), "Non-final code versions are not included")
        XCTAssertFalse(node.markdown.contains("// STEP TWO"), "Non-final code versions are not included")
        let codeIndex = try XCTUnwrap(node.markdown.firstRange(of: "// STEP THREE"), "Final code version is included")
        let step4Index = try XCTUnwrap(node.markdown.firstRange(of: "### Step 4"))
        XCTAssert(codeIndex.lowerBound < step4Index.lowerBound, "Code reference is added after the last step that references it")
        XCTAssertTrue(node.markdown.contains("struct StartCodeAgain {"), "New file reference is included")
    }
        
    // MARK: - Metadata
    
    func testArticleMetadata() async throws {
        let catalog = catalog(files: [
            TextFile(name: "ArticleRole.md", utf8Content: """
                # Article Role
                
                This article will have the correct document type and role
                
                ## Overview
                
                Content
                """)
        ])
        let (node, _) = try await markdownOutput(catalog: catalog, path: "ArticleRole")
        XCTAssert(node.metadata.documentType == .article)
        XCTAssert(node.metadata.role == RenderMetadata.Role.article.rawValue)
        XCTAssert(node.metadata.title == "Article Role")
        XCTAssert(node.metadata.uri == "/documentation/MarkdownOutput/ArticleRole")
        XCTAssert(node.metadata.framework == "MarkdownOutput")
    }
    
    func testAPICollectionRole() async throws {
        let catalog = catalog(files: [
            TextFile(name: "APICollection.md", utf8Content: """
                # API Collection

                This is an API collection

                ## Topics

                ### Topic subgroup

                -<doc:Links>
                -<doc:RowsAndColumns>

                """),
            TextFile(name: "Links.md", utf8Content: """
                # Links

                An article to be linked to
                """),
            TextFile(name: "RowsAndColumns.md", utf8Content: """
                # Rows and Columns

                An article to be linked to
                """)
            
        ])
        let (node, _) = try await markdownOutput(catalog: catalog, path: "APICollection")
        XCTAssert(node.metadata.role == RenderMetadata.Role.collectionGroup.rawValue)
    }
        
    func testArticleAvailability() async throws {
        let catalog = catalog(files: [
            TextFile(name: "AvailabilityArticle.md", utf8Content: """
                # Availability Demonstration

                @Metadata {
                    @PageKind(sampleCode)
                    @Available(Xcode, introduced: "14.3")
                    @Available(macOS, introduced: "13.0")
                }

                This article demonstrates platform availability defined in metadata

                ## Overview

                Some stuff
                """)
        ])
        
        let (node, _) = try await markdownOutput(catalog: catalog, path: "AvailabilityArticle")
        XCTAssert(node.metadata.availability(for: "Xcode")?.introduced == "14.3.0")
        XCTAssert(node.metadata.availability(for: "macOS")?.introduced == "13.0.0")
    }
    
    func testSymbolDocumentType() async throws {
        let catalog = catalog(files: [
            JSONFile(name: "MarkdownOutput.symbols.json", content: makeSymbolGraph(moduleName: "MarkdownOutput", symbols: [
                makeSymbol(id: "MarkdownSymbol", kind: .struct, pathComponents: ["MarkdownSymbol"], docComment: "A basic symbol to test markdown output")
            ]))
        ])
        let (node, _) = try await markdownOutput(catalog: catalog, path: "MarkdownSymbol")
        XCTAssert(node.metadata.documentType == .symbol)
    }
    
    func testSymbolMetadata() async throws {
        let catalog = catalog(files: [
            JSONFile(name: "MarkdownOutput.symbols.json", content: makeSymbolGraph(moduleName: "MarkdownOutput", symbols: [
                makeSymbol(id: "MarkdownSymbol", kind: .struct, pathComponents: ["MarkdownSymbol"], docComment: "A basic symbol to test markdown output"),
                makeSymbol(id: "MarkdownSymbol_init_name", kind: .`init`, pathComponents: ["MarkdownSymbol", "init(name:)"])
            ]))
        ])
        let (node, _) = try await markdownOutput(catalog: catalog, path: "MarkdownSymbol/init(name:)")
        XCTAssert(node.metadata.title == "init(name:)")
        XCTAssert(node.metadata.symbol?.kind == "init")
        XCTAssert(node.metadata.role == "Initializer")
        XCTAssertEqual(node.metadata.symbol?.modules, ["MarkdownOutput"])
    }
        
    func testSymbolExtendedModule() async throws {
        let catalog = catalog(files: [
            JSONFile(name: "MarkdownOutput.symbols.json", content: makeSymbolGraph(moduleName: "MarkdownOutput", symbols: [
                makeSymbol(id: "Array_asdf", kind: .property, pathComponents: ["Swift", "Array", "asdf"], otherMixins: [SymbolGraph.Symbol.Swift.Extension(extendedModule: "Swift", constraints: [])])
                ])
             )
        ])
        let (node, _) = try await markdownOutput(catalog: catalog, path: "Swift/Array/asdf")
        XCTAssertEqual(node.metadata.symbol?.modules, ["MarkdownOutput", "Swift"])
    }
    
    func testSymbolDefaultAvailabilityWhenNothingPresent() async throws {
        let catalog = catalog(files: [
            JSONFile(name: "MarkdownOutput.symbols.json", content: makeSymbolGraph(moduleName: "MarkdownOutput", symbols: [
                makeSymbol(id: "MarkdownSymbol", kind: .struct, pathComponents: ["MarkdownSymbol"], docComment: "A basic symbol to test markdown output")
            ])),
            InfoPlist(defaultAvailability: [
                "MarkdownOutput" : [.init(platformName: .iOS, platformVersion: "1.0.0")]
            ])
        ])
        let (node, _) = try await markdownOutput(catalog: catalog, path: "MarkdownSymbol")
        let availability = try XCTUnwrap(node.metadata.availability)
        XCTAssert(availability.contains(.init(platform: "iOS", introduced: "1.0.0", deprecated: nil, unavailable: false)))
    }
    
    func testSymbolAvailabilityFromMetadataBlock() async throws {
        let catalog = catalog(files: [
            JSONFile(name: "MarkdownOutput.symbols.json", content: makeSymbolGraph(moduleName: "MarkdownOutput", symbols: [
                makeSymbol(id: "MarkdownSymbol", kind: .struct, pathComponents: ["MarkdownSymbol"], docComment: "A basic symbol to test markdown output")
            ])),
            InfoPlist(defaultAvailability: [
                "MarkdownOutput" : [.init(platformName: .iOS, platformVersion: "1.0.0")]
            ]),
            TextFile(name: "MarkdownSymbol.md", utf8Content: """
                # ``MarkdownSymbol``
                
                @Metadata {
                    @Available(iPadOS, introduced: "13.1")
                }
                
                A basic symbol to test markdown output
                
                ## Overview
                
                Overview goes here
                """)
        ])
        let (node, _) = try await markdownOutput(catalog: catalog, path: "MarkdownSymbol")
        let availability = try XCTUnwrap(node.metadata.availability)
        XCTAssert(availability.contains(where: { $0.platform == "iPadOS" && $0.introduced == "13.1.0" }))
    }
    
    func testAvailabilityStringRepresentationIntroduced() async throws {
        let a = "iOS: 14.0"
        let availability = MarkdownOutputNode.Metadata.Availability(stringRepresentation: a)
        XCTAssertEqual(availability.platform, "iOS")
        XCTAssertEqual(availability.introduced, "14.0")
        XCTAssertNil(availability.deprecated)
        XCTAssertFalse(availability.unavailable)
    }
    
    func testAvailabilityStringRepresentationDeprecated() async throws {
        let a = "iOS: 14.0 - 15.0"
        let availability = MarkdownOutputNode.Metadata.Availability(stringRepresentation: a)
        XCTAssertEqual(availability.platform, "iOS")
        XCTAssertEqual(availability.introduced, "14.0")
        XCTAssertEqual(availability.deprecated, "15.0")
        XCTAssertFalse(availability.unavailable)
    }
    
    func testAvailabilityStringRepresentationUnavailable() async throws {
        let a = "iOS: -"
        let availability = MarkdownOutputNode.Metadata.Availability(stringRepresentation: a)
        XCTAssertEqual(availability.platform, "iOS")
        XCTAssertNil(availability.introduced)
        XCTAssertNil(availability.deprecated)
        XCTAssert(availability.unavailable)
    }
    
    func testAvailabilityCreateStringRepresentationIntroduced() async throws {
        let availability = MarkdownOutputNode.Metadata.Availability(platform: "iOS", introduced: "14.0", unavailable: false)
        let expected = "iOS: 14.0 -"
        XCTAssertEqual(availability.stringRepresentation, expected)
    }
    
    func testAvailabilityCreateStringRepresentationDeprecated() async throws {
        let availability = MarkdownOutputNode.Metadata.Availability(platform: "iOS", introduced: "14.0", deprecated: "15.0", unavailable: false)
        let expected = "iOS: 14.0 - 15.0"
        XCTAssertEqual(availability.stringRepresentation, expected)
    }
    
    func testAvailabilityCreateStringRepresentationUnavailable() async throws {
        let availability = MarkdownOutputNode.Metadata.Availability(platform: "iOS", unavailable: true)
        let expected = "iOS: -"
        XCTAssertEqual(availability.stringRepresentation, expected)
    }
    
    func testAvailabilityCreateStringRepresentationEmptyAvailability() async throws {
        let availability = MarkdownOutputNode.Metadata.Availability(platform: "iOS", introduced: "", unavailable: false)
        let expected = "iOS: -"
        XCTAssertEqual(availability.stringRepresentation, expected)
    }
            
    func testSymbolDeprecation() async throws {
        let catalog = catalog(files: [
            JSONFile(name: "MarkdownOutput.symbols.json", content: makeSymbolGraph(moduleName: "MarkdownOutput", symbols: [
                makeSymbol(id: "MarkdownSymbol", kind: .struct, pathComponents: ["MarkdownSymbol"], docComment: "A basic symbol to test markdown output"),
                makeSymbol(
                    id: "MarkdownSymbol_fullName",
                    kind: .property,
                    pathComponents: ["MarkdownSymbol", "fullName"],
                    docComment: "A basic property to test markdown output",
                    availability: [
                        .init(domain: .init(rawValue: "iOS"),
                              introducedVersion: .init(string: "1.0.0"),
                              deprecatedVersion: .init(string: "4.0.0"),
                              obsoletedVersion: nil,
                              message: nil,
                              renamed: nil,
                              isUnconditionallyDeprecated: false,
                              isUnconditionallyUnavailable: false,
                              willEventuallyBeDeprecated: false
                             ),
                        .init(domain: .init(rawValue: "macOS"),
                              introducedVersion: .init(string: "2.0.0"),
                              deprecatedVersion: .init(string: "4.0.0"),
                              obsoletedVersion: nil,
                              message: nil,
                              renamed: nil,
                              isUnconditionallyDeprecated: false,
                              isUnconditionallyUnavailable: false,
                              willEventuallyBeDeprecated: false
                             ),
                        .init(domain: .init(rawValue: "visionOS"),
                              introducedVersion: .init(string: "2.0.0"),
                              deprecatedVersion: .init(string: "4.0.0"),
                              obsoletedVersion: .init(string: "5.0.0"),
                              message: nil,
                              renamed: nil,
                              isUnconditionallyDeprecated: false,
                              isUnconditionallyUnavailable: false,
                              willEventuallyBeDeprecated: false
                             )
                    ])
            ]))
        ])
        
        let (node, _) = try await markdownOutput(catalog: catalog, path: "MarkdownSymbol/fullName")
        let availability = try XCTUnwrap(node.metadata.availability(for: "iOS"))
        XCTAssertEqual(availability.introduced, "1.0.0")
        XCTAssertEqual(availability.deprecated, "4.0.0")
        XCTAssertEqual(availability.unavailable, false)
        
        let macAvailability = try XCTUnwrap(node.metadata.availability(for: "macOS"))
        XCTAssertEqual(macAvailability.introduced, "2.0.0")
        XCTAssertEqual(macAvailability.deprecated, "4.0.0")
        XCTAssertEqual(macAvailability.unavailable, false)
        
        let visionAvailability = try XCTUnwrap(node.metadata.availability(for: "visionOS"))
        XCTAssert(visionAvailability.unavailable)
    }
    
    
    func testSymbolIdentifier() async throws {
        let catalog = catalog(files: [
            JSONFile(name: "MarkdownOutput.symbols.json", content: makeSymbolGraph(moduleName: "MarkdownOutput", symbols: [
                makeSymbol(id: "MarkdownSymbol_Identifier", kind: .struct, pathComponents: ["MarkdownSymbol"], docComment: "A basic symbol to test markdown output"),
            ]))
        ])
        
        let (node, _) = try await markdownOutput(catalog: catalog, path: "MarkdownSymbol")
        XCTAssertEqual(node.metadata.symbol?.preciseIdentifier, "MarkdownSymbol_Identifier")
    }
    
    func testTutorialMetadata() async throws {
        let catalog = catalog(files: [
            TextFile(name: "Tutorial.tutorial", utf8Content: """
            @Tutorial(time: 30) {
                @Intro(title: "Tutorial Title") {
                    A tutorial for testing markdown output.
                    
                    @Image(source: placeholder.png, alt: "Alternative text")
                }
                
                @Section(title: "The first section") {
                                        
                    @Steps {
                        @Step {
                            Do the first set of things
                        }
                    }
                }
            }
            """
            )
        ])
        let (node, _) = try await markdownOutput(catalog: catalog, path: "/tutorials/MarkdownOutput/Tutorial")
        XCTAssert(node.metadata.documentType == .tutorial)
        XCTAssert(node.metadata.title == "Tutorial Title")
    }
          
    // MARK: - Encoding / Decoding
    func testMarkdownRoundTrip() async throws {
        let catalog = catalog(files: [
            TextFile(name: "Links.md", utf8Content: """
                # Links

                Tests the appearance of inline and linked lists

                ## Overview

                This is an inline link: ``MarkdownSymbol``

                ## Topics

                ### Links with abstracts

                - ``MarkdownSymbol``
                """),
            JSONFile(name: "MarkdownOutput.symbols.json", content: makeSymbolGraph(moduleName: "MarkdownOutput", symbols: [
                makeSymbol(id: "MarkdownSymbol", kind: .struct, pathComponents: ["MarkdownSymbol"], docComment: "A basic symbol to test markdown output")
            ]))
        ])
        
        let (node, _) = try await markdownOutput(catalog: catalog, path: "MarkdownSymbol")
        let data = try node.data
        let fromData = try MarkdownOutputNode(data)
        XCTAssertEqual(node.markdown, fromData.markdown)
        XCTAssertEqual(node.metadata.uri, fromData.metadata.uri)
    }
    
    // MARK: - Manifest
    func testArticleManifestLinks() async throws {
        
        let catalog = catalog(files: [
            JSONFile(name: "MarkdownOutput.symbols.json", content: makeSymbolGraph(moduleName: "MarkdownOutput", symbols: [
                makeSymbol(id: "MarkdownSymbol_Identifier", kind: .struct, pathComponents: ["MarkdownSymbol"], docComment: "A basic symbol to test markdown output"),
            ])),
            TextFile(name: "RowsAndColumns.md", utf8Content: """
                # Rows and Columns
                
                Just here for the links
                """),
            TextFile(name: "APICollection.md", utf8Content: """
                # API Collection
                
                An API collection
                
                ## Topics
                
                - <doc:RowsAndColumns>
                """),
            TextFile(name: "Links.md", utf8Content: """
                # Links

                Tests the appearance of inline and linked lists

                ## Overview

                This is an inline link: <doc:RowsAndColumns>
                This is an inline link: ``MarkdownSymbol``
                This is a link that isn't curated in a topic so shouldn't come up in the manifest: <doc:APICollection>.

                ## Topics

                ### Links with abstracts

                - <doc:RowsAndColumns>
                - ``MarkdownSymbol``
                """)
        ])
        
        let (_, manifest) = try await markdownOutput(catalog: catalog, path: "Links")
        let rows = MarkdownOutputManifest.Relationship(
            sourceURI: "/documentation/MarkdownOutput/RowsAndColumns",
            relationshipType: .belongsToTopic,
            targetURI: "/documentation/MarkdownOutput/Links#Links-with-abstracts"
        )
        
        let symbol = MarkdownOutputManifest.Relationship(
            sourceURI: "/documentation/MarkdownOutput/MarkdownSymbol",
            relationshipType: .belongsToTopic,
            targetURI: "/documentation/MarkdownOutput/Links#Links-with-abstracts"
        )
        
        XCTAssert(manifest.relationships.contains(rows))
        XCTAssert(manifest.relationships.contains(symbol))
    }
    
    func testSymbolManifestChildSymbols() async throws {
        // This is a calculated function so we don't need to ingest anything
        let documentURIs: [String] = [
            "/documentation/MarkdownOutput/MarkdownSymbol",
            "/documentation/MarkdownOutput/MarkdownSymbol/name",
            "/documentation/MarkdownOutput/MarkdownSymbol/otherName",
            "/documentation/MarkdownOutput/MarkdownSymbol/fullName",
            "/documentation/MarkdownOutput/MarkdownSymbol/init(name:)",
            "documentation/MarkdownOutput/MarkdownSymbol/Child/Grandchild",
            "documentation/MarkdownOutput/Sibling/name"
        ]
        
        let documents = documentURIs.map {
            MarkdownOutputManifest.Document(uri: $0, documentType: .symbol, title: $0)
        }
        let manifest = MarkdownOutputManifest(title: "Test", documents: Set(documents))
        
        let document = try XCTUnwrap(manifest.documents.first(where: { $0.uri == "/documentation/MarkdownOutput/MarkdownSymbol" }))
        let children = manifest.children(of: document).map { $0.uri }
        XCTAssertEqual(children.count, 4)
        
        XCTAssert(children.contains("/documentation/MarkdownOutput/MarkdownSymbol/name"))
        XCTAssert(children.contains("/documentation/MarkdownOutput/MarkdownSymbol/otherName"))
        XCTAssert(children.contains("/documentation/MarkdownOutput/MarkdownSymbol/fullName"))
        XCTAssert(children.contains("/documentation/MarkdownOutput/MarkdownSymbol/init(name:)"))
    }
    
    func testSymbolManifestInheritance() async throws {
        
        let symbols = [
            makeSymbol(id: "MO_Subclass", kind: .class, pathComponents: ["LocalSubclass"]),
            makeSymbol(id: "MO_Superclass", kind: .class, pathComponents: ["LocalSuperclass"])
        ]
        
        let relationships = [
            SymbolGraph.Relationship(source: "MO_Subclass", target: "MO_Superclass", kind: .inheritsFrom, targetFallback: nil)
        ]
        
        let catalog = catalog(files: [
            JSONFile(name: "MarkdownOutput.symbols.json", content:
                    makeSymbolGraph(moduleName: "MarkdownOutput", symbols: symbols, relationships: relationships))
        ])
        
        
        let (_, manifest) = try await markdownOutput(catalog: catalog, path: "LocalSubclass")
        let related = manifest.relationships.filter { $0.relationshipType == .relatedSymbol }
        XCTAssert(related.contains(where: {
            $0.targetURI == "/documentation/MarkdownOutput/LocalSuperclass" && $0.subtype == "inheritsFrom"
        }))
        
        let (_, parentManifest) = try await markdownOutput(catalog: catalog, path: "LocalSuperclass")
        let parentRelated = parentManifest.relationships.filter { $0.relationshipType == .relatedSymbol }
        XCTAssert(parentRelated.contains(where: {
            $0.targetURI == "/documentation/MarkdownOutput/LocalSubclass" && $0.subtype == "inheritedBy"
        }))
    }
        
    func testSymbolManifestConformance() async throws {
        
        let symbols = [
            makeSymbol(id: "MO_Conformer", kind: .struct, pathComponents: ["LocalConformer"]),
            makeSymbol(id: "MO_Protocol", kind: .protocol, pathComponents: ["LocalProtocol"]),
            makeSymbol(id: "MO_ExternalConformer", kind: .struct, pathComponents: ["ExternalConformer"])
        ]
        
        let relationships = [
            SymbolGraph.Relationship(source: "MO_Conformer", target: "MO_Protocol", kind: .conformsTo, targetFallback: nil),
            SymbolGraph.Relationship(source: "MO_ExternalConformer", target: "s:SH", kind: .conformsTo, targetFallback: "Swift.Hashable")
        ]
        
        let catalog = catalog(files: [
            JSONFile(name: "MarkdownOutput.symbols.json", content:
                    makeSymbolGraph(moduleName: "MarkdownOutput", symbols: symbols, relationships: relationships))
        ])
        
        let (_, manifest) = try await markdownOutput(catalog: catalog, path: "LocalConformer")
        let related = manifest.relationships.filter { $0.relationshipType == .relatedSymbol }
        XCTAssert(related.contains(where: {
            $0.targetURI == "/documentation/MarkdownOutput/LocalProtocol" && $0.subtype == "conformsTo"
        }))
        
        let (_, protocolManifest) = try await markdownOutput(catalog: catalog, path: "LocalProtocol")
        let protocolRelated = protocolManifest.relationships.filter { $0.relationshipType == .relatedSymbol }
        XCTAssert(protocolRelated.contains(where: {
            $0.targetURI == "/documentation/MarkdownOutput/LocalConformer" && $0.subtype == "conformingTypes"
        }))
        
        let (_, externalManifest) = try await markdownOutput(catalog: catalog, path: "ExternalConformer")
        let externalRelated = externalManifest.relationships.filter { $0.relationshipType == .relatedSymbol }
        XCTAssert(externalRelated.contains(where: {
            $0.targetURI == "/documentation/Swift/Hashable" && $0.subtype == "conformsTo"
        }))
    }
}
