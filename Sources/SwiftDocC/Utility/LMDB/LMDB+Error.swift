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
     A convenience Error enum to handle potential LMDB errors.
     - Note: [List of return codes](http://www.lmdb.tech/doc/group__errors.html).
     */
    public enum Error: Swift.Error, Equatable {
        
        // LMDB defined errors.
        case keyExists
        case notFound
        case pageNotFound
        case corrupted
        case panic
        case versionMismatch
        case invalid
        case mapFull
        case dbsFull
        case readersFull
        case tlsFull
        case txnFull
        case cursorFull
        case pageFull
        case mapResized
        case incompatible
        case badReaderSlot
        case badTransaction
        case badValueSize
        case badDBI
        
        // System Errors
        case invalidParameter
        case accessError
        case synchronizationError
        case readOnlyFileSystem
        
        case other(errorCode: Int32)
        
        init(errorCode: Int32) {
            switch errorCode {
            
            case MDB_KEYEXIST: self = .keyExists
            case MDB_NOTFOUND: self = .notFound
            case MDB_PAGE_NOTFOUND: self = .pageNotFound
            case MDB_CORRUPTED: self = .corrupted
            case MDB_PANIC: self = .panic
            case MDB_VERSION_MISMATCH: self = .versionMismatch
            case MDB_INVALID: self = .invalid
            case MDB_MAP_FULL: self = .mapFull
            case MDB_DBS_FULL: self = .dbsFull
            case MDB_READERS_FULL: self = .readersFull
            case MDB_TLS_FULL: self = .tlsFull
            case MDB_TXN_FULL: self = .txnFull
            case MDB_CURSOR_FULL: self = .cursorFull
            case MDB_PAGE_FULL:  self = .pageFull
            case MDB_MAP_RESIZED: self = .mapResized
            case MDB_INCOMPATIBLE: self = .incompatible
            case MDB_BAD_RSLOT: self = .badReaderSlot
            case MDB_BAD_TXN: self = .badTransaction
            case MDB_BAD_VALSIZE: self = .badValueSize
            case MDB_BAD_DBI: self = .badDBI
                
            // System Errors
            case EINVAL: self = .invalidParameter
            case EACCES: self = .accessError
            case EIO: self = .synchronizationError
            case EROFS: self = .readOnlyFileSystem
                
            // Proxy the original code if it's another error.
            default:
                self = .other(errorCode: errorCode)
            }

        }
        
    }
}
