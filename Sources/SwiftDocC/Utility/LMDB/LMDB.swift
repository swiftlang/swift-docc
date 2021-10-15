/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import CLMDB

/**
    A general utility class for LMDB.
 
    - Note: LMDB wrapper doesn't use any writing queue to serialize writes, but it relies on LMDB's low level solution.
            Reads are never blocked, but writes are serialized using a mutually exclusive lock at the database level.
 */
final class LMDB {
        
    /// Default instance.
    public static var `default` = LMDB()
    
    /// Returns the library version.
    public var version: Version {        
        return [Int(MDB_VERSION_MAJOR), Int(MDB_VERSION_MINOR), Int(MDB_VERSION_PATCH)]
    }
    
    /// The default number of databases to open which is `0`. The `0` value means no named databases can be opened.
    public static let defaultMaxDBs: UInt32 = 0
    
    /// The default number of  readers to open which is `126`.
    public static let defaultMaxReaders: UInt32 = 126
    
    /// The default number of map size which is `10485760`.
    public static let defaultMapSize: size_t = 10485760
    
    /// The default file mode for opening an environment which is `744`.
    public static let defaultFileMode: mode_t = S_IRWXU | S_IRGRP | S_IROTH
    
}

/**
 A type with a customized data representation suited for storage inside an LMDB database.

 Types that conform to the `LMDBData` protocol can provide their own representation to be used when converting 
 an instance to a valid data representation ready for LMDB storage.

 > Note: Default implementations for some common Swift types are included. Custom types require an appropriate 
 implementation of the conversion.
 */
public protocol LMDBData {
    init?(data: UnsafeRawBufferPointer)
    func read<ResultType>(_ body: (UnsafeRawBufferPointer) throws -> ResultType) rethrows -> ResultType
}

public extension LMDBData {
    init?(data: UnsafeRawBufferPointer) {
        guard data.count == MemoryLayout<Self>.stride else { return nil }
        self = data.baseAddress!.assumingMemoryBound(to: Self.self).pointee
    }
    
    func read<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
        var val = self
        return try withUnsafeBytes(of: &val, body)
    }
}

extension Data: LMDBData {
    public init?(data: UnsafeRawBufferPointer) {
        self = Data.init(bytes: data.baseAddress!, count: data.count)
    }

#if swift(>=5.0)
    public func read<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R{
        return try self.withUnsafeBytes({ (ptr) -> R in
            return try body(ptr)
        })
    }
#else
    public func read<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R{
        return try self.withUnsafeBytes({ (ptr) -> R in
            return try body(UnsafeRawBufferPointer(start: ptr, count: self.count))
        })
    }
#endif
}

extension String: LMDBData {
    public init?(data: UnsafeRawBufferPointer) {
        self.init(bytes: data, encoding: .utf8)
    }

    public func read<ResultType>(_ body: (UnsafeRawBufferPointer) throws -> ResultType) rethrows -> ResultType {
        return try self.data(using: .utf8)!.read(body)
    }
}

#if !os(Linux) && !os(Android)
// This is required for macOS and Swift 4.2, for Linux the default implementation works as expected.
extension Array: LMDBData where Element: FixedWidthInteger {
    
    public init?(data: UnsafeRawBufferPointer) {
        var array = Array<Element>(repeating: 0, count: data.count / MemoryLayout<Element>.stride)
        _ = array.withUnsafeMutableBytes { data.copyBytes(to: $0) }
        self = array
    }
    
    public func read<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
        let data = self.withUnsafeBufferPointer { Data(buffer: $0) }
        return try data.read(body)
    }

}
#else
extension Array: LMDBData where Element: FixedWidthInteger {}
#endif

extension Bool: LMDBData {}
extension Int: LMDBData {}
extension Int8: LMDBData {}
extension Int16: LMDBData {}
extension Int32: LMDBData {}
extension Int64: LMDBData {}
extension UInt: LMDBData {}
extension UInt8: LMDBData {}
extension UInt16: LMDBData {}
extension UInt32: LMDBData {}
extension UInt64: LMDBData {}
extension Float: LMDBData {}
extension Double: LMDBData {}
extension Date: LMDBData {}
extension URL: LMDBData {}
