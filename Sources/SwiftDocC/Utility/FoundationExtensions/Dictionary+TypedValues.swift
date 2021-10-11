/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

extension Dictionary where Key == String, Value == Any {
    /// Reads the value for the given key as the requested type.
    ///
    /// - Parameter key: The key to read from the dictionary.
    /// - Throws: A ``TypedValueError/missingValue`` if the value is missing or ``TypedValueError/wrongType`` if the value has the wrong type.
    /// - Returns: The value for the specified key as the requested type.
    func typedValue<T>(forKey key: String) throws -> T {
        guard let value = self[key] else {
            throw TypedValueError.missingValue(key: key)
        }
        guard let castedValue = value as? T else {
            throw TypedValueError.wrongType(key: key, expected: T.self, actual: type(of: value))
        }
        return castedValue
    }
}

/// A set of errors related to reading dictionary values as specific types.
enum TypedValueError: DescribedError {
    /// The requested value is missing.
    case missingValue(key: String)
    /// The requested value is of the wrong type.
    case wrongType(key: String, expected: Any.Type, actual: Any.Type)
    /// One or more required ``DocumentationBundle.Info.Key``s are missing.
    case missingRequiredKeys([DocumentationBundle.Info.Key])
    
    var errorDescription: String {
        switch self {
        case let .missingValue(key):
            return "Missing value for key '\(key.singleQuoted)'."
        case let .wrongType(key, expected, actual):
            return "Type mismatch for key '\(key.singleQuoted)'. Expected '\(expected)', but found '\(actual)'."
        case .missingRequiredKeys(let keys):
            var errorMessage = ""
            
            for key in keys {
                errorMessage += """
                \n
                Missing value for \(key.rawValue.singleQuoted).
                Use the \(key.argumentName.singleQuoted) argument or add \(key.rawValue.singleQuoted) to the bundle Info.plist.
                """
            }
            
            return errorMessage
        }
    }
}
