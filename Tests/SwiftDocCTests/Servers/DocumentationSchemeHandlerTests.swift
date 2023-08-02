/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import HTTPTypes

import XCTest
@testable import SwiftDocC

fileprivate let baseURL = URL(string: "test://")!
fileprivate let helloWorldHTML = "<html><header><title>Hello Title</title></header><body>Hello world</body></html>".data(using: .utf8)!

class DocumentationSchemeHandlerTests: XCTestCase {
    let templateURL = Bundle.module.url(
        forResource: "TestBundle", withExtension: "docc", subdirectory: "Test Bundles")!
    
    func testDocumentationSchemeHandler() {
        let topicSchemeHandler = DocumentationSchemeHandler(withTemplateURL: templateURL)
        
        let request = HTTPRequest(path: "/images/figure1.jpg")

        var (response, data) = topicSchemeHandler.response(to: request)
        XCTAssertNotNil(data)
        XCTAssertEqual(response.mimeType, "image/jpeg")
        
        let failingRequest = HTTPRequest(path: "/not/found.jpg")
        (response, data) = topicSchemeHandler.response(to: failingRequest)
        XCTAssertNil(data)
        
        topicSchemeHandler.fallbackHandler = { (request: HTTPRequest) -> (HTTPTypes.HTTPResponse, Data)? in
            let response = HTTPResponse(mimeType: "text/html", expectedContentLength: helloWorldHTML.count)
            return (response, helloWorldHTML)
        }
        
        (response, data) = topicSchemeHandler.response(to: failingRequest)
        XCTAssertEqual(data, helloWorldHTML)
        XCTAssertEqual(response.mimeType, "text/html")
    }
    
    func testSetData() {
        let topicSchemeHandler = DocumentationSchemeHandler(withTemplateURL: templateURL)
        
        let data = "hello!".data(using: .utf8)!
        topicSchemeHandler.setData(data: ["a.txt": data])
        
        XCTAssertEqual(
            topicSchemeHandler.response(
                to: HTTPRequest(path: "/data/a.txt")
            ).1,
            data
        )
        
        topicSchemeHandler.setData(data: ["b.txt": data])
        
        XCTAssertEqual(
            topicSchemeHandler.response(
                to: HTTPRequest(path: "/data/b.txt")
            ).1,
            data
        )
        
        XCTAssertNil(
            topicSchemeHandler.response(
                to: HTTPRequest(path: "/data/a.txt")
            ).1,
            "a.txt should have been deleted because we set the data to b.txt."
        )
    }
}
