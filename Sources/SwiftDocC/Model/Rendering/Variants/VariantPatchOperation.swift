/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A patch to update a render node value.
public struct VariantPatchOperation<Value: Codable>: Codable {
    /// The operation to apply.
    public var operation: PatchOperation
    
    /// The new value to use when performing the update.
    public var value: Value
    
    /// Creates a patch to update a render node value.
    ///
    /// - Parameters:
    ///   - operation: The operation to apply.
    ///   - value: The value to use when performing the update.
    public init(operation: PatchOperation, value: Value) {
        self.operation = operation
        self.value = value
    }
}

/// The patch operation to apply.
///
/// Values of this type follow the [JSON Patch](https://datatracker.ietf.org/doc/html/rfc6902) format.
public enum PatchOperation: String, Codable {
    /// A replacement operation.
    case replace
}
