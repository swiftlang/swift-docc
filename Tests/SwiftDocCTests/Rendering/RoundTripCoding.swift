/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import XCTest

/// Asserts that the implementation of the `Codable` for the given value is correct, by encoding and decoding the values, and checking whether
/// the original and decoded `Data` are equal.
/// - Parameter value: The value to test.
/// - Throws: An error if encoding or decoding of the given value failed.
func assertRoundTripCoding<Value: Equatable>(
    _ value: Value,
    file: StaticString = #file,
    line: UInt = #line
) throws where Value: Codable {
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()

    // Decode one time
    let encoded = try encoder.encode(value)
    let decoded = try decoder.decode(Value.self, from: encoded)
    XCTAssertEqual(value, decoded, file: (file), line: line)
    
    // Decode a second time to ensure no data is lost during the round-trip
    let reEncoded = try encoder.encode(decoded)
    let reDecoded = try decoder.decode(Value.self, from: reEncoded)
    XCTAssertEqual(decoded, reDecoded, file: (file), line: line)
}

/// Asserts that the given value and its JSON representation are equal, by decoding the given JSON into the value's type.
/// - Parameters:
///   - value: The value to test.
///   - json: A JSON encoding of the value after being serialized.
/// - Throws: An error if decoding the given JSON failed.
func assertJSONRepresentation<Value: Decodable & Equatable>(
    _ value: Value,
    _ json: String,
    file: StaticString = #file,
    line: UInt = #line
) throws {
    let decoder = JSONDecoder()

    var decoded: Value? = nil
    
    let encoding: String.Encoding
    #if os(Linux) || os(Android)
    // Work around a JSON decoding issue on Linux (github.com/apple/swift/issues/57362).
    encoding = .utf8
    #else
    encoding = json.fastestEncoding
    #endif
    XCTAssertNoThrow(decoded = try decoder.decode(Value.self, from: XCTUnwrap(json.data(using: encoding))))

    XCTAssertEqual(decoded, value, file: (file), line: line)
}
