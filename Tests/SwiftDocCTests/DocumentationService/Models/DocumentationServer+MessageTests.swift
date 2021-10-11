/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
import SwiftDocC

class DocumentationServer_MessageTests: XCTestCase {
    func testGeneratesRandomIdentifierByDefault() {
        // Configure the random identifier generator to return a constant string.
        DocumentationServer.Message.randomIdentifierGenerator = { "random-identifier" }
        
        XCTAssertEqual(
            DocumentationServer.Message(type: .error, payload: nil).identifier,
            "random-identifier",
            """
            Expected the generated identifier to be the same as the one the random generator is \
            configured to use.
            """
        )
    }
    
    func testPrefixesClientNameToRandomIdentifier() {
        // Configure the random identifier generator to return a constant string.
        DocumentationServer.Message.randomIdentifierGenerator = { "random-identifier" }
        
        XCTAssertEqual(
            DocumentationServer.Message(
                type: "type", clientName: "the-client", payload: nil).identifier,
            "the-client-random-identifier",
            "Expected the generated identifier to have the client's name as a prefix."
        )
    }
}
