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

class RESTExampleRenderSectionTests: XCTestCase {
    
    func testDecodingCodeExample() throws {
        let jsonData = """
        {
          "type" : "dictionaryExample",
          "example" : {
            "content" : [
              {
                "collapsible" : false,
                "code" : [
                  "lines of code",
                  "goes here..."
                ]
              }
            ]
          }
        }
        """.data(using: .utf8)!
        
        let content = try JSONDecoder().decode(RenderBlockContent.self, from: jsonData)
        guard case .dictionaryExample(let e) = content, e.summary == nil else {
            XCTFail("Unexpected type of RenderBlockContent. Expected a 'dictionaryExample'.")
            return
        }
        
        XCTAssertEqual(e.example.type, nil, "The `type` is optional in the specification and there's no value to decode in this test.")
        XCTAssertEqual(e.example.syntax, nil, "The `syntax` is optional in the specification and there's no value to decode in this test.")
        XCTAssertEqual(e.example.content, [
            CodeExample.Code(collapsible: false, code: ["lines of code", "goes here..."]),
        ])
    }
    
    func testDecodingExampleRenderNodeWithMissingCodeExampleType() throws {
        let jsonFile = Bundle.module.url(
            forResource: "link-button-render-node",
            withExtension: "json", subdirectory: "Test Resources")!
        let jsonData = try Data(contentsOf: jsonFile)
        
        let node = try JSONDecoder().decode(RenderNode.self, from: jsonData)
        
        guard let section = node.primaryContentSections[0] as? ContentRenderSection,
              case .dictionaryExample(let e) = section.content[3],
              e.summary == nil
        else {
            XCTFail("Unexpected type of RenderBlockContent. Expected a 'dictionaryExample'.")
            return
        }
        
        XCTAssertEqual(e.example.type, nil, "The `type` is optional in the specification and there's no value to decode in this test.")
    }
}
