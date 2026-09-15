/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Testing
import DocCTestUtilities
import SymbolKit
@testable import SwiftDocC
import DocCCommon

struct MarkdownOutputTests {
    
    // MARK: - Test conveniences
    
    private func markdownOutput(catalog: Folder, path: String) async throws -> (MarkdownOutputNode, MarkdownOutputManifest) {
        let context = try await load(catalog: catalog)
        var path = path
        if !path.hasPrefix("/") {
            path = "/documentation/MarkdownOutput/\(path)"
        }
        let reference = ResolvedTopicReference(bundleID: context.inputs.id, path: path, sourceLanguage: .swift)
        let node = try context.entity(with: reference)
        var visitor = MarkdownOutputSemanticVisitor(context: context, node: node)
        let output = visitor.createOutput()
        let markdownNode = try #require(output)
        let manifest = try #require(visitor.manifest)
        return (markdownNode, manifest)
    }
    
    private func catalog(files: [any File] = []) -> Folder {
        Folder(name: "MarkdownOutput.docc", content: [
            TextFile(name: "Article.md", utf8Content: """
                # Article

                A mostly empty article to make sure paths are formatted correctly. 
                
                If we create a test catalog with a single file, then the reference for that file is doc://MarkdownOutput/documentation/FileName, instead of doc://MarkdownOutput/documentation/MarkdownOutput/Filename
                
                ## Overview
                
                Nothing to see here
                """)
            ] + files
        )
    }
    
    // MARK: Directive special processing
    
    @Test
    func alternateDeclarationsAreIncluded() async throws {
        
        func platformDeclaration(name: String, type: String) -> SymbolGraph.Symbol.DeclarationFragments {
            .init(declarationFragments: [
                .init(kind: .keyword, spelling: "func", preciseIdentifier: nil),
                .init(kind: .text, spelling: " ", preciseIdentifier: nil),
                .init(kind: .identifier, spelling: name, preciseIdentifier: nil),
                .init(kind: .text, spelling: "(", preciseIdentifier: nil),
                .init(kind: .externalParameter, spelling: "value", preciseIdentifier: nil),
                .init(kind: .text, spelling: ": ", preciseIdentifier: nil),
                .init(kind: .typeIdentifier, spelling: type, preciseIdentifier: nil),
                .init(kind: .text, spelling: ")", preciseIdentifier: nil),
            ])
        }
        
        func functionDeclaration(alternate: Bool) -> SymbolGraph.Symbol.DeclarationFragments {
            var fragments: [SymbolGraph.Symbol.DeclarationFragments.Fragment] = [
                .init(kind: .keyword, spelling: "func", preciseIdentifier: nil),
                .init(kind: .text, spelling: " ", preciseIdentifier: nil),
                .init(kind: .identifier, spelling: "doSomething", preciseIdentifier: nil),
                .init(kind: .text, spelling: "(", preciseIdentifier: nil),
            ]
            
            if alternate {
                fragments.append(contentsOf: [
                    .init(kind: .text, spelling: ") ", preciseIdentifier: nil),
                    .init(kind: .keyword, spelling: "async", preciseIdentifier: nil),
                ])
            } else {
                fragments.append(contentsOf: [
                    .init(kind: .externalParameter, spelling: "completionHandler", preciseIdentifier: nil),
                    .init(kind: .text, spelling: " ", preciseIdentifier: nil),
                    .init(kind: .internalParameter, spelling: "handler", preciseIdentifier: nil),
                    .init(kind: .text, spelling: ": ", preciseIdentifier: nil),
                    .init(kind: .attribute, spelling: "@escaping ", preciseIdentifier: nil),
                    .init(kind: .attribute, spelling: "@Sendable", preciseIdentifier: nil),
                    .init(kind: .text, spelling: " () -> ", preciseIdentifier: nil),
                    .init(kind: .typeIdentifier, spelling: "Void", preciseIdentifier: nil),
                    .init(kind: .text, spelling: ")", preciseIdentifier: nil),
                ])
            }
            
            return .init(declarationFragments: fragments)
        }
                        
        func graph(platform: String, type: String) -> SymbolGraph {
            makeSymbolGraph(
                moduleName: "MarkdownOutput",
                platform: .init(operatingSystem: .init(name: platform)),
                symbols: [
                    makeSymbol(id: "markdown-symbol-id", kind: .struct, pathComponents: ["MarkdownSymbol"]),
                    makeSymbol(id: "markdown-symbol-variants-id", kind: .func, pathComponents: ["MarkdownSymbol", "varies(_:)"], otherMixins: [platformDeclaration(name: "varies", type: type)]),
                    makeSymbol(id: "markdown-symbol-no-variants-id", kind: .func, pathComponents: ["MarkdownSymbol", "notVaries(_:)"], otherMixins: [platformDeclaration(name: "notVaries", type: "Int")]),
                    makeSymbol(id: "markdown-symbol-alternates-id", kind: .func, pathComponents: ["MarkdownSymbol", "doSomething(completionHandler:)"], otherMixins: [
                        functionDeclaration(alternate: false),
                        SymbolGraph.Symbol.AlternateSymbols(alternateSymbols: [.init(declarationFragments: functionDeclaration(alternate: true))])
                    ])
                ],
                relationships: [
                    SymbolGraph.Relationship(source: "markdown-symbol-variants-id", target: "markdown-symbol-id", kind: .memberOf, targetFallback: nil),
                    SymbolGraph.Relationship(source: "markdown-symbol-no-variants-id", target: "markdown-symbol-id", kind: .memberOf, targetFallback: nil)
                ]
            )
        }
        
        let catalog = catalog(files: [
            JSONFile(name: "visionos-MarkdownOutput.symbols.json", content: graph(platform: "visionos", type: "UIColor")),
            JSONFile(name: "macos-MarkdownOutput.symbols.json", content: graph(platform: "macos", type: "NSColor")),
            JSONFile(name: "ios-MarkdownOutput.symbols.json", content: graph(platform: "ios", type: "UIColor")),
        ])
        
        let (node, _) = try await markdownOutput(catalog: catalog, path: "MarkdownSymbol/varies(_:)")
        
        let expectedDeclaration = """
        iOS, iPadOS, Mac Catalyst, visionOS:
        
        ```
        func varies(value: UIColor)
        ```
        
        macOS:
        
        ```
        func varies(value: NSColor)
        ```
        """
        #expect(node.markdown.contains(expectedDeclaration))
        
        let (nonVariantNode, _) = try await markdownOutput(catalog: catalog, path: "MarkdownSymbol/notVaries(_:)")
        let expectedNonVariant = """
        # notVaries(_:)
        
        ```
        func notVaries(value: Int)
        ```
        """
        #expect(nonVariantNode.markdown.contains(expectedNonVariant))
        
        let (alternateNode, _) = try await markdownOutput(catalog: catalog, path: "MarkdownSymbol/doSomething(completionHandler:)")
        
        let expectedVariantDeclarations = """
        ```
        func doSomething(completionHandler handler: @escaping @Sendable () -> Void)
        ```

        ```
        func doSomething() async
        ```
        """
        #expect(alternateNode.markdown.contains(expectedVariantDeclarations))
    }
    
    @Test
    func rowsAndColumnsAreRenderedAsParagraphs() async throws {
        
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
        #expect(node.markdown.contains(expected))
    }
    
    @Test
    func curatedArticlesDisplayLinksAndAbstractAsSeparateParagraphs() async throws {
        let catalog = catalog(files: [
            TextFile(name: "RowsAndColumns.md", utf8Content: """
                # Rows and Columns
                
                Abstract rendered when curated
                
                ## Overview
                
                My section header will be specifically linked below
                
                ## Multi-word heading
                
                My section header is also linked below, and it has a hyphen in it and multiple words
                """),
            TextFile(name: "Links.md", utf8Content: """
                # Links

                Tests the appearance of inline and linked lists

                ## Overview

                This is an inline link: <doc:RowsAndColumns>
                This is an inline link with a heading: <doc:RowsAndColumns#Overview>
                This is an inline link with a multi-word heading: <doc:RowsAndColumns#Multi-word-heading>

                ## Topics

                ### Links with abstracts

                - <doc:RowsAndColumns>
                - <doc:RowsAndColumns#Overview>
                
                ### No more links
                
                Empty section
                """)
            ])
        
        let (node, _) = try await markdownOutput(catalog: catalog, path: "Links")
        let expectedInline = "inline link: [Rows and Columns](/documentation/MarkdownOutput/RowsAndColumns)"
        #expect(node.markdown.contains(expectedInline))
        
        let expectedInlineAnchor = "inline link with a heading: [Overview](/documentation/MarkdownOutput/RowsAndColumns#Overview)"
        #expect(node.markdown.contains(expectedInlineAnchor))
        let expectedInlineAnchorMultiWord = "inline link with a multi-word heading: [Multi-word heading](/documentation/MarkdownOutput/RowsAndColumns#Multi-word-heading)"
        #expect(node.markdown.contains(expectedInlineAnchorMultiWord))
        
        let expectedLinkList = "[Rows and Columns](/documentation/MarkdownOutput/RowsAndColumns)\n\nAbstract rendered when curated"
        #expect(node.markdown.contains(expectedLinkList))
        
        // No abstract
        let expectedLinkListAnchor = "[Overview](/documentation/MarkdownOutput/RowsAndColumns#Overview)\n\n###"
        #expect(node.markdown.contains(expectedLinkListAnchor))
    }

    @Test
    func articleInListItemIsTitleAndLink() async throws {
        let catalog = catalog(files: [
            TextFile(name: "RowsAndColumns.md", utf8Content: """
                # Rows and Columns
                
                Just here for the links
                
                ## Overview
                
                Section is linked below
                
                ## Multi-word heading
                
                Multi-word section is linked below
                """),
            TextFile(name: "Links.md", utf8Content: """
                # Links

                - This is an inline link: <doc:RowsAndColumns>
                  - This is a nested inline link with a heading: <doc:RowsAndColumns#Overview>
                - This is an inline link with a multi-word heading: <doc:RowsAndColumns#Multi-word-heading>
                
                1. This is an inline link: <doc:RowsAndColumns>
                    1. This is a nested inline link with a heading: <doc:RowsAndColumns#Overview>
                    2. Here is it again <doc:RowsAndColumns#Overview>
                2. This is an inline link with a multi-word heading: <doc:RowsAndColumns#Multi-word-heading>
                """)
            ])

        let (node, _) = try await markdownOutput(catalog: catalog, path: "Links")
        let expectedInline = "- This is an inline link: [Rows and Columns](/documentation/MarkdownOutput/RowsAndColumns)"
        #expect(node.markdown.contains(expectedInline))

        let expectedInlineAnchor = "  - This is a nested inline link with a heading: [Overview](/documentation/MarkdownOutput/RowsAndColumns#Overview)"
        #expect(node.markdown.contains(expectedInlineAnchor))
        let expectedInlineAnchorMultiWord = "- This is an inline link with a multi-word heading: [Multi-word heading](/documentation/MarkdownOutput/RowsAndColumns#Multi-word-heading)"
        #expect(node.markdown.contains(expectedInlineAnchorMultiWord))

        let expectedOrdered = """
        1. This is an inline link: [Rows and Columns](/documentation/MarkdownOutput/RowsAndColumns)
           1. This is a nested inline link with a heading: [Overview](/documentation/MarkdownOutput/RowsAndColumns#Overview)
           2. Here is it again [Overview](/documentation/MarkdownOutput/RowsAndColumns#Overview)
        2. This is an inline link with a multi-word heading: [Multi-word heading](/documentation/MarkdownOutput/RowsAndColumns#Multi-word-heading)
        """
        #expect(node.markdown.contains(expectedOrdered))
    }

    @Test
    func nestedListsRetainNesting() async throws {
        let catalog = catalog(files: [
            TextFile(name: "NestedLists.md", utf8Content: """
                # Nested Lists
                
                - This is a top-level list item
                  - This is a nested list item
                  - This is another nested list item
                - This is back to the top-level
                """)
            ])

        let (node, _) = try await markdownOutput(catalog: catalog, path: "NestedLists")
        let expectedOutput = """
        - This is a top-level list item
          - This is a nested list item
          - This is another nested list item
        - This is back to the top-level
        """
        #expect(node.markdown.contains(expectedOutput))
    }
    
    @Test 
    func curatedSymbolDisplaysLinkAndAbstractAsSeparateParagraphs() async throws {
        let catalog = catalog(files: [
            TextFile(name: "Links.md", utf8Content: """
                # Links

                Tests the appearance of inline and linked lists

                ## Overview

                This is an inline link: ``MarkdownSymbol``
                
                This is an unresolvable link: ``Unresolvable``
                
                This is a list of things that have links:
                
                - You can use ``MarkdownSymbol`` to do interesting things

                ## Topics

                ### Links with abstracts

                - ``MarkdownSymbol``
                - ``UnresolvableInList``
                
                """),
            JSONFile(name: "MarkdownOutput.symbols.json", content: makeSymbolGraph(moduleName: "MarkdownOutput", symbols: [
                makeSymbol(id: "markdown-symbol-id", kind: .struct, pathComponents: ["MarkdownSymbol"], docComment: "A basic symbol to test markdown output")
            ]))
        ])
        
        let (node, _) = try await markdownOutput(catalog: catalog, path: "Links")
        let expectedInline = "inline link: [`MarkdownSymbol`](/documentation/MarkdownOutput/MarkdownSymbol)"
        #expect(node.markdown.contains(expectedInline))
        
        let expectedLinkList = "[`MarkdownSymbol`](/documentation/MarkdownOutput/MarkdownSymbol)\n\nA basic symbol to test markdown output"
        #expect(node.markdown.contains(expectedLinkList))
        
        let unresolvableLink = "[`Unresolvable`]"
        #expect(node.markdown.contains(unresolvableLink) == false)
        let unresolvableAsCodeVoice = "unresolvable link: `Unresolvable`"
        #expect(node.markdown.contains(unresolvableAsCodeVoice))
        #expect(node.markdown.contains("UnresolvableInList") == false)
        let expectedUnorderedListContent = "- You can use [`MarkdownSymbol`](/documentation/MarkdownOutput/MarkdownSymbol) to do interesting things"
        #expect(node.markdown.contains(expectedUnorderedListContent))

    }
    
    @Test 
    func curatedPageWithLinkInAbstractDoesNotRecurse() async throws {
        let catalog = catalog(files: [
            TextFile(name: "Links.md", utf8Content: """
                # Links

                Tests the appearance of inline and linked lists

                ## Overview

                This is an inline link: ``MarkdownSymbol``

                ## Topics

                ### Links with abstracts

                - ``MarkdownSymbol``
                - ``OtherMarkdownSymbol``
                """),
            JSONFile(name: "MarkdownOutput.symbols.json", content: makeSymbolGraph(moduleName: "MarkdownOutput", symbols: [
                makeSymbol(id: "markdown-symbol-id", kind: .struct, pathComponents: ["MarkdownSymbol"], docComment: "A basic symbol to test markdown output. Different to ``OtherMarkdownSymbol``"),
                makeSymbol(id: "other-markdown-symbol-id", kind: .struct, pathComponents: ["OtherMarkdownSymbol"], docComment: "A basic symbol to test markdown output. Different to ``MarkdownSymbol``")
            ]))
        ])
        
        let (node, _) = try await markdownOutput(catalog: catalog, path: "Links")
        let expectedInline = "inline link: [`MarkdownSymbol`](/documentation/MarkdownOutput/MarkdownSymbol)"
        #expect(node.markdown.contains(expectedInline))
        
        let expectedLinkList = "[`MarkdownSymbol`](/documentation/MarkdownOutput/MarkdownSymbol)\n\nA basic symbol to test markdown output. Different to [`OtherMarkdownSymbol`](/documentation/MarkdownOutput/OtherMarkdownSymbol)"
        #expect(node.markdown.contains(expectedLinkList))
    }
    
    @Test
    func curatedSymbolUsesSubheadingAsLinkTitle() async throws {
        let catalog = catalog(files: [
            JSONFile(
                name: "MarkdownOutput.symbols.json",
                content:
                    makeSymbolGraph(
                        moduleName: "MarkdownOutput",
                        symbols: [
                            makeSymbol(id: "markdown-symbol-id", kind: .struct, pathComponents: ["MarkdownSymbol"], docComment: "A basic symbol to test markdown output"),
                            makeSymbol(
                                id: "markdown-symbol-var-id",
                                kind: .property,
                                pathComponents: ["MarkdownSymbol", "property"],
                                docComment: "A property of the symbol",
                                declaration: [
                                    .init(kind: .attribute, spelling: "@objc", preciseIdentifier: nil),
                                    .init(kind: .text, spelling: " ", preciseIdentifier: nil),
                                    .init(kind: .keyword, spelling: "var", preciseIdentifier: nil),
                                    .init(kind: .text, spelling: " ", preciseIdentifier: nil),
                                    .init(kind: .identifier, spelling: "property", preciseIdentifier: nil),
                                    .init(kind: .text, spelling: ": ", preciseIdentifier: nil),
                                    .init(kind: .typeIdentifier, spelling: "Int", preciseIdentifier: "s:Si"),
                                    .init(kind: .text, spelling: " { ", preciseIdentifier: nil),
                                    .init(kind: .keyword, spelling: "get", preciseIdentifier: nil),
                                    .init(kind: .text, spelling: " ", preciseIdentifier: nil),
                                    .init(kind: .keyword, spelling: "set", preciseIdentifier: nil),
                                    .init(kind: .text, spelling: " }", preciseIdentifier: nil),
                                ],
                                subHeading: [
                                    .init(kind: .keyword, spelling: "var", preciseIdentifier: nil),
                                    .init(kind: .text, spelling: " ", preciseIdentifier: nil),
                                    .init(kind: .identifier, spelling: "property", preciseIdentifier: nil),
                                    .init(kind: .text, spelling: ": ", preciseIdentifier: nil),
                                    .init(kind: .typeIdentifier, spelling: "Int", preciseIdentifier: "s:Si"),
                                ]
                            )
                        ],
                        relationships: [
                            .init(source: "markdown-symbol-var-id", target: "markdown-symbol-id", kind: .memberOf, targetFallback: nil),
                        ]
                    )
            )
        ])
        
        let (node, _) = try await markdownOutput(catalog: catalog, path: "MarkdownSymbol")
        #expect(node.markdown.contains("[`var property: Int`](/documentation/MarkdownOutput/MarkdownSymbol/property"))
        #expect(node.markdown.contains("@objc var property: Int { get set }") == false)
    }
    
    @Test
    func linkTitlesAreRetained() async throws {
        let catalog = catalog(files: [
            TextFile(name: "RootDocument.md", utf8Content: """
                # Links
                
                Tests the processing of named links
                
                ## Overview
                
                This is a [named *link*](doc:LinkDestination)
                This is not <doc:LinkDestination>
                
                This is a [named symbol link](doc:MarkdownSymbol)
                This is not <doc:MarkdownSymbol>
                
                This has an empty title [](doc:LinkDestination)
                
                This is a reference link with an empty title [][link-id]
                This is a reference link with a title [title][link-id]
                
                [link-id]: doc:LinkDestination
                """),
            TextFile(name: "LinkDestination.md", utf8Content: """
                # Link Destination
                
                This document title should not replace the specific title in the link
                """),
            JSONFile(name: "MarkdownOutput.symbols.json", content: makeSymbolGraph(moduleName: "MarkdownOutput", symbols: [
                makeSymbol(id: "MarkdownSymbol", kind: .struct, pathComponents: ["MarkdownSymbol"], docComment: "A basic symbol to test markdown output."),
            ]))
        ])
        
        let (node, _) = try await markdownOutput(catalog: catalog, path: "RootDocument")
        
        let expectedLinks = [
            "This is a [named *link*](/documentation/MarkdownOutput/LinkDestination",
            "This is not [Link Destination](/documentation/MarkdownOutput/LinkDestination",
            "This is a [named symbol link](/documentation/MarkdownOutput/MarkdownSymbol",
            "This is not [`MarkdownSymbol`](/documentation/MarkdownOutput/MarkdownSymbol)",
            "This has an empty title [Link Destination](/documentation/MarkdownOutput/LinkDestination",
            "This is a reference link with an empty title [Link Destination](/documentation/MarkdownOutput/LinkDestination)",
            "This is a reference link with a title [title](/documentation/MarkdownOutput/LinkDestination)",
        ]
        
        for expectedLink in expectedLinks {
            #expect(node.markdown.contains(expectedLink))
        }
    }
        
    @Test
    func languageTabOnlyIncludesPrimaryLanguage() async throws {
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
        #expect(node.markdown.contains("I am an Objective-C code block") == false)
        #expect(node.markdown.contains("I am a Swift code block"))
    }
    
    @Test
    func nonLanguageTabIncludesAllEntries() async throws {
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
        #expect(node.markdown.contains("**Left:**\n\nLeft text"))
        #expect(node.markdown.contains("**Right:**\n\nRight text"))
    }
    
    @Test
    func tutorialCodeHasFinalStageOnly() async throws {
        
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
        #expect(node.markdown.contains("// STEP ONE") == false, "Non-final code versions are not included")
        #expect(node.markdown.contains("// STEP TWO") == false, "Non-final code versions are not included")
        let codeIndex = try #require(node.markdown.firstRange(of: "// STEP THREE"), "Final code version is included")
        let step4Index = try #require(node.markdown.firstRange(of: "### Step 4"))
        #expect(codeIndex.lowerBound < step4Index.lowerBound, "Code reference is added after the last step that references it")
        #expect(node.markdown.contains("struct StartCodeAgain {"), "New file reference is included")
    }
    
    @Test
    func snippetCodeIsIncluded() async throws {
        let articleWithSnippet = TextFile(name: "SnippetArticle.md", utf8Content: """
            # Snippets
            
            Here is an article with some snippets
            
            ## Overview
            
            @Snippet(path: "MarkdownOutput/SnippetA")
            
            Post snippet content
            """)
        
        let snippetContent = """
        import Foundation
        // I am a code snippet
        """
        
        let snippet = makeSnippet(pathComponents: ["MarkdownOutput", "SnippetA"], explanation: nil, code: snippetContent)
        let graph = JSONFile(name: "MarkdownOutput.symbols.json", content: makeSymbolGraph(moduleName: "MarkdownOutput", symbols: [snippet]))
        
        let asMarkdown = "```swift\n\(snippetContent)\n```"
        let catalog = catalog(files: [articleWithSnippet, graph])
        let (node, _) = try await markdownOutput(catalog: catalog, path: "SnippetArticle")
        #expect(node.markdown.contains(asMarkdown))
    }
    
    @Test
    func snippetCodeWithSliceOnlyRendersSlice() async throws {
        let articleWithSnippet = TextFile(name: "SnippetArticle.md", utf8Content: """
            # Snippets
            
            Here is an article with some snippets
            
            ## Overview
            
            @Snippet(path: "MarkdownOutput/SnippetA", slice: "sliceOne")
            
            Post snippet content
            """)
        
        let snippetContent = """
        import Foundation
        // I am a code snippet
        
        // snippet.sliceOne
        // I am slice one
        """
        
        let snippet = makeSnippet(pathComponents: ["MarkdownOutput", "SnippetA"], explanation: nil, code: snippetContent, slices: ["sliceOne": 4..<5])
        let graph = JSONFile(name: "MarkdownOutput.symbols.json", content: makeSymbolGraph(moduleName: "MarkdownOutput", symbols: [snippet]))
        
        let catalog = catalog(files: [articleWithSnippet, graph])
        let (node, _) = try await markdownOutput(catalog: catalog, path: "SnippetArticle")
        #expect(node.markdown.contains("// I am slice one"))
        #expect(node.markdown.contains("// I am a code snippet") == false)
    }
    
    @Test
    func snippetCodeDoesNotIncludeHiddenContent() async throws {
        let articleWithSnippet = TextFile(name: "SnippetArticle.md", utf8Content: """
            # Snippets
            
            Here is an article with some snippets
            
            ## Overview
            
            @Snippet(path: "MarkdownOutput/SnippetA", slice: "sliceOne")
            
            Post snippet content
            """)
        
        let snippetContent = """
        import Foundation
        // I am a code snippet
        
        // snippet.hide
        // I am hidden content
        """
        
        let snippet = makeSnippet(pathComponents: ["MarkdownOutput", "SnippetA"], explanation: nil, code: snippetContent)
        let graph = JSONFile(name: "MarkdownOutput.symbols.json", content: makeSymbolGraph(moduleName: "MarkdownOutput", symbols: [snippet]))
        
        let catalog = catalog(files: [articleWithSnippet, graph])
        let (node, _) = try await markdownOutput(catalog: catalog, path: "SnippetArticle")
        #expect(node.markdown.contains("// I am hidden content") == false)
    }
    
    @Test
    func snippetExplanationIsRenderedBeforeCode() async throws {
        let articleWithSnippet = TextFile(name: "SnippetArticle.md", utf8Content: """
            # Snippets
            
            Here is an article with some snippets
            
            ## Overview
            
            @Snippet(path: "MarkdownOutput/SnippetA")
            
            Post snippet content
            """)
        
        let snippetContent = """
        import Foundation
        // I am a code snippet
        """
        
        let explanation = """
        I am the explanatory text.
        I am two lines long.
        """
        let snippet = makeSnippet(pathComponents: ["MarkdownOutput", "SnippetA"], explanation: explanation, code: snippetContent)
        let graph = JSONFile(name: "MarkdownOutput.symbols.json", content: makeSymbolGraph(moduleName: "MarkdownOutput", symbols: [snippet]))
        
        let catalog = catalog(files: [articleWithSnippet, graph])
        let (node, _) = try await markdownOutput(catalog: catalog, path: "SnippetArticle")
        let codeRange = try #require(node.markdown.range(of: snippetContent), "Code not included in snippet output")
        let explanationRange = try #require(node.markdown.range(of: explanation), "Explanation not included in snippet output")
        #expect(explanationRange.lowerBound < codeRange.lowerBound)
    }
      
    private func makeSnippet(
        pathComponents: [String],
        explanation: String?,
        code: String,
        slices: [String: Range<Int>] = [:]
    ) -> SymbolGraph.Symbol {
        makeSymbol(
            id: "$snippet__module-name.\(pathComponents.map { $0.lowercased() }.joined(separator: "."))",
            kind: .snippet,
            pathComponents: pathComponents,
            docComment: explanation,
            otherMixins: [
                SymbolGraph.Symbol.Snippet(
                    language: SourceLanguage.swift.id,
                    lines: code.components(separatedBy: "\n"),
                    slices: slices
                )
            ]
        )
    }
    
    @Test
    func tableWithSpanningCellInLastColumnDoNotCrash() async throws {
        let catalog = catalog(files: [
            // It's the || that causes the problem - there is no issue if there is a space between the characters
            TextFile(name: "DodgyTables.md", utf8Content: """
                # Tables

                Demonstrates how markdown tables that are badly formatted dont crash the export

                ## Overview

                | Parameter | Description |
                |:----------|:------------|
                | `a` | The first parameter |
                | `b` | The second parameter || `c` | The third parameter |
                
                end of the table
                """)
        ])
        
        let (node, _) = try await markdownOutput(catalog: catalog, path: "DodgyTables")
        let expected = """
            # Tables

            Demonstrates how markdown tables that are badly formatted dont crash the export

            ## Overview

            |Parameter|Description         |
            |:--------|:-------------------|
            |`a`      |The first parameter |
            |`b`      |The second parameter|
            
            end of the table
            """
        
        #expect(node.markdown == expected)
    }
        
    @Test
    func imagesUseArchiveRelativePathsForLocalFiles() async throws {
        let catalog = catalog(files: [
            TextFile(name: "ImageArticle.md", utf8Content: """
                # Images
                
                ![Alternative Title](image.png)
                ![](image.png)
                ![Web Image](https://www.example.com/webimage.png)
                ![Unresolved Image](unresolved.png)
                """),
            Folder(name: "Resources") {
                Folder(name: "Images") {
                    DataFile(name: "image.png", data: Data())
                }
            }
        ])
        
        let (node, _) = try await markdownOutput(catalog: catalog, path: "ImageArticle")
        #expect(node.markdown.contains("![Alternative Title](images/MarkdownOutput/image.png"))
        #expect(node.markdown.contains("![](images/MarkdownOutput/image.png"))
        #expect(node.markdown.contains("![Web Image](https://www.example.com/webimage.png)"))
        #expect(node.markdown.contains("![Unresolved Image](unresolved.png)"))
    }
    
    @Test(arguments: 1...10)
    func imagesUseSameVariantOverMultipleRuns(run: Int) async throws {      
        let catalog = catalog(files: [
            TextFile(name: "ImageVariants.md", utf8Content: """
            # Image variants
            
            ![Image Title](image.png)
            """),
            Folder(name: "Resources") {
                Folder(name: "Images") {
                    DataFile(name: "image.png",         data: Data())
                    DataFile(name: "image@2x.png",      data: Data())
                    DataFile(name: "image~dark@2x.png", data: Data())
                    DataFile(name: "image@3x.png",      data: Data())
                    DataFile(name: "image~dark@2x.png", data: Data())
                }
            }
        ])
        
        let (node, _) = try await markdownOutput(catalog: catalog, path: "ImageVariants")
        #expect(node.markdown.contains("![Image Title](images/MarkdownOutput/image.png)"), "Expected to choose the first variant matching in order of DataTraitCollection.allCases.")
    }
    
    @Test
    func asidesAreRenderedLikeSource() async throws {
        let content = """
        # Asides
        
        Shows how asides are represented in markdown output
        
        ## Overview
        
        Here is some content
        
        > Tip: This is an aside
        
        Here is some post-aside content
        """
        let catalog = catalog(files: [
            TextFile(name: "AsideArticle.md", utf8Content: content)
        ])
        
        let (node, _) = try await markdownOutput(catalog: catalog, path: "AsideArticle")
        #expect(node.markdown == content)
    }
    
    @Test
    func rawHTMLBlocksAndCommentsAreRemoved() async throws {
        let catalog = catalog(files: [
            TextFile(name: "Comments.md", utf8Content: """
                # Comments

                Showing how comments are removed from the markdown export

                ## Overview

                @Comment {
                    COMMENT CONTENT 1
                }
                
                This text is fine
                
                <!-- COMMENT CONTENT 2 -->
                
                Comments in code blocks should be kept
                
                ```
                <h1>Text in a code block HTML</h1>
                <!-- COMMENT CONTENT 3 -->
                ```
                
                Raw HTML in the body should not be kept
                                
                <h1>More Complex example</h1>

                <!-- COMMENT CONTENT 4 -->

                <p>This paragraph is invisible.</p>

                <!--
                  COMMENT CONTENT 5
                  COMMENT CONTENT 6
                -->

                <p>This paragraph is also invisible. <!-- COMMENT CONTENT 7 --></p>
                
                Inline HTML is <em>EMPHASISED</em> stripped of tags
                """)
        ])
        
        let (node, _) = try await markdownOutput(catalog: catalog, path: "Comments")
        let markdown = node.markdown
        #expect(markdown.contains("COMMENT CONTENT 1") == false)
        #expect(markdown.contains("COMMENT CONTENT 2") == false)
        #expect(markdown.contains("COMMENT CONTENT 4") == false)
        #expect(markdown.contains("COMMENT CONTENT 5") == false)
        #expect(markdown.contains("COMMENT CONTENT 6") == false)
        #expect(markdown.contains("COMMENT CONTENT 7") == false)
        #expect(markdown.contains("More Complex example") == false)
        #expect(markdown.contains("This paragraph is invisible") == false)
        #expect(markdown.contains("This paragraph is also invisible") == false)
        #expect(markdown.contains("COMMENT CONTENT 3"))
        #expect(markdown.contains("Text in a code block HTML"))
        #expect(markdown.contains("Inline HTML is EMPHASISED stripped of tags"))
    }
    
    @Test
    func termListRemovesTermNotation() async throws {
        let catalog = catalog(files: [
            TextFile(name: "TermList.md", utf8Content: """
                # Term Lists
                                
                - term Spring: The first season of the year 
                - term Summer: The second season of the year
                - term `Code`: A code voice item used as a term
                """)
        ])

        let (node, _) = try await markdownOutput(catalog: catalog, path: "TermList")
        let expectedList = """
        - Spring: The first season of the year
        - Summer: The second season of the year
        - `Code`: A code voice item used as a term
        """
        #expect(node.markdown.contains(expectedList))
    }
    
    @Test
    func protocolRelationshipsIncludedInExport() async throws {
        let catalog = catalog(files: [
            JSONFile(name: "MarkdownOutput.symbols.json", content:
                    makeSymbolGraph(
                        moduleName: "MarkdownOutput",
                        symbols: [
                            makeSymbol(id: "local-conformer-id", kind: .struct, pathComponents: ["LocalConformer"]),
                            makeSymbol(id: "local-protocol-id", kind: .protocol, pathComponents: ["LocalProtocol"]),
                        ],
                        relationships: [
                            SymbolGraph.Relationship(source: "local-conformer-id", target: "local-protocol-id", kind: .conformsTo, targetFallback: nil),
                            SymbolGraph.Relationship(source: "local-conformer-id", target: "s:SH", kind: .conformsTo, targetFallback: "Swift.Hashable")
                        ]
                    ))
        ])
        
        let (conformerNode, _) = try await markdownOutput(catalog: catalog, path: "LocalConformer")
        let conformerMarkdown = conformerNode.markdown
        #expect(conformerMarkdown.contains(RelationshipsGroup(kind: .conformsTo, destinations: []).sectionTitle))
        let localProtocolLink = "\n[`LocalProtocol`](/documentation/MarkdownOutput/LocalProtocol)"
        #expect(conformerMarkdown.contains(localProtocolLink))
        let externalProtocolLink = "\n[`Hashable`](/documentation/Swift/Hashable)"
        #expect(conformerMarkdown.contains(externalProtocolLink) == false)
        #expect(conformerMarkdown.contains("\n`Swift.Hashable`"))
        
        let (protocolNode, _) = try await markdownOutput(catalog: catalog, path: "LocalProtocol")
        let protocolMarkdown = protocolNode.markdown
        #expect(protocolMarkdown.contains(RelationshipsGroup(kind: .conformingTypes, destinations: []).sectionTitle))
        let conformerLink = "\n[`LocalConformer`](/documentation/MarkdownOutput/LocalConformer)"
        #expect(protocolMarkdown.contains(conformerLink))
    }
        
    @Test
    func inheritanceRelationshipsIncludedInExport() async throws {
        let catalog = catalog(files: [
            JSONFile(name: "MarkdownOutput.symbols.json", content:
                    makeSymbolGraph(
                        moduleName: "MarkdownOutput",
                        symbols: [
                            makeSymbol(id: "local-superclass-id", kind: .class, pathComponents: ["LocalSuper"]),
                            makeSymbol(id: "local-subclass-id", kind: .class, pathComponents: ["LocalSub"]),
                        ],
                        relationships: [
                            SymbolGraph.Relationship(source: "local-subclass-id", target: "local-superclass-id", kind: .inheritsFrom, targetFallback: nil),
                        ]
                    ))
        ])
        
        let (inheritorNode, _) = try await markdownOutput(catalog: catalog, path: "LocalSub")
        let inheritorMarkdown = inheritorNode.markdown
        #expect(inheritorMarkdown.contains(RelationshipsGroup(kind: .inheritsFrom, destinations: []).sectionTitle))
        let superclassLink = "\n[`LocalSuper`](/documentation/MarkdownOutput/LocalSuper)"
        #expect(inheritorMarkdown.contains(superclassLink))
        
        let (superclassNode, _) = try await markdownOutput(catalog: catalog, path: "LocalSuper")
        let superclassMarkdown = superclassNode.markdown
        #expect(superclassMarkdown.contains(RelationshipsGroup(kind: .inheritedBy, destinations: []).sectionTitle))
        let subclassLink = "\n[`LocalSub`](/documentation/MarkdownOutput/LocalSub)"
        #expect(superclassMarkdown.contains(subclassLink))
    }
     
    @Test
    func sectionsThatAreEmptyAfterFilteringDoNotHaveHeadingsAdded() async throws {
        let catalog = catalog(files: [
            JSONFile(
                name: "MarkdownOutput.symbols.json",
                content: makeSymbolGraph(
                    moduleName: "MarkdownOutput",
                    symbols: [
                        makeSymbol(id: "markdown-symbol-id", kind: .struct, pathComponents: ["MarkdownSymbol"], docComment: """
                            Abstract.
                                                        
                            The next heading will appear in the output as it does not imply a `Section` in the document so is just markdown content. The last two headings should not appear, because they are `Section`s, but have no section content.
                            
                            ## Random heading
                            
                            ## Topics
                            
                            ## See Also
                            
                            @Comment {
                                This should be removed, but should not lead to a See Also heading.
                            }
                            """),
                        makeSymbol(id: "markdown-symbol-my-function-id", kind: .method, pathComponents: ["MarkdownSymbol", "myFunction(_:)"], docComment: """
                    Everything is described in the abstract.

                    - Parameters:
                      - arg: The first argument.

                    @Comment {
                        This should be removed, but should not lead to a discussion heading.
                    }
                    """),
                        // A symbol with no children, so that no automatic curation is added to it.
                        makeSymbol(id: "childless-symbol-id", kind: .struct, pathComponents: ["ChildlessSymbol"], docComment: """
                            Abstract.

                            These headings are `Section`s with no content, so they should not appear.

                            ## Topics

                            ## See Also
                            """)
                    ],
                    relationships: [
                        .init(source: "markdown-symbol-my-function-id", target: "markdown-symbol-id", kind: .memberOf, targetFallback: nil)
                    ]
            ))
        ])
        let (functionNode, _) = try await markdownOutput(catalog: catalog, path: "MarkdownSymbol/myFunction(_:)")
        #expect(functionNode.markdown.contains("## Parameters"))
        #expect(functionNode.markdown.contains("## Discussion") == false)

        let (structNode, _) = try await markdownOutput(catalog: catalog, path: "MarkdownSymbol")
        #expect(structNode.markdown.contains("## Overview"))
        #expect(structNode.markdown.contains("## Random heading"))
        #expect(structNode.markdown.contains("## See Also") == false)

        // `MarkdownSymbol` has a member, so its "Topics" section is filled in by automatic curation. A symbol with no
        // children has nothing to curate, so its empty authored section is not given a heading.
        let (childlessNode, _) = try await markdownOutput(catalog: catalog, path: "ChildlessSymbol")
        #expect(childlessNode.markdown.contains("## Topics") == false)
        #expect(childlessNode.markdown.contains("## See Also") == false)
    }
    
    // MARK: - Automatic curation

    // The render JSON equivalent of this test is `AutomaticCurationTests.testAutomaticTopicsGenerationForSameModuleTypes`,
    // which asserts that uncurated members appear in generated `topicSections` named after their symbol kind.
    // The group order matches `AutomaticCuration.groupKindOrder`.
    @Test
    func automaticTopicGroupsAreIncludedForSymbols() async throws {
        let catalog = catalog(files: [
            JSONFile(name: "MarkdownOutput.symbols.json", content: makeSymbolGraph(
                moduleName: "MarkdownOutput",
                symbols: [
                    makeSymbol(id: "some-class-id", kind: .class, pathComponents: ["SomeClass"], docComment: "A class with members that aren't manually curated."),
                    makeSymbol(id: "some-init-id", kind: .`init`, pathComponents: ["SomeClass", "init()"], docComment: "The initializer abstract."),
                    makeSymbol(id: "some-property-id", kind: .property, pathComponents: ["SomeClass", "someProperty"], docComment: "The property abstract."),
                    makeSymbol(id: "some-method-id", kind: .method, pathComponents: ["SomeClass", "someMethod()"], docComment: "The method abstract."),
                ],
                relationships: [
                    .init(source: "some-init-id", target: "some-class-id", kind: .memberOf, targetFallback: nil),
                    .init(source: "some-property-id", target: "some-class-id", kind: .memberOf, targetFallback: nil),
                    .init(source: "some-method-id", target: "some-class-id", kind: .memberOf, targetFallback: nil),
                ]
            ))
        ])

        let (node, _) = try await markdownOutput(catalog: catalog, path: "SomeClass")
        let markdown = node.markdown

        #expect(markdown.contains("## Topics"))

        // Each member is curated in a generated group named after its symbol kind.
        let initializersHeading = try #require(markdown.range(of: "### \(AutomaticCuration.groupTitle(for: .`init`))"))
        let propertiesHeading = try #require(markdown.range(of: "### \(AutomaticCuration.groupTitle(for: .property))"))
        let methodsHeading = try #require(markdown.range(of: "### \(AutomaticCuration.groupTitle(for: .method))"))

        // The groups are ordered by `AutomaticCuration.groupKindOrder`: initializers, then properties, then methods.
        #expect(initializersHeading.lowerBound < propertiesHeading.lowerBound)
        #expect(propertiesHeading.lowerBound < methodsHeading.lowerBound)

        // Each group links to its member and displays that member's abstract, like an authored link list does.
        #expect(markdown.contains("/documentation/MarkdownOutput/SomeClass/init()"))
        #expect(markdown.contains("The initializer abstract."))

        #expect(markdown.contains("/documentation/MarkdownOutput/SomeClass/someProperty"))
        #expect(markdown.contains("The property abstract."))

        #expect(markdown.contains("/documentation/MarkdownOutput/SomeClass/someMethod()"))
        #expect(markdown.contains("The method abstract."))
    }

    // The render JSON equivalent is `RenderNodeTranslatorTests.testAutomaticTaskGroupsOrderingInSymbols`,
    // which asserts that the authored task groups are listed before the generated ones.
    @Test
    func automaticTopicGroupsFollowAuthoredTopicGroups() async throws {
        let catalog = catalog(files: [
            JSONFile(name: "MarkdownOutput.symbols.json", content: makeSymbolGraph(
                moduleName: "MarkdownOutput",
                symbols: [
                    makeSymbol(id: "some-class-id", kind: .class, pathComponents: ["SomeClass"], docComment: "A class with a mix of manual and automatic curation."),
                    makeSymbol(id: "curated-method-id", kind: .method, pathComponents: ["SomeClass", "curatedMethod()"], docComment: "The manually curated method."),
                    makeSymbol(id: "uncurated-property-id", kind: .property, pathComponents: ["SomeClass", "uncuratedProperty"], docComment: "The uncurated property."),
                ],
                relationships: [
                    .init(source: "curated-method-id", target: "some-class-id", kind: .memberOf, targetFallback: nil),
                    .init(source: "uncurated-property-id", target: "some-class-id", kind: .memberOf, targetFallback: nil),
                ]
            )),
            TextFile(name: "SomeClass.md", utf8Content: """
                # ``MarkdownOutput/SomeClass``

                Curate one member manually and leave the other to automatic curation.

                ## Topics

                ### Basics

                - ``curatedMethod()``
                """)
        ])

        let (node, _) = try await markdownOutput(catalog: catalog, path: "SomeClass")
        let markdown = node.markdown

        // A single `## Topics` heading covers both the authored and the generated groups.
        #expect(markdown.components(separatedBy: "## Topics").count - 1 == 1)

        let authoredHeading = try #require(markdown.range(of: "### Basics"))
        let generatedHeading = try #require(markdown.range(of: "### \(AutomaticCuration.groupTitle(for: .property))"))
        #expect(authoredHeading.lowerBound < generatedHeading.lowerBound)
    }

    // The render JSON equivalent is `AutomaticCurationTests.testAutomaticTopicsSkippingCustomCuratedSymbols`,
    // which asserts that manually curated members are not curated a second time by automatic curation.
    @Test
    func manuallyCuratedMembersAreNotAutomaticallyCurated() async throws {
        let catalog = catalog(files: [
            JSONFile(name: "MarkdownOutput.symbols.json", content: makeSymbolGraph(
                moduleName: "MarkdownOutput",
                symbols: [
                    makeSymbol(id: "some-class-id", kind: .class, pathComponents: ["SomeClass"], docComment: "A class where every member is manually curated."),
                    makeSymbol(id: "first-method-id", kind: .method, pathComponents: ["SomeClass", "firstMethod()"], docComment: "The first method."),
                    makeSymbol(id: "second-method-id", kind: .method, pathComponents: ["SomeClass", "secondMethod()"], docComment: "The second method."),
                ],
                relationships: [
                    .init(source: "first-method-id", target: "some-class-id", kind: .memberOf, targetFallback: nil),
                    .init(source: "second-method-id", target: "some-class-id", kind: .memberOf, targetFallback: nil),
                ]
            )),
            TextFile(name: "SomeClass.md", utf8Content: """
                # ``MarkdownOutput/SomeClass``

                Curate one of the two members manually.

                ## Topics

                ### Basics

                - ``firstMethod()``
                """)
        ])

        let (node, _) = try await markdownOutput(catalog: catalog, path: "SomeClass")
        let markdown = node.markdown

        // The manually curated member is listed once, under the authored group only.
        #expect(markdown.components(separatedBy: "/documentation/MarkdownOutput/SomeClass/firstMethod()").count - 1 == 1)

        // The uncurated member is automatically curated.
        #expect(markdown.contains("/documentation/MarkdownOutput/SomeClass/secondMethod()"))
    }

    // Articles that aren't manually curated are collected into an "Articles" task group with a `.top`
    // render position preference. See `DocumentationContext.autoCurateArticles(_:startingFrom:)`, and the
    // render JSON equivalent `AutomaticCurationTests.testAutomaticallyCuratedArticlesAreSortedByTitle`.
    @Test
    func automaticArticleGroupIsIncludedForModulePage() async throws {
        let catalog = catalog(files: [
            JSONFile(name: "MarkdownOutput.symbols.json", content: makeSymbolGraph(
                moduleName: "MarkdownOutput",
                symbols: [
                    makeSymbol(id: "some-struct-id", kind: .struct, pathComponents: ["SomeStruct"], docComment: "A top level symbol."),
                ]
            )),
            TextFile(name: "UncuratedArticle.md", utf8Content: """
                # An Uncurated Article

                This article isn't curated anywhere, so it's automatically curated under the module.
                """)
        ])

        let (node, _) = try await markdownOutput(catalog: catalog, path: "/documentation/MarkdownOutput")
        let markdown = node.markdown

        #expect(markdown.contains("## Topics"))

        // The "Articles" group is placed before the generated symbol-kind groups.
        let articlesHeading = try #require(markdown.range(of: "### Articles"))
        let structuresHeading = try #require(markdown.range(of: "### \(AutomaticCuration.groupTitle(for: .struct))"))
        #expect(articlesHeading.lowerBound < structuresHeading.lowerBound)

        #expect(markdown.contains("/documentation/MarkdownOutput/UncuratedArticle"))
        #expect(markdown.contains("/documentation/MarkdownOutput/SomeStruct"))
    }

    // Default implementations are collected into a generated "<Protocol> Implementations" API collection page
    // by `GeneratedDocumentationTopics.createInheritedSymbolsAPICollections(relationships:context:)`. That page is an
    // article whose members come from `automaticTaskGroups`. The render JSON equivalent is
    // `RenderNodeTranslatorTests.testOrderingOfAutomaticGroupsInDefiningProtocol`.
    @Test
    func automaticTopicGroupsAreIncludedForGeneratedAPICollections() async throws {
        var inheritedMemberRelationship = SymbolGraph.Relationship(
            source: "conformer-method-id",
            target: "conformer-id",
            kind: .memberOf,
            targetFallback: nil
        )
        inheritedMemberRelationship.mixins["sourceOrigin"] = SymbolGraph.Relationship.SourceOrigin(
            identifier: "protocol-method-id",
            displayName: "SomeProtocol.someMethod()"
        )

        let catalog = catalog(files: [
            JSONFile(name: "MarkdownOutput.symbols.json", content: makeSymbolGraph(
                moduleName: "MarkdownOutput",
                symbols: [
                    makeSymbol(id: "protocol-id", kind: .protocol, pathComponents: ["SomeProtocol"], docComment: "A protocol with a default implementation."),
                    makeSymbol(id: "protocol-method-id", kind: .method, pathComponents: ["SomeProtocol", "someMethod()"], docComment: "The protocol requirement."),
                    makeSymbol(id: "conformer-id", kind: .struct, pathComponents: ["Conformer"], docComment: "A type that conforms to the protocol."),
                    // The inherited member needs Swift extension information for it to be collected into an API collection.
                    makeSymbol(
                        id: "conformer-method-id",
                        kind: .method,
                        pathComponents: ["Conformer", "someMethod()"],
                        docComment: "The inherited default implementation.",
                        otherMixins: [
                            SymbolGraph.Symbol.Swift.Extension(extendedModule: "MarkdownOutput", typeKind: .struct, constraints: [])
                        ]
                    ),
                ],
                relationships: [
                    .init(source: "protocol-method-id", target: "protocol-id", kind: .requirementOf, targetFallback: nil),
                    .init(source: "conformer-id", target: "protocol-id", kind: .conformsTo, targetFallback: nil),
                    inheritedMemberRelationship,
                ]
            ))
        ])

        // The conforming type links to the generated collection under a "Default Implementations" group.
        let (conformerNode, _) = try await markdownOutput(catalog: catalog, path: "Conformer")
        #expect(conformerNode.markdown.contains("### Default Implementations"))
        #expect(conformerNode.markdown.contains("/documentation/MarkdownOutput/Conformer/SomeProtocol-Implementations"))

        // The generated collection page lists the inherited member.
        let (collectionNode, _) = try await markdownOutput(catalog: catalog, path: "Conformer/SomeProtocol-Implementations")
        #expect(collectionNode.markdown.contains("## Topics"))
        #expect(collectionNode.markdown.contains("### \(AutomaticCuration.groupTitle(for: .method))"))
        #expect(collectionNode.markdown.contains("/documentation/MarkdownOutput/Conformer/someMethod()"))
    }

    // Automatically curated members produce the same `belongsToTopic` manifest relationships as manually
    // curated ones do in `manifestIncludesRelationshipsForCuratedPages`, anchored on the generated group's heading.
    @Test
    func automaticTopicGroupsPopulateManifestRelationships() async throws {
        let catalog = catalog(files: [
            JSONFile(name: "MarkdownOutput.symbols.json", content: makeSymbolGraph(
                moduleName: "MarkdownOutput",
                symbols: [
                    makeSymbol(id: "some-class-id", kind: .class, pathComponents: ["SomeClass"], docComment: "A class with an uncurated member."),
                    makeSymbol(id: "some-method-id", kind: .method, pathComponents: ["SomeClass", "someMethod()"], docComment: "The method abstract."),
                ],
                relationships: [
                    .init(source: "some-method-id", target: "some-class-id", kind: .memberOf, targetFallback: nil),
                ]
            ))
        ])

        let (_, manifest) = try await markdownOutput(catalog: catalog, path: "SomeClass")

        let expected = MarkdownOutputManifest.Relationship(
            sourceIdentifier: "/documentation/MarkdownOutput/SomeClass/someMethod()",
            relationshipType: .belongsToTopic,
            targetIdentifier: "/documentation/MarkdownOutput/SomeClass#Instance-Methods"
        )
        #expect(manifest.relationships.contains(expected))
    }

    // Render JSON merges a generated group into an authored section with the same title (rdar://61899214).
    // The markdown output is built as a linear string, so it emits a separate group with the same heading instead.
    // Both groups anchor to the same fragment, so manifest relationships are unaffected.
    // The render JSON behavior is covered by
    // `AutomaticCurationTests.testAutomaticallyCuratedSymbolTopicsAreMergedWithManuallyCuratedTopics`.
    @Test
    func automaticGroupWithSameTitleAsAuthoredGroupIsEmittedSeparately() async throws {
        let topicSectionTitle = AutomaticCuration.groupTitle(for: .method)

        let catalog = catalog(files: [
            JSONFile(name: "MarkdownOutput.symbols.json", content: makeSymbolGraph(
                moduleName: "MarkdownOutput",
                symbols: [
                    makeSymbol(id: "some-class-id", kind: .class, pathComponents: ["SomeClass"], docComment: "A class with an authored section that collides with a generated one."),
                    makeSymbol(id: "some-method-id", kind: .method, pathComponents: ["SomeClass", "someMethod()"], docComment: "The uncurated method."),
                ],
                relationships: [
                    .init(source: "some-method-id", target: "some-class-id", kind: .memberOf, targetFallback: nil),
                ]
            )),
            TextFile(name: "SomeArticle.md", utf8Content: """
                # Some Article

                An article curated under a section named after a symbol kind.
                """),
            TextFile(name: "SomeClass.md", utf8Content: """
                # ``MarkdownOutput/SomeClass``

                Curate an article under a section whose title matches a generated group's title.

                ## Topics

                ### \(topicSectionTitle)

                - <doc:SomeArticle>
                """)
        ])

        let (node, _) = try await markdownOutput(catalog: catalog, path: "SomeClass")
        let markdown = node.markdown

        // Unlike render JSON, the two groups are not merged into one section.
        #expect(markdown.components(separatedBy: "### \(topicSectionTitle)").count - 1 == 2)

        // Both the manually curated article and the automatically curated member are listed.
        #expect(markdown.contains("/documentation/MarkdownOutput/SomeArticle"))
        #expect(markdown.contains("/documentation/MarkdownOutput/SomeClass/someMethod()"))
    }

    // MARK: - Metadata

    @Test
    func metadataForArticleHasArticleTypeAndRole() async throws {
        let catalog = catalog(files: [
            TextFile(name: "ArticleRole.md", utf8Content: """
                # Article Role
                
                This article will have the correct document type and role
                
                ## Overview
                
                Content
                """)
        ])
        let (node, _) = try await markdownOutput(catalog: catalog, path: "ArticleRole")
        #expect(node.metadata.documentType == .article)
        #expect(node.metadata.role == RenderMetadata.Role.article.rawValue)
        #expect(node.metadata.title == "Article Role")
        #expect(node.metadata.identifier == "/documentation/MarkdownOutput/ArticleRole")
        #expect(node.metadata.framework == "MarkdownOutput")
    }
    
    @Test
    func apiCollectionHasCollectionGroupRole() async throws {
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
        #expect(node.metadata.role == RenderMetadata.Role.collectionGroup.rawValue)
    }
        
    @Test
    func articleAvailabilityIsRepresentedInMetadata() async throws {
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
        #expect(node.metadata.availability(for: "Xcode")?.introduced == "14.3.0")
        #expect(node.metadata.availability(for: "macOS")?.introduced == "13.0.0")
    }
    
    @Test
    func symbolDocumentHasSymbolType() async throws {
        let catalog = catalog(files: [
            JSONFile(name: "MarkdownOutput.symbols.json", content: makeSymbolGraph(moduleName: "MarkdownOutput", symbols: [
                makeSymbol(id: "markdown-symbol-id", kind: .struct, pathComponents: ["MarkdownSymbol"], docComment: "A basic symbol to test markdown output")
            ]))
        ])
        let (node, _) = try await markdownOutput(catalog: catalog, path: "MarkdownSymbol")
        #expect(node.metadata.documentType == .symbol)
    }
    
    @Test
    func symbolDocumentPopulatesMetadata() async throws {
        let catalog = catalog(files: [
            JSONFile(name: "MarkdownOutput.symbols.json", content: makeSymbolGraph(moduleName: "MarkdownOutput", symbols: [
                makeSymbol(id: "markdown-symbol-id", kind: .struct, pathComponents: ["MarkdownSymbol"], docComment: "A basic symbol to test markdown output"),
                makeSymbol(id: "markdown-symbol-init-name-id", kind: .`init`, pathComponents: ["MarkdownSymbol", "init(name:)"])
            ]))
        ])
        let (node, _) = try await markdownOutput(catalog: catalog, path: "MarkdownSymbol/init(name:)")
        #expect(node.metadata.title == "init(name:)")
        #expect(node.metadata.symbol?.kindDisplayName == "Initializer")
        #expect(node.metadata.role == "Initializer")
        #expect(node.metadata.symbol?.modules == ["MarkdownOutput"])
    }
        
    @Test
    func symbolExtendedModulePopulatesMetadata() async throws {
        let catalog = catalog(files: [
            JSONFile(name: "MarkdownOutput.symbols.json", content: makeSymbolGraph(moduleName: "MarkdownOutput", symbols: [
                makeSymbol(id: "array-asdf-id", kind: .property, pathComponents: ["Swift", "Array", "asdf"], otherMixins: [SymbolGraph.Symbol.Swift.Extension(extendedModule: "Swift", constraints: [])])
                ])
             )
        ])
        let (node, _) = try await markdownOutput(catalog: catalog, path: "Swift/Array/asdf")
        #expect(node.metadata.symbol?.modules == ["MarkdownOutput", "Swift"])
    }
    
    private let iOSPlatform = SymbolGraph.Platform(operatingSystem: .init(name: "ios"))
    private let macOSPlatform = SymbolGraph.Platform(operatingSystem: .init(name: "macosx"))
    
    @Test
    func symbolMetadataGetsDefaultAvailability() async throws {
        let catalog = catalog(files: [
            JSONFile(name: "MarkdownOutput.symbols.json", content: makeSymbolGraph(moduleName: "MarkdownOutput", platform: iOSPlatform, symbols: [
                makeSymbol(id: "markdown-symbol-id", kind: .struct, pathComponents: ["MarkdownSymbol"], docComment: "A basic symbol to test markdown output")
            ])),
            InfoPlist(defaultAvailability: [
                "MarkdownOutput" : [.init(platformName: .iOS, platformVersion: "1.0.0")]
            ])
        ])
        let (node, _) = try await markdownOutput(catalog: catalog, path: "MarkdownSymbol")
        let availability = try #require(node.metadata.availability)
        #expect(availability.contains(.init(platform: "iOS", introduced: "1.0.0", deprecated: nil, unavailable: false)))
    }
    
    @Test
    func symbolMetadataGetsSymbolLevelAvailability() async throws {
        let catalog = catalog(files: [
            JSONFile(name: "MarkdownOutput.symbols.json", content: makeSymbolGraph(moduleName: "MarkdownOutput", platform: iOSPlatform, symbols: [
                makeSymbol(id: "markdown-symbol-id", kind: .struct, pathComponents: ["MarkdownSymbol"], docComment: "A basic symbol to test markdown output", availability: [.init(domainName: "iOS", introduced: .init(string: "2.0.0"), deprecated: nil)])
            ])),
            InfoPlist(defaultAvailability: [
                "MarkdownOutput" : [.init(platformName: .iOS, platformVersion: "1.0.0")]
            ])
        ])
        let (node, _) = try await markdownOutput(catalog: catalog, path: "MarkdownSymbol")
        let availability = try #require(node.metadata.availability)
        #expect(availability.contains(.init(platform: "iOS", introduced: "2.0.0", deprecated: nil, unavailable: false)))
    }
    
    @Test
    func symbolAvailabilityIsCapturedFromMetadataBlock() async throws {
        let catalog = catalog(files: [
            JSONFile(name: "MarkdownOutput.symbols.json", content: makeSymbolGraph(moduleName: "MarkdownOutput", platform: iOSPlatform, symbols: [
                makeSymbol(id: "markdown-symbol-id", kind: .struct, pathComponents: ["MarkdownSymbol"], docComment: "A basic symbol to test markdown output")
            ])),
            InfoPlist(defaultAvailability: [
                "MarkdownOutput" : [.init(platformName: .iOS, platformVersion: "1.0.0")]
            ]),
            TextFile(name: "MarkdownSymbol.md", utf8Content: """
                # ``MarkdownSymbol``
                
                @Metadata {
                    @Available(iOS, introduced: "13.1")
                }
                
                A basic symbol to test markdown output
                
                ## Overview
                
                Overview goes here
                """)
        ])
        let (node, _) = try await markdownOutput(catalog: catalog, path: "MarkdownSymbol")
        let availability = try #require(node.metadata.availability)
        let expected = MarkdownOutputNode.Metadata.Availability(platform: "iOS", introduced: "13.1.0", deprecated: nil, unavailable: false)
        #expect(availability.contains(expected))
    }
    
    @Test
    func symbolAvailabilityOnePlatformDoesntUseDefaults() async throws {
        // A symbol that only exists in the macOS graph should not show as available on iOS.
        let catalog = catalog(files: [
            JSONFile(
                name: "MarkdownOutput-macOS.symbols.json",
                content: makeSymbolGraph(
                    moduleName: "MarkdownOutput",
                    platform: macOSPlatform,
                    symbols: [
                        makeSymbol(
                            id: "markdown-symbol-id",
                            kind: .struct,
                            pathComponents: ["MarkdownSymbol"],
                            docComment: "A basic symbol to test markdown output"
                        )
                    ]
                )),
            JSONFile(
                name: "MarkdownOutput-iOS.symbols.json",
                content: makeSymbolGraph(
                    moduleName: "MarkdownOutput",
                    platform: iOSPlatform,
                    symbols: []
                )),
            InfoPlist(defaultAvailability: [
                "MarkdownOutput" : [
                    .init(platformName: .iOS, platformVersion: "1.0.0"),
                    .init(platformName: .macOS, platformVersion: "1.0.0"),
                ]
            ]),
        ])
        
        let (node, _) = try await markdownOutput(catalog: catalog, path: "MarkdownSymbol")
        let availability = try #require(node.metadata.availability)
        #expect(availability.count == 1)
        #expect(availability.first?.platform == "macOS")
    }
    
    @Test(arguments: [
        ("iOS: 14.0", MarkdownOutputNode.Metadata.Availability(platform: "iOS", introduced: "14.0", deprecated: nil, unavailable: false)),
        ("iOS: 14.0 - 15.0", MarkdownOutputNode.Metadata.Availability(platform: "iOS", introduced: "14.0", deprecated: "15.0", unavailable: false)),
        ("iOS: -", MarkdownOutputNode.Metadata.Availability(platform: "iOS", introduced: nil, deprecated: nil, unavailable: true)),
        ("iOS: 14.0 -", MarkdownOutputNode.Metadata.Availability(platform: "iOS", introduced: "14.0", unavailable: false)),
    ])
    func availabilityFromStringRepresentation(_ representation: String, _ expected: MarkdownOutputNode.Metadata.Availability) async throws {
        let availability = MarkdownOutputNode.Metadata.Availability(stringRepresentation: representation)
        #expect(availability == expected)
    }
 
    @Test(arguments: [
        (MarkdownOutputNode.Metadata.Availability(platform: "iOS", introduced: "14.0", unavailable: false), "iOS: 14.0 -"),
        (MarkdownOutputNode.Metadata.Availability(platform: "iOS", introduced: "14.0", deprecated: "15.0", unavailable: false), "iOS: 14.0 - 15.0"),
        (MarkdownOutputNode.Metadata.Availability(platform: "iOS", unavailable: true), "iOS: -"),
        (MarkdownOutputNode.Metadata.Availability(platform: "iOS", introduced: "", unavailable: false), "iOS: -"),
    ])
    func stringRepresentationFromAvailability(_ availability: MarkdownOutputNode.Metadata.Availability, _ expected: String) async throws {
        #expect(availability.stringRepresentation == expected)
    }
    
    @Test
    func symbolDeprecationRepresentedInMetadata() async throws {
        let catalog = catalog(files: [
            JSONFile(name: "MarkdownOutput.symbols.json", content: makeSymbolGraph(moduleName: "MarkdownOutput", symbols: [
                makeSymbol(id: "markdown-symbol-id", kind: .struct, pathComponents: ["MarkdownSymbol"], docComment: "A basic symbol to test markdown output"),
                makeSymbol(
                    id: "markdown-symbol_full-name-id",
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
        let availability = try #require(node.metadata.availability(for: "iOS"))
        #expect(availability.introduced == "1.0.0")
        #expect(availability.deprecated == "4.0.0")
        #expect(availability.unavailable == false)
        
        let macAvailability = try #require(node.metadata.availability(for: "macOS"))
        #expect(macAvailability.introduced == "2.0.0")
        #expect(macAvailability.deprecated == "4.0.0")
        #expect(macAvailability.unavailable == false)
        
        let visionAvailability = try #require(node.metadata.availability(for: "visionOS"))
        #expect(visionAvailability.unavailable)
    }
    
    
    @Test
    func symbolIdentifierMatchesSymbolGraph() async throws {
        let catalog = catalog(files: [
            JSONFile(name: "MarkdownOutput.symbols.json", content: makeSymbolGraph(moduleName: "MarkdownOutput", symbols: [
                makeSymbol(id: "markdown-symbol-id", kind: .struct, pathComponents: ["MarkdownSymbol"], docComment: "A basic symbol to test markdown output"),
            ]))
        ])
        
        let (node, _) = try await markdownOutput(catalog: catalog, path: "MarkdownSymbol")
        #expect(node.metadata.symbol?.preciseIdentifier == "markdown-symbol-id")
    }
    
    @Test
    func tutorialPopulatesMetadata() async throws {
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
        #expect(node.metadata.documentType == .tutorial)
        #expect(node.metadata.title == "Tutorial Title")
    }
          
    // MARK: - Encoding / Decoding
    @Test
    func markdownSurvivesCodingRoundTrip() async throws {
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
                makeSymbol(id: "markdown-symbol-id", kind: .struct, pathComponents: ["MarkdownSymbol"], docComment: "A basic symbol to test markdown output")
            ]))
        ])
        
        let (node, _) = try await markdownOutput(catalog: catalog, path: "MarkdownSymbol")
        let data = try node.generateDataRepresentation()
        let fromData = try MarkdownOutputNode(data)
        #expect(node.markdown == fromData.markdown)
        #expect(node.metadata.identifier == fromData.metadata.identifier)
    }
    
    // MARK: - Manifest
    @Test 
    func manifestIncludesRelationshipsForCuratedPages() async throws {
        
        let catalog = catalog(files: [
            JSONFile(name: "MarkdownOutput.symbols.json", content: makeSymbolGraph(moduleName: "MarkdownOutput", symbols: [
                makeSymbol(id: "markdown-symbol-id", kind: .struct, pathComponents: ["MarkdownSymbol"], docComment: "A basic symbol to test markdown output"),
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
            sourceIdentifier: "/documentation/MarkdownOutput/RowsAndColumns",
            relationshipType: .belongsToTopic,
            targetIdentifier: "/documentation/MarkdownOutput/Links#Links-with-abstracts"
        )
        
        let symbol = MarkdownOutputManifest.Relationship(
            sourceIdentifier: "/documentation/MarkdownOutput/MarkdownSymbol",
            relationshipType: .belongsToTopic,
            targetIdentifier: "/documentation/MarkdownOutput/Links#Links-with-abstracts"
        )
        
        #expect(manifest.relationships.contains(rows))
        #expect(manifest.relationships.contains(symbol))
    }
        
    @Test
    func symbolInheritancePopulatesManifest() async throws {
        
        let catalog = catalog(files: [
            JSONFile(name: "MarkdownOutput.symbols.json", content:
                    makeSymbolGraph(
                        moduleName: "MarkdownOutput",
                        symbols: [
                            makeSymbol(id: "local-subclass-id", kind: .class, pathComponents: ["LocalSubclass"]),
                            makeSymbol(id: "local-superclass-id", kind: .class, pathComponents: ["LocalSuperclass"])
                        ],
                        relationships: [
                            SymbolGraph.Relationship(source: "local-subclass-id", target: "local-superclass-id", kind: .inheritsFrom, targetFallback: nil)
                        ]
                    ))
        ])
        
        
        let (_, manifest) = try await markdownOutput(catalog: catalog, path: "LocalSubclass")
        let inheritsFrom = MarkdownOutputManifest.Relationship(
            sourceIdentifier: "/documentation/MarkdownOutput/LocalSubclass",
            relationshipType: .relatedSymbol,
            subtype: .inheritsFrom,
            targetIdentifier: "/documentation/MarkdownOutput/LocalSuperclass"
        )
        #expect(manifest.relationships.contains(inheritsFrom))
        
        let (_, parentManifest) = try await markdownOutput(catalog: catalog, path: "LocalSuperclass")
        let inheritedBy = MarkdownOutputManifest.Relationship(
            sourceIdentifier: "/documentation/MarkdownOutput/LocalSuperclass",
            relationshipType: .relatedSymbol,
            subtype: .inheritedBy,
            targetIdentifier: "/documentation/MarkdownOutput/LocalSubclass"
        )
        #expect(parentManifest.relationships.contains(inheritedBy))
    }
        
    @Test
    func symbolConformancePopulatesManifest() async throws {
                
        let catalog = catalog(files: [
            JSONFile(name: "MarkdownOutput.symbols.json", content:
                    makeSymbolGraph(
                        moduleName: "MarkdownOutput",
                        symbols: [
                            makeSymbol(id: "local-conformer-id", kind: .struct, pathComponents: ["LocalConformer"]),
                            makeSymbol(id: "local-protocol-id", kind: .protocol, pathComponents: ["LocalProtocol"]),
                            makeSymbol(id: "external-conformer-id", kind: .struct, pathComponents: ["ExternalConformer"])
                        ],
                        relationships: [
                            SymbolGraph.Relationship(source: "local-conformer-id", target: "local-protocol-id", kind: .conformsTo, targetFallback: nil),
                            SymbolGraph.Relationship(source: "external-conformer-id", target: "s:SH", kind: .conformsTo, targetFallback: "Swift.Hashable")
                        ]
                    ))
        ])
        
        let (_, manifest) = try await markdownOutput(catalog: catalog, path: "LocalConformer")
        let conformsTo = MarkdownOutputManifest.Relationship(
            sourceIdentifier: "/documentation/MarkdownOutput/LocalConformer",
            relationshipType: .relatedSymbol,
            subtype: .conformsTo,
            targetIdentifier: "/documentation/MarkdownOutput/LocalProtocol"
        )
        #expect(manifest.relationships.contains(conformsTo))
        
        let (_, protocolManifest) = try await markdownOutput(catalog: catalog, path: "LocalProtocol")
        let conformingTypes = MarkdownOutputManifest.Relationship(
            sourceIdentifier: "/documentation/MarkdownOutput/LocalProtocol",
            relationshipType: .relatedSymbol,
            subtype: .conformingTypes,
            targetIdentifier: "/documentation/MarkdownOutput/LocalConformer"
        )
        #expect(protocolManifest.relationships.contains(conformingTypes))
        
        let (_, externalManifest) = try await markdownOutput(catalog: catalog, path: "ExternalConformer")
        // Unresolved symbol should use the fallback identifier
        let externalConformsTo = MarkdownOutputManifest.Relationship(
            sourceIdentifier: "/documentation/MarkdownOutput/ExternalConformer",
            relationshipType: .relatedSymbol,
            subtype: .conformsTo,
            targetIdentifier: "Swift.Hashable"
        )
        #expect(externalManifest.relationships.contains(externalConformsTo))
    }
}

extension MarkdownOutputNode.Metadata {    
    func availability(for platform: String) -> Availability? {
        availability?.first(where: { $0.platform == platform })
    }
}
