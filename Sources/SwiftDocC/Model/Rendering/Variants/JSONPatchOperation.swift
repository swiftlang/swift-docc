/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A patch to update a JSON value.
///
/// Values of this type follow the [JSON Patch](https://datatracker.ietf.org/doc/html/rfc6902) format.
public struct JSONPatchOperation: Codable {
    /// The operation to apply.
    public var operation: PatchOperation
    
    /// The pointer to the value to update.
    public var pointer: JSONPointer
    
    /// The new value to use when performing the update.
    public var value: AnyCodable
    
    /// Creates a patch to update a JSON value.
    ///
    /// Values of this type follow the [JSON Patch](https://datatracker.ietf.org/doc/html/rfc6902) format.
    ///
    /// - Parameters:
    ///   - operation: The operation to apply.
    ///   - pointer: The pointer to the value to update.
    ///   - value: The value to use when performing the update.
    public init(operation: PatchOperation, pointer: JSONPointer, value: AnyCodable) {
        self.operation = operation
        self.pointer = pointer
        self.value = value
    }
    
    /// Creates a patch to update a JSON value.
    ///
    /// Values of this type follow the [JSON Patch](https://datatracker.ietf.org/doc/html/rfc6902) format.
    ///
    /// - Parameters:
    ///   - variantPatch: The patch to apply.
    ///   - pointer: The pointer to the value to update.
    public init<Value>(variantPatch: VariantPatchOperation<Value>, pointer: JSONPointer) {
        self.operation = variantPatch.operation
        self.value = AnyCodable(variantPatch.value)
        self.pointer = pointer
    }
    
    public enum CodingKeys: String, CodingKey {
        case operation = "op"
        case pointer = "path"
        case value
    }
}
