/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// Protocol for request-response based servers.
public protocol DocumentationServerProtocol {
    /// Processes the given message and responds using the given completion closure.
    func process(_ message: Data, completion: @escaping (Data) -> ())
}
