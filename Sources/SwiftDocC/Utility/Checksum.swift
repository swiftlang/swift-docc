/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Crypto

/// A checksum generator.
public struct Checksum {
    
    /// Computes the SHA512 checksum of the given data as a lowercased hex string.
    ///
    /// - Parameter data: The data to compute the checksum for.
    /// - Returns: The SHA512 checksum as a hex string.
    public static func sha512(of data: Data) -> String {
        return SHA512.hash(data: data).hexString()
    }
    
    /// Computes the MD5 checksum of the given data as a lowercased hex string.
    ///
    /// - Important: This hash algorithm isn’t considered cryptographically secure.
    ///
    /// - Parameter data: The data to compute the checksum for.
    /// - Returns: The MD5 checksum as a hex string.
    public static func md5(of data: Data) -> String {
        return Insecure.MD5.hash(data: data).hexString()
    }
}

/// Note: this extension is private because it's not meant for general use.
private extension Sequence where Self.Element == UInt8 {
    
    /// Creates a lowercase hex string from a sequence of 8-bit unsigned integers.
    func hexString() -> String {
        return reduce(into: "") { accumulator, byte in
            accumulator += String(format: "%02x", byte)
        }
    }
}
