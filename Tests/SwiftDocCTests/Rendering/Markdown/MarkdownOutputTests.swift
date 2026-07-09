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
                makeSymbol(id: "MarkdownSymbol", kind: .struct, pathComponents: ["MarkdownSymbol"], docComment: "A basic symbol to test markdown output")
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
                makeSymbol(id: "MarkdownSymbol", kind: .struct, pathComponents: ["MarkdownSymbol"], docComment: "A basic symbol to test markdown output. Different to ``OtherMarkdownSymbol``"),
                makeSymbol(id: "OtherMarkdownSymbol", kind: .struct, pathComponents: ["OtherMarkdownSymbol"], docComment: "A basic symbol to test markdown output. Different to ``MarkdownSymbol``")
            ]))
        ])
        
        let (node, _) = try await markdownOutput(catalog: catalog, path: "Links")
        let expectedInline = "inline link: [`MarkdownSymbol`](/documentation/MarkdownOutput/MarkdownSymbol)"
        #expect(node.markdown.contains(expectedInline))
        
        let expectedLinkList = "[`MarkdownSymbol`](/documentation/MarkdownOutput/MarkdownSymbol)\n\nA basic symbol to test markdown output. Different to [`OtherMarkdownSymbol`](/documentation/MarkdownOutput/OtherMarkdownSymbol)"
        #expect(node.markdown.contains(expectedLinkList))
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
                makeSymbol(id: "MarkdownSymbol", kind: .struct, pathComponents: ["MarkdownSymbol"], docComment: "A basic symbol to test markdown output")
            ]))
        ])
        let (node, _) = try await markdownOutput(catalog: catalog, path: "MarkdownSymbol")
        #expect(node.metadata.documentType == .symbol)
    }
    
    @Test
    func symbolDocumentPopulatesMetadata() async throws {
        let catalog = catalog(files: [
            JSONFile(name: "MarkdownOutput.symbols.json", content: makeSymbolGraph(moduleName: "MarkdownOutput", symbols: [
                makeSymbol(id: "MarkdownSymbol", kind: .struct, pathComponents: ["MarkdownSymbol"], docComment: "A basic symbol to test markdown output"),
                makeSymbol(id: "MarkdownSymbol_init_name", kind: .`init`, pathComponents: ["MarkdownSymbol", "init(name:)"])
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
                makeSymbol(id: "Array_asdf", kind: .property, pathComponents: ["Swift", "Array", "asdf"], otherMixins: [SymbolGraph.Symbol.Swift.Extension(extendedModule: "Swift", constraints: [])])
                ])
             )
        ])
        let (node, _) = try await markdownOutput(catalog: catalog, path: "Swift/Array/asdf")
        #expect(node.metadata.symbol?.modules == ["MarkdownOutput", "Swift"])
    }
    
    @Test
    func symbolMetadataGetsDefaultAvailability() async throws {
        let catalog = catalog(files: [
            JSONFile(name: "MarkdownOutput.symbols.json", content: makeSymbolGraph(moduleName: "MarkdownOutput", symbols: [
                makeSymbol(id: "MarkdownSymbol", kind: .struct, pathComponents: ["MarkdownSymbol"], docComment: "A basic symbol to test markdown output")
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
    func symbolAvailabilityIsCapturedFromMetadataBlock() async throws {
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
        let availability = try #require(node.metadata.availability)
        let expected = MarkdownOutputNode.Metadata.Availability(platform: "iPadOS", introduced: "13.1.0", deprecated: nil, unavailable: false)
        #expect(availability.contains(expected))
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
                makeSymbol(id: "MarkdownSymbol_Identifier", kind: .struct, pathComponents: ["MarkdownSymbol"], docComment: "A basic symbol to test markdown output"),
            ]))
        ])
        
        let (node, _) = try await markdownOutput(catalog: catalog, path: "MarkdownSymbol")
        #expect(node.metadata.symbol?.preciseIdentifier == "MarkdownSymbol_Identifier")
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
                makeSymbol(id: "MarkdownSymbol", kind: .struct, pathComponents: ["MarkdownSymbol"], docComment: "A basic symbol to test markdown output")
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
        #expect(related.contains(where: {
            $0.targetIdentifier == "/documentation/MarkdownOutput/LocalSuperclass" && $0.subtype == .inheritsFrom
        }))
        
        let (_, parentManifest) = try await markdownOutput(catalog: catalog, path: "LocalSuperclass")
        let parentRelated = parentManifest.relationships.filter { $0.relationshipType == .relatedSymbol }
        #expect(parentRelated.contains(where: {
            $0.targetIdentifier == "/documentation/MarkdownOutput/LocalSubclass" && $0.subtype == .inheritedBy
        }))
    }
        
    @Test
    func symbolConformancePopulatesManifest() async throws {
        
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
        #expect(related.contains(where: {
            $0.targetIdentifier == "/documentation/MarkdownOutput/LocalProtocol" && $0.subtype == .conformsTo
        }))
        
        let (_, protocolManifest) = try await markdownOutput(catalog: catalog, path: "LocalProtocol")
        let protocolRelated = protocolManifest.relationships.filter { $0.relationshipType == .relatedSymbol }
        #expect(protocolRelated.contains(where: {
            $0.targetIdentifier == "/documentation/MarkdownOutput/LocalConformer" && $0.subtype == .conformingTypes
        }))
        
        let (_, externalManifest) = try await markdownOutput(catalog: catalog, path: "ExternalConformer")
        let externalRelated = externalManifest.relationships.filter { $0.relationshipType == .relatedSymbol }
        #expect(externalRelated.contains(where: {
            $0.targetIdentifier == "/documentation/Swift/Hashable" && $0.subtype == .conformsTo
        }))
    }
}

extension MarkdownOutputNode.Metadata {    
    func availability(for platform: String) -> Availability? {
        availability?.first(where: { $0.platform == platform })
    }
}
