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
    
    /// An addition operation.
    ///
    /// - Parameter value: The value to use in the addition.
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
    
    /// Returns a new patch operation with its value transformed using the given closure.
    ///
    /// If the patch operation doesn't have a value—for example, if it's a removal operation—the operation is returned unmodified.
    func map<TransformedValue>(
        _ transform: (Value) -> TransformedValue
    ) -> VariantPatchOperation<TransformedValue> {
        switch self {
        case .replace(let value):
            return VariantPatchOperation<TransformedValue>.replace(value: transform(value))
            
        case .add(let value):
            return VariantPatchOperation<TransformedValue>.add(value: transform(value))
            
        case .remove:
            return .remove
        }
    }
}

extension VariantCollection.Variant where Value: RangeReplaceableCollection {
    /// Applies the variant's patch operations to a given value and returns the patched value.
    ///
    /// - Parameter originalValue: The value that the variant will apply the patch operations to.
    /// - Returns: The value after applying all patch operations.
    func applyingPatchTo(_ originalValue: Value) -> Value {
        var result = originalValue
        for operation in patch {
            switch operation {
            case .replace(let newValue):
                result = newValue
            case .add(let newValue):
                result.append(contentsOf: newValue)
            case .remove:
                result.removeAll()
            }
        }
        return result
    }
}
