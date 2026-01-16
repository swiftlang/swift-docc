/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2025-2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

@testable import DocCCommon
import Foundation
import Testing
import SymbolKit

struct FastSymbolGraphJSONDecoderErrorTests {
    
    // Verify that the custom decoder matches the errors from JSONDecoder
    
    @Test
    func decodingIntWhenDataIsNull() throws {
        try expectMatchingErrors(decoding: Int.self, fromJSON: "null", expectedDebugDescription: "Cannot get value of type Int -- found null value instead")
    }
    
    @Test
    func decodingIntWhenDataIsEmpty() throws {
        try expectMatchingErrors(decoding: Int.self, fromJSON: " ", expectedDebugDescription: "The given data was not valid JSON.")
    }
    
    @Test
    func decodingIntWhenNumberIsTooLarge() throws {
        try expectMatchingErrors(decoding: Int.self, fromJSON: String(repeating: "1", count: 30), expectedDebugDescription: "The given data was not valid JSON.")
    }
    
    @Test(arguments: [
        "[]": "an array",
        "{}": "a dictionary",
        "true": "bool",
        "\"\"": "a string",
    ])
    func decodingIntWhenDataIsOtherType(json: String, expectedTypeDescription: String) throws {
        try expectMatchingErrors(decoding: Int.self, fromJSON: json, expectedDebugDescription: "Expected to decode Int but found \(expectedTypeDescription) instead.")
    }
    
    @Test(arguments: [
        "[]": "an array",
        "{}": "a dictionary",
        "123": "number",
        "\"\"": "a string",
    ])
    func decodingBoolWhenDataIsOtherType(json: String, expectedTypeDescription: String) throws {
        try expectMatchingErrors(decoding: Bool.self, fromJSON: json, expectedDebugDescription: "Expected to decode Bool but found \(expectedTypeDescription) instead.")
    }
    
    @Test(arguments: [
        "[]": "an array",
        "{}": "a dictionary",
        "123": "number",
        "false": "bool",
    ])
    func decodingStringWhenDataIsOtherType(json: String, expectedTypeDescription: String) throws {
        try expectMatchingErrors(decoding: String.self, fromJSON: json, expectedDebugDescription: "Expected to decode String but found \(expectedTypeDescription) instead.")
    }
    
    @Test
    func decodingSemanticVersionWhenDataIsEmptyObject() throws {
        try expectMatchingErrors(decoding: SymbolGraph.SemanticVersion.self, fromJSON: "{}", expectedDebugDescription: "No value associated with key \"major\".")
    }
    
    @Test
    func decodingInvalidIntRanges() throws {
        // Too few numbers
        try expectMatchingErrors(decoding: Range<Int>.self, fromJSON: "[]", expectedDebugDescription: "Unkeyed container is at end.")
        try expectMatchingErrors(decoding: Range<Int>.self, fromJSON: "[1]", expectedDebugDescription: "Unkeyed container is at end.")
        
        // Upper bound is less than lower bound
        try expectMatchingErrors(decoding: Range<Int>.self, fromJSON: "[2,1]", expectedDebugDescription: "Cannot initialize Range<Int> with a lowerBound (2) greater than upperBound (1)")
    }
    
    // Verify that the custom decoder produces the same coding path as JSONDecoder does.
    
    @Test
    func decodingInnerValueWithWrongTypeInSecondElement() async throws {
        let json = #"""
        { 
          "inner": [
            {
              "condition": false,
              "id": 123,
              "name": "First"
            },
            {
              "name": "First",
              "id": "Not a number" 
            }              
          ]
        }
        """#
        try expectMatchingErrors(decoding: Outer.self, fromJSON: json, expectedDebugDescription: "Expected to decode Int but found a string instead.")
    }
    
    @Test
    func decodingRecursiveValueWithMissingValueDeepDown() async throws {
        let json = #"""
        { 
          "nested": [
            {
              "nested": [
                {
                  "nested": [
                    {
                      "nested": [
                        {
                          "nested": []
                        }
                      ]
                    },
                    {
                      "nested": []
                    }
                  ]
                }
              ]
            },
            {
              "nested": [
                {
                  "nested": [
                    {
                      "nested": [
                        {
                          "nested": []
                        }
                      ]
                    },
                    {
                      "nested": []
                    },
                    {
                      "nested": 123
                    }
                  ]
                }
              ]
            }
          ]
        }
        """#
        
        try expectMatchingErrors(decoding: Recursive.self, fromJSON: json, expectedDebugDescription: "Expected to decode Array<Any> but found number instead.")
        
        // Verify that ignoring the full JSON doesn't fail
        _ = try FastSymbolGraphJSONDecoder.decode(Outer.self, from: Data(json.utf8))
    }
}

private struct Outer: FastJSONDecodable, Decodable {
    var inner: [Inner]
    
    init(using decoder: inout DocCCommon.FastSymbolGraphJSONDecoder) throws(DecodingError) {
        var inner: [Inner] = []
        
        try decoder.descendIntoObject()
        while try decoder.advanceToNextKey() {
            if decoder.matchKey("inner") {
                inner = try decoder.decode([Inner].self)
            } else {
                try decoder.ignoreValue()
            }
        }
        
        self.inner = inner
    }
    
    struct Inner: FastJSONDecodable, Decodable {
        var id: Int
        var name: String?
        var condition: Bool = false
        
        init(using decoder: inout DocCCommon.FastSymbolGraphJSONDecoder) throws(DecodingError) {
            var id: Int? // needs to be unwrapped
            
            var name: String?
            var condition: Bool = false
            
            try decoder.descendIntoObject()
            while try decoder.advanceToNextKey() {
                if decoder.matchKey("id") {
                    id = try decoder.decode(Int.self)
                } else if decoder.matchKey("name") {
                    name = try decoder.decode(String?.self)
                } else if decoder.matchKey("condition") {
                    condition = try decoder.decode(Bool.self)
                } else {
                    try decoder.ignoreValue()
                }
            }
            guard let id else {
                throw decoder.makeKeyNotFoundError("id")
            }
            
            self.id = id
            self.name = name
            self.condition = condition
        }
    }
}

private struct Recursive: FastJSONDecodable, Decodable {
    var nested: [Recursive]
    
    init(using decoder: inout DocCCommon.FastSymbolGraphJSONDecoder) throws(DecodingError) {
        var nested: [Recursive] = []
        
        try decoder.descendIntoObject()
        while try decoder.advanceToNextKey() {
            if decoder.matchKey("\"nested\"", byteOffset: -1) {
                nested = try decoder.decode([Recursive].self)
            } else {
                try decoder.ignoreValue()
            }
        }
        
        self.nested = nested
    }
    
    enum CodingKeys: CodingKey {
        case nested
    }
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.nested = try container.decode([Recursive].self, forKey: .nested)
    }
}

// Some of Swift Testing's #expect macros for errors require Swift 6.1, so we use a custom helper instead.
private func expectMatchingErrors<Value: Decodable & FastJSONDecodable>(
    decoding type: Value.Type,
    fromJSON json: String,
    expectedDebugDescription: String,
    sourceLocation: SourceLocation = #_sourceLocation
) throws {
    let data = Data(json.utf8)
    func catchDecodingError(performing work: () throws -> Void) throws -> DecodingError? {
        do {
            try work()
        } catch let error as DecodingError {
            return error
        }
        return nil
    }
    
    let lhs = try catchDecodingError {
        let v = try JSONDecoder().decode(type, from: data)
        dump(v)
        Issue.record("JSONDecoder didn't raise an error", sourceLocation: sourceLocation)
    }
    let rhs = try catchDecodingError {
        _ = try FastSymbolGraphJSONDecoder.decode(type, from: data)
        Issue.record("The custom decoder didn't raise an error", sourceLocation: sourceLocation)
    }
    guard let lhs, let rhs else {
        return
    }
    
    switch (lhs, rhs) {
    case (.typeMismatch(let lhsType, let lhsContext),  .typeMismatch(let rhsType, let rhsContext)),
         (.valueNotFound(let lhsType, let lhsContext), .valueNotFound(let rhsType, let rhsContext)):
        #expect("\(lhsType)" == "\(rhsType)", "Different types.", sourceLocation: sourceLocation)
        #expect(lhsContext.codingPath.formatted() == rhsContext.codingPath.formatted(), "Different coding paths.", sourceLocation: sourceLocation)
        // Don't compare the exact debug descriptions against JSONDecoder's implementation. We don't want the test to fail if that wording changes.
        #expect(rhsContext.debugDescription == expectedDebugDescription, "Unexpected debug descriptions.", sourceLocation: sourceLocation)

    case (.keyNotFound(let lhsKey, let lhsContext),
          .keyNotFound(let rhsKey, let rhsContext)):
        #expect(lhsKey.stringValue == rhsKey.stringValue, "Different keys.", sourceLocation: sourceLocation)
        fallthrough
        
    case (.dataCorrupted(let lhsContext),
          .dataCorrupted(let rhsContext)):
        #expect(lhsContext.codingPath.formatted() == rhsContext.codingPath.formatted(), "Different coding paths.", sourceLocation: sourceLocation)
        // Don't compare the exact debug descriptions against JSONDecoder's implementation. We don't want the test to fail if that wording changes.
        #expect(rhsContext.debugDescription == expectedDebugDescription, "Unexpected debug descriptions.", sourceLocation: sourceLocation)
        
    default:
        Issue.record("Expected '\(lhs.kindDescription)' error. Got '\(rhs.kindDescription)'", sourceLocation: sourceLocation)
    }
}

private extension DecodingError {
    var kindDescription: String {
        switch self {
            case .typeMismatch:  "typeMismatch"
            case .valueNotFound: "valueNotFound"
            case .keyNotFound:   "keyNotFound"
            case .dataCorrupted: "dataCorrupted"
            @unknown default:    "unknown"
        }
    }
}

private extension [any CodingKey] {
    func formatted() -> String {
        guard !isEmpty else {
            return "."
        }
        
        return map {
            if let index = $0.intValue {
                "[\(index)]"
            } else {
                ".\($0.stringValue)"
            }
        }
        .joined()
    }
}
