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
    A base transaction for LMDB.
     */
    class Transaction {
        
        /// Queue to serialize write access.
        private let queue = DispatchQueue(label: "org.swift.docc.LMDB.serialize")
        
        /// The opaque pointer of the transaction.
        var opaquePointer: OpaquePointer? = nil
        
        /// The environment the transaction is executed.
        let environment: Environment
        
        /// The parent transaction.
        weak var parent: Transaction? = nil
        
        /// Defines if a transaction is read only or not.
        public let readOnly: Bool
        
        /// Internal variable holding information if the transaction has completed or not.
        private var _completed : Bool = false
        
        /// A boolean indicating if a transaction has been completed or not. Note: thread safe.
        public var completed: Bool {
            set {
                queue.sync {
                    _completed = newValue
                }
            }
            get {
                var value: Bool!
                queue.sync {
                    value = _completed
                }
                return value
            }
        }
        
        public init(environment: Environment, parent: Transaction? = nil, readOnly: Bool = false) {
            self.environment = environment
            self.readOnly = environment.readOnly || readOnly
            self.parent = parent
        }
        
        /**
         Run a given block as transaction.
         */
        public func run<R>(_ block: ((Transaction) throws -> R)) throws -> R {
            do {
                try begin()
                let result = try block(self)
                try commit()
                return result
            } catch {
                abort()
                throw error
            }
        }
        
        /// Begins a transaction.
        public func begin() throws {
            let flags = readOnly ? UInt32(MDB_RDONLY) : 0

            let result = mdb_txn_begin(environment.opaquePointer, parent?.opaquePointer ?? nil, flags, &opaquePointer)
            guard result == 0 else {
                throw Error(errorCode: result)
            }
        }
        
        /// Renews a read-only transaction.
        public func renew() throws {
            assert(self.readOnly)
            assert(!self.completed)

            mdb_txn_reset(opaquePointer)

            let result = mdb_txn_renew(opaquePointer)
            guard result == 0 else {
                throw Error(errorCode: result)
            }
        }
        
        /// Commit current transaction.
        public func commit() throws {
            assert(!completed)
            completed = true
            
            let result = mdb_txn_commit(opaquePointer)
            guard result == 0 else {
                throw Error(errorCode: result)
            }
        }
        
        /// Abort current transaction.
        public func abort() {
            if !completed {
                completed = true
                mdb_txn_abort(opaquePointer)
            }
        }
        
        deinit {
            if !completed {
                mdb_txn_abort(opaquePointer)
            }
        }
        
        // MARK: - Convenience
        
        /**
         Get a value from a given database with given key, converting it to the given type.
         
         - Parameters:
            - type: The expected type of the returned object.
            - key: The key of the value associated with.
            - db: The database to look for the value.
         - Returns: The value related to the given key, if existing.
         */
        public func get<Value: LMDBData, Key: LMDBData>(type: Value.Type, forKey key: Key, from db: Database) -> Value?{
            return key.read { (keyPointer) in
                var keyValue = MDB_val(unsafeRawBufferPointer: keyPointer)
                var value = MDB_val()
                let result = mdb_get(self.opaquePointer, db.handle, &keyValue, &value)
                
                guard result != MDB_NOTFOUND else { return nil }

                return Value(data: UnsafeRawBufferPointer(mdbValue: value))
            }
        }
        
        /**
         Insert a value with the given key inside a database.
         
         - Parameters:
            - key: The key of the value.
            - value: The value to be insert inside the database.
            - db: The database to insert the value into.
         - Throws: An error in case a read-only transaction has been used, an invalid parameter has been specified, the database is full or the transaction has too many dirty pages to complete.
         */
        public func put<Value: LMDBData, Key: LMDBData>(key: Key, value: Value, in db: Database, flags: Database.WriteFlags = []) throws {
            try key.read() { (key: UnsafeRawBufferPointer) in
                try value.read() { (value: UnsafeRawBufferPointer) in
                    var key = MDB_val(unsafeRawBufferPointer: key)
                    var val = MDB_val(unsafeRawBufferPointer: value)
                    let result = mdb_put(self.opaquePointer, db.handle, &key, &val, UInt32(flags.rawValue))
                    guard result == 0 else {
                        throw Error(errorCode: result)
                    }
                }
            }
        }
        
        /**
        Delete a value from the database with a given key.
        
        - Parameters:
           - key: The key of the value.
           - db: The database form which the value has to be deleted.
        - Throws: An error in case a read-only transaction has been used or an invalid parameter has been specified.
        */
        public func delete<Key: LMDBData>(_ key: Key, from db: Database) throws {
            try key.read() { key in
                var keyVal = MDB_val(unsafeRawBufferPointer:key)
                let result = mdb_del(self.opaquePointer, db.handle, &keyVal, nil)
                guard result == 0 else {
                    throw Error(errorCode: result)
                }
            }
        }
        
    }
}

// MARK: - Utilities

internal extension UnsafeRawBufferPointer {
        
    /// Initialize `UnsafeRawBufferPointer` from the current MDB_val.
    init(mdbValue: MDB_val) {
        self.init(start: mdbValue.mv_data, count: mdbValue.mv_size)
    }
    
}

internal extension MDB_val {
    
    /// Initialize a `MDB_val` from the current pointer.
    init(unsafeRawBufferPointer: UnsafeRawBufferPointer) {
        self.init(mv_size: unsafeRawBufferPointer.count, mv_data: UnsafeMutableRawPointer(mutating: unsafeRawBufferPointer.baseAddress))
    }
    
}
