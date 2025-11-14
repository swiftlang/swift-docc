/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

#if os(macOS) || os(iOS)
import Darwin

// This type is designs to have the same API surface as 'Synchronization.Mutex'.
// It's different from 'SwiftDocC.Synchronized' which requires that the wrapped values is `Copyable`.
//
// When we can require macOS 15.0 we can remove this custom type and use 'Synchronization.Mutex' directly on all platforms.
struct Mutex<Value: ~Copyable>: ~Copyable, @unchecked Sendable {
    private var value: UnsafeMutablePointer<Value>
    private var lock: UnsafeMutablePointer<os_unfair_lock>
    
    init(_ initialValue: consuming sending Value) {
        value = UnsafeMutablePointer<Value>.allocate(capacity: 1)
        value.initialize(to: initialValue)
        
        lock = UnsafeMutablePointer<os_unfair_lock>.allocate(capacity: 1)
        lock.initialize(to: os_unfair_lock())
    }
    
    deinit {
        value.deallocate()
        lock.deallocate()
    }
    
    borrowing func withLock<Result: ~Copyable, E: Error>(_ body: (inout sending Value) throws(E) -> sending Result) throws(E) -> sending Result {
        os_unfair_lock_lock(lock)
        defer { os_unfair_lock_unlock(lock) }
        
        return try body(&value.pointee)
    }
}

//extension Mutex:  where Value: ~Copyable {}
#else
import Synchronization

typealias Mutex = Synchronization.Mutex
#endif
