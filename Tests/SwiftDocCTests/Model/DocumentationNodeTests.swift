/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022-2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown
@testable import SwiftDocC
import SymbolKit
import XCTest

class DocumentationNodeTests: XCTestCase {
    func testH4AndUpAnchorSections() throws {
        let articleSource = """
        # Title

        ## Heading2

        ### Heading3
        
        #### Heading4
        
        ##### Heading5

        ###### Heading6
        """
        
        let article = Article(markup: Document(parsing: articleSource, options: []), metadata: nil, redirects: nil, options: [:])
        let node = try DocumentationNode(
            reference: ResolvedTopicReference(bundleID: "org.swift.docc", path: "/blah", sourceLanguage: .swift),
            article: article
        )
        XCTAssertEqual(node.anchorSections.count, 5)
        for (index, anchorSection) in node.anchorSections.enumerated() {
            let expectedTitle = "Heading\(index + 2)"
            XCTAssertEqual(anchorSection.title, expectedTitle)
            XCTAssertEqual(anchorSection.reference, node.reference.withFragment(expectedTitle))
        }
    }
    
    func testDocumentationKindToSymbolKindMapping() throws {
        // Testing all symbol kinds map to a documentation kind
        for symbolKind in SymbolGraph.Symbol.KindIdentifier.allCases {
            let documentationKind = DocumentationNode.kind(forKind: symbolKind)
            guard documentationKind != .unknown else {
                continue
            }
        
            let roundtrippedSymbolKind = DocumentationNode.symbolKind(for: documentationKind)
            XCTAssertEqual(symbolKind, roundtrippedSymbolKind)
        }
        
        // Testing that documentation kinds correctly map to a symbol kind
        // Sometimes there are multiple mappings from DocumentationKind -> SymbolKind, exclude those here and test them separately
        let documentationKinds = DocumentationNode.Kind.allKnownValues
            .filter({ ![.localVariable, .typeDef, .typeConstant, .`keyword`, .tag, .object].contains($0) })
        for documentationKind in documentationKinds {
            let symbolKind = DocumentationNode.symbolKind(for: documentationKind)
            if documentationKind.isSymbol {
                let symbolKind = try XCTUnwrap(DocumentationNode.symbolKind(for: documentationKind), "Expected a symbol kind equivalent for \(documentationKind)")
                let rountrippedDocumentationKind = DocumentationNode.kind(forKind: symbolKind)
                XCTAssertEqual(documentationKind, rountrippedDocumentationKind)
            } else {
                XCTAssertNil(symbolKind)
            }
        }
        
        // Test the exception documentation kinds
        XCTAssertEqual(DocumentationNode.symbolKind(for: .localVariable), .var)
        XCTAssertEqual(DocumentationNode.symbolKind(for: .typeDef), .typealias)
        XCTAssertEqual(DocumentationNode.symbolKind(for: .typeConstant), .typeProperty)
        XCTAssertEqual(DocumentationNode.symbolKind(for: .object), .dictionary)
    }

    func testWithMultipleSourceLanguages() throws {
        let sourceLanguages: Set<SourceLanguage> = [.swift, .objectiveC]
        // Test if articles contain all available source languages
        let article = Article(markup: Document(parsing: "# Title", options: []), metadata: nil, redirects: nil, options: [:])
        let articleNode = try DocumentationNode(
            reference: ResolvedTopicReference(bundleID: "org.swift.docc", path: "/blah", sourceLanguages: sourceLanguages),
            article: article
        )
        XCTAssertEqual(articleNode.availableSourceLanguages, sourceLanguages)

        // Test if symbols contain all available source languages
        let symbol = makeSymbol(id: "blah", kind: .class, pathComponents: ["blah"])
        let symbolNode = DocumentationNode(
            reference: ResolvedTopicReference(bundleID: "org.swift.docc", path: "/blah", sourceLanguages: sourceLanguages),
            symbol: symbol,
            platformName: nil,
            moduleReference: ResolvedTopicReference(bundleID: "org.swift.docc", path: "/blah", sourceLanguages: sourceLanguages),
            article: nil,
            engine: DiagnosticEngine()
        )
        XCTAssertEqual(symbolNode.availableSourceLanguages, sourceLanguages)
    }
}
