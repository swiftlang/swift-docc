/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

// The WebKitCommunicationBridge is only available on platforms that support WebKit.
#if canImport(WebKit)
import Foundation
import WebKit

/// Provides bi-directional communication with a documentation renderer via JavaScript calls in a web view.
public struct WebKitCommunicationBridge: CommunicationBridge {
    public var onReceiveMessage: ((Message) -> ())? = nil
    
    /// Creates a communication bridge configured with the given controller to receive messages.
    /// - Parameter contentController: The controller that receives messages. Set to `nil` if  you need the communication bridge
    /// to ignore received messages.
    /// - Parameter onReceiveMessage: The handler that the communication bridge calls when it receives a message.
    /// Set to `nil` if you need the communication bridge to ignore received messages.
    public init(
        with contentController: WKUserContentController? = nil,
        onReceiveMessage: ((Message) -> ())? = nil
    ) {
        guard let onReceiveMessage = onReceiveMessage else {
            return
        }
        
        self.onReceiveMessage = onReceiveMessage
        
        contentController?.add(
            ScriptMessageHandler(onReceiveMessageData: onReceiveMessageData),
            name: "bridge"
        )
    }
    
    /// Sends a message using the given handler using the JSON format.
    /// - Parameter message: The message to send.
    /// - Parameter evaluateJavaScript: A handler that the communication bridge uses to send the given message, encoded in JSON.
    /// - Throws: Throws a ``CommunicationBridgeError/unableToEncodeMessage(_:underlyingError:)`` if the communication bridge could not encode the given message to JSON.
    public func send(
        _ message: Message,
        using evaluateJavaScript: (String, ((Any?, Error?) -> ())?) -> ()
    ) throws {
        do {
            let encodedMessage = try JSONEncoder().encode(message)
            let messageJSON = String(data: encodedMessage, encoding: .utf8)!
                // Escape backticks to avoid conflicting with JavaScript's template string syntax.
                .replacingOccurrences(of: "`", with: "\\`")
            
            evaluateJavaScript("window.bridge.receive(JSON.parse(`\(messageJSON)`))") { _, _ in }
        } catch let error {
            throw CommunicationBridgeError.unableToEncodeMessage(message, underlyingError: error)
        }
    }
    
    /// Called by the communication bridge when a message is received by a script message handler.
    ///
    /// Decodes the given WebKit script message as a ``Message``, and calls the ``onReceiveMessage`` handler.
    /// The communication bridge ignores unrecognized messages.
    /// - Parameter messageBody: The body of a `WKScriptMessage` provided by a `WKScriptMessageHandler`.
    func onReceiveMessageData(messageBody: Any) {
        
        // `WKScriptMessageHandler` transforms JavaScript objects to dictionaries.
        // Serialize the given dictionary to JSON data if possible, and decode the JSON data to a
        // message. If either of these steps fail, the communication-bridge ignores the message.
        guard let messageData = try? JSONSerialization.data(withJSONObject: messageBody),
            let message = try? JSONDecoder().decode(Message.self, from: messageData) else {
                return
        }
        
        onReceiveMessage?(message)
    }
    
    /// A WebKit script message handler for communication bridge messages.
    ///
    /// When receiving a message, the handler calls the given `onReceiveMessageData` handler with the message's body.
    private class ScriptMessageHandler: NSObject, WKScriptMessageHandler {
        var onReceiveMessageData: (Any) -> ()
        
        init(onReceiveMessageData: @escaping (Any) -> ()) {
            self.onReceiveMessageData = onReceiveMessageData
        }
        
        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            onReceiveMessageData(message.body)
        }
    }
}
#endif
