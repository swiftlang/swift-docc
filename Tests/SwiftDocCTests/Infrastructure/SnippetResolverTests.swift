/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocC
import SymbolKit
import SwiftDocCTestUtilities

class SnippetResolverTests: XCTestCase {
    
    let optionalPathPrefixes = [
        // The module name as the first component
        "/ModuleName/Snippets/",
         "ModuleName/Snippets/",
        
         // The catalog name as the first component
         "/Something/Snippets/",
          "Something/Snippets/",
        
          // Snippets repeated as the first component
          "/Snippets/Snippets/",
           "Snippets/Snippets/",
        
                   // Only the "Snippets" prefix
                   "/Snippets/",
                    "Snippets/",
        
                            // No prefix
                            "/",
                             "",
    ]
    
    func testRenderingSnippetsWithOptionalPathPrefixes() async throws {
        for pathPrefix in optionalPathPrefixes {
            let (problems, _, snippetRenderBlocks) = try await makeSnippetContext(
                snippets: [
                    makeSnippet(
                        pathComponents: ["Snippets", "First"],
                        explanation: """
                        Some _formatted_ **content** that provides context to the snippet.
                        """,
                        code: """
                        // Some code comment
                        print("Hello, world!")
                        """,
                        slices: ["comment": 0..<1]
                    ),
                    makeSnippet(
                        pathComponents: ["Snippets", "Path", "To", "Second"],
                        explanation: nil,
                        code: """
                        print("1 + 2 = \\(1+2)")
                        """
                    )
                ],
                rootContent: """
                @Snippet(path: \(pathPrefix)First)
                
                @Snippet(path: \(pathPrefix)Path/To/Second)
                
                @Snippet(path: \(pathPrefix)First, slice: comment)
                """
            )
            
            // These links should all resolve, regardless of optional prefix
            XCTAssertTrue(problems.isEmpty, "Unexpected problems for path prefix '\(pathPrefix)': \(problems.map(\.diagnostic.summary))")
            
            // Because the snippet links resolved, their content should render on the page.
            
            // The explanation for the first snippet
            if case .paragraph(let paragraph) = snippetRenderBlocks.first {
                XCTAssertEqual(paragraph.inlineContent, [
                    .text("Some "),
                    .emphasis(inlineContent: [.text("formatted")]),
                    .text(" "),
                    .strong(inlineContent: [.text("content")]),
                    .text(" that provides context to the snippet."),
                ])
            } else {
                XCTFail("Missing expected rendered explanation.")
            }
            
            // The first snippet code
            if case .codeListing(let codeListing) = snippetRenderBlocks.dropFirst().first {
                XCTAssertEqual(codeListing.syntax, "swift")
                XCTAssertEqual(codeListing.code, [
                    #"// Some code comment"#,
                    #"print("Hello, world!")"#,
                ])
            } else {
                XCTFail("Missing expected rendered code block.")
            }
            
            // The second snippet (without an explanation)
            if case .codeListing(let codeListing) = snippetRenderBlocks.dropFirst(2).first {
                XCTAssertEqual(codeListing.syntax, "swift")
                XCTAssertEqual(codeListing.code, [
                    #"print("1 + 2 = \(1+2)")"#
                ])
            } else {
                XCTFail("Missing expected rendered code block.")
            }
            
            // The third snippet is a slice, so it doesn't display its explanation
            if case .codeListing(let codeListing) = snippetRenderBlocks.dropFirst(3).first {
                XCTAssertEqual(codeListing.syntax, "swift")
                XCTAssertEqual(codeListing.code, [
                    #"// Some code comment"#,
                ])
            } else {
                XCTFail("Missing expected rendered code block.")
            }
            
            XCTAssertNil(snippetRenderBlocks.dropFirst(4).first, "There's no more content after the snippets")
        }
    }
    
    func testWarningsAboutMisspelledSnippetPathsAndMisspelledSlice() async throws {
        for pathPrefix in optionalPathPrefixes.prefix(1) {
            let (problems, logOutput, snippetRenderBlocks) = try await makeSnippetContext(
                snippets: [
                    makeSnippet(
                        pathComponents: ["Snippets", "First"],
                        explanation: """
                        Some _formatted_ **content** that provides context to the snippet.
                        """,
                        code: """
                        // Some code comment
                        print("Hello, world!")
                        """,
                        slices: [
                            "comment": 0..<1,
                            "print":   1..<2,
                        ]
                    ),
                ],
                rootContent: """
                @Snippet(path: \(pathPrefix)Frst)
                
                @Snippet(path: \(pathPrefix)First, slice: cmmnt)
                """
            )
            
            // These links should all resolve, regardless of optional prefix
            XCTAssertEqual(problems.map(\.diagnostic.summary).sorted(), [
                "Snippet named 'Frst' couldn't be found.",
                "Snippet slice 'cmmnt' does not exist in snippet '/ModuleName/Snippets/First'; this directive will be ignored",
            ])
            
            XCTAssertEqual(logOutput, """
            warning: Snippet named 'Frst' couldn't be found.
             --> ModuleName.md:7:16-7:41
            5 | ## Overview
            6 |
            7 + @Snippet(path: /ModuleName/Snippets/Frst)
            8 |
            9 | @Snippet(path: /ModuleName/Snippets/First, slice: cmmnt)

            warning: Snippet slice 'cmmnt' does not exist in snippet '/ModuleName/Snippets/First'; this directive will be ignored
             --> ModuleName.md:9:1-9:8
            7 | @Snippet(path: /ModuleName/Snippets/Frst)
            8 |
            9 + @Snippet(path: /ModuleName/Snippets/First, slice: cmmnt)
            
            """)
            
            // Because the snippet links failed to resolve, their content shouldn't render on the page.
            XCTAssertTrue(snippetRenderBlocks.isEmpty, "There's no more content after the snippets")
        }
    }
    
    private func makeSnippetContext(
        snippets: [SymbolGraph.Symbol],
        rootContent: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws -> ([Problem], logOutput: String, some Collection<RenderBlockContent>) {
        let catalog = Folder(name: "Something.docc", content: [
            JSONFile(name: "something-snippets.symbols.json", content: makeSymbolGraph(moduleName: "Snippets", symbols: snippets)),
            // Include a "real" module that's separate from the snippet symbol graph.
            JSONFile(name: "ModuleName.symbols.json", content: makeSymbolGraph(moduleName: "ModuleName")),
            
            TextFile(name: "ModuleName.md", utf8Content: """
            # ``ModuleName``
                
            Always include an abstract here before the custom markup
            
            ## Overview
            
            \(rootContent)
            """)
        ])
        // We make the "Overview" heading explicit above so that the rendered page will always have a `primaryContentSections`.
        // This makes it easier for the test to then
        
        let logStore = LogHandle.LogStorage()
        let (_, context) = try await loadBundle(catalog: catalog, logOutput: LogHandle.memory(logStore))
        
        XCTAssertEqual(context.knownIdentifiers.count, 1, "The snippets don't have their own identifiers", file: file, line: line)
        
        let reference = try XCTUnwrap(context.soleRootModuleReference, file: file, line: line)
        let moduleNode = try context.entity(with: reference)
        let renderNode = DocumentationNodeConverter(bundle: context.bundle, context: context).convert(moduleNode)
        
        let renderBlocks = try XCTUnwrap(renderNode.primaryContentSections.first as? ContentRenderSection, file: file, line: line).content
        
        if case .heading(let heading) = renderBlocks.first  {
            XCTAssertEqual(heading.level, 2, file: file, line: line)
            XCTAssertEqual(heading.text, "Overview", file: file, line: line)
        } else {
            XCTFail("The rendered page is missing the 'Overview' heading. Something unexpected is happening with the page content.", file: file, line: line)
        }
        
        return (context.problems, logStore.text, renderBlocks.dropFirst())
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
}
