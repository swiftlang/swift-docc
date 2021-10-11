/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
import SwiftDocC

class DocumentationServerTests: XCTestCase {
    func testCallsCorrectServiceForMessageType() throws {
        let server = DocumentationServer()
        
        server.register(service: TestServiceA())
        server.register(service: TestServiceB())
        
        let message1 = DocumentationServer.Message(type: "type-1", payload: nil)
        let message2 = DocumentationServer.Message(type: "type-2", payload: nil)
        let message3 = DocumentationServer.Message(type: "type-3", payload: nil)
        
        processAndAssert(server, withMessage: message1) { data in
            XCTAssertEqual(
                try self.decode(DocumentationServer.Message.self, from: data),
                TestServiceA.response
            )
        }
        
        processAndAssert(server, withMessage: message2) { data in
            XCTAssertEqual(
                try self.decode(DocumentationServer.Message.self, from: data),
                TestServiceA.response
            )
        }
        
        processAndAssert(server, withMessage: message3) { data in
            XCTAssertEqual(
                try self.decode(DocumentationServer.Message.self, from: data),
                TestServiceB.response
            )
        }
    }
    
    func testPassesTheMessageToTheService() throws {
        let server = DocumentationServer()
        
        let expectedMessage = DocumentationServer.Message(
            type: .init(rawValue: "type"),
            payload: "payload".data(using: .utf8)!
        )
        
        let expectation = XCTestExpectation()
        
        server.register(service: TestServiceA(onProcess: { message in
            XCTAssertEqual(message, expectedMessage)
            expectation.fulfill()
        }))
        
        XCTWaiter().wait(for: [expectation], timeout: 1.0)
    }
    
    func testReturnsInvalidMessageErrorWhenGivenAnInvalidMessage() throws {
        let server = DocumentationServer()
        
        processAndAssert(
            server,
            withMessageData: "this is not a valid message".data(using: .utf8)!,
            satisfies: { data in
                self.assertIsErrorMessageWithIdentifier("invalid-message", messageData: data)
            })
    }
    
    func testSynchronizationQueueHasGivenQualityOfService() {
        let server = DocumentationServer(qualityOfService: .userInitiated)
        XCTAssertEqual(server.synchronizationQueue.qos, .userInitiated)
    }
    
    func processAndAssert(
        _ server: DocumentationServer,
        withMessage message: DocumentationServer.Message,
        satisfies assertion: @escaping (Data) throws -> ()
    ) {
        processAndAssert(
            server,
            withMessageData: try! JSONEncoder().encode(message),
            satisfies: { data in
                try assertion(data)
            }
        )
    }
    
    func processAndAssert(
        _ server: DocumentationServer,
        withMessageData message: Data,
        satisfies assertion: @escaping (Data) throws -> ()
    ) {
        let expectation = XCTestExpectation(description: "Completion closure called")
        
        server.process(message, completion: { data in
            do {
                try assertion(data)
            } catch {
                XCTFail(error.localizedDescription)
            }
        })
        
        XCTWaiter().wait(for: [expectation], timeout: 1.0)
    }

    func assertIsErrorMessageWithIdentifier(_ identifier: String, messageData: Data) {
        do {
            let message = try self.decode(DocumentationServer.Message.self, from: messageData)
            XCTAssertEqual(message.type.rawValue, "error")
            guard let payload = message.payload else {
                XCTFail("Unexpectedly received nil payload")
                return
            }
            let errorPayload = try self.decode(DocumentationServerError.self, from: payload)
            XCTAssertEqual(errorPayload.identifier, "invalid-message")
        } catch {
            XCTFail("Unable to decode message data")
        }
    }
    
    func decode<Message : Decodable>(_ type: Message.Type, from data: Data) throws -> Message {
        try JSONDecoder().decode(type, from: data)
    }
    
    struct TestServiceA: DocumentationService {
        static var handlingTypes: [DocumentationServer.MessageType] = ["type-1", "type-2"]
        
        static let response = DocumentationServer.Message(
            type: "response", payload: "TestServiceA response".data(using: .utf8)!)
        
        var onProcess: ((DocumentationServer.Message) -> ())?
        
        func process(
            _ message: DocumentationServer.Message,
            completion: (DocumentationServer.Message) -> ()
        ) {
            onProcess?(message)
            completion(Self.response)
        }
    }
    
    struct TestServiceB: DocumentationService {
        static var handlingTypes: [DocumentationServer.MessageType] = ["type-3"]
        
        static let response = DocumentationServer.Message(
            type: "response", payload: "TestServiceB response".data(using: .utf8)!)
        
        func process(
            _ message: DocumentationServer.Message,
            completion: (DocumentationServer.Message) -> ()
        ) {
            completion(Self.response)
        }
    }
}
