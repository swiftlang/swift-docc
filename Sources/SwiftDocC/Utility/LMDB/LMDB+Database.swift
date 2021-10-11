/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import CLMDB

extension LMDB {
    
    /**
    A `Database` is a single LMDB database which can be used to store and retrieve data.
    
    - Note: It requires an environment to work.
    */
    class Database {
        
        /// The set of flags used by the database.
        /// - Note: [Original documentation](http://www.lmdb.tech/doc/group__mdb__dbi__open.html).
        public struct Flags: OptionSet {
            public let rawValue: Int32
            public init(rawValue: Int32) { self.rawValue = rawValue}
            
            public static let reverseKey = Flags(rawValue: MDB_REVERSEKEY)
            public static let duplicateSort = Flags(rawValue: MDB_DUPSORT)
            public static let integerKey = Flags(rawValue: MDB_INTEGERKEY)
            public static let duplicateFixed = Flags(rawValue: MDB_DUPFIXED)
            public static let integerDuplicate = Flags(rawValue: MDB_INTEGERDUP)
            public static let reverseDuplicate = Flags(rawValue: MDB_REVERSEDUP)
            public static let create = Flags(rawValue: MDB_CREATE)
        }
        
        /// The set of flags used by the database when writing a value.
        /// - Note: [Original documentation](http://www.lmdb.tech/doc/group__mdb__put.html).
        public struct WriteFlags: OptionSet {
            public let rawValue: Int32
            public init(rawValue: Int32) { self.rawValue = rawValue}
            
            public static let noOverwrite = WriteFlags(rawValue: MDB_NOOVERWRITE)
            public static let noDuplicateData = WriteFlags(rawValue: MDB_NODUPDATA)
            public static let current = WriteFlags(rawValue: MDB_CURRENT)
            public static let reserve = WriteFlags(rawValue: MDB_RESERVE)
            public static let append = WriteFlags(rawValue: MDB_APPEND)
            public static let appendDuplicate = WriteFlags(rawValue: MDB_APPENDDUP)
            public static let multiple = WriteFlags(rawValue: MDB_MULTIPLE)
        }
        
        /// A handle for an individual database in the DB environment.
        var handle: MDB_dbi = MDB_dbi()
        
        /// The environment to which the database is related to.
        public let environment: Environment
        
        internal init(environment: Environment, name: String?, flags: Flags = [.create]) throws {
            self.environment = environment
            
            let result = try Transaction(environment: environment).run { (txn) in
                return mdb_dbi_open(txn.opaquePointer, name, UInt32(flags.rawValue), &self.handle)
            }
            guard result == 0 else {
                throw Error(errorCode: result)
            }
        }
        
        // MARK: - Convenience Methods
        
        /**
        Returns the value from a given database associated with a given key, converting it to the given type.
        
        - Parameters:
           - type: The expected type of the returned object.
           - key: The key of the value associated with.
        - Returns: The value related to the given key, if existing.
        */
        public func get<Value: LMDBData, Key: LMDBData>(type: Value.Type, forKey key: Key) -> Value? {
            let result = try? Transaction(environment: environment, readOnly: true).run {
                $0.get(type: type, forKey: key, from: self)
            }
            return result ?? nil
        }
        
        /**
        Inserts a value with the given key inside a database.
        
        - Parameters:
           - key: The key of the value.
           - value: The value to be insert inside the database.
           - flags: The list of `WriteFlags` to use for the put action.
        - Throws: An error in case a read-only transaction has been used, an invalid parameter has been specified, the database is full or the transaction has too many dirty pages to complete.
        */
        public func put<Value: LMDBData, Key: LMDBData>(key: Key, value: Value, flags: WriteFlags = []) throws {
            try Transaction(environment: environment).run {
                try $0.put(key: key, value: value, in: self, flags: flags)
            }
        }
        
        /**
        Deletes a value from the database associated with a given key.
        
        - Parameters:
           - key: The key of the value.
        - Throws: An error in case a read-only transaction has been used or an invalid parameter has been specified.
        */
        public func delete<Key: LMDBData>(_ key: Key) throws {
            try Transaction(environment: environment).run {
                try $0.delete(key, from: self)
            }
        }
        
    }
}
