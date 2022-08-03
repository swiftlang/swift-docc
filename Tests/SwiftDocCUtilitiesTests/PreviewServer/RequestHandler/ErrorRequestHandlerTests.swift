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
@testable import SwiftDocCUtilities

import NIO
import NIOHTTP1

class ErrorRequestHandlerTests: XCTestCase {
    func testErrorHandlerDefault() throws {
        let request = makeRequestHead(uri: "/random-path")
        let factory = ErrorRequestHandler()
        let response = try responseWithPipeline(request: request, handler: factory)
        
        XCTAssertEqual(response.head?.status, .internalServerError)
        XCTAssertEqual(response.body, "Server Error")
    }

    func testErrorHandlerStatus() throws {
        let request = makeRequestHead(uri: "/random-path")
        let factory = ErrorRequestHandler(error: RequestError(status: .notFound))
        let response = try responseWithPipeline(request: request, handler: factory)
        
        XCTAssertEqual(response.head?.status, .notFound)
        XCTAssertEqual(response.body, "")
    }

    func testErrorHandlerCustomHeader() throws {
        let request = makeRequestHead(uri: "/random-path")
        let factory = ErrorRequestHandler(error: RequestError(status: .notFound), headers: [("Name", "Value")])
        let response = try responseWithPipeline(request: request, handler: factory)
        
        XCTAssertEqual(response.head?.status, .notFound)
        XCTAssertEqual(response.head?.headers["Name"], ["Value"])
        XCTAssertEqual(response.body, "")
    }

    func testErrorHandlerCustomHeaderCustomMessage() throws {
        let request = makeRequestHead(uri: "/random-path")
        let factory = ErrorRequestHandler(error: RequestError(status: .notFound, message: "Message!"))
        let response = try responseWithPipeline(request: request, handler: factory)
        
        XCTAssertEqual(response.head?.status, .notFound)
        XCTAssertEqual(response.body, "Message!")
    }
}
