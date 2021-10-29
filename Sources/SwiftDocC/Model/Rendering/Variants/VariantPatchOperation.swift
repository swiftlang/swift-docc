/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A patch to update a render node value.
public enum VariantPatchOperation<Value: Codable> {
    /// A replacement operation.
    ///
    /// - Parameter value: The value to use in the replacement.
    case replace(value: Value)
    
    case add(value: Value)
    
    /// A removal operation.
    case remove
    
    /// The operation to apply.
    public var operation: PatchOperation {
        switch self {
        case .replace(_):
            return .replace
        case .add(_):
            return .add
        case .remove:
            return .remove
        }
    }
}
