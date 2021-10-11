/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

indirect enum JSON: Codable {
    case dictionary([String: JSON])
    case array([JSON])
    case string(String)
    case number(Double)
    case boolean(Bool)
    case null
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let boolValue = try? container.decode(Bool.self) {
            self = .boolean(boolValue)
        } else if let numericValue = try? container.decode(Double.self) {
            self = .number(numericValue)
        } else if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else if let arrayValue = try? container.decode([JSON].self) {
            self = .array(arrayValue)
        } else {
            self = .dictionary(try container.decode([String: JSON].self))
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .dictionary(let dictionary):
            try container.encode(dictionary)
        case .array(let array):
            try container.encode(array)
        case .string(let string):
            try container.encode(string)
        case .number(let number):
            try container.encode(number)
        case .boolean(let boolean):
            try container.encode(boolean)
        case .null:
            try container.encodeNil()
            
        }
    }
}

extension JSON: CustomDebugStringConvertible {
    var debugDescription: String {
        let encoder = JSONEncoder()
        if #available(macOS 10.13, iOS 11.0, watchOS 4.0, tvOS 11.0, *) {
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        } else {
            encoder.outputFormatting = [.prettyPrinted]
        }
        
        do {
            let data = try encoder.encode(self)
            return String(data: data, encoding: .utf8) ?? "JSON(error decoding UTF8 string)"
        } catch {
            return "JSON(error encoding description: '\(error.localizedDescription)')"
        }
    }
}

extension JSON {
    
    subscript(key: Any) -> JSON? {
        get {
            if let array = self.array, let index = key as? Int, index < array.count  {
                return array[index]
            } else if let dic = self.dictionary, let key = key as? String, let obj = dic[key] {
                return obj
            } else {
                return nil
            }
        }
    }
    
    /// Returns a `JSON` dictionary, if possible.
    var dictionary: [String: JSON]? {
        switch self {
        case .dictionary(let dict):
            return dict
        default:
            return nil
        }
    }

    /// Returns a `JSON` array, if possible.
    var array: [JSON]? {
        switch self {
        case .array(let array):
            return array
        default:
            return nil
        }
    }

    /// Returns a `String` value, if possible.
    var string: String? {
        switch self {
        case .string(let value):
            return value
        default:
            return nil
        }
    }

    /// Returns a `Double` value, if possible.
    var number: Double? {
        switch self {
        case .number(let number):
            return number
        default:
            return nil
        }
    }

    /// Returns a `Bool` value, if possible.
    var bool: Bool? {
        switch self {
        case .boolean(let value):
            return value
        default:
            return nil
        }
    }
    
}
