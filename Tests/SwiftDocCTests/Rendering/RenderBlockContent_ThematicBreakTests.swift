/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024-2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

@testable import SwiftDocC
import Markdown
import XCTest

class RenderBlockContent_ThematicBreakTests: XCTestCase {
    func testThematicBreakCodability() throws {
        try assertRoundTripCoding(RenderBlockContent.thematicBreak)
    }
    
    func testThematicBreakIndexable() throws {
        let thematicBreak = RenderBlockContent.thematicBreak
        XCTAssertEqual("", thematicBreak.rawIndexableTextContent(references: [:]))
    }
    
    // MARK: - Thematic Break Markdown Variants
    func testThematicBreakVariants() async throws {
        let source = """

        ---
        ***
        ___

        """
        
        let markup = Document(parsing: source, options: .parseBlockDirectives)
        
        XCTAssertEqual(markup.childCount, 3)
        
        let (inputs, context) = try await testBundleAndContext()
        
        var contentTranslator = RenderContentCompiler(context: context, inputs: inputs, identifier: ResolvedTopicReference(bundleID: inputs.id, path: "/TestThematicBreak", sourceLanguage: .swift))
        
        let renderContent = try XCTUnwrap(markup.children.reduce(into: [], { result, item in result.append(contentsOf: contentTranslator.visit(item))}) as? [RenderBlockContent])
        let expectedContent: [RenderBlockContent] = [
            .thematicBreak,
            .thematicBreak,
            .thematicBreak
        ]
        
        XCTAssertEqual(expectedContent, renderContent)
    }
    
    func testThematicBreakVariantsWithSpaces() async throws {
        let source = """

        - - -
        * * *
        _ _ _

        """
        
        let markup = Document(parsing: source, options: .parseBlockDirectives)
        
        XCTAssertEqual(markup.childCount, 3)
        
        let (inputs, context) = try await testBundleAndContext()
        
        var contentTranslator = RenderContentCompiler(context: context, inputs: inputs, identifier: ResolvedTopicReference(bundleID: inputs.id, path: "/TestThematicBreak", sourceLanguage: .swift))
        
        let renderContent = try XCTUnwrap(markup.children.reduce(into: [], { result, item in result.append(contentsOf: contentTranslator.visit(item))}) as? [RenderBlockContent])
        let expectedContent: [RenderBlockContent] = [
            .thematicBreak,
            .thematicBreak,
            .thematicBreak
        ]
        
        XCTAssertEqual(expectedContent, renderContent)
    }
    
    func testThematicBreakMoreThanThreeCharacters() async throws {
        let source = """

        ----
        *****
        ______
        - - - - - -
        * * * * *
        _ _ _ _ _ _ _ _

        """
        
        let markup = Document(parsing: source, options: .parseBlockDirectives)
        
        XCTAssertEqual(markup.childCount, 6)
        
        let (inputs, context) = try await testBundleAndContext()
        
        var contentTranslator = RenderContentCompiler(context: context, inputs: inputs, identifier: ResolvedTopicReference(bundleID: inputs.id, path: "/TestThematicBreak", sourceLanguage: .swift))
        
        let renderContent = try XCTUnwrap(markup.children.reduce(into: [], { result, item in result.append(contentsOf: contentTranslator.visit(item))}) as? [RenderBlockContent])
        let expectedContent: [RenderBlockContent] = [
            .thematicBreak, .thematicBreak, .thematicBreak, .thematicBreak, .thematicBreak, .thematicBreak
        ]
        
        XCTAssertEqual(expectedContent, renderContent)
    }
}
