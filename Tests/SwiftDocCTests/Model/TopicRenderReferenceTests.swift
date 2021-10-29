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

class TopicRenderReferenceTests: XCTestCase {
    
    let testReference = TopicRenderReference(
        identifier: RenderReferenceIdentifier("identifier"),
        titleVariants: VariantCollection<String>(
            defaultValue: "Default value",
            objectiveCValue: "Objective-C value"
        ),
        abstractVariants: .init(defaultValue: []),
        url: "",
        kind: .article,
        estimatedTime: nil
    )
    
    let encodedReference = """
        {
            "type": "topic",
            "identifier": "myIdentifier",
            "title": "myTitle",
            "url": "myURL"
        }
        """.data(using: .utf8)!
    
    // Test for backwards-compatibility.
    func testDecoderAcceptsMissingKindKey() {
        XCTAssertNoThrow(try JSONDecoder().decode(TopicRenderReference.self, from: encodedReference))
    }

    // Test for backwards-compatibility via an additional role for symbol references.
    func testDecodeTopicReferenceRole() {
        let json = """
        {
          "abstract" : [],
          "identifier" : "doc://org.swift.docc.example/mykit/myclass",
          "kind" : "symbol",
          "title" : "MyClass",
          "type" : "topic",
          "url" : "/documentation/mykit/myclass",
          "role" : "API Collection"
        }
        """.data(using: .utf8)!
        
        do {
            let reference = try JSONDecoder().decode(TopicRenderReference.self, from: json)
            XCTAssertEqual(reference.role, "API Collection")
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
    
    func testEmitsTitleVariantsDuringEncoding() throws {
        let encoder = RenderJSONEncoder.makeEncoder()
        _ = try encoder.encode(testReference)
        let variantOverrides = try XCTUnwrap(encoder.userInfo[.variantOverrides] as? VariantOverrides)
        XCTAssertEqual(variantOverrides.values.count, 1)
        
        let variantOverride = try XCTUnwrap(variantOverrides.values.first)
        XCTAssertEqual(variantOverride.traits, [.interfaceLanguage("objc")])
        
        XCTAssertEqual(variantOverride.patch.count, 1)
        let operation = try XCTUnwrap(variantOverride.patch.first)
        XCTAssertEqual(operation.operation, .replace)
        XCTAssertEqual(operation.pointer.pathComponents, ["title"])
    }
        
    func testSetsTitleDuringDecoding() throws {
        let reference = try JSONDecoder().decode(TopicRenderReference.self, from: encodedReference)
        XCTAssertEqual(reference.title, "myTitle")
    }
    
    func testSetsTitleVariantsDefaultValueWhenInstantiatingWithTitle() {
        let reference = TopicRenderReference(
            identifier: RenderReferenceIdentifier("identifier"),
            title: "myTitle",
            abstract: [],
            url: "",
            kind: .article,
            estimatedTime: nil
        )
        
        XCTAssertEqual(reference.titleVariants.defaultValue, "myTitle")
        XCTAssert(reference.titleVariants.variants.isEmpty)
    }
    
    func testSetsTitleVariantsDefaultValueWhenSettingTitle() {
        var reference = testReference
        reference.title = "another title"
        
        XCTAssertEqual(reference.titleVariants.defaultValue, "another title")
    }
    
    func testGetsTitleVariantsDefaultValueWhenGettingTitle() {
        XCTAssertEqual(testReference.title, "Default value")
    }
}
