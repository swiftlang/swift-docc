/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A server that provides documentation-related services.
///
/// A documentation server receives ``Message`` values (encoded in JSON format) from clients and
/// forwards them to the appropriate ``DocumentationService`` depending on their
/// ``Message/type``. Documentation services declare what message types they handle and clients
/// register documentation services using the ``register(service:)`` function.
public class DocumentationServer: DocumentationServerProtocol {
    /// The services provided by the server.
    public var services: [DocumentationServer.MessageType: DocumentationService] = [:]
    
    /// Synchronization queue used for server operations.
    ///
    /// Operations on the server, for example registering new services or processing messages, are performed on this queue.
    public var synchronizationQueue: DispatchQueue
    
    /// The encoder used to encode outgoing messages.
    var encoder = JSONEncoder()
    
    /// The encoder used to decode outgoing messages.
    var decoder = JSONDecoder()
    
    /// Creates a server that processes messages using the given quality of service.
    public init(qualityOfService: DispatchQoS = .unspecified) {
        self.synchronizationQueue = DispatchQueue(
            label: "org.swift.docc.DocumentationServerOperationQueue",
            qos: qualityOfService
        )
    }
    
    /// Registers the given service.
    ///
    /// The server registers the service for its declared handling message types. Message types that
    /// already have a service registered will now use the new service instead.
    ///
    /// - Parameter service: The service to register.
    public func register<S : DocumentationService>(service: S) {
        synchronizationQueue.sync {
            for type in S.handlingTypes {
                self.services[type] = service
            }
        }
    }
    
    /// Processes the given message and responds using the given completion closure.
    ///
    /// The given message is expected to be a ``Message``, encoded as JSON. If the server cannot
    /// decode the message, the completion closure is called with a ``DocumentationServerError`` message of type
    /// "unsupported-message-type", encoded in JSON format.
    ///
    /// Once decoded, the server uses the message's type to determine a service that can handle the message. If no service can
    /// handle the message, the completion closure is called with a ``DocumentationServerError`` message of type
    /// "invalid-message", encoded in JSON format.
    ///
    /// - Parameters:
    ///   - message: The message the server should process.
    ///   - completion: The closure the server calls when the message has been processed.
    public func process(_ message: Data, completion: @escaping (Data) -> ()) {
        synchronizationQueue.async {
            do {
                let message = try self.decodeMessage(message)
                guard let service = self.services[message.type] else {
                    completion(self.encodedErrorMessage((.unsupportedMessageType())))
                    return
                }
                service.process(message, completion: { responseMessage in
                    do {
                        completion(try self.encode(responseMessage))
                    } catch {
                        completion(
                            self.encodedErrorMessage(
                                .invalidResponseMessage(underlyingError: error.localizedDescription)
                            )
                        )
                    }
                })
            } catch let error {
                completion(
                    self.encodedErrorMessage(
                        .invalidMessage(underlyingError: error.localizedDescription))
                )
            }
        }
    }
    
    /// Decodes the given documentation service message.
    ///
    /// The documentation service message is expected to be encoded in JSON format.
    func decodeMessage(_ encodedMessage: Data) throws -> Message {
        try decoder.decode(Message.self, from: encodedMessage)
    }
    
    /// Encodes the given value.
    ///
    /// The value is encoded in JSON format.
    func encode<Value: Encodable>(_ value: Value) throws -> Data {
        try encoder.encode(value)
    }
    
    /// Creates a documentation service message that contains the given error as payload.
    /// 
    /// - Parameter error: The error to be included in the payload of the documentation service message.
    /// - Returns: A ``Message`` with the given error as the payload.
    func encodedErrorMessage(_ error: DocumentationServerError) -> Data {
        // Force trying because encoding known messages should never fail.
        try! encode(Message(type: .error, payload: try! encode(error)))
    }
}
