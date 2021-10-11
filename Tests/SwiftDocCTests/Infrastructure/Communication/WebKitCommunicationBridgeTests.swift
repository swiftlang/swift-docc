/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
#if canImport(WebKit)
import WebKit
#endif
import XCTest
@testable import SwiftDocC

class WebKitCommunicationBridgeTests: XCTestCase {
    func testMessagesCanBeSent() throws {
        #if canImport(WebKit)
        try assertMessageIsSent(message: .rendered())
        try assertMessageIsSent(message: .codeColors(CodeColors.testValue))
        #endif
    }
    
    func testMessagesCanBeReceived() throws {
        #if canImport(WebKit)
        let message = Message.codeColors(CodeColors.testValue)
        
        let userContentController = WKUserContentController()
        let expectation = XCTestExpectation(description: "Message has been received.")
        let bridge = WebKitCommunicationBridge(with: userContentController) { _message in
            XCTAssertEqual(message.type.rawValue, _message.type.rawValue)
            XCTAssertEqual(message.identifier, _message.identifier)
            XCTAssertEqual(message.data?.value as! CodeColors, _message.data?.value as! CodeColors)
            expectation.fulfill()
        }
        
        let json = try JSONSerialization.jsonObject(with: try! JSONEncoder().encode(message))
        bridge.onReceiveMessageData(messageBody: json)
        
        wait(for: [expectation], timeout: 5.0)
        #endif
    }
    
    func assertMessageIsSent(message: Message) throws {
        #if canImport(WebKit)
        let encodedMessage = try! JSONEncoder().encode(message)
        let messageJSON = String(data: encodedMessage, encoding: .utf8)!
        
        let evaluateJavaScript: (String, ((Any?, Error?) -> ())?) -> () = { string, _ in
            XCTAssertEqual(string, "window.bridge.receive(JSON.parse(`\(messageJSON)`))")
        }
        
        let bridge = WebKitCommunicationBridge()
        XCTAssertNoThrow(try bridge.send(message, using: evaluateJavaScript))
        #endif
    }
}

private extension CodeColors {
    static var testValue: CodeColors {
        return .init(
            background: SRGBColor(red: UInt8(1), green: UInt8(2), blue: UInt8(3), alpha: 0.1),
            text: SRGBColor(red: UInt8(4), green: UInt8(5), blue: UInt8(6), alpha: 0.2),
            keyword: SRGBColor(red: UInt8(7), green: UInt8(8), blue: UInt8(9), alpha: 0.3),
            identifier: SRGBColor(red: UInt8(10), green: UInt8(11), blue: UInt8(12), alpha: 0.4),
            parameterName: SRGBColor(red: UInt8(13), green: UInt8(14), blue: UInt8(15), alpha: 0.5),
            numberLiteral: SRGBColor(red: UInt8(16), green: UInt8(17), blue: UInt8(18), alpha: 0.6),
            stringLiteral: SRGBColor(red: UInt8(19), green: UInt8(20), blue: UInt8(21), alpha: 0.7),
            typeAnnotation: SRGBColor(red: UInt8(22), green: UInt8(23), blue: UInt8(24), alpha: 0.8),
            docComment: SRGBColor(red: UInt8(25), green: UInt8(26), blue: UInt8(27), alpha: 0.9),
            docCommentField: SRGBColor(red: UInt8(28), green: UInt8(29), blue: UInt8(30), alpha: 0.91),
            comment: SRGBColor(red: UInt8(31), green: UInt8(32), blue: UInt8(33), alpha: 0.92),
            commentURL: SRGBColor(red: UInt8(34), green: UInt8(35), blue: UInt8(36), alpha: 0.93),
            buildConfigKeyword: SRGBColor(red: UInt8(37), green: UInt8(38), blue: UInt8(39), alpha: 0.94),
            buildConfigId: SRGBColor(red: UInt8(40), green: UInt8(41), blue: UInt8(42), alpha: 0.95)
        )
    }
}
