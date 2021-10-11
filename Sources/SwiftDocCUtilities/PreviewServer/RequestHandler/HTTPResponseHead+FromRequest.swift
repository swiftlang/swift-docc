/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import NIOHTTP1

extension HTTPResponseHead {
    
    /// Creates a new response head to answer a given request.
    ///
    /// Handles the difference between HTTP versions 1.0 and 1.1 for the Connection HTTP header.
    init(matchingRequestHead request: HTTPRequestHead, status: HTTPResponseStatus, headers: HTTPHeaders = HTTPHeaders()) {
        self.init(version: request.version, status: status, headers: headers)
        
        let connectionHeaders = headers[canonicalForm: "connection"].map { $0.lowercased() }

        if !connectionHeaders.contains("keep-alive") && !connectionHeaders.contains("close") {
            // the user hasn't pre-set either 'keep-alive' or 'close', so we might need to add headers

            switch (request.isKeepAlive, request.version.major, request.version.minor) {
            case (true, 1, 0):
                // HTTP/1.0 and the request has 'Connection: keep-alive', we should mirror that
                self.headers.add(name: "Connection", value: "keep-alive")
            case (false, 1, let n) where n >= 1:
                // HTTP/1.1 (or treated as such) and the request has 'Connection: close', we should mirror that
                self.headers.add(name: "Connection", value: "close")
            default: break
            }
        }
    }
}
