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

class AnyCommunicationBridgeTests: XCTestCase {

    struct TestCommunicationBridge: CommunicationBridge {
        var onReceiveMessage: ((Message) -> ())?

        func send(_ message: Message, using handler: (Message) -> ()) throws {
            handler(message)
        }
    }

    func testFunctionsAreBeingDelegated() throws {
        let expectedMessage = Message.requestCodeColors()

        let testBridge = AnyCommunicationBridge(
            TestCommunicationBridge(
                onReceiveMessage: { message in
                    XCTAssertEqual(message.type, expectedMessage.type)
                    XCTAssertEqual(message.identifier, expectedMessage.identifier)
                    XCTAssertNil(message.data)
                }
            )
        )

        testBridge.onReceiveMessage!(expectedMessage)

        func sendHandler(message: Message) {
            XCTAssertEqual(message.type, expectedMessage.type)
            XCTAssertEqual(message.identifier, expectedMessage.identifier)
            XCTAssertNil(message.data)
        }

        try testBridge.send(expectedMessage, using: sendHandler)
    }
}
