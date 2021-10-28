/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A utility type for applying JSON patches.
///
/// Use this type to apply ``JSONPatchOperation`` values onto JSON.
public struct JSONPatchApplier {
    /// Creates a new JSON patch applier.
    public init() {}
    
    /// Applies the given patch onto the given JSON data.
    ///
    /// - Parameters:
    ///   - patch: The patch to apply.
    ///   - jsonData: The data on which to apply the patch.
    /// - Returns: The JSON data with the patch applied.
    /// - Throws: This function throws an ``Error`` if the application was not successful.
    public func apply(_ patch: JSONPatch, to jsonData: Data) throws -> Data {
        let json = try JSONDecoder().decode(JSON.self, from: jsonData)
        
        // Apply each patch operation one-by-one to the JSON, and throw an error if one of the patches could not
        // be applied.
        let appliedJSON = try patch.reduce(json) { json, operation in
            guard let newValue = try apply(operation, to: json, originalPointer: operation.pointer) else {
                // If the application of the operation onto the top-level JSON element results in a `nil` value (i.e.,
                // the entire value was removed), throw an error since this is not supported.
                throw Error.invalidPatch
            }
            return newValue
        }
        
        return try JSONEncoder().encode(appliedJSON)
    }
    
    private func apply(_ operation: JSONPatchOperation, to json: JSON, originalPointer: JSONPointer) throws -> JSON? {
        // If the pointer has no path components left, this is the value we need to update.
        guard let component = operation.pointer.pathComponents.first else {
            switch operation {
            case .replace(_, let value):
                if let json = value.value as? JSON {
                    return json
                } else {
                    // If the value is not encoded as a `JSON` value already, convert it.
                    let data = try JSONEncoder().encode(value)
                    return try JSONDecoder().decode(JSON.self, from: data)
                }
            case .remove(_):
                return nil
            }
        }
        
        let nextOperation = operation.removingPointerFirstPathComponent()
        
        // Traverse the JSON element and apply the operation recursively.
        switch json {
        case .dictionary(var dictionary):
            // If the element is a dictionary, modify the value at the key indicated by the current path component
            // of the pointer.
            guard let value = dictionary[component] else {
                throw Error.invalidObjectPointer(
                    originalPointer,
                    component: component,
                    availableObjectKeys: dictionary.keys
                )
            }
            
            dictionary[component] = try apply(nextOperation, to: value, originalPointer: originalPointer)
            
            return .dictionary(dictionary)
        case .array(var array):
            // If the element is an array, modify the value at the index indicated by the current integer path
            // component of the pointer.
            guard let index = Int(component), array.indices.contains(index) else {
                throw Error.invalidArrayPointer(
                    originalPointer,
                    index: component,
                    arrayCount: array.count
                )
            }
            
            if let newValue = try apply(nextOperation, to: array[index], originalPointer: originalPointer) {
                array[index] = newValue
            } else {
                array.remove(at: index)
            }
            
            return .array(array)
        default:
            // The pointer is invalid because it has a non-empty path component, but the JSON element is not
            // traversable, i.e., it's a number, string, boolean, or null value.
            throw Error.invalidValuePointer(
                originalPointer,
                component: component,
                jsonValue: String(describing: json)
            )
        }
    }
    
    /// An error that occured during the application of a JSON patch.
    public enum Error: DescribedError {
        /// An error indicating that the pointer of a patch operation is invalid for a JSON object.
        ///
        /// - Parameters:
        ///     - component: The component that's causing the pointer to be invalid in the JSON object.
        ///     - availableKeys: The keys available in the JSON object.
        case invalidObjectPointer(JSONPointer, component: String, availableKeys: [String])
        
        
        /// An error indicating that the pointer of a patch operation is invalid for a JSON object.
        ///
        /// - Parameters:
        ///     - component: The component that's causing the pointer to be invalid in the JSON object.
        ///     - availableObjectKeys: The keys available in the JSON object.
        public static func invalidObjectPointer<Keys: Collection>(
            _ pointer: JSONPointer,
            component: String,
            availableObjectKeys: Keys
        ) -> Self where Keys.Element == String {
            return .invalidObjectPointer(pointer, component: component, availableKeys: Array(availableObjectKeys))
        }
        
        /// An error indicating that the pointer of a patch operation is invalid for a JSON array.
        ///
        /// - Parameters:
        ///     - index: The index component that's causing the pointer to be invalid in the JSON array.
        ///     - arrayCount: The size of the JSON array.
        case invalidArrayPointer(JSONPointer, index: String, arrayCount: Int)
        
        /// An error indicating that the pointer of a patch operation is invalid for a JSON value.
        ///
        /// - Parameters:
        ///     - component: The component that's causing the pointer to be invalid, since the JSON element is a non-traversable value.
        ///     - jsonValue: The string-encoded description of the JSON value.
        case invalidValuePointer(JSONPointer, component: String, jsonValue: String)
        
        /// An error indicating that a patch operation is invalid.
        case invalidPatch
        
        public var errorDescription: String {
            switch self {
            case .invalidObjectPointer(let pointer, let component, let availableKeys):
                return """
                Invalid dictionary pointer '\(pointer)'. The component '\(component)' is not valid for the object with \
                keys \(availableKeys.sorted().map(\.singleQuoted).list(finalConjunction: .and)).
                """
            case .invalidArrayPointer(let pointer, let index, let arrayCount):
                return """
                Invalid array pointer '\(pointer)'. The index '\(index)' is not valid for array of \(arrayCount) \
                elements.
                """
            case .invalidValuePointer(let pointer, let component, let jsonValue):
                return """
                Invalid value pointer '\(pointer)'. The component '\(component)' is not valid for the non-traversable \
                value '\(jsonValue)'.
                """
            case .invalidPatch:
                return "Invalid patch"
            }
        }
    }
}
