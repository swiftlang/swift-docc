/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2025-2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

extension UnsafeRawPointer {
    /// Checks if the raw pointer has the given ASCII prefix at the given byte offset.
    ///
    /// - Parameters:
    ///   - prefix: The ASCII prefix to check if the raw pointer starts with.
    ///   - byteOffset: The byte offset from where the raw pointer checks for the given prefix.
    /// - Returns: `true` if the raw pointer has the given ASCII prefix at the given byte offset; `false` otherwise.
    @inlinable
    func hasASCIIPrefix(_ prefix: StaticString, byteOffset: Int = 0) -> Bool {
        assert(prefix.isASCII, """
        "\(prefix)" isn't an ASCII string. It's a programming error to pass non-ASCII strings to this method.
        """)
        
        // Inline helper functions to create multi-byte values out of the static string's buffer.
        func load2Bytes(from buffer: UnsafeBufferPointer<UInt8>, offset: Int = 0) -> UInt16 {
            return UInt16(buffer[offset &+ 0])
                 | UInt16(buffer[offset &+ 1]) &<<  8
        }
        
        func load4Bytes(from buffer: UnsafeBufferPointer<UInt8>, offset: Int = 0) -> UInt32 {
            return UInt32(buffer[offset &+ 0])
                 | UInt32(buffer[offset &+ 1]) &<<  8
                 | UInt32(buffer[offset &+ 2]) &<< 16
                 | UInt32(buffer[offset &+ 3]) &<< 24
        }
        
        func load8Bytes(from buffer: UnsafeBufferPointer<UInt8>, offset: Int = 0) -> UInt64 {
            return UInt64(buffer[offset &+ 0])
                 | UInt64(buffer[offset &+ 1]) &<<  8
                 | UInt64(buffer[offset &+ 2]) &<< 16
                 | UInt64(buffer[offset &+ 3]) &<< 24
                 | UInt64(buffer[offset &+ 4]) &<< 32
                 | UInt64(buffer[offset &+ 5]) &<< 40
                 | UInt64(buffer[offset &+ 6]) &<< 48
                 | UInt64(buffer[offset &+ 7]) &<< 56
        }
        
        // Use `withUTF8Buffer` so to handle both kinds of StaticString internal implementations (either a pointer or a single Unicode scalar value).
        return prefix.withUTF8Buffer { buffer in
            // It may seem like it would be slow to switch over the string's count like this,
            // but the compiler is able to inline only the case for each string's length and optimize it into simple move instructions of integer literals.
            // This is only possible because the string is a `StaticString` which _has_ to be known at compile time.
            switch prefix.utf8CodeUnitCount {
            case 0:
                return true // An empty string is always considered a prefix match
                
            case 1:
                // Load and compare a single byte
                return loadUnaligned(fromByteOffset: byteOffset, as: UInt8.self) == buffer[0]
                
            case 2:
                // Load and compare a 2 bytes
                return loadUnaligned(fromByteOffset: byteOffset, as: UInt16.self) == load2Bytes(from: buffer)
                
            case 3:
                assertionFailure("""
                It's unnecessarily to check for a 3-byte prefix because it either requires 2 loads, or a load with a mask or shift operation. \
                For identifying JSON keys; append the trailing string delimiter as a suffix so that the prefix fully fills up a 4-byte value.
                """)
                // To avoid doing two separate reads we load 4 bytes and mask away 1 of them before comparing to the 3 bytes of static string data.
                // This technically risks reading beyond the bounds of `self`, but because we mask away the extra out-of-bounds byte, it doesn't matter.
                let bytesToCompareTo = UInt64(buffer[0])
                                     | UInt64(buffer[1]) &<<  8
                                     | UInt64(buffer[2]) &<< 16
                return loadUnaligned(fromByteOffset: byteOffset, as: UInt32.self) & 0x00_FF_FF_FF == bytesToCompareTo
                
            case 4:
                // Load and compare a 4 bytes
                return loadUnaligned(fromByteOffset: byteOffset, as: UInt32.self) == load4Bytes(from: buffer)
                
            case 5:
                // If the JSON key is 5 bytes, then we can't fill a full 8 byte value even if we include the leading and trailing string delimiters.
                // We just have to accept that this requires a bitwise and instruction before we can make the comparison.
                
                // To avoid doing two separate reads we load 8 bytes and mask away 3 of them before comparing to the 5 bytes of static string data.
                // This technically risks reading beyond the bounds of `self`, but because we mask away the extra out-of-bounds byte, it doesn't matter.
                let bytesToCompareTo = UInt64(buffer[0])
                                     | UInt64(buffer[1]) &<<  8
                                     | UInt64(buffer[2]) &<< 16
                                     | UInt64(buffer[3]) &<< 24
                                     | UInt64(buffer[4]) &<< 32
                return loadUnaligned(fromByteOffset: byteOffset, as: UInt64.self) & 0x00_00_00_FF_FF_FF_FF_FF == bytesToCompareTo
                
            case 6:
                assertionFailure("""
                It's unnecessarily to check for a 6-byte prefix, because it either requires 2 loads, or a load with a mask or shift operation. \
                For identifying JSON keys; append the leading _and_ trailing string delimiters as a prefix and suffix so that the prefix fully fills up a 8-byte value.
                """)
                // To avoid doing two separate reads we load 8 bytes and mask away 2 of them before comparing to the 5 bytes of static string data.
                // This technically risks reading beyond the bounds of `self`, but because we mask away the extra out-of-bounds byte, it doesn't matter.
                let bytesToCompareTo = UInt64(buffer[0])
                                     | UInt64(buffer[1]) &<<  8
                                     | UInt64(buffer[2]) &<< 16
                                     | UInt64(buffer[3]) &<< 24
                                     | UInt64(buffer[4]) &<< 32
                                     | UInt64(buffer[5]) &<< 40
                return loadUnaligned(fromByteOffset: byteOffset, as: UInt64.self) & 0x00_00_FF_FF_FF_FF_FF_FF == bytesToCompareTo
                
            case 7:
                assertionFailure("""
                It's unnecessarily to check for a 7-byte prefix, because it either requires 2 loads, or a load with a mask or shift operation. \
                For identifying JSON keys; append the trailing string delimiter as a suffix so that the prefix fully fills up a 8-byte value.
                """)
                // To avoid doing two separate reads we load 8 bytes and mask away 1 of them before comparing to the 5 bytes of static string data.
                // This technically risks reading beyond the bounds of `self`, but because we mask away the extra out-of-bounds byte, it doesn't matter.
                let bytesToCompareTo = UInt64(buffer[0])
                                     | UInt64(buffer[1]) &<<  8
                                     | UInt64(buffer[2]) &<< 16
                                     | UInt64(buffer[3]) &<< 24
                                     | UInt64(buffer[4]) &<< 32
                                     | UInt64(buffer[5]) &<< 40
                                     | UInt64(buffer[6]) &<< 48
                return loadUnaligned(fromByteOffset: byteOffset, as: UInt64.self) & 0x00_FF_FF_FF_FF_FF_FF_FF == bytesToCompareTo
                
            case 8:
                // Load and compare a 8 bytes
                return loadUnaligned(fromByteOffset: byteOffset, as: UInt64.self) == load8Bytes(from: buffer)
                
            // Any string longer than 8 bytes needs to be checked in two or more comparisons.
            
            // For 9 through 12, we can load 1, 2, or 4 additional bytes.
            
            case 9:
                // Load and compare a 8 bytes, then load and compare the the 9th byte.
                return loadUnaligned(fromByteOffset: byteOffset,     as: UInt64.self) == load8Bytes(from: buffer)
                    && load(         fromByteOffset: byteOffset + 8, as: UInt8.self)  == buffer[8]
                
            case 10:
                // Load and compare a 8 bytes, then load and compare the last 2 bytes.
                return loadUnaligned(fromByteOffset: byteOffset,     as: UInt64.self) == load8Bytes(from: buffer)
                    && loadUnaligned(fromByteOffset: byteOffset + 8, as: UInt16.self) == load2Bytes(from: buffer, offset: 8)
            
            case 11:
                // Load and compare a 8 bytes, then load and compare the last 4 bytes, including the 8th byte in both comparisons.
                // This makes it so that both the second load fills the full 4 bytes and don'd need further bit shifting or bit masking.
                return loadUnaligned(fromByteOffset: byteOffset,     as: UInt64.self) == load8Bytes(from: buffer)
                    && loadUnaligned(fromByteOffset: byteOffset + 7, as: UInt32.self) == load4Bytes(from: buffer, offset: 7)
            
            case 12:
                // Load and compare a 8 bytes, then load and compare the last 4 bytes.
                return loadUnaligned(fromByteOffset: byteOffset,     as: UInt64.self) == load8Bytes(from: buffer)
                    && loadUnaligned(fromByteOffset: byteOffset + 8, as: UInt32.self) == load4Bytes(from: buffer, offset: 8)
            
            // When the string is _longer than_ 12 bytes, its faster to make full 8-byte reads with overlap than it would be to make multiple shorter reads.
            //
            // For example, consider the string "pathComponents", which is 14 characters:
            // If we read the first 8 bytes ("pathComp") into one value and the last 8 bytes ("mponents") into another value, we can check the prefix in just 2 comparisons.
            //
            //   pathComponents
            //   12345678
            //         12345678
            //
            // However, if we try to make 4-byte or 2-byte reads to avoid overlap, it requires 3 reads and 3 comparison operations to check the prefix:
            //
            //   pathComponents
            //   12345678
            //           1234
            //               12
            //
            //
            case let count:
                // It may seem like it would be slow to loop over the prefix string's buffer like this,
                // but the compiler is able to unroll the loop the loop and optimize it into a series of simple move instructions of integer literals.
                // This is only possible because the string is a `StaticString` which _has_ to be known at compile time.
                
                // As long as there are 8 more bytes to read in the static string's storage, load those 8 bytes.
                var offset = 0
                while offset < (count &- 8) {
                    guard loadUnaligned(fromByteOffset: byteOffset + offset, as: UInt64.self) == load8Bytes(from: buffer, offset: offset) else {
                        return false
                    }
                    offset &+= 8
                }
                // Afterwards, check the last 8 bytes with some overlap
                offset = count &- 8
                guard loadUnaligned(fromByteOffset: byteOffset + offset, as: UInt64.self) == load8Bytes(from: buffer, offset: offset) else {
                    return false
                }
                
                return true
            }
        }
    }
}
