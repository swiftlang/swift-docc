/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2024 Apple Inc. and the Swift project authors
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
    /// If the patch operation doesn't have a value---for example, if it's a removal operation---the operation is returned unmodified.
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

// The synthesized implementation is sufficient for this conformance.
extension VariantPatchOperation: Equatable where Value: Equatable {}

// MARK: Applying patches

/// A type that can be transformed by incrementally applying variant patch operations.
protocol VariantCollectionPatchable {
    /// Apply an "add" patch operation to the value
    mutating func add(_ other: Self)
    /// Apply a "remove" patch operation to the value
    mutating func remove()
}

extension Optional: VariantCollectionPatchable where Wrapped: VariantCollectionPatchable {
    mutating func add(_ other: Wrapped?) {
        guard var wrapped, let other else { return }
        wrapped.add(other)
        self = wrapped
    }
    
    mutating func remove() {
        self = nil
    }
}

extension Array: VariantCollectionPatchable {
    mutating func add(_ other: [Element]) {
        append(contentsOf: other)
    }
    
    mutating func remove() {
        self.removeAll()
    }
}

extension String: VariantCollectionPatchable {
    mutating func add(_ other: String) {
        append(contentsOf: other)
    }
    
    mutating func remove() {
        self.removeAll()
    }
}

extension VariantCollection where Value: VariantCollectionPatchable {
    /// Returns the transformed value after applying the patch operations for all variants that match the given source language to the default value.
    /// - Parameters:
    ///   - language: The source language that determine what variant's patches to apply to the default value.
    /// - Returns: The transformed value, or the default value if no variants match the given source language.
    func value(for language: SourceLanguage) -> Value {
        applied(to: defaultValue, for: [.interfaceLanguage(language.id)])
    } 
    
    /// Returns the transformed value after applying the patch operations for all variants that match the given traits to the default value.
    /// - Parameters:
    ///   - traits: The traits that determine what variant's patches to apply to the default value.
    /// - Returns: The transformed value, or the default value if no variants match the given traits.
    func value(for traits: [RenderNode.Variant.Trait]) -> Value {
        applied(to: defaultValue, for: traits)
    }
    
    /// Returns the transformed value after applying the patch operations for all variants that match the given traits to the original value.
    /// - Parameters:
    ///   - originalValue: The original value to transform.
    ///   - traits: The traits that determine what variant's patches to apply to the original value.
    /// - Returns: The transformed value, or the original value if no variants match the given traits.
    func applied(to originalValue: Value, for traits: [RenderNode.Variant.Trait]) -> Value {
        var patchedValue = originalValue
        for variant in variants where variant.traits == traits {
            for patch in variant.patch {
                switch patch {
                case .replace(let value):
                    patchedValue = value
                case .add(let value):
                    patchedValue.add(value)
                case .remove:
                    patchedValue.remove()
                }
            }
        }
        return patchedValue
    }
}
