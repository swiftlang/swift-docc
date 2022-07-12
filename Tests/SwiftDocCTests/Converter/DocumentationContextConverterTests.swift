/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import XCTest
@testable import SwiftDocC

class DocumentationContextConverterTests: XCTestCase {
    func testRenderNodesAreIdentical() throws {
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        
        // We'll use this to convert nodes ad-hoc
        let perNodeConverter = DocumentationNodeConverter(bundle: bundle, context: context)
        
        // We'll use these to convert nodes in bulk
        let renderContext = RenderContext(documentationContext: context, bundle: bundle)
        let bulkNodeConverter = DocumentationContextConverter(bundle: bundle, context: context, renderContext: renderContext)
        let encoder = JSONEncoder()
        
        for identifier in context.knownPages {
            let documentationNode = try XCTUnwrap(try context.entity(with: identifier))
            
            let renderNode1 = try perNodeConverter.convert(documentationNode, at: nil)
            let renderNode2 = try bulkNodeConverter.renderNode(for: documentationNode, at: nil)
            
            // Compare the two nodes are identical
            let data1 = try encoder.encode(renderNode1)
            let data2 = try encoder.encode(renderNode2)
            
            // We compare the length of the data which should allow for arrays where the element order isn't
            // significant to not produce false mismatches.
            XCTAssertEqual(data1.count, data2.count, "Encoded data didn't match for '\(identifier.absoluteString)'")
        }
    }
    
    func testSymbolLocationsAreOnlyIncludedWhenRequested() throws {
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        let renderContext = RenderContext(documentationContext: context, bundle: bundle)
        
        let fillIntroducedSymbolNode = try XCTUnwrap(
            context.symbolIndex["s:14FillIntroduced19macOSOnlyDeprecatedyyF"]
        )
        
        do {
            let documentationContextConverter = DocumentationContextConverter(
                bundle: bundle,
                context: context,
                renderContext: renderContext,
                emitSymbolSourceFileURIs: true)
            
            let renderNode = try XCTUnwrap(documentationContextConverter.renderNode(
                for: fillIntroducedSymbolNode, at: nil))
            XCTAssertEqual(renderNode.metadata.sourceFileURI, "file:///tmp/FillIntroduced.swift")
        }
        
        do {
            let documentationContextConverter = DocumentationContextConverter(
                bundle: bundle,
                context: context,
                renderContext: renderContext)
            
            let renderNode = try XCTUnwrap(documentationContextConverter.renderNode(
                for: fillIntroducedSymbolNode, at: nil))
            XCTAssertNil(renderNode.metadata.sourceFileURI)
        }
    }
    
    func testSymbolAccessLevelsAreOnlyIncludedWhenRequested() throws {
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        let renderContext = RenderContext(documentationContext: context, bundle: bundle)
        
        let fillIntroducedSymbolNode = try XCTUnwrap(
            context.symbolIndex["s:14FillIntroduced19macOSOnlyDeprecatedyyF"]
        )
        
        do {
            let documentationContextConverter = DocumentationContextConverter(
                bundle: bundle,
                context: context,
                renderContext: renderContext,
                emitSymbolAccessLevels: true
            )
            
            let renderNode = try XCTUnwrap(documentationContextConverter.renderNode(
                for: fillIntroducedSymbolNode, at: nil))
            XCTAssertEqual(renderNode.metadata.symbolAccessLevel, "public")
        }
        
        do {
            let documentationContextConverter = DocumentationContextConverter(
                bundle: bundle,
                context: context,
                renderContext: renderContext)
            
            let renderNode = try XCTUnwrap(documentationContextConverter.renderNode(
                for: fillIntroducedSymbolNode, at: nil))
            XCTAssertNil(renderNode.metadata.symbolAccessLevel)
        }
    }
}
