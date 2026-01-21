/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2025-2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import struct Foundation.Data
import struct Foundation.URL

/// A protocol for types that can be decoded using a `FastSymbolGraphJSONDecoder`.
///
/// The only "primitive" types that can be decoded are `Int`, `String`, and `Bool` and array values and optional values of those primitive types.
/// Any other type needs its own decoding implementation.
///
/// If the decodable type is an "object"—meaning that it decodes individual properties for different string keys—its decoding implementation happens in 3 steps:
/// - Declare local optional variables for each property that needs to be decoded
/// - Advance the decoder and decode each value in the order that the keys appear in the data
/// - Verify that all required properties were decoded.
///
/// For example, a type with a "first" `String` property and a "second" `Int` property that defaults to 0 can be implement its decoding like this:
/// ```
/// // Declare local variables for the properties that needs to be decoded
/// var first: String?  // This needs to be optional to represent that it hasn't been decoded yet.
/// var second: Int = 0 // This doesn't need to be optional because it has a default value.
///
/// // Decode each property in the order they appear in the data
/// try decoder.descendIntoObject()
/// while try decoder.advanceToNextKey() {
///     if decoder.matchKey("first") {
///         first = try decoder.decode(String.self)
///     }
///     else if decoder.matchKey("second") {
///         second = try decoder.decode(Int.self)
///     }
///     // Do nothing for any unknown keys that the decoder might encounter
///     else {
///         // Your implementation explicitly needs to ignore this value so that the decoder can advance to the next key.
///         try decoder.ignoreValue()
///     }
/// }
///
/// // Verify that the property without a default value was decoded
/// guard let first else {
///     throw .keyNotFound(...)
/// }
///
/// self.init(...)
/// ```
///
/// If the decodable type is `RawRepresentable` it can decode its raw value and initialize itself like this:
///
/// ```
/// let rawValue = try decoder.decode(RawValue.self)
/// self = .init(rawValue: consume rawValue)
/// ```
package protocol FastJSONDecodable {
    init(using decoder: inout FastSymbolGraphJSONDecoder) throws(DecodingError)
}

/// A custom JSON decoder for symbol graph files that focuses on performance and memory usage.
///
/// The decoder is designed around a single linear scan through the bytes of the JSON data in order to minimize unnecessary work.
/// This means that elements needs to be decoded in the order the they appear in the JSON data and that to ignore unknown elements in the JSON data,
/// the decoder still needs to parse them to know where that ignored element ends.
///
/// The decoder also requires that all keys are static strings known at compile time, and compares their underlying raw bytes.
/// This makes it unsuitable as a general purpose JSON decoder for arbitrary that needs to decode arbitrary structures,
/// but it's not an issue for decoding symbol graph data (or even other known structured that are known to use all ASCII keys that don't require normalization).
///
/// ## Topics
///
/// ### Essentials
///
/// Call the static ``decode(_:from:)`` method to decode a ``FastJSONDecodable`` value.
///
/// - ``decode(_:from:)``
/// - ``FastJSONDecodable``
///
/// ### Implementing keyed decoding
///
/// - ``descendIntoObject()``
/// - ``advanceToNextKey()``
/// - ``matchKey(_:byteOffset:)``
/// - ``ignoreValue()``
///
/// ### Decoding individual values
///
/// - ``decode()->Bool``
/// - ``decode()->Int``
/// - ``decode()->String``
/// - ``decode()->Value``
/// - ``decode()->Value?``
/// - ``decode()->[Value]``
/// - ``decode()->[String:Value]``
///
/// ### Errors
///
/// - ``makeKeyNotFoundError(_:)``
/// - ``makeTypeMismatchError(_:)``
/// - ``makeGenericDataCorruptedError()``
package struct FastSymbolGraphJSONDecoder: ~Copyable {
    /// The raw pointer to the current byte in the JSON's data.
    ///
    /// As the decoder scans through the JSON data, it advances this pointer.
    private var pointer: UnsafeRawPointer
    /// The raw pointer to the JSON data's "past the end" position.
    ///
    /// The decoder uses this pointer to perform bounds checks using `try _boundsCheck()`.
    /// This usually happens right after advancing the pointer but some private functions, for example `_skipWhitespace()` or `_descendIntoArray()`,
    /// advance the pointer but push this bounds checking responsibility on the caller.
    /// These private functions each document this behavior in a "note" callout.
    private let endOfData: UnsafeRawPointer
    
    /// Creates a new fast symbol graph JSON decoder from a raw buffer of JSON data.
    ///
    /// It's the caller's responsibility to ensure that the decoder doesn't outlive the lifetime of the JSON data.
    /// The API design ensures this by making this initializer private and only calling it from ``decode(_:from:)``.
    private init(buffer: UnsafeRawBufferPointer) {
        // The UnsafeRawBufferPointer makes a force unwrap of the base pointer on each read (correctly assuming that it's not a null pointer).
        // Across an entire symbol graph file this can result in literally millions of `nil`-checks that `abort()`.
        //
        // By unwrapping the base pointer only once here, we can avoid all those repeated `nil`-checks.
        self.pointer = buffer.baseAddress!
        
        // The drawback is that we no longer have a `count` of remaining bytes in the buffer.
        // Instead of storing an integer count that needs to be decremented every time the base pointer is incremented,
        // we store another pointer to the one-past-the-last-valid-element and compare the pointers when we need to do a bounds check.
        self.endOfData = buffer.baseAddress!.advanced(by: buffer.count)
    }
    
    /// Decodes a value of the given type from the given JSON data.
    ///
    /// - Parameters:
    ///   - type: The type that the decoder will decode.
    ///   - data: The JSON data that the decoder will parse to decode the value.
    /// - Returns: The decoded value.
    @inlinable
    package static func decode<Decodable: FastJSONDecodable>(_ type: Decodable.Type, from data: consuming Data) throws -> Decodable {
        try data.withUnsafeBytes { buffer in
            var decoder = FastSymbolGraphJSONDecoder(buffer: buffer)
            return try Decodable(using: &decoder)
        }
    }
    
    // MARK: Implementing keyed decoding
    
    /// Advances the decoder past the opening curly brace (`{`) and prepares it to decode a series of values using `advanceToNextKey()`.
    ///
    /// If your `FastJSONDecodable` conformance don't call this method before attempting to decode the first key,
    /// the decoder will be in an incorrect state and will fail to parse the key, resulting in a `DecodingError`.
    @inlinable
    package mutating func descendIntoObject() throws(DecodingError) {
        do {
            try _descendIntoObject()
            // Even if we only expect this to skip whitespace and the "{" character, verify that the decoder didn't go beyond the data's bounds doing so.
            try _boundsCheck()
        } catch .unexpectedCharacter {
            throw makeTypeMismatchError([AnyHashable: Any].self) // We don't know of a more specific type at this point.
        } catch {
            throw makeGenericDataCorruptedError()
        }
    }
    
    /// Advances the decoder to just beyond the opening string delimiter of the next key.
    ///
    /// If the decoder returns `true`, the decoder is in a state where your `FastJSONDecodable` conformance can call ``matchKey(_:byteOffset:)`` to check which key the decoder encountered in the JSON data.
    /// If the decoder returns `false`, the decoder found the last key for this JSON object. In this case the decoder will advance past the closing curly brace (`}`) that marks the end of this JSON object.
    ///
    /// - Returns: `true` if the decoder found another key, `false` if the decoder found the end of the current JSON object—a closing curly brace (`}`).
    @inlinable
    package mutating func advanceToNextKey() throws(DecodingError) -> Bool {
        do {
            return try _advanceToNextKey()
        } catch {
            throw makeGenericDataCorruptedError()
        }
    }
    
    /// Checks if the decoder is currently pointing to a specific JSON key.
    ///
    /// If the decoder's current state matches the given key, the decoder advances past the key and its value separator (`:`) so that the decoder is in a state where it can decode the value for that key.
    ///
    /// ## Performance considerations
    ///
    /// If the key you're checking for is only 3 bytes or only 7 bytes, it's faster to include the trailing string delimiter (`"`) in the key so that it fully fills a 4 byte value or 8 byte value.
    ///
    /// If the key you're checking for is only 6 bytes, it's faster to include both the leading and trailing string delimiters (`"`) in the key so that it fully fills a 8 byte value.
    /// To include the _leading_ string delimiter you'll need to specify a `-1` byte offset, because the decoder will have already advanced just past the leading string delimiter after calling `advanceToNextKey`.
    ///
    /// - Parameters:
    ///   - jsonKey: The json key that the decoder checks for
    ///   - byteOffset: The byte offset from the decoder's current state where the decoder checks for the key.
    /// - Returns: `true` if the decoder matched this key, `false` otherwise.
    @inlinable
    mutating func matchKey(_ jsonKey: StaticString, byteOffset: Int = 0) -> Bool {
        guard pointer.hasASCIIPrefix(jsonKey, byteOffset: byteOffset) else {
            return false
        }
        
        path.push(.key(pointer))
        
        // Start from the end of the found json key and scan one past the value separator (":").
        _skipPastNextValueSeparator(byteOffset: jsonKey.utf8CodeUnitCount + byteOffset)
       
        return true
    }
    
    /// Scans past the current value (regardless of its type) and advances the decoder's state so that it can decode the next value.
    ///
    /// If your `FastJSONDecodable` conformance encounters a key that it doesn't recognize, your implementation has to call `ignoreValue()`.
    /// Otherwise, the decoder's state won't advance past the unknown value and any following call to `advanceToNextKey()` will raise a `DecodingError`.
    @inlinable
    package mutating func ignoreValue() throws(DecodingError) {
        do {
            // Add the ignored key to the path so that we have the correct path if there's an error deep down in a nested ignored value.
            path.push(.key(pointer))
            _skipPastNextValueSeparator(byteOffset: 0)
            
            try _ignoreValue()
        } catch {
            // We're ignoring this value, we don't care as much about the specificity of the error.
            throw makeGenericDataCorruptedError()
        }
    }
    
    /// Advances the decoder's state until it find the given byte and then advances to just beyond that byte.
    private mutating func _skipPastNextValueSeparator(byteOffset: Int) {
        var length = byteOffset
        while pointer.load(fromByteOffset: length, as: UInt8.self) != .init(ascii: ":") {
            length &+= 1
        }
        pointer.removeFirst(length &+ 1)
    }
    
    // MARK: Decoding individual values
    
    /// Decodes a Boolean value and advances the decoder's state.
    ///
    /// - Parameter type: The type of value to decode.
    /// - Returns: The decoded value.
    @inlinable
    package mutating func decode(_ type: Bool.Type) throws(DecodingError) -> Bool {
        do {
            let value = try _scanBool()
            try _boundsCheck()
            return value
        } catch .unexpectedCharacter {
            throw makeTypeMismatchError(type)
        } catch {
            throw makeGenericDataCorruptedError()
        }
    }
    
    /// Decodes an integer value and advances the decoder's state.
    ///
    /// - Parameter type: The type of value to decode.
    /// - Returns: The decoded value.
    @inlinable
    package mutating func decode(_ type: Int.Type) throws(DecodingError) -> Int {
        let parsed: (buffer: UnsafeRawBufferPointer, isNegative: Bool)
        do {
            parsed = try _scanInteger()
        } catch .unexpectedCharacter {
            throw makeTypeMismatchError(type)
        } catch {
            throw makeGenericDataCorruptedError()
        }
        
        guard parsed.buffer.count < 19 else {
            // The largest Int value is 19 digits. If this is shorter, then we can decode it without overflowing.
            // This is technically a little bit too strict but considering that integers in symbol graph files are rarely beyond 2-3 digits, it shouldn't be an issue in practice.
            throw makeGenericDataCorruptedError() // This is the same error as JSONDecoder.
        }
        
        var result = 0
        for byte in parsed.buffer {
            result &*= 10
            result &+= Int(byte - UInt8(ascii: "0"))
        }
        
        assert(
            result == Int(String(decoding: parsed.buffer, as: UTF8.self)),
            "The custom initialized Int (\(result)) decoded differently compared to the default Int initialization of those characters in a String (\(Int(String(decoding: parsed.buffer, as: UTF8.self))?.description ?? "<nil>"))."
        )
        
        if parsed.isNegative {
            result.negate()
        }
        
        do {
            try _boundsCheck()
        } catch {
            throw makeGenericDataCorruptedError()
        }
        return result
    }
    
    /// Decodes a string and advances the decoder's state.
    ///
    /// - Parameter type: The type of value to decode.
    /// - Returns: The decoded value.
    @inlinable
    package mutating func decode(_ type: String.Type) throws(DecodingError) -> String {
        do {
            let parsed = try _scanString()
            if parsed.isTrivialStringConvertible {
                // If the scanned string doesn't contain any escaped characters, then we can immediately decode the scanned bytes as a UTF8 string.
                return String(decoding: parsed.buffer, as: UTF8.self)
            }
            
            // This string contains some escaped JSON "characters" that need to be transformed.
            let data = parsed.buffer
            // Make one allocation that fits all the scanned bytes.
            // This will be a little bit too long, but it ensures that we don't need to reallocate as we process incrementally add UTF8 bytes to the string.
            return try String(unsafeUninitializedCapacity: data.count) { buffer in
                // A helper function for appending to the String's uninitialized storage.
                var outputIndex = 0
                func append(_ byte: consuming UInt8) {
                    buffer[outputIndex] = byte
                    outputIndex &+= 1
                }
                
                // Iterate through each byte of the parsed input..
                var inputIndex = 0
                while inputIndex < data.count {
                    let byte = data[inputIndex]
                    inputIndex &+= 1
                    
                    // ... unless this byte is the string escape character, simply append it to the String's uninitialized storage.
                    guard byte == UInt8(ascii: "\\") else {
                        append(byte)
                        continue
                    }
                    
                    // Advance past the escape character ...
                    let nextByte = data[inputIndex]
                    inputIndex &+= 1
                    // ... and check what it is escaping
                    switch nextByte {
                    case .init(ascii: "\""): append(.init(ascii: "\""))
                    case .init(ascii: "\\"): append(.init(ascii: "\\"))
                    case .init(ascii: "/"):  append(.init(ascii: "/"))
                    case .init(ascii: "n"):  append(.init(ascii: "\n"))
                    case .init(ascii: "r"):  append(.init(ascii: "\r"))
                    case .init(ascii: "t"):  append(.init(ascii: "\t"))
                    case .init(ascii: "b"):  append(0x8) // backspace
                    case .init(ascii: "f"):  append(0xC) // form feed
                    case .init(ascii: "u"):
                        // This escaped character is a 4-hex-digit unicode character.
                        
                        // The way we're decoding this is slow, but I've never seen any symbol graph JSON with escaped 4-hex-digit unicode characters, so that's fine.
                        let hex = String(decoding: data[inputIndex ..< inputIndex + 4], as: UTF8.self)
                        inputIndex &+= 4
                        let num = Int(hex, radix: 16)!
                        let char = Character(UnicodeScalar(num)!)
                        for byte in char.utf8 {
                            append(byte)
                        }
                        
                    default:
                        throw ScanningError.unexpectedCharacter
                    }
                }
                
                // Return the _actual_ length of the initialized storage so that the String knowns how long it is.
                return outputIndex
            }
        } catch ScanningError.unexpectedCharacter {
            throw makeTypeMismatchError(type)
        } catch {
            throw makeGenericDataCorruptedError()
        }
    }
    
    /// Decodes a decodable value and advances the decoder's state.
    ///
    /// - Parameter type: The type of value to decode.
    /// - Returns: The decoded value.
    @inlinable
    package mutating func decode<Value: FastJSONDecodable>(_ type: Value.Type) throws(DecodingError) -> Value {
        _skipWhitespace()
        return try Value(using: &self)
    }
    
    /// Decodes an array of decodable values and advances the decoder's state.
    ///
    /// - Parameter type: The type of value to decode.
    /// - Returns: The decoded values.
    @inlinable
    package mutating func decode<Value: FastJSONDecodable>(_ type: [Value].Type) throws(DecodingError) -> [Value] {
        do {
            try _descendIntoArray()
            
            // Add a new index to the decoder's path.
            path.push(.index(0))
            
            var values: [Value] = []
            _skipWhitespace()
            
            while pointer.nextByte != .init(ascii: "]") {
                values.append(try decode(Value.self))
                path.incrementCurrentIndex()
                
                _skipWhitespace()
                if pointer.nextByte == .init(ascii: ",") {
                    pointer.removeFirst()
                    _skipWhitespace()
                }
            }
            pointer.removeFirst()
            path.pop()
            
            try _boundsCheck()
            
            return values
        } catch ScanningError.unexpectedCharacter {
            throw makeTypeMismatchError(Array<Any>.self) // We're dropping some type information here to match JSONDecoder's behavior
        } catch let decodingError as DecodingError{
            throw decodingError
        } catch {
            throw makeGenericDataCorruptedError()
        }
    }
    
    /// Decodes an optional decodable values and advances the decoder's state.
    ///
    /// - Parameter type: The type of value to decode.
    /// - Returns: The decoded value.
    @inlinable
    package mutating func decode<Value: FastJSONDecodable>(_ type: Value?.Type) throws(DecodingError) -> Value? {
        _skipWhitespace()
        do {
            if try _scanNull() {
                return nil
            }
        } catch .unexpectedCharacter {
            throw makeTypeMismatchError(type)
        } catch {
            throw makeGenericDataCorruptedError()
        }
        
        return try Value(using: &self)
    }
    
    /// Decodes a dictionary of decodable values and string keys and advances the decoder's state.
    ///
    /// - Parameter type: The type of value to decode.
    /// - Returns: The decoded value.
    @inlinable
    package mutating func decode<Value: FastJSONDecodable>(_ type: [String: Value].Type) throws(DecodingError) -> [String: Value] {
        _skipWhitespace()
        
        var result: [String: Value] = [:]
        
        do {
            try _descendIntoObject()
            
            while try _advanceToNextKey() {
                // We can't make guarantees about the string keys so we need to full proper string decoding.
                // For this, the call to `_advanceToNextKey` has advanced 1 too far, so we need to take a step back before decoding the key
                let startOfKey = pointer
                pointer = pointer.advanced(by: -1)
                let key = try decode(String.self)
                
                // Update the coding path so that potential errors for each decoded value includes the dynamic key.
                path.push(.key(startOfKey))
                
                _skipPastNextValueSeparator(byteOffset: 0)
                let value = try decode(Value.self)
                
                result[consume key] = consume value
            }
            try _boundsCheck()
        } catch ScanningError.unexpectedCharacter {
            throw makeTypeMismatchError(type)
        } catch let error as DecodingError {
            throw error
        } catch {
            throw makeGenericDataCorruptedError()
        }
        
        return result
    }
    
    // MARK: Errors
    
    /// The path to the element that the decoder is currently decoding.
    ///
    /// The decoder keeps track of the coding path solely for error reporting purposes.
    fileprivate var path = Path()
    
    /// Creates a key-not-found error for the given key and information derived from the decoder's current state.
    @inlinable
    package func makeKeyNotFoundError(_ key: String) -> DecodingError {
        .keyNotFound(Path.CodingKey(stringValue: key), .init(codingPath: path.makeCodingPath(), debugDescription: "No value associated with key \"\(key)\"."))
    }
    
    /// Creates a type-mismatch (or value-not-found) error for the given type and information derived from the decoder's current state.
    @inlinable
    package func makeTypeMismatchError(_ type: Any.Type) -> DecodingError {
        guard !pointer.hasASCIIPrefix("null") else {
            // DecodingError uses a different case for null values but it's easier for the caller to handle null values as a type mismatch.
            return .valueNotFound(type, .init(codingPath: path.makeCodingPath(), debugDescription: "Cannot get value of type \(type) -- found null value instead"))
        }
        
        let foundValueDescription = switch pointer.nextByte {
            case .init(ascii: "\""):
                "a string"
            case .init(ascii: "t"), .init(ascii: "f"): // true / false
                "bool"
            case .init(ascii: "-"), .init(ascii: "0") ... .init(ascii: "9"):
                "number"
            case .init(ascii: "{"):
                "a dictionary"
            case .init(ascii: "["):
                "an array"
            default:
                "invalid JSON"
        }
        
        return .typeMismatch(type, .init(codingPath: path.makeCodingPath(), debugDescription: "Expected to decode \(type) but found \(foundValueDescription) instead."))
    }
    
    /// Creates a generic data-corrupted error based on the decoder's current state.
    @inlinable
    package func makeGenericDataCorruptedError() -> DecodingError {
        .dataCorrupted(.init(codingPath: path.makeCodingPath(), debugDescription: "The given data was not valid JSON."))
    }
    
    // MARK: Scanning
    
    /// Checks that the decoder's current state is still in bounds in the data and raises an `ScanningError.unexpectedEndOfFile` otherwise.
    private func _boundsCheck() throws(ScanningError) {
        guard pointer <= endOfData else {
            throw .unexpectedEndOfFile
        }
    }
    
    /// Verifies and skips over the next byte, raising an error if the decoder's next byte doesn't match the expected byte.
    ///
    /// - Note:
    ///   Despite advancing the pointer by 1, this private function _doesn't_ call `try _boundsCheck()`.
    ///   Instead it's the caller's responsibility to do a final bounds check before returning any value from any non-private method.
    private mutating func _skipExpectedByte(_ byte: UInt8) throws(ScanningError) {
        guard pointer.nextByte == byte else {
            throw .unexpectedCharacter
        }
        pointer.removeFirst()
    }
    
    /// Skips past any leading whitespace, advancing the decoder's state to just past the last leading whitespace.
    ///
    /// - Note:
    ///   Despite advancing the pointer, this private function _doesn't_ call `try _boundsCheck()`.
    ///   Instead it's the caller's responsibility to do a final bounds check before returning any value from any non-private method.
    private mutating func _skipWhitespace() {
        var length = 0
        while pointer.load(fromByteOffset: length, as: UInt8.self).isJSONWhitespace {
            length &+= 1
        }
        pointer.removeFirst(length)
    }
    
    /// Scans a Boolean literal in the data.
    /// - Returns: `true` if the decoder scanned the "true" JSON literal or `false` if the decoder scanned the "false" JSON literal.
    private mutating func _scanBool() throws(ScanningError) -> Bool {
        _skipWhitespace()
        
        if pointer.hasASCIIPrefix("true") {
            pointer.removeFirst(4)
            try _boundsCheck()
            return true
        } else if pointer.hasASCIIPrefix("false") {
            pointer.removeFirst(5)
            try _boundsCheck()
            return false
        } else {
            // Do a bounds check in case skipping leading whitespace went beyond the data's bounds.
            try _boundsCheck()
            throw .unexpectedCharacter
        }
    }
    
    /// Attempts to scan a JSON "null" literal in the data.
    /// - Returns: `true` if the decoder scanned the "null" JSON literal, `false` otherwise.
    private mutating func _scanNull() throws(ScanningError) -> Bool {
        _skipWhitespace()
        
        if pointer.hasASCIIPrefix("null") {
            pointer.removeFirst(4)
            try _boundsCheck()
            return true
        } else {
            // Do a bounds check in case skipping leading whitespace went beyond the data's bounds.
            try _boundsCheck()
            return false
        }
    }
    
    /// Scans an integer in the data and advances the decoder's state.
    /// - Returns: A buffer that spans the ASCII numbers of the integer and a Boolean value that indicates if the scanned integer is negative.
    private mutating func _scanInteger() throws(ScanningError) -> (buffer: UnsafeRawBufferPointer, isNegative: Bool) {
        _skipWhitespace()
    
        let parsed = try _scanNumber()
        guard !parsed.isFloatingPoint, !parsed.hasExponent else {
            throw .unexpectedCharacter
        }
        
        let numbersBuffer: UnsafeRawBufferPointer = if parsed.isNegative {
            // Skip the minus sign in the returned numeric data
            .init(start: pointer.advanced(by: 1), count: parsed.length &- 1)
        } else {
            .init(start: pointer, count: parsed.length)
        }
        
        pointer.removeFirst(parsed.length)
        try _boundsCheck()
        
        return (numbersBuffer, parsed.isNegative)
    }
    
    /// Scans an unknown number in the data _without_ advancing the decoder's state.
    ///
    /// The caller should have already skipped whitespaces before calling this method.
    /// - Returns: The length of the scanned data and 3 Boolean values that indicates if the scanned number is floating point, if it has an exponent, and if it is negative.
    private func _scanNumber() throws(ScanningError) -> (length: Int, isFloatingPoint: Bool, hasExponent: Bool, isNegative: Bool) {
        assert(!pointer.nextByte.isJSONWhitespace, "The caller should have already skipped whitespaces.")
        var length = 0
        
        // Check for minus sign
        let isNegative = pointer.nextByte == .init(ascii: "-")
        if isNegative {
            length &+= 1
        }
        
        // Check for integer digits
        while pointer.load(fromByteOffset: length, as: UInt8.self).isAsciiDigit {
            length &+= 1
        }
        
        // Check for a floating point number
        let isFloatingPoint = pointer.load(fromByteOffset: length, as: UInt8.self) == .init(ascii: ".")
        if isFloatingPoint {
            length &+= 1
            
            // Check for fractional digits
            while pointer.load(fromByteOffset: length, as: UInt8.self).isAsciiDigit {
                length &+= 1
            }
        }
        
        // Check for an exponent
        let hasExponent = pointer.load(fromByteOffset: length, as: UInt8.self).isJSONNumberExponent
        if hasExponent {
            length &+= 1
            
            let next = pointer.load(fromByteOffset: length, as: UInt8.self)
            if next == .init(ascii: "+") || next == .init(ascii: "-") {
                length &+= 1
            }
            // Check for exponent digits
            while pointer.load(fromByteOffset: length, as: UInt8.self).isAsciiDigit {
                length &+= 1
            }
        }
        
        // Verify that the scanned number isn't empty
        guard 0 < length else {
            // Do a bounds check here to match the JSONDecoder error message when the data is all whitespace.
            if endOfData <= pointer.advanced(by: length) {
                throw .unexpectedEndOfFile
            } else {
                throw .unexpectedCharacter
            }
        }
        
        return (length, isFloatingPoint, hasExponent, isNegative)
    }
    
    /// Scans a string in the data.
    /// - Returns: A buffer that spans the bytes of the string and a Boolean value that indicates if the buffer can trivially be converted to a string or if the decoder needs to transform escaped characters in the buffer.
    private mutating func _scanString() throws(ScanningError) -> (buffer: UnsafeRawBufferPointer, isTrivialStringConvertible: Bool) {
        // Skip whitespace and the opening string delimiter.
        _skipWhitespace()
        try _skipExpectedByte(.init(ascii: "\""))
        let startOfString = pointer

        // Unless the bytes contains a slash (`0x5C`), they can trivially be decoded as a string.
        var isTrivialStringConvertible = true
        
        var length = 0
        let count = pointer.distance(to: endOfData)
        
        while count >= length {
            let bytes = pointer.loadUnaligned(fromByteOffset: length, as: UInt64.self)
            
            let isQuote = ByteMatches(bytes, ByteMatches.quoteSearchPattern)
            let isSlash = ByteMatches(bytes, ByteMatches.slashSearchPattern)
            
            guard isQuote.hasMatches else {
                // There's no string delimiter in any of these 8 bytes.
                length &+= 8
                // The string remains trivially convertible as longer as there aren't any slashes in these 8 bytes.
                isTrivialStringConvertible = isTrivialStringConvertible && !isSlash.hasMatches
                
                assert(
                    isTrivialStringConvertible != UnsafeRawBufferPointer(start: pointer, count: length).contains(where: { $0 == .init(ascii: "\\") }),
                    "Unexpectedly miscategorized '\(String(decoding: UnsafeRawBufferPointer(start: pointer, count: length), as: UTF8.self))' as \(isTrivialStringConvertible ? "" : "NOT") trivially string convertible"
                )
                
                continue
            }
            
            // We've found the end of this string.
            length &+= isQuote.numberOfLeadingNonMatches
            // The string remains trivially convertible as longer as the first quote is before the first slash.
            isTrivialStringConvertible = isTrivialStringConvertible && isQuote.isBefore(isSlash)
            
            assert(
                isTrivialStringConvertible != UnsafeRawBufferPointer(start: pointer, count: length).contains(where: { $0 == .init(ascii: "\\") }),
                "Unexpectedly miscategorized '\(String(decoding: UnsafeRawBufferPointer(start: pointer, count: length), as: UTF8.self))' as \(isTrivialStringConvertible ? "" : "NOT") trivially string convertible"
            )
            
            if isTrivialStringConvertible {
                break
            }
            
            // Determine if the quote we found is escaped or not by counting the number of slashes before it.
            var numberOfSlashesBefore = 0
            while pointer.load(fromByteOffset: length - 1 - numberOfSlashesBefore, as: UInt8.self) == .init(ascii: "\\") {
                numberOfSlashesBefore &+= 1
            }
            if numberOfSlashesBefore.isMultiple(of: 2) {
                // An even number of slashes means that it's the _slashes_ that are escaped, not the quotation mark.
                // For example, consider a string that ends in 4 slashes. The 1st slash escapes the 2nd and the 3rd escapes the 4th, leaving the quotation mark unescaped:
                //
                //     "ABC\\\\"
                //         ├╯├╯╰─╴string delimiter
                //         │ ╰───╴escaped slash
                //         ╰─────╴escaped slash
                break
            } else {
                // An odd number of slashes means that the last slash escapes the quote, so this byte is part of the string's content.
                // For example, consider a string that ends in 3 slashes. The 1st slash escapes the 2nd leaving 3rd slash to escape the quotation mark:
                //
                //     "ABC\\\"
                //         ├╯├╯
                //         │ ╰───╴escaped quote
                //         ╰─────╴escaped slash
                length &+= 1
                continue
            }
        }
        
        // We've found the closing string delimiter.
        pointer.removeFirst(length + 1)
        try _boundsCheck()
        
        return (.init(start: startOfString, count: length), isTrivialStringConvertible)
    }
    
    /// Advance the decoder's state to just past the "begin array" structural character (`[`).
    ///
    /// - Note:
    ///   Despite advancing the pointer, this private function _doesn't_ call `try _boundsCheck()`.
    ///   Instead it's the caller's responsibility to do a final bounds check before returning any value from any non-private method.
    ///   - The package access `decode(_:)->[Value]` method does the a single bounds check just before returning.
    ///   - The private `_ignoreValue()` method does so after finding the "end array" structural character (`]`).
    private mutating func _descendIntoArray() throws(ScanningError) {
        _skipWhitespace()
        
        try _skipExpectedByte(.init(ascii: "["))
    }
    
    /// Advance the decoder's state to just past the "begin object" structural character (`{`).
    ///
    /// - Note:
    ///   Despite advancing the pointer, this private function _doesn't_ call `try _boundsCheck()`.
    ///   Instead it's the caller's responsibility to do a final bounds check before returning any value from any non-private method.
    ///   - The package access `decode(_:)->[String: Value]` method does the a single bounds check just before returning.
    ///   - The private `_ignoreValue()` method does so just before returning.
    private mutating func _descendIntoObject() throws(ScanningError) {
        _skipWhitespace()
        
        try _skipExpectedByte(.init(ascii: "{"))
        
        // We don't push anything to the decoder's path until we've found the first key.
    }

    private mutating func _advanceToNextKey() throws(ScanningError) -> Bool {
        if pointer.load(fromByteOffset: -1, as: UInt8.self) != .init(ascii: "{") {
            path.pop()
        }
        
        if pointer.nextByte == .init(ascii: ",") {
            // Fast path for when the previous value is immediately followed by a comma (",")
            pointer.removeFirst()
        } else {
            _skipWhitespace()
            
            // If the previously scanned element was a value in the object, skip the "," before scanning the key
            switch pointer.nextByte {
            case .init(ascii: "}"):
                // Reached the end of this JSON object
                pointer.removeFirst()
                try _boundsCheck()
                
                // Indicate that the decoder has found the last key for this JSON object.
                return false
                
            case .init(ascii: ","):
                pointer.removeFirst()
            
            case .init(ascii: "\""):
                // For the first key in an object, we find the opening string delimiter after skipping the leading whitespace.
                pointer.removeFirst()
                
                try _boundsCheck()
                return true
                
            default:
                throw .unexpectedCharacter
            }
        }
        _skipWhitespace()
        try _skipExpectedByte(.init(ascii: "\""))
        
        try _boundsCheck()
        
        // Indicate that the decoder's has found another key for this JSON object
        return true
    }
    
    /// Advance the decoder's state to past the upcoming value, regardless of what kind of JSON value that is.
    private mutating func _ignoreValue() throws(ScanningError) {
        _skipWhitespace()
        
        switch pointer.nextByte {
            case .init(ascii: "\""):
                _ = try _scanString()
                assert(pointer.load(fromByteOffset: -1, as: UInt8.self) == .init(ascii: "\""), "The decoder should have advanced past the closing string delimiter")
            
            case .init(ascii: "t"), .init(ascii: "f"): // true / false
                _ = try _scanBool()
                
            case .init(ascii: "n"): // null
                _ = try _scanNull()
                
            case .init(ascii: "-"), .init(ascii: "0") ... .init(ascii: "9"):
                let (length, _, _, _) = try _scanNumber()
                pointer.removeFirst(length)
                // The bounds check happens after the swift-statement.
                
            case .init(ascii: "{"):
                try _descendIntoObject()
                while try _advanceToNextKey() {
                    // Pretend that we found a key (for better diagnostics)
                    path.push(.key(pointer))
                    
                    // We don't know if keys in nested objects are trivially string convertible so we back up one byte and decode it as a proper string.
                    pointer = pointer.advanced(by: -1)
                    _ = try _scanString()
                    
                    _skipPastNextValueSeparator(byteOffset: 0)
                    try _ignoreValue()
                }
                assert(pointer.load(fromByteOffset: -1, as: UInt8.self) == .init(ascii: "}"), "The decoder should have advanced past the closing curly brace.")
                
            case .init(ascii: "["):
                // descend into array and skip all values
                try _descendIntoArray()
                while true {
                    _skipWhitespace()
                    switch pointer.nextByte {
                        case .init(ascii: "]"):
                            pointer.removeFirst()
                            // Verify that we haven't skipped beyond the bounds of the data before returning
                            try _boundsCheck()
                            return
                        case .init(ascii: ","):
                            pointer.removeFirst()
                            try _ignoreValue()
                        default:
                            try _ignoreValue()
                    }
                }
                
            default:
                throw .unexpectedCharacter
        }
        
        // Verify that we haven't skipped beyond the bounds of the data before returning
        try _boundsCheck()
    }
    
    /// A lightweight error type for unexpected data in low-level scanning operations.
    private enum ScanningError: Error {
        case unexpectedEndOfFile
        case unexpectedCharacter
    }
    
    // MARK: Any scalar decoding
    
    // I don't want to encourage API design where a decodable type doesn't know what values it is decoding for a given property.
    // Unfortunately, a few types in SymbolKit use a `AnyNumber` or `AnyScalar` type to represent a value of an unknown kind,
    // so we need to be able to decode that.
    // However, I don't want to pollute the deciders intended API with these additions,
    // so instead the decoding of these types are hardcodes in the core of the decoder implementation where they can directly read and manipulate the decoder's private state.
    
    fileprivate mutating func __workaround_decodeAnyNumber() throws(DecodingError) -> SymbolGraph.AnyNumber {
        _skipWhitespace()
    
        let startOfNumber = pointer
        
        let length: Int
        let isFloatingPoint: Bool
        do {
            (length, isFloatingPoint, _, _) = try _scanNumber()
            pointer.removeFirst(length)
            try _boundsCheck()
        } catch .unexpectedCharacter {
            throw makeTypeMismatchError(SymbolGraph.AnyNumber.self)
        } catch {
            throw makeGenericDataCorruptedError()
        }
        
        // Instead of decoding the numeric data ourselves, we use the `Double` and `Int` initializers with a String argument.
        // This requires making an allocation for the temporary String.
        // In practice decoding numbers like this should be quite uncommon but in the future we could consider implementing our own decoding.
        let temporaryString = String(decoding: UnsafeRawBufferPointer(start: startOfNumber, count: length), as: UTF8.self)
        
        if isFloatingPoint {
            guard let number = Double(temporaryString) else {
                throw makeGenericDataCorruptedError()
            }
            return .float(number)
        } else {
            guard let number = Int(temporaryString) else {
                throw makeGenericDataCorruptedError()
            }
            return .integer(number)
        }
    }
    
    fileprivate mutating func __workaround_decodeAnyScalar() throws(DecodingError) -> SymbolGraph.AnyScalar {
        _skipWhitespace()
        
        switch pointer.nextByte {
            case .init(ascii: "\""):
                return .string(try decode(String.self))
            
            case .init(ascii: "t"), .init(ascii: "f"): // true / false
                return .boolean(try decode(Bool.self))
                
            case .init(ascii: "n"): // null
                do {
                    guard try _scanNull() else {
                        throw makeTypeMismatchError(SymbolGraph.AnyScalar.self)
                    }
                } catch {
                    throw makeGenericDataCorruptedError()
                }
                guard pointer <= endOfData else {
                    throw makeGenericDataCorruptedError()
                }
                return .null
                
            case .init(ascii: "-"), .init(ascii: "0") ... .init(ascii: "9"):
                switch try __workaround_decodeAnyNumber() {
                    case .integer(let number): return .integer(number)
                    case .float(let number):   return .float(number)
                    
                    default: throw makeTypeMismatchError(SymbolGraph.AnyScalar.self)
                }
                
            // JSON arrays and JSON objects aren't scalar values
            default:
                throw makeTypeMismatchError(SymbolGraph.AnyScalar.self)
        }
    }
}

import SymbolKit

extension SymbolGraph.AnyNumber: FastJSONDecodable {
    package init(using decoder: inout FastSymbolGraphJSONDecoder) throws(DecodingError) {
        self = try decoder.__workaround_decodeAnyNumber()
    }
}

extension SymbolGraph.AnyScalar: FastJSONDecodable {
    package init(using decoder: inout FastSymbolGraphJSONDecoder) throws(DecodingError) {
        self = try decoder.__workaround_decodeAnyScalar()
    }
}

// MARK: Decodable conformances

extension String: FastJSONDecodable {
    package init(using decoder: inout FastSymbolGraphJSONDecoder) throws(DecodingError) {
        self = try decoder.decode(String.self)
    }
}

extension Int: FastJSONDecodable {
    package init(using decoder: inout FastSymbolGraphJSONDecoder) throws(DecodingError) {
        self = try decoder.decode(Int.self)
    }
}

extension Bool: FastJSONDecodable {
    package init(using decoder: inout FastSymbolGraphJSONDecoder) throws(DecodingError) {
        self = try decoder.decode(Bool.self)
    }
}

extension URL: FastJSONDecodable {
    package init(using decoder: inout FastSymbolGraphJSONDecoder) throws(DecodingError) {
        let decoded = try decoder.decode(String.self)
        guard let url = URL(string: consume decoded) else {
            throw decoder.makeGenericDataCorruptedError()
        }
        self = consume url
    }
}

extension Range<Int>: FastJSONDecodable {
    package init(using decoder: inout FastSymbolGraphJSONDecoder) throws(DecodingError) {
        let decoded = try decoder.decode([Int].self)
        // Match the behavior of JSONDecoder which decodes the first two values and ignores the rest.
        guard 2 <= decoded.count else {
            // If there are too few values, JSONDecoder treats that as a `valueNotFound` error for the specific index.
            decoder.path.push(.index(decoded.count)) // Push either 0 or 1 depending on which number is missing.
            throw .valueNotFound(Int.self, .init(codingPath: decoder.path.makeCodingPath(), debugDescription: "Unkeyed container is at end."))
        }
        // Match the behavior of JSONDecoder which decodes the first upper bound values is less than the lower bound value.
        guard decoded[0] <= decoded[1] else {
            throw .dataCorrupted(.init(codingPath: decoder.path.makeCodingPath(), debugDescription: "Cannot initialize Range<Int> with a lowerBound (\(decoded[0])) greater than upperBound (\(decoded[1]))"))
        }
        
        // We have checked the bounds above, so we don't need `Range` to check them again.
        self = .init(uncheckedBounds: (lower: decoded[0], upper: decoded[1]))
    }
}

extension Array: FastJSONDecodable where Element: FastJSONDecodable {
    package init(using decoder: inout FastSymbolGraphJSONDecoder) throws(DecodingError) {
        self = try decoder.decode([Element].self)
    }
}

extension Optional: FastJSONDecodable where Wrapped: FastJSONDecodable {
    package init(using decoder: inout FastSymbolGraphJSONDecoder) throws(DecodingError) {
        self = try decoder.decode(Wrapped?.self)
    }
}

extension Dictionary: FastJSONDecodable where Key == String, Value: FastJSONDecodable {
    package init(using decoder: inout FastSymbolGraphJSONDecoder) throws(DecodingError) {
        self = try decoder.decode([String: Value].self)
    }
}

// MARK: Private types and extensions

/// A very low level type that represents matching locations of a byte pattern in a collection of 8 bytes.
///
/// Use this type to look for a specific byte in a sequence, checking 8 bytes at a time.
private struct ByteMatches: ~Copyable {
    private let raw: UInt64
    
    /// Creates a new byte match result to find the first byte that matches the given search pattern.
    /// - Parameters:
    ///   - bytes: The 8 consecutive bytes of data to match against the search pattern.
    ///   - searchPattern: The byte to search for, repeated 8 times.
    @inlinable
    init(_ bytes: UInt64, _ searchPattern: UInt64) {
        // To understand how this type finds the locations of the bytes that match the search pattern,
        // consider the a decoder that has advanced to the first byte of the first key in the JSON below:
        //
        //     { "kind": "keyword", "spelling": "func" }
        //        ▲
        //
        // All binary illustrative below will use `_` to represent an unset bit for glanceability and will
        // order the bytes from left to right for readability, even if this doesn't represent the real endianness.
        //
        // From that state, the next 8 bytes, and their hex and binary representations, are:
        //
        //            k        i        n        d        "        :                 "
        //           6B       69       6E       64       22       3A       20       22
        //     _11_1_11 _11_1__1 _11_111_ _11__1__ __1___1_ __111_1_ __1_____ __1___1_
        //
        // If the caller is looking for the locations of string delimiter, it will pass a search pattern---
        // like `ByteMatches.quoteSearchPattern`---which repeats the "quote" character (`0x22`) 8 times.
        //
        //            "        "        "        "        "        "        "        "
        //           22       22       22       22       22       22       22       22
        //     __1___1_ __1___1_ __1___1_ __1___1_ __1___1_ __1___1_ __1___1_ __1___1_
        
        // The first step to find the matching locations it to XOR the 8 bytes with the search pattern:
        //     _11_1_11 _11_1__1 _11_111_ _11__1__ __1___1_ __111_1_ __1_____ __1___1_
        //     __1___1_ __1___1_ __1___1_ __1___1_ __1___1_ __1___1_ __1___1_ __1___1_
        //   = _1__1__1 _1__1_11 _1__11__ _1___11_ ________ ___11___ ______1_ ________
        //
        // This produces all zeros for the bytes that match the search pattern exactly, and garbage elsewhere.
        let matches = bytes ^ searchPattern
        // Next, we wrapping subtract a bit pattern where each byte only has the lowest bit set:
        //     _1__1__1 _1__1_11 _1__11__ _1___11_ ________ ___11___ ______1_ ________
        //     _______1 _______1 _______1 _______1 _______1 _______1 _______1 _______1
        //   = _1__1___ _1__1_1_ _1__1_11 _1___1_1 11111111 ___1_11_ _______1 11111111
        //
        // This produces all ones for the bytes that match the search pattern exactly, and garbage elsewhere.
        var result = matches &- Self.lowBitInEachByte
        // Next, we bitwise inverse the `matches` ...
        //     _1__1__1 _1__1_11 _1__11__ _1___11_ ________ ___11___ ______1_ ________
        //     1_11_11_ 1_11_1__ 1_11__11 1_111__1 11111111 111__111 111111_1 11111111
        //
        // This also produces all ones for the exact matching byte location, and different garbage elsewhere.
        // However, these garbage bytes and the previous garbage bytes together have an important attribute:
        // they can't _both_ have the highest bit set.
        //
        // This means that if we bitwise-and this inverse `match` with the result so far ...
        //     1_11_11_ 1_11_1__ 1_11__11 1_111__1 11111111 111__111 111111_1 11111111
        //     ________ ________ ______11 _______1 11111111 _____11_ _______1 11111111
        result &= ~matches
        // ... and then bitwise-and with a mask that only has the top bit set:
        //     1_______ 1_______ 1_______ 1_______ 1_______ 1_______ 1_______ 1_______
        //     ________ ________ ________ ________ 1_______ ________ ________ 1_______
        //
        // This produces all zeroes for the locations where the byte didn't match the search pattern and `0x80`
        // for the locations that did match the search pattern exactly.
        //
        // From this byte pattern we can quickly determine if there are any matches and where the also find the
        // number of leading non-matches before the first match.
        result &= Self.highBitInEachByte
        
        raw = result
    }
    
    // String scanning
    
    /// A search pattern for finding the "quote" character (`0x22`) in a sequence of 8 bytes.
    @usableFromInline
    static let quoteSearchPattern = Self.lowBitInEachByte &* UInt64( UInt8(ascii: "\"") )
    /// A search pattern for finding the "slash" character (`0x5C`) in a sequence of 8 bytes.
    @usableFromInline
    static let slashSearchPattern = Self.lowBitInEachByte &* UInt64( UInt8(ascii: "\\") )
    
    /// A 64-bit value that repeats a byte with only the _low_ bit set (`0b00000001`) 8 times.
    private static let lowBitInEachByte  : UInt64 = 0x01_01_01_01_01_01_01_01
    /// A 64-bit value that repeats a byte with only the _high_ bit set (`0b10000000`) 8 times.
    private static let highBitInEachByte : UInt64 = 0x80_80_80_80_80_80_80_80
    
    /// A Boolean value indicating whether there are any matches.
    @inlinable
    var hasMatches: Bool {
        raw != 0
    }
    
    /// The number of leading bytes that don't match the search pattern.
    @inlinable
    var numberOfLeadingNonMatches: Int {
        raw.trailingZeroBitCount / 8
    }
    
    /// Returns a Boolean value indicating whether the first matching location in this byte match are before the first matching location in the other byte match.
    @inlinable
    func isBefore(_ other: borrowing ByteMatches) -> Bool {
        guard other.hasMatches else {
            // Avoid counting the trailing zero bits if there are no matches in the other element.
            return true
        }
        
        return raw.trailingZeroBitCount < other.raw.trailingZeroBitCount
    }
}

/// A path into the decoder's current location in the JSON structure, consisting of keys of JSON objects and indices of JSON arrays.
///
/// This data is entirely used for error reporting and is meant to be fast lightweight until the point where a decoding error occurs.
private struct Path: ~Copyable {
    /// A component of the path to the decoder's current location in the JSON structure.
    enum Component: BitwiseCopyable {
        case key(UnsafeRawPointer)
        case index(Int)
        
        /// Increments the value of the known `.index` component.
        ///
        /// Calling this method on a `.key` component causes a fatal error.
        @inlinable
        mutating func incrementIndex() {
            switch self {
                case .index(let index): self = .index(index &+ 1)
                case .key: fatalError("Attempted to 'increment' a string key path component. It's a programming error to call `incrementIndex()` if you don't _know_ that the current component is an integer index.")
            }
        }
    }
    
    // The path uses a separate count, rather than using a buffer pointer, so that it can easily push and pop elements to the allocated storage.
    private var storage: UnsafeMutablePointer<Component>
    private var count: UInt8
    
    // Symbol graph JSON is a rather shallow structure. In practice we could allocate as little as 8 elements, without going out of bounds,
    // but we increase that eightfold to provide some headroom for future changes to the symbol graph JSON that may make its structure deeper.
    //
    // For comparison, JSONDecoder limits the nested scope at 512 but has too deal with _any_ arbitrary JSON:
    // https://github.com/swiftlang/swift-foundation/blob/main/Sources/FoundationEssentials/JSON/JSONScanner.swift#L415-L417
    // However, this decoder is for known JSON structured that's known to be shallow, so it can have different constraints.
    private static let capacity: UInt8 = 64
    
    /// Creates a new empty path, representing the decoder's initial location.
    @inlinable
    init() {
        storage = .allocate(capacity: Int(Self.capacity))
        count = 0
    }
    
    @inlinable
    deinit {
        storage.deallocate()
    }
    
    /// Pushes a new component to the end of the decoder's path
    /// - Parameter component: The component to add to the end of the decoder's path.
    @inlinable
    mutating func push(_ component: consuming Component) {
        precondition(count < Self.capacity, "Encountered an unexpectedly deep JSON structure (\(Self.capacity)).")
        storage[Int(count)] = component
        count &+= 1
    }
    
    /// Removes the last component from the decoder's path.
    @inlinable
    mutating func pop() {
        assert(0 < count, "Unbalanced number of `push` and `pop` operations. Attempted to remove more path components than what was added.")
        count &-= 1
    }
    
    /// Increments the value of last component, which you know is an `.index` component.
    ///
    /// Calling this method when the decoder's current location _isn't_ an `.index` component causes a fatal error.
    @inlinable
    mutating func incrementCurrentIndex() {
        assert(0 < count, "Attempted to 'increment' the last component of an empty path. It's a programming error to call `incrementCurrentIndex()` if you don't _know_ that the current component is an integer index.")
        storage[Int(count &- 1)].incrementIndex()
    }
    
    /// Creates a coding path to be used in decoding errors.
    @inlinable
    func makeCodingPath() -> [Path.CodingKey] {
        UnsafeBufferPointer(start: storage, count: Int(count)).map { Path.CodingKey($0) }
    }
}

private extension Path {
    /// A coding key for decoding errors.
    struct CodingKey: Swift.CodingKey {
        /// Creates a new coding key from a component of the path to the decoder's current location.
        init(_ component: Component) {
            switch component {
            case .key(let pointer):
                // Decode the key spelling by scanning until we find the closing string delimiter
                var length = 0
                while pointer.load(fromByteOffset: length, as: UInt8.self) != .init(ascii: "\"") {
                    length &+= 1
                }
                let keySpelling = String(decoding: UnsafeRawBufferPointer(start: pointer, count: length), as: UTF8.self)
                self.init(stringValue: keySpelling)
                
            case .index(let index):
                self.init(intValue: index)
            }
        }
        
        // These initializers are required
        
        let stringValue: String
        init(stringValue: String) {
            self.stringValue = stringValue
            self.intValue    = nil
        }
        
        let intValue: Int?
        init(intValue: Int) {
            self.intValue    = intValue
            self.stringValue = intValue.description
        }
    }
}

private extension UnsafeRawPointer {
    /// Advances the pointer by the given `length`.
    mutating func removeFirst(_ length: Int = 1) {
        self = advanced(by: length)
    }
    
    /// The next byte that the raw pointer is pointing to.
    var nextByte: UInt8 {
        load(as: UInt8.self)
    }
}

private extension UTF8.CodeUnit {
    /// Checks if the UTF8 code point is a JSON whitespace character (space, tab, newline, return).
    var isJSONWhitespace: Bool {
        // Note; the JSON spec only considers these 4 characters as whitespace.
        // This is a generally applicable whitespace classification.
        return self == .init(ascii:" " ) // Space
            || self == .init(ascii:"\t") // Tab
            || self == .init(ascii:"\n") // New line / Line feed
            || self == .init(ascii:"\r") // Carriage return
    }
    
    /// Checks if the UTF8 code point is an ASCII digit ("0" through "9").
    var isAsciiDigit: Bool {
        .init(ascii: "0") ... .init(ascii: "9") ~= self
    }
    
    /// Checks if the UTF8 code point is a JSON number exponent character ("e" or "E").
    var isJSONNumberExponent: Bool {
        self == .init(ascii: "e") || self == .init(ascii: "E")
    }
}
