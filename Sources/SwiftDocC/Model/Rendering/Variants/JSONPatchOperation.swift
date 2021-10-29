/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A patch to update a JSON value.
public typealias JSONPatch = [JSONPatchOperation]

/// A patch operation to update a JSON value.
///
/// Values of this type follow the [JSON Patch](https://datatracker.ietf.org/doc/html/rfc6902) format.
///
/// ## Topics
///
/// ### Applying Patches
///
/// - ``JSONPatchApplier``
///
/// ### Operations
///
/// - ``PatchOperation``
public enum JSONPatchOperation: Codable {
    
    /// A replacement operation.
    ///
    /// - Parameters:
    ///     - pointer: The pointer to the value to replace.
    ///     - value: The value to use in the replacement.
    case replace(pointer: JSONPointer, value: AnyCodable)
    
    case add(pointer: JSONPointer, value: AnyCodable)
    
    /// A remove operation.
    ///
    /// - Parameter pointer: The pointer to the value to remove.
    case remove(pointer: JSONPointer)
    
    /// The pointer to the value to modify.
    public var pointer: JSONPointer {
        switch self {
        case .replace(let pointer, _):
            return pointer
        case .add(let pointer, _):
            return pointer
        case .remove(let pointer):
            return pointer
        }
    }
    
    /// The operation to apply.
    public var operation: PatchOperation {
        switch self {
        case .replace(_, _):
            return .replace
        case .add(_, _):
            return .add
        case .remove(_):
            return .remove
        }
    }
    
    /// Creates a patch to update a JSON value.
    ///
    /// Values of this type follow the [JSON Patch](https://datatracker.ietf.org/doc/html/rfc6902) format.
    ///
    /// - Parameters:
    ///   - variantPatchOperation: The patch to apply.
    ///   - pointer: The pointer to the value to update.
    public init<Value>(variantPatchOperation: VariantPatchOperation<Value>, pointer: JSONPointer) {
        switch variantPatchOperation {
        case .replace(let value):
            self = .replace(pointer: pointer, encodableValue: value)
        case .add(let value):
            self = .add(pointer: pointer, encodableValue: value)
        case .remove:
            self = .remove(pointer: pointer)
        }
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let operation = try container.decode(PatchOperation.self, forKey: .operation)
        
        let pointer = try container.decode(JSONPointer.self, forKey: .pointer)
        
        switch operation {
        case .replace:
            let value = try container.decode(AnyCodable.self, forKey: .value)
            self = .replace(pointer: pointer, value: value)
        case .add:
            let value = try container.decode(AnyCodable.self, forKey: .value)
            self = .add(pointer: pointer, value: value)
        case .remove:
            self = .remove(pointer: pointer)
        }
    }
    
    /// A replacement operation.
    ///
    /// - Parameters:
    ///     - pointer: The pointer to the value to replace.
    ///     - encodedValue: The value to use in the replacement.
    public static func replace(pointer: JSONPointer, encodableValue: Encodable) -> JSONPatchOperation {
        .replace(pointer: pointer, value: AnyCodable(encodableValue))
    }
    
    public static func add(pointer: JSONPointer, encodableValue: Encodable) -> JSONPatchOperation {
        .add(pointer: pointer, value: AnyCodable(encodableValue))
    }
    
    /// Returns the patch operation with the first path component of the pointer removed.
    public func removingPointerFirstPathComponent() -> Self {
        let newPointer = pointer.removingFirstPathComponent()
        switch self {
        case .replace(_, let value):
            return .replace(pointer: newPointer, value: value)
        case .add(_, let value):
            return .add(pointer: newPointer, value: value)
        case .remove(_):
            return .remove(pointer: newPointer)
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .replace(let pointer, let value):
            try container.encode(PatchOperation.replace, forKey: .operation)
            try container.encode(pointer, forKey: .pointer)
            try container.encode(value, forKey: .value)
        case .add(let pointer, let value):
            try container.encode(PatchOperation.add, forKey: .operation)
            try container.encode(pointer, forKey: .pointer)
            try container.encode(value, forKey: .value)
        case .remove(let pointer):
            try container.encode(PatchOperation.remove, forKey: .operation)
            try container.encode(pointer, forKey: .pointer)
        }
    }
    
    public enum CodingKeys: String, CodingKey {
        case operation = "op"
        case pointer = "path"
        case value
    }
}
