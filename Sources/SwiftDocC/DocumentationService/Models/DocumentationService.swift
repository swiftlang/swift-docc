/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A service for processing documentation requests.
public protocol DocumentationService {
    /// The types of messages this service can handle.
    static var handlingTypes: [DocumentationServer.MessageType] { get }
    
    /// Processes the given documentation service message and calls the completion closure with the result as a message.
    func process(
        _ message: DocumentationServer.Message,
        completion: @escaping (DocumentationServer.Message) -> ()
    )
}
