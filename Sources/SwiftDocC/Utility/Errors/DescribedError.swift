/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// An error that offers a plain-text error message.
public protocol DescribedError: Foundation.LocalizedError {
    /// A plain-text description of the error.
    var errorDescription: String { get }
}

public extension DescribedError {
    var errorDescription: String? {
        return (errorDescription as String)
    }
}

/// Shadows `Foundation.LocalizedError` in the current module
/// in order to promote usage of `DescribedError`.
internal protocol LocalizedError {
    // Use ``DescribedError`` instead of `LocalizedError`.
    var useDescribedErrorInstead: Void { get }
}
