/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
import SwiftDocC

class DocumentationServer_MessageTypeTests: XCTestCase {
    func testMessageTypeDebugDescription() {
        XCTAssertEqual(
            DocumentationServer.MessageType(rawValue: "value").debugDescription,
            "MessageType(value)"
        )
    }
    
    func testErrorMessageType() {
        XCTAssertEqual(DocumentationServer.MessageType.error.rawValue, "error")
    }
}
