/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

extension Dictionary where Key == String, Value == Any {
    /// Returns the value for the given key decoded as the requested type.
    func decode<T>(_ expectedType: T.Type, forKey key: String) throws -> T where T : Decodable {
        guard let value = self[key] else {
            throw TypedValueError.missingValue(key: key)
        }
        
        // First attempt to just cast the value as the requested type
        if let castedValue = value as? T {
            return castedValue
        }
        
        // If that fails, attempt to decode it. Since we know T is Decodable,
        // even if the given value cannot be _directly_ cast to T, it's possible
        // that it can be decoded as T.
        //
        // For example, the String "1.0.0" cannot be cast directly to `Version`,
        // but it can be _decoded_ to `Version`.
        do {
            let data = try JSONSerialization.data(withJSONObject: value, options: .fragmentsAllowed)
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            // Decoding failed as well, throw an error indicating that we were given the wrong type.
            throw TypedValueError.wrongType(key: key, expected: T.self, actual: type(of: value))
        }
    }
    
    /// Returns the value for the given key decoded as the requested type, if present.
    func decodeIfPresent<T>(_ expectedType: T.Type, forKey key: String) throws -> T? where T : Decodable {
        guard self.keys.contains(key) else {
            return nil
        }
        return try decode(expectedType, forKey: key)
    }
}

/// A set of errors related to reading dictionary values as specific types.
enum TypedValueError: DescribedError {
    /// The requested value is missing.
    case missingValue(key: String)
    /// The requested value is of the wrong type.
    case wrongType(key: String, expected: Any.Type, actual: Any.Type)
    /// One or more required ``DocumentationBundle.Info.Key``s are missing.
    case missingRequiredKeys([DocumentationBundle.Info.CodingKeys])
    
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
                
                """
                
                if let argumentName = key.argumentName {
                    errorMessage += """
                    Use the \(argumentName.singleQuoted) argument or add \(key.rawValue.singleQuoted) to the bundle Info.plist.
                    """
                } else {
                    errorMessage += """
                    Add \(key.rawValue.singleQuoted) to the bundle Info.plist.
                    """
                }
            }
            
            return errorMessage
        }
    }
}
