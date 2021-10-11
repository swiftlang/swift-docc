/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

public extension DocumentationServer {
    /// Creates a server configured with default services.
    /// - Parameter qualityOfService: The quality of service for the server's dispatch queue.
    /// - Parameter peer: A peer server that can be used to perform outgoing requests.
    static func createDefaultServer(
        qualityOfService: DispatchQoS,
        peer: DocumentationServer?
    ) -> DocumentationServer {
        let server = DocumentationServer(qualityOfService: qualityOfService)
        server.register(service: ConvertService(linkResolvingServer: peer))
        return server
    }
}
