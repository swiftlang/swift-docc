/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import XCTest
import Markdown
@testable import SymbolKit
@_spi(ExternalLinks) @testable import SwiftDocC
import SwiftDocCTestUtilities

class AutoCapitalizationTests: XCTestCase {
    
    
    // MARK: Test helpers
    
    private let start = SymbolGraph.LineList.SourceRange.Position(line: 7, character: 6) // an arbitrary non-zero start position
    private let symbolURL =  URL(fileURLWithPath: "/path/to/SomeFile.swift")
    
    private func makeSymbolGraph(docComment: String) -> SymbolGraph {
        makeSymbolGraph(
            docComment: docComment,
            sourceLanguage: .swift,
            parameters: [
                ("firstParameter", nil),
                ("secondParameter", nil),
                ("thirdParameter", nil),
                ("fourthParameter", nil),
            ],
            returnValue: .init(kind: .typeIdentifier, spelling: "ReturnValue", preciseIdentifier: "return-value-id")
        )
    }
    
    private func makeSymbolGraph(
        docComment: String?,
        sourceLanguage: SourceLanguage,
        parameters: [(name: String, externalName: String?)],
        returnValue: SymbolGraph.Symbol.DeclarationFragments.Fragment
    ) -> SymbolGraph {
        let uri = symbolURL.absoluteString // we want to include the file:// scheme here
        func makeLineList(text: String) -> SymbolGraph.LineList {
            return .init(text.splitByNewlines.enumerated().map { lineOffset, line in
                    .init(text: line, range: .init(start: .init(line: start.line + lineOffset, character: start.character),
                                                   end: .init(line: start.line + lineOffset, character: start.character + line.count)))
            }, uri: uri)
        }
        
        return makeSymbolGraph(
            moduleName: "ModuleName",
            symbols: [
                .init(
                    identifier: .init(precise: "symbol-id", interfaceLanguage: sourceLanguage.id),
                    names: .init(title: "functionName(...)", navigator: nil, subHeading: nil, prose: nil),
                    pathComponents: ["functionName(...)"],
                    docComment: docComment.map { makeLineList(text: $0) },
                    accessLevel: .public, kind: .init(parsedIdentifier: .func, displayName: "Function"),
                    mixins: [
                        SymbolGraph.Symbol.Location.mixinKey: SymbolGraph.Symbol.Location(uri: uri, position: start),
                        
                        SymbolGraph.Symbol.FunctionSignature.mixinKey: SymbolGraph.Symbol.FunctionSignature(
                            parameters: parameters.map {
                                .init(name: $0.name, externalName: $0.externalName, declarationFragments: [], children: [])
                            },
                            returns: [returnValue]
                        )
                    ]
                )
            ]
        )
    }
    
    
    // MARK: End-to-end integration tests
    
    func testParametersCapitalization() throws {
        let symbolGraph = makeSymbolGraph(docComment: """
            Some symbol description.

            - Parameters:
                - one: upper-cased first parameter description.
                - two:     the second parameter has extra white spaces
                - three: inValid third parameter will not be capitalized
                - four: `code block` will not be capitalized
                - five: a`nother invalid capitalization
            """)
        
        let url = try createTempFolder(content: [
            Folder(name: "unit-test.docc", content: [
                JSONFile(name: "ModuleName.symbols.json", content: symbolGraph)
            ])
        ])
        let (_, bundle, context) = try loadBundle(from: url)
        
        XCTAssertEqual(context.problems.count, 0)
        
        let reference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/ModuleName/functionName(...)", sourceLanguage: .swift)
        var node = try context.entity(with: reference)
        let symbol = try XCTUnwrap(node.semantic as? Symbol)
        let parameterSections = symbol.parametersSectionVariants
        XCTAssertEqual(parameterSections[.swift]?.parameters.map(\.name), ["one", "two", "three", "four", "five"])
        
        let parameterSectionTranslator = ParametersSectionTranslator()
        var renderNodeTranslator = RenderNodeTranslator(context: context, bundle: bundle, identifier: reference, source: url)
        var renderNode = renderNodeTranslator.visit(symbol) as! RenderNode
        let translatedParameters = parameterSectionTranslator.translateSection(for: symbol, renderNode: &renderNode, renderNodeTranslator: &renderNodeTranslator)
        let paramsRenderSection = translatedParameters?.defaultValue?.section as! ParametersRenderSection
        
        XCTAssertEqual(paramsRenderSection.parameters.map(\.content), [
            [SwiftDocC.RenderBlockContent.paragraph(SwiftDocC.RenderBlockContent.Paragraph(inlineContent: [SwiftDocC.RenderInlineContent.text("Upper-cased first parameter description.")]))],
            [SwiftDocC.RenderBlockContent.paragraph(SwiftDocC.RenderBlockContent.Paragraph(inlineContent: [SwiftDocC.RenderInlineContent.text("The second parameter has extra white spaces")]))],
            [SwiftDocC.RenderBlockContent.paragraph(SwiftDocC.RenderBlockContent.Paragraph(inlineContent: [SwiftDocC.RenderInlineContent.text("inValid third parameter will not be capitalized")]))],
            [SwiftDocC.RenderBlockContent.paragraph(SwiftDocC.RenderBlockContent.Paragraph(inlineContent: [SwiftDocC.RenderInlineContent.text(""), SwiftDocC.RenderInlineContent.codeVoice(code: "code block"), SwiftDocC.RenderInlineContent.text(" will not be capitalized")]))],
            [SwiftDocC.RenderBlockContent.paragraph(SwiftDocC.RenderBlockContent.Paragraph(inlineContent: [SwiftDocC.RenderInlineContent.text("a`nother invalid capitalization")]))]])
    }
    
    func testIndividualParametersCapitalization() throws {
        let symbolGraph = makeSymbolGraph(docComment: """
            Some symbol description.

            - parameter one: upper-cased first parameter description.
            - parameter two:     the second parameter has extra white spaces
            - parameter three: inValid third parameter will not be capitalized
            - parameter four: `code block` will not be capitalized
            - parameter five: a`nother invalid capitalization
            """)
        
        let url = try createTempFolder(content: [
            Folder(name: "unit-test.docc", content: [
                JSONFile(name: "ModuleName.symbols.json", content: symbolGraph)
            ])
        ])
        let (_, bundle, context) = try loadBundle(from: url)
        
        XCTAssertEqual(context.problems.count, 0)
        
        let reference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/ModuleName/functionName(...)", sourceLanguage: .swift)
        var node = try context.entity(with: reference)
        let symbol = try XCTUnwrap(node.semantic as? Symbol)
        let parameterSections = symbol.parametersSectionVariants
        XCTAssertEqual(parameterSections[.swift]?.parameters.map(\.name), ["one", "two", "three", "four", "five"])
        
        let parameterSectionTranslator = ParametersSectionTranslator()
        var renderNodeTranslator = RenderNodeTranslator(context: context, bundle: bundle, identifier: reference, source: url)
        var renderNode = renderNodeTranslator.visit(symbol) as! RenderNode
        let translatedParameters = parameterSectionTranslator.translateSection(for: symbol, renderNode: &renderNode, renderNodeTranslator: &renderNodeTranslator)
        let paramsRenderSection = translatedParameters?.defaultValue?.section as! ParametersRenderSection
        
        XCTAssertEqual(paramsRenderSection.parameters.map(\.content), [
            [SwiftDocC.RenderBlockContent.paragraph(SwiftDocC.RenderBlockContent.Paragraph(inlineContent: [SwiftDocC.RenderInlineContent.text("Upper-cased first parameter description.")]))],
            [SwiftDocC.RenderBlockContent.paragraph(SwiftDocC.RenderBlockContent.Paragraph(inlineContent: [SwiftDocC.RenderInlineContent.text("The second parameter has extra white spaces")]))],
            [SwiftDocC.RenderBlockContent.paragraph(SwiftDocC.RenderBlockContent.Paragraph(inlineContent: [SwiftDocC.RenderInlineContent.text("inValid third parameter will not be capitalized")]))],
            [SwiftDocC.RenderBlockContent.paragraph(SwiftDocC.RenderBlockContent.Paragraph(inlineContent: [SwiftDocC.RenderInlineContent.text(""), SwiftDocC.RenderInlineContent.codeVoice(code: "code block"), SwiftDocC.RenderInlineContent.text(" will not be capitalized")]))],
            [SwiftDocC.RenderBlockContent.paragraph(SwiftDocC.RenderBlockContent.Paragraph(inlineContent: [SwiftDocC.RenderInlineContent.text("a`nother invalid capitalization")]))]])
    }
    
    func testRenderBlockContentAside() {
        let aside = RenderBlockContent.aside(.init(style: .init(rawValue: "Experiment"), content: [.paragraph(.init(inlineContent: [.text("hello, world!")]))]))
        
        XCTAssertEqual("Hello, world!", aside.withFirstWordCapitalized.rawIndexableTextContent(references: [:]))
    }
    
}
