/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import XCTest
@testable import SwiftDocC
import SwiftDocCTestUtilities

class RenderNodeDiffingTests: XCTestCase {
    func testDiffingKind() throws {
        
        let renderNodeArticle = RenderNode(
            identifier: .init(bundleIdentifier: "com.bundle", path: "/", sourceLanguage: .swift),
            kind: .article
        )
        let renderNodeSymbol = RenderNode(
            identifier: .init(bundleIdentifier: "com.bundle", path: "/", sourceLanguage: .swift),
            kind: .symbol
        )
        
        let diffs = renderNodeSymbol.difference(from: renderNodeArticle, at: [])
        let expectedDiff = [ JSONPatchOperation.replace(pointer: JSONPointer(from: [RenderNode.CodingKeys.kind]), encodableValue: RenderNode.Kind.symbol) ]
        
        XCTAssert(diffs == expectedDiff)
    }
    
    func testDiffingNewAbstract() throws {
        
        var renderNodeV1 = RenderNode(
            identifier: .init(bundleIdentifier: "com.bundle", path: "/", sourceLanguage: .swift),
            kind: .symbol
        )

        let renderNodeV2 = RenderNode(
            identifier: .init(bundleIdentifier: "com.bundle", path: "/", sourceLanguage: .swift),
            kind: .symbol
        )
        renderNodeV1.abstract = [RenderInlineContent.text("Testing new abstract")]
        
        let diffs = renderNodeV1.difference(from: renderNodeV2, at: [])
        let expectedDiff = [ JSONPatchOperation.add(pointer: JSONPointer(from: [RenderNode.CodingKeys.abstract]), encodableValue: [RenderInlineContent.text("Testing new abstract")]) ]

        XCTAssert(diffs == expectedDiff)
    }
    
//    func testDiffingExistingAbstract() throws {
//        
//        var renderNodeV1 = RenderNode(
//            identifier: .init(bundleIdentifier: "com.bundle", path: "/", sourceLanguage: .swift),
//            kind: .symbol
//        )
//
//        var renderNodeV2 = RenderNode(
//            identifier: .init(bundleIdentifier: "com.bundle", path: "/", sourceLanguage: .swift),
//            kind: .symbol
//        )
//        renderNodeV2.abstract = [RenderInlineContent.text("This is the fancy new version of the abstract")]
//        renderNodeV1.abstract = [RenderInlineContent.text("Testing abstract")]
//        
//        let diffs = renderNodeV1.difference(from: renderNodeV2, at: [])
//        let expectedDiff = [ JSONPatchOperation.replace(pointer: JSONPointer(from: [RenderNode.CodingKeys.abstract]), encodableValue: "Testing abstract") ]
//        print(diffs)
//        XCTAssert(diffs == expectedDiff)
//    }
    
    func testDiffingFromFile() throws {
        
        let renderNodev1URL = Bundle.module.url(
            forResource: "RenderNodev1", withExtension: "json", subdirectory: "Test Resources")!
        let renderNodev2URL = Bundle.module.url(
            forResource: "RenderNodev2", withExtension: "json", subdirectory: "Test Resources")!
        
        let datav1 = try Data(contentsOf: renderNodev1URL)
        let datav2 = try Data(contentsOf: renderNodev2URL)
        let symbolv1 = try RenderNode.decode(fromJSON: datav1)
        let symbolv2 = try RenderNode.decode(fromJSON: datav2)
        
        let encoder = RenderJSONEncoder.makeEncoder()
        encoder.userInfoPreviousNode = symbolv1
        let encodedNode = try encoder.encode(symbolv2)
        print(String(data: encodedNode, encoding: .utf8)!)
    }
}

