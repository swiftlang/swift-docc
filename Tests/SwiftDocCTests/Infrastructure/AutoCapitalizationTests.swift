/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import XCTest
import SymbolKit
@testable import SwiftDocC
import SwiftDocCTestUtilities

class AutoCapitalizationTests: XCTestCase {
    
    // MARK: Test helpers
    
    private func makeSymbolGraph(docComment: String, parameters: [String]) -> SymbolGraph {
        makeSymbolGraph(
            moduleName: "ModuleName",
            symbols: [
                makeSymbol(
                    id: "symbol-id",
                    kind: .func,
                    pathComponents: ["functionName(...)"],
                    docComment: docComment,
                    signature: .init(
                        parameters: parameters.map {
                            .init(name: $0, externalName: nil, declarationFragments: [], children: [])
                        },
                        returns: [
                            .init(kind: .typeIdentifier, spelling: "ReturnValue", preciseIdentifier: "return-value-id")
                        ]
                    )
                )
            ]
        )
    }
    
    // MARK: End-to-end integration tests
    
    func testParametersCapitalization() throws {
        let symbolGraph = makeSymbolGraph(
            docComment: """
            Some symbol description.

            - Parameters:
                - one: upper-cased first parameter description.
                - two:     the second parameter has extra white spaces
                - three: inValid third parameter will not be capitalized
                - four: `code block` will not be capitalized
                - five: a`nother invalid capitalization
            """,
            parameters: ["one", "two", "three", "four", "five"]
        )
        
        let url = try createTempFolder(content: [
            Folder(name: "unit-test.docc", content: [
                JSONFile(name: "ModuleName.symbols.json", content: symbolGraph)
            ])
        ])
        let (_, bundle, context) = try loadBundle(from: url)
        
        XCTAssertEqual(context.problems.count, 0)
        
        let reference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/ModuleName/functionName(...)", sourceLanguage: .swift)
        let node = try context.entity(with: reference)
        let symbol = try XCTUnwrap(node.semantic as? Symbol)
        let parameterSections = symbol.parametersSectionVariants
        XCTAssertEqual(parameterSections[.swift]?.parameters.map(\.name), ["one", "two", "three", "four", "five"])
        
        let parameterSectionTranslator = ParametersSectionTranslator()
        var renderNodeTranslator = RenderNodeTranslator(context: context, bundle: bundle, identifier: reference)
        var renderNode = renderNodeTranslator.visit(symbol) as! RenderNode
        let translatedParameters = parameterSectionTranslator.translateSection(for: symbol, renderNode: &renderNode, renderNodeTranslator: &renderNodeTranslator)
        let paramsRenderSection = translatedParameters?.defaultValue?.section as! ParametersRenderSection
        
        // Different locales treat capitalization of hyphenated words differently (e.g. Upper-Cased vs Upper-cased).
        let hyphenatedString = "upper-cased"
        let hyphenatedCapitalizedResult = hyphenatedString.localizedCapitalized + " first parameter description."
        
        XCTAssertEqual(paramsRenderSection.parameters.map(\.content), [
            [SwiftDocC.RenderBlockContent.paragraph(SwiftDocC.RenderBlockContent.Paragraph(inlineContent: [SwiftDocC.RenderInlineContent.text(hyphenatedCapitalizedResult)]))],
            [SwiftDocC.RenderBlockContent.paragraph(SwiftDocC.RenderBlockContent.Paragraph(inlineContent: [SwiftDocC.RenderInlineContent.text("The second parameter has extra white spaces")]))],
            [SwiftDocC.RenderBlockContent.paragraph(SwiftDocC.RenderBlockContent.Paragraph(inlineContent: [SwiftDocC.RenderInlineContent.text("inValid third parameter will not be capitalized")]))],
            [SwiftDocC.RenderBlockContent.paragraph(SwiftDocC.RenderBlockContent.Paragraph(inlineContent: [SwiftDocC.RenderInlineContent.text(""), SwiftDocC.RenderInlineContent.codeVoice(code: "code block"), SwiftDocC.RenderInlineContent.text(" will not be capitalized")]))],
            [SwiftDocC.RenderBlockContent.paragraph(SwiftDocC.RenderBlockContent.Paragraph(inlineContent: [SwiftDocC.RenderInlineContent.text("a`nother invalid capitalization")]))]])
    }
    
    func testIndividualParametersCapitalization() throws {
        let symbolGraph = makeSymbolGraph(
            docComment: """
            Some symbol description.

            - parameter one: upper-cased first parameter description.
            - parameter two:     the second parameter has extra white spaces
            - parameter three: inValid third parameter will not be capitalized
            - parameter four: `code block` will not be capitalized
            - parameter five: a`nother invalid capitalization
            """,
            parameters: ["one", "two", "three", "four", "five"]
        )
        
        let url = try createTempFolder(content: [
            Folder(name: "unit-test.docc", content: [
                JSONFile(name: "ModuleName.symbols.json", content: symbolGraph)
            ])
        ])
        let (_, bundle, context) = try loadBundle(from: url)
        
        XCTAssertEqual(context.problems.count, 0)
        
        let reference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/ModuleName/functionName(...)", sourceLanguage: .swift)
        let node = try context.entity(with: reference)
        let symbol = try XCTUnwrap(node.semantic as? Symbol)
        let parameterSections = symbol.parametersSectionVariants
        XCTAssertEqual(parameterSections[.swift]?.parameters.map(\.name), ["one", "two", "three", "four", "five"])
        
        let parameterSectionTranslator = ParametersSectionTranslator()
        var renderNodeTranslator = RenderNodeTranslator(context: context, bundle: bundle, identifier: reference)
        var renderNode = renderNodeTranslator.visit(symbol) as! RenderNode
        let translatedParameters = parameterSectionTranslator.translateSection(for: symbol, renderNode: &renderNode, renderNodeTranslator: &renderNodeTranslator)
        let paramsRenderSection = translatedParameters?.defaultValue?.section as! ParametersRenderSection
        
        // Different locales treat capitalization of hyphenated words differently (e.g. Upper-Cased vs Upper-cased).
        let hyphenatedString = "upper-cased"
        let hyphenatedCapitalizedResult = hyphenatedString.localizedCapitalized + " first parameter description."
        
        XCTAssertEqual(paramsRenderSection.parameters.map(\.content), [
            [SwiftDocC.RenderBlockContent.paragraph(SwiftDocC.RenderBlockContent.Paragraph(inlineContent: [SwiftDocC.RenderInlineContent.text(hyphenatedCapitalizedResult)]))],
            [SwiftDocC.RenderBlockContent.paragraph(SwiftDocC.RenderBlockContent.Paragraph(inlineContent: [SwiftDocC.RenderInlineContent.text("The second parameter has extra white spaces")]))],
            [SwiftDocC.RenderBlockContent.paragraph(SwiftDocC.RenderBlockContent.Paragraph(inlineContent: [SwiftDocC.RenderInlineContent.text("inValid third parameter will not be capitalized")]))],
            [SwiftDocC.RenderBlockContent.paragraph(SwiftDocC.RenderBlockContent.Paragraph(inlineContent: [SwiftDocC.RenderInlineContent.text(""), SwiftDocC.RenderInlineContent.codeVoice(code: "code block"), SwiftDocC.RenderInlineContent.text(" will not be capitalized")]))],
            [SwiftDocC.RenderBlockContent.paragraph(SwiftDocC.RenderBlockContent.Paragraph(inlineContent: [SwiftDocC.RenderInlineContent.text("a`nother invalid capitalization")]))]])
    }
    
    func testReturnsCapitalization() throws {
        let symbolGraph = makeSymbolGraph(
            docComment: """
            Some symbol description.

            - Returns: string, first word should have been capitalized here.
            """,
            parameters: []
        )
        
        let url = try createTempFolder(content: [
            Folder(name: "unit-test.docc", content: [
                JSONFile(name: "ModuleName.symbols.json", content: symbolGraph)
            ])
        ])
        let (_, bundle, context) = try loadBundle(from: url)
        
        XCTAssertEqual(context.problems.count, 0)
        
        let reference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/ModuleName/functionName(...)", sourceLanguage: .swift)
        let node = try context.entity(with: reference)
        let symbol = try XCTUnwrap(node.semantic as? Symbol)
        
        let returnsSectionTranslator = ReturnsSectionTranslator()
        var renderNodeTranslator = RenderNodeTranslator(context: context, bundle: bundle, identifier: reference)
        var renderNode = renderNodeTranslator.visit(symbol) as! RenderNode
        let translatedReturns = returnsSectionTranslator.translateSection(for: symbol, renderNode: &renderNode, renderNodeTranslator: &renderNodeTranslator)
        let returnsRenderSection = translatedReturns?.defaultValue?.section as! ContentRenderSection
        
        XCTAssertEqual(returnsRenderSection.content, [SwiftDocC.RenderBlockContent.heading(SwiftDocC.RenderBlockContent.Heading(level: 2, text: "Return Value", anchor: Optional("return-value"))), SwiftDocC.RenderBlockContent.paragraph(SwiftDocC.RenderBlockContent.Paragraph(inlineContent: [SwiftDocC.RenderInlineContent.text("String, first word should have been capitalized here.")]))])
    }
}
