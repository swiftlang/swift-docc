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

class TopicRenderReferencesTests: XCTestCase {
    // Test for backwards-compatibility.
    func testDecoderAcceptsMissingKindKey() {
        let json = """
        {
            "type": "topic",
            "identifier": "myIdentifier",
            "title": "myTitle",
            "url": "myURL"
        }
        """.data(using: .utf8)!
        
        XCTAssertNoThrow(try JSONDecoder().decode(TopicRenderReference.self, from: json))
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
}
