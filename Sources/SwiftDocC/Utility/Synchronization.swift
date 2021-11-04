/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A wrapper type that ensures a synchronous access to a value.
///
/// To guarantee safe concurrent access to a value wrap it in a `Synchronized` type.
/// ```swift
/// let index = Synchronized([String: String]())
///
/// // Mutate the value
/// index.sync { $0["key"] = "value" }
/// // Access the value
/// let value = index.sync { $0["key"] }
/// ```
public class Synchronized<Value> {
    /// A value that requires synchronized access.
    private var value: Value
    
    #if os(macOS) || os(iOS)
    /// A lock type appropriate for the current platform.
    /// > Note: To avoid access race reports we manage the memory manually.
    var lock: UnsafeMutablePointer<os_unfair_lock>
    #elseif os(Linux) || os(Android)
    /// A lock type appropriate for the current platform.
    var lock: UnsafeMutablePointer<pthread_mutex_t>
    #else
    #error("Unsupported platform")
    #endif
    
    /// Creates a new synchronization over the given value.
    /// - Parameter value: A value that requires synchronous access.
    public init(_ value: Value) {
        self.value = value

        #if os(macOS) || os(iOS)
        lock = UnsafeMutablePointer<os_unfair_lock>.allocate(capacity: 1)
        lock.initialize(to: os_unfair_lock())
        #elseif os(Linux) || os(Android)
        lock = UnsafeMutablePointer<pthread_mutex_t>.allocate(capacity: 1)
        lock.initialize(to: pthread_mutex_t())
        pthread_mutex_init(lock, nil)
        #else
        #error("Unsupported platform")
        #endif
    }
    
    deinit {
        // Release the lock's memory.
        lock.deallocate()
    }
    
    /// Performs a given block of code while synchronizing over the type's stored value.
    /// - Parameter block: A throwing block of work that optionally returns a value.
    /// - Returns: Returns the returned value of `block`, if any.
    @discardableResult
    public func sync<Result>(_ block: (inout Value) throws -> Result) rethrows -> Result {
        #if os(macOS) || os(iOS)
        os_unfair_lock_lock(lock)
        defer { os_unfair_lock_unlock(lock) }
        #elseif os(Linux) || os(Android)
        pthread_mutex_lock(lock)
        defer { pthread_mutex_unlock(lock) }
        #else
        #error("Unsupported platform")
        #endif
        
        return try block(&value)
    }
}

/// A platform-appropriate locking mechanism.
/// - Note: Prefer ``Synchronized`` if you need to synchronize access
/// to a given value instead of a generic lock.
/// ```swift
/// let lock = Lock()
///
/// lock.sync { myVar = 1 }
/// let result = lock.sync { return index["key"] }
/// ```
typealias Lock = Synchronized<Void>

public extension Lock {
    /// Creates a new lock.
    convenience init() {
        self.init(())
    }
    
    @discardableResult
    func sync<Result>(_ block: () throws -> Result) rethrows -> Result {
        #if os(macOS) || os(iOS)
        os_unfair_lock_lock(lock)
        defer { os_unfair_lock_unlock(lock) }
        #elseif os(Linux) || os(Android)
        pthread_mutex_lock(lock)
        defer { pthread_mutex_unlock(lock) }
        #else
        #error("Unsupported platform")
        #endif
        return try block()
    }    
}
