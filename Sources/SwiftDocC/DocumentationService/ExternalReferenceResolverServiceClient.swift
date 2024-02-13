/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SymbolKit

/// A client for performing link resolution requests to a documentation server.
class ExternalReferenceResolverServiceClient {
    /// The maximum amount of time, in seconds, to await a response from the external reference resolver.
    static let responseTimeout = 5
    
    /// The documentation server to which link resolution requests should be sent to.
    var server: DocumentationServer
    
    /// The identifier of the convert request that initiates the reference resolution requests.
    var convertRequestIdentifier: String?
    
    /// The queue on which server messages are awaited.
    var serverResponseQueue = DispatchQueue(
        label: "org.swift.docc.service-external-reference-resolver",
        qos: .unspecified
    )
    
    private var encoder = JSONEncoder()
    
    init(server: DocumentationServer, convertRequestIdentifier: String?) {
        self.server = server
        self.convertRequestIdentifier = convertRequestIdentifier
    }
    
    func sendAndWait<Request: Codable>(_ request: Request) throws -> Data {
        let resultGroup = DispatchGroup()
        
        var result: Result<Data?, Error>?
        
        resultGroup.enter()
        
        serverResponseQueue.async { [weak self] in
            guard let self = self else { return }
            
            do {
                let encodedRequest = try self.encoder.encode(
                    ConvertRequestContextWrapper(
                        convertRequestIdentifier: self.convertRequestIdentifier,
                        payload: request
                    )
                )
                
                let message = DocumentationServer.Message(
                    type: "resolve-reference",
                    clientName: "SwiftDocC",
                    payload: encodedRequest
                )
                
                let messageData = try self.encoder.encode(message)
                
                self.server.process(messageData) { responseData in
                    defer { resultGroup.leave() }
                    
                    result = self.decodeMessage(responseData).map(\.payload)
                }
            } catch {
                result = .failure(.failedToEncodeRequest(underlyingError: error))
                resultGroup.leave()
            }
        }
        
        guard resultGroup.wait(timeout: .now() + .seconds(Self.responseTimeout)) == .success else {
            logError(.timeout)
            throw Error.timeout
        }
        
        switch result {
        case .success(let data?)?:
            return data
        case .success?:
            logError(.missingPayload)
            throw Error.missingPayload
        case .failure(let error):
            logError(error)
            throw error
        case nil:
            logError(.unknownError)
            throw Error.unknownError
        }
    }
    
    private func decodeMessage(_ data: Data) -> Result<DocumentationServer.Message, Error> {
        Result {
            try JSONDecoder().decode(DocumentationServer.Message.self, from: data)
        }.mapError { error in
            .invalidResponse(underlyingError: error)
        }.flatMap { message in
            message.type == "resolve-reference-response" ?
                .success(message) :
                .failure(.invalidResponseType(receivedType: message.type.rawValue))
        }
    }
    
    private func logError(_ error: Error) {
        switch error {
        case .failedToEncodeRequest(let underlyingError):
            xlog("Unable to encode request for request: \(underlyingError.localizedDescription)")
        case .invalidResponse(let underlyingError):
            xlog("Received invalid response when resolving request: \(underlyingError.localizedDescription)")
        case .invalidResponseType(let receivedType):
            xlog("Received unknown response type when resolving request: '\(receivedType)'")
        case .missingPayload:
            xlog("Received nil payload when resolving request.")
        case .timeout:
            xlog("Timed out when resolving request.")
        case .receivedErrorFromServer(let message):
            xlog("Received error from server when resolving request: \(message)")
        case .unknownError:
            xlog("Unknown error when resolving request.")
        }
    }

    enum Error: Swift.Error {
        case failedToEncodeRequest(underlyingError: Swift.Error)
        case invalidResponse(underlyingError: Swift.Error)
        case invalidResponseType(receivedType: String)
        case missingPayload
        case timeout
        case receivedErrorFromServer(message: String)
        case unknownError
    }
}
