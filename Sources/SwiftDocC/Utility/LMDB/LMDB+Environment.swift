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
     An `Environment` is the base of LMDB.
     It's opened using a file path which can contain 0 or more databases.
     
     - Note: An environment is necessary to open a database.
     */
    class Environment {
        
        /// The set of flags used by the environment.
        /// - Note: [Original documentation](http://www.lmdb.tech/doc/group__mdb__env.html).
        public struct Flags: OptionSet {
            public let rawValue: Int32
            public init(rawValue: Int32) { self.rawValue = rawValue }
            
            public static let fixedMap = Flags(rawValue: MDB_FIXEDMAP)
            public static let noSubDir = Flags(rawValue: MDB_NOSUBDIR)
            public static let noSync = Flags(rawValue: MDB_NOSYNC)
            public static let readOnly = Flags(rawValue: MDB_RDONLY)
            public static let noMetaSync = Flags(rawValue: MDB_NOMETASYNC)
            public static let writeMap = Flags(rawValue: MDB_WRITEMAP)
            public static let mapAsync = Flags(rawValue: MDB_MAPASYNC)
            public static let noTLS = Flags(rawValue: MDB_NOTLS)
            public static let noLock = Flags(rawValue: MDB_NOLOCK)
            public static let noReadahead = Flags(rawValue: MDB_NORDAHEAD)
            public static let noMemoryInit = Flags(rawValue: MDB_NOMEMINIT)
        }
        
        /// Provides access to database handle when in opened state only.
        public private(set) var opaquePointer: OpaquePointer? = nil
        
        /// Provides the information is the Environment is in read-only mode.
        public private(set) var readOnly: Bool = false
        
        /**
         Initialize an environment for a given path using the given flags.
         
         - Parameters:
            - path: The path to open the environment. Note: the path must exist on the disk.
            - maxDBs: The maximum number of databases that can be opened in the environment. Default: infinite.
            - maxReaders: The maximum number of readers to use. Default: 126
            - mapSize: The size of the map on disk in bytes. Default: 10 MB.
            - fileMode: The `mode_t` to use when opening a file for the database. Default: 744.
         
         - Throws: An error if the environment can't be initialized correctly.
         */
        public init(path: String, flags: Flags = [], maxDBs: UInt32 = LMDB.defaultMaxDBs, maxReaders: UInt32 = LMDB.defaultMaxReaders, mapSize: size_t = LMDB.defaultMapSize, fileMode: mode_t = LMDB.defaultFileMode) throws {

            let result = mdb_env_create(&opaquePointer)
            guard result == 0 else {
                throw Error(errorCode: result)
            }
            
            // Mark the environment as read-only if the flag is set.
            readOnly = flags.contains(.readOnly)
            try configureEnvironment(opaquePointer: opaquePointer, maxDBs: maxDBs, maxReaders: maxReaders, mapSize: mapSize, fileMode: fileMode)
            
            var status = mdb_env_open(opaquePointer, path, UInt32(flags.rawValue), fileMode)
            
            // In case the filesystem is ready-only or the user has not permission to write, just open the environment as read-only and return it.
            if Error(errorCode: status) == Error.readOnlyFileSystem || (Error(errorCode: status) == Error.accessError && !flags.contains(.readOnly))  {
                close() // We need to release the previously failed pointer before performing the fallback process.
                
                guard mdb_env_create(&opaquePointer) == 0 else {
                    throw Error(errorCode: result)
                }
                
                try configureEnvironment(opaquePointer: opaquePointer, maxDBs: maxDBs, maxReaders: maxReaders, mapSize: mapSize, fileMode: fileMode)
                
                status = mdb_env_open(opaquePointer, path, UInt32(flags.union([.readOnly, .noLock]).rawValue), fileMode)
                readOnly = true
            }
            
            guard status == 0 else {
                close()
                throw Error(errorCode: status)
            }
        }
        
        private func configureEnvironment(opaquePointer: OpaquePointer? = nil, maxDBs: UInt32 = LMDB.defaultMaxDBs, maxReaders: UInt32 = LMDB.defaultMaxReaders, mapSize: size_t = LMDB.defaultMapSize, fileMode: mode_t = LMDB.defaultFileMode) throws {
            
            if maxDBs != LMDB.defaultMaxDBs {
                let returnCode = mdb_env_set_maxdbs(opaquePointer, MDB_dbi(maxDBs))
                guard returnCode == 0 else {
                    throw Error(errorCode: returnCode)
                }
            }
            
            if maxReaders != LMDB.defaultMaxReaders {
                let returnCode = mdb_env_set_maxreaders(opaquePointer, maxReaders)
                guard returnCode == 0 else {
                    throw Error(errorCode: returnCode)
                }
            }
            
            if mapSize != LMDB.defaultMapSize {
                let returnCode = mdb_env_set_mapsize(opaquePointer, mapSize)
                guard returnCode == 0 else {
                    throw Error(errorCode: returnCode)
                }
            }
            
        }
        
        deinit {
            close()
        }
        
        // MARK: State Management
        
        /// Close the environment and release the memory map.
        public func close() {
            if opaquePointer != nil {
                mdb_env_close(opaquePointer)
                opaquePointer = nil
            }
        }
        
        
        /// Opens a database in the environment.
        /// - Parameters:
        ///   - name: The name of the database. `nil` implies the usage of the anonymous database.
        ///   - flags: The flags to be used to open the database.
        /// - Throws: An error if operation fails. See `LMDB.Error` for reference.
        /// - Returns: An instance of `Database`.
        public func openDatabase(named name: String? = nil, flags: Database.Flags = [.create]) throws -> Database {
            return try Database(environment: self, name: name, flags: flags)
        }
        
        
        /// Creates a transaction for this Environment.
        /// - Parameters:
        ///   - parent: The parent transaction to use. Default: `nil`.
        ///   - readOnly: Defines if a transaction is read-only. Default `false`.
        /// - Returns: Returns a `Transaction` instance for the current Environment.
        public func transaction(parent: Transaction? = nil, readOnly: Bool = false) -> Transaction {
            return Transaction(environment: self, parent: parent, readOnly: readOnly)
        }

    }
}
