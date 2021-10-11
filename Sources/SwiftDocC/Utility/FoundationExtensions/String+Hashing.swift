/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

extension String {
    
    /// Returns an FNV1 hashed value of the string.
    internal func fnv1() -> UInt32 {
        
        // Magic number for FNV hashing.
        let prime: UInt32 = 16777619
        
        // Start with the FNV-1 init value and keep hashing into it;
        // the hash value will overflow.
        return utf8.reduce(2166136261) { (hash, byte) -> UInt32 in
            var hval = hash &* prime
            hval ^= UInt32(byte)
            return hval
        }
    }
    
    /// FNV-1 hash string, folded to fit 24 bits, and then base36 encoded;
    /// - note: The FNV-1 algorithm is public domain.
    var stableHashString: String {
        let fnv = fnv1()
        // Fold to 24 bits and encode in base 36.
        return String((fnv >> 24) ^ (fnv & 0xffffff), radix: 36, uppercase: false)
    }
}
