/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024-2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
import SwiftDocCTestUtilities
@testable import SwiftDocC
import Markdown

class ListItemExtractorTests: XCTestCase {
    
    func testSupportsSpacesInTaggedElementNames() throws {
        let testSource = URL(fileURLWithPath: "/path/to/test-source-\(ProcessInfo.processInfo.globallyUniqueString)")
        func extractedTags(_ markup: String) -> TaggedListItemExtractor {
            let document = Document(parsing: markup, source: testSource, options: .parseSymbolLinks)
            
            var extractor = TaggedListItemExtractor()
            _ = extractor.visit(document)
            return extractor
        }
    
        for whitespace in [" ", "   ", "\t"] {
            let parameters = extractedTags("""
            - Parameter\(whitespace)some parameter with spaces: Some description of this parameter.
            """).parameters
            XCTAssertEqual(parameters.count, 1)
            let parameter = try XCTUnwrap(parameters.first)
            XCTAssertEqual(parameter.name, "some parameter with spaces")
            XCTAssertEqual(parameter.contents.map { $0.format() }, ["Some description of this parameter."])
            XCTAssertEqual(parameter.nameRange?.source?.path, testSource.path)
            XCTAssertEqual(parameter.range?.source?.path, testSource.path)
        }

        let parameters = extractedTags("""
        - Parameters:
          - some parameter with spaces: Some description of this parameter.
        """).parameters
        XCTAssertEqual(parameters.count, 1)
        let parameter = try XCTUnwrap(parameters.first)
        XCTAssertEqual(parameter.name, "some parameter with spaces")
        XCTAssertEqual(parameter.contents.map { $0.format() }, ["Some description of this parameter."])
        XCTAssertEqual(parameter.nameRange?.source?.path, testSource.path)
        XCTAssertEqual(parameter.range?.source?.path, testSource.path)
        
        let dictionaryKeys = extractedTags("""
        - DictionaryKeys:
          - some key with spaces: Some description of this key.
        """).dictionaryKeys
        XCTAssertEqual(dictionaryKeys.count, 1)
        let dictionaryKey = try XCTUnwrap(dictionaryKeys.first)
        XCTAssertEqual(dictionaryKey.name, "some key with spaces")
        XCTAssertEqual(dictionaryKey.contents.map { $0.format() }, ["Some description of this key."])
        
        let possibleValues = extractedTags("""
        - PossibleValue some value with spaces: Some description of this value.
        """).possiblePropertyListValues
        XCTAssertEqual(possibleValues.count, 1)
        let possibleValue = try XCTUnwrap(possibleValues.first)
        XCTAssertEqual(possibleValue.value, "some value with spaces")
        XCTAssertEqual(possibleValue.contents.map { $0.format() }, ["Some description of this value."])
        XCTAssertEqual(possibleValue.nameRange?.source?.path, testSource.path)
        XCTAssertEqual(possibleValue.range?.source?.path, testSource.path)
        
        XCTAssert(extractedTags("- Parameter: Missing parameter name.").parameters.isEmpty)
        XCTAssert(extractedTags("- Parameter  : Missing parameter name.").parameters.isEmpty)
        
        XCTAssert(extractedTags("- DictionaryKey: Missing key name.").dictionaryKeys.isEmpty)
        XCTAssert(extractedTags("- PossibleValue: Missing value name.").possiblePropertyListValues.isEmpty)
    }
    
    func testExtractingTags() async throws {
        try await assertExtractsRichContentFor(
            tagName: "Returns",
            findModelContent: { semantic in
                semantic.returnsSection?.content
            },
            renderContentSectionTitle: "Return Value"
        )

        try await assertExtractsRichContentFor(
            tagName: "Note",
            isAside: true,
            findModelContent: { semantic in
                semantic.discussion?.content
                    .mapFirst { $0 as? BlockQuote }
                    .map { Array($0.blockChildren) }
                              
            },
            renderVerification: .verify(find: { renderNode in
                renderNode.primaryContentSections
                    .mapFirst { $0 as? ContentRenderSection }
                    .flatMap { section in
                        for content in section.content {
                            guard case .aside(let aside) = content else { continue }
                            return aside.content
                        }
                        return nil
                    }
            })
        )
        
        try await assertExtractsRichContentFor(
            tagName: "Precondition",
            isAside: true,
            findModelContent: { semantic in
                semantic.discussion?.content
                    .mapFirst { $0 as? BlockQuote }
                    .map { Array($0.blockChildren) }
                              
            },
            renderVerification: .verify(find: { renderNode in
                renderNode.primaryContentSections
                    .mapFirst { $0 as? ContentRenderSection }
                    .flatMap { section in
                        for content in section.content {
                            guard case .aside(let aside) = content else { continue }
                            return aside.content
                        }
                        return nil
                    }
            })
        )
        
        try await assertExtractsRichContentFor(
            tagName: "Parameter someParameterName",
            findModelContent: { semantic in
                semantic.parametersSection?.parameters.first?.contents
            },
            renderVerification: .verify(find: { renderNode in
                renderNode.primaryContentSections
                    .mapFirst { $0 as? ParametersRenderSection }
                    .flatMap { $0.parameters.first }
                    .map { Array($0.content) }
            })
        )
        
        try await assertExtractsRichContentOutlineFor(
            tagName: "Parameters",
            findModelContent: { semantic in
                semantic.parametersSection?.parameters.first?.contents
            },
            renderVerification: .verify(find: { renderNode in
                renderNode.primaryContentSections
                    .mapFirst { $0 as? ParametersRenderSection }
                    .flatMap { $0.parameters.first }
                    .map { Array($0.content) }
            })
        )
        
        // Dictionary and HTTP tags are filtered out from the rendering without symbol information.
        // These test helpers can't easily set up a bundle that supports general tags, REST tags, and HTTP tags.
        
        try await assertExtractsRichContentFor(
            tagName: "DictionaryKey someKey",
            findModelContent: { semantic in
                semantic.dictionaryKeysSection?.dictionaryKeys.first?.contents
            },
            renderVerification: .skip
        )
        
        try await assertExtractsRichContentOutlineFor(
            tagName: "DictionaryKeys",
            findModelContent: { semantic in
                semantic.dictionaryKeysSection?.dictionaryKeys.first?.contents
            },
            renderVerification: .skip
        )
        
        try await assertExtractsRichContentFor(
            tagName: "HTTPResponse 200",
            findModelContent: { semantic in
                semantic.httpResponsesSection?.responses.first?.contents
            },
            renderVerification: .skip
        )
        
        try await assertExtractsRichContentOutlineFor(
            tagName: "HTTPResponses",
            findModelContent: { semantic in
                semantic.httpResponsesSection?.responses.first?.contents
            },
            renderVerification: .skip
        )
        
        try await assertExtractsRichContentFor(
            tagName: "httpBody",
            findModelContent: { semantic in
                semantic.httpBodySection?.body.contents
            },
            renderVerification: .skip
        )
        
        try await assertExtractsRichContentFor(
            tagName: "HTTPParameter someParameter",
            findModelContent: { semantic in
                semantic.httpParametersSection?.parameters.first?.contents
            },
            renderVerification: .skip
        )
        
        try await assertExtractsRichContentOutlineFor(
            tagName: "HTTPParameters",
            findModelContent: { semantic in
                semantic.httpParametersSection?.parameters.first?.contents
            },
            renderVerification: .skip
        )
        
        try await assertExtractsRichContentFor(
            tagName: "HTTPBodyParameter someParameter",
            findModelContent: { semantic in
                semantic.httpBodySection?.body.parameters.first?.contents
            },
            renderVerification: .skip
        )
        
        try await assertExtractsRichContentOutlineFor(
            tagName: "HTTPBodyParameters",
            findModelContent: { semantic in
                semantic.httpBodySection?.body.parameters.first?.contents
            },
            renderVerification: .skip
        )
    }

    // MARK: Test helpers
    
    func assertExtractsRichContentFor(
        tagName: String,
        findModelContent: (Symbol) -> [any Markup]?,
        renderContentSectionTitle: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws {
        try await assertExtractsRichContentFor(
            tagName: tagName,
            isAside: false,
            findModelContent: findModelContent,
            renderVerification: .verify(find: { renderNode in
                renderNode.primaryContentSections
                    .lazy
                    .compactMap { $0 as? ContentRenderSection }
                    .filter { $0.headings == [renderContentSectionTitle] }
                    .first
                    .map {
                        Array($0.content.dropFirst())
                    }
            }),
            file: file,
            line: line
        )
    }
    
    
    enum RenderVerification {
        case skip
        case verify(find: (RenderNode) -> [RenderBlockContent]?)
    }
    
    func assertExtractsRichContentFor(
        tagName: String,
        isAside: Bool = false,
        findModelContent: (Symbol) -> [any Markup]?,
        renderVerification: RenderVerification,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws {
        // Build documentation for a module page with one tagged item with a lot of different
        
        let (bundle, context) = try await loadBundle(
            catalog: Folder(name: "Something.docc", content: [
                JSONFile(name: "ModuleName.symbols.json", content: makeSymbolGraph(moduleName: "ModuleName")),
                TextFile(name: "Extension.md", utf8Content: """
                    # ``ModuleName``
                    
                    Some description of this module.
                    
                    - \(tagName): First paragraph describing this tag, with ``FirstNotFoundSymbol`` link
                    
                      Second paragraph of description, with ``SecondNotFoundSymbol`` link
                      
                      - First inner unordered list item
                      - Second inner unordered list item
                    
                      ![](some-image)
                    
                      1. First inner ordered list item
                      1. Second inner ordered list item
                    
                      ```
                      Inner code block
                      ```
                    
                      > Warning: Inner aside, with ``ThirdNotFoundSymbol`` link
                    """),
                DataFile(name: "some-image.png", data: Data()),
            ])
        )
        
        try _assertExtractsRichContentFor(tagName: tagName, findModelContent: findModelContent, renderVerification: renderVerification, isAside: isAside, bundle: bundle, context: context, expectedLogText: """
        \u{001B}[1;33mwarning: 'FirstNotFoundSymbol' doesn't exist at '/ModuleName'\u{001B}[0;0m
         --> /Something.docc/Extension.md:5:\(49+tagName.count)-5:\(68+tagName.count)
        3 | Some description of this module.
        4 |
        5 + - \(tagName): First paragraph describing this tag, with ``\u{001B}[1;32mFirstNotFoundSymbol\u{001B}[0;0m`` link
        6 |
        7 |   Second paragraph of description, with ``SecondNotFoundSymbol`` link

        \u{001B}[1;33mwarning: 'SecondNotFoundSymbol' doesn't exist at '/ModuleName'\u{001B}[0;0m
         --> /Something.docc/Extension.md:7:43-7:63
        5 | - \(tagName): First paragraph describing this tag, with ``FirstNotFoundSymbol`` link
        6 |
        7 +   Second paragraph of description, with ``\u{001B}[1;32mSecondNotFoundSymbol\u{001B}[0;0m`` link
        8 |
        9 |   - First inner unordered list item

        \u{001B}[1;33mwarning: 'ThirdNotFoundSymbol' doesn't exist at '/ModuleName'\u{001B}[0;0m
          --> /Something.docc/Extension.md:21:34-21:53
        19 |   ```
        20 |
        21 +   > Warning: Inner aside, with ``\u{001B}[1;32mThirdNotFoundSymbol\u{001B}[0;0m`` link
        
        """, file: file, line: line)
    }
    
    
    func assertExtractsRichContentOutlineFor(
        tagName: String,
        findModelContent: (Symbol) -> [any Markup]?,
        renderVerification: RenderVerification,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws {
        // Build documentation for a module page with one tagged item with a lot of different
        
        let (bundle, context) = try await loadBundle(
            catalog: Folder(name: "Something.docc", content: [
                JSONFile(name: "ModuleName.symbols.json", content: makeSymbolGraph(moduleName: "ModuleName")),
                TextFile(name: "Extension.md", utf8Content: """
                    # ``ModuleName``
                    
                    Some description of this module.
                    
                    - \(tagName):
                      - someValue: First paragraph describing this tag, with ``FirstNotFoundSymbol`` link
                      
                        Second paragraph of description, with ``SecondNotFoundSymbol`` link
                        
                        - First inner unordered list item
                        - Second inner unordered list item
                      
                        ![](some-image)
                      
                        1. First inner ordered list item
                        1. Second inner ordered list item
                      
                        ```
                        Inner code block
                        ```
                      
                        > Warning: Inner aside, with ``ThirdNotFoundSymbol`` link
                    """),
                DataFile(name: "some-image.png", data: Data()),
            ])
        )
        
        try _assertExtractsRichContentFor(tagName: tagName, findModelContent: findModelContent, renderVerification: renderVerification, isAside: false, bundle: bundle, context: context, expectedLogText: """
        \u{001B}[1;33mwarning: 'FirstNotFoundSymbol' doesn't exist at '/ModuleName'\u{001B}[0;0m
         --> /Something.docc/Extension.md:6:60-6:79
        4 |
        5 | - \(tagName):
        6 +   - someValue: First paragraph describing this tag, with ``\u{001B}[1;32mFirstNotFoundSymbol\u{001B}[0;0m`` link
        7 |
        8 |     Second paragraph of description, with ``SecondNotFoundSymbol`` link

        \u{001B}[1;33mwarning: 'SecondNotFoundSymbol' doesn't exist at '/ModuleName'\u{001B}[0;0m
          --> /Something.docc/Extension.md:8:45-8:65
        6  |   - someValue: First paragraph describing this tag, with ``FirstNotFoundSymbol`` link
        7  |
        8  +     Second paragraph of description, with ``\u{001B}[1;32mSecondNotFoundSymbol\u{001B}[0;0m`` link
        9  |
        10 |     - First inner unordered list item

        \u{001B}[1;33mwarning: 'ThirdNotFoundSymbol' doesn't exist at '/ModuleName'\u{001B}[0;0m
          --> /Something.docc/Extension.md:22:36-22:55
        20 |     ```
        21 |
        22 +     > Warning: Inner aside, with ``\u{001B}[1;32mThirdNotFoundSymbol\u{001B}[0;0m`` link
        
        """, file: file, line: line)
    }
    
    func _assertExtractsRichContentFor(
        tagName: String,
        findModelContent: (Symbol) -> [any Markup]?,
        renderVerification: RenderVerification,
        isAside: Bool,
        bundle: DocumentationBundle,
        context: DocumentationContext,
        expectedLogText: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let expectedLinkProblems = context.problems.filter { $0.diagnostic.identifier == "org.swift.docc.unresolvedTopicReference" }
        XCTAssert(expectedLinkProblems.allSatisfy { $0.diagnostic.source != nil }, "Diagnostics are missing source information.", file: file, line: line)
        XCTAssert(expectedLinkProblems.allSatisfy { $0.diagnostic.range != nil }, "Diagnostics are missing range information.", file: file, line: line)
        
        let logStorage = LogHandle.LogStorage()
        let diagnosticWriter = DiagnosticConsoleWriter(LogHandle.memory(logStorage), formattingOptions: [], highlight: true, dataProvider: context.linkResolver.dataProvider)
        diagnosticWriter.receive(expectedLinkProblems)
        try diagnosticWriter.flush()
        XCTAssertEqual(logStorage.text, expectedLogText, file: file, line: line)
        
        let reference = try XCTUnwrap(context.soleRootModuleReference)
        let node = try context.entity(with: reference)
        let symbolSemantic = try XCTUnwrap(node.semantic as? Symbol)
        
        let extractedContent = try XCTUnwrap(findModelContent(symbolSemantic), "Didn't find any model content", file: file, line: line)
        var expectedContent = [
            "First paragraph describing this tag, with ``FirstNotFoundSymbol`` link",
            
            "Second paragraph of description, with ``SecondNotFoundSymbol`` link",
            
            """
            - First inner unordered list item
            - Second inner unordered list item
            """,
            
            "![](some-image)",
            
            """
            1. First inner ordered list item
            1. Second inner ordered list item
            """,
            
            """
            ```
            Inner code block
            ```
            """,
            
            "> Warning: Inner aside, with ``ThirdNotFoundSymbol`` link",
        ]
        if isAside {
            expectedContent[0] = "\(tagName): \(expectedContent[0])"
        }
        
        XCTAssertEqual(extractedContent.map { $0.detachedFromParent.format() }, expectedContent, "Found model content doesn't match expected content", file: file, line: line)
        
        guard case .verify(let findRenderContent) = renderVerification else {
            return
        }
        
        let converter = DocumentationNodeConverter(bundle: bundle, context: context)
        let renderNode = converter.convert(node)
        
        let renderContent = try XCTUnwrap(findRenderContent(renderNode), "Didn't find any rendered content", file: file, line: line)
        let expectedRenderContent: [RenderBlockContent] = [
            // First paragraph describing this tag
            .paragraph(.init(inlineContent: [
                .text("First paragraph describing this tag, with "),
                .codeVoice(code: "FirstNotFoundSymbol"),
                .text(" link"),
            ])),
            
            // Second paragraph of description
            .paragraph(.init(inlineContent: [
                .text("Second paragraph of description, with "),
                .codeVoice(code: "SecondNotFoundSymbol"),
                .text(" link"),
            ])),
            
            // - First inner unordered list item
            // - Second inner unordered list item
            .unorderedList(.init(items: [
                .init(content: [
                    .paragraph(.init(inlineContent: [
                        .text("First inner unordered list item")
                    ]))
                ]),
                .init(content: [
                    .paragraph(.init(inlineContent: [
                        .text("Second inner unordered list item")
                    ]))
                ])
            ])),
            
            // ![](some-image)
            .paragraph(.init(inlineContent: [
                .image(identifier: RenderReferenceIdentifier("some-image"), metadata: nil)
            ])),
            
            // 1. First inner ordered list item
            // 1. Second inner ordered list item
            .orderedList(.init(items: [
                .init(content: [
                    .paragraph(.init(inlineContent: [
                        .text("First inner ordered list item")
                    ]))
                ]),
                .init(content: [
                    .paragraph(.init(inlineContent: [
                        .text("Second inner ordered list item")
                    ]))
                ])
            ])),
            
            // ```
            // Inner code block
            // ```
            .codeListing(.init(syntax: nil, code: ["Inner code block"], metadata: nil, copyToClipboard: false)),
        
            // > Warning: Inner aside, with ``ThirdNotFoundSymbol`` link
            .aside(.init(style: .init(asideKind: .warning), content: [
                .paragraph(.init(inlineContent: [
                    .text("Inner aside, with "),
                    .codeVoice(code: "ThirdNotFoundSymbol"),
                    .text(" link"),
                ]))
            ]))
        ]
        
        XCTAssertEqual(expectedRenderContent.count, Array(renderContent).count, "Unexpected number of rendered items", file: file, line: line)
        for (expected, got) in zip(expectedRenderContent, renderContent) {
            XCTAssertEqual(expected, got, file: file, line: line)
        }
    }
}
