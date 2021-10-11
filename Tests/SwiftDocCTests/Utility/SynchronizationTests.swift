/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocC

class SynchronizationTests: XCTestCase {
    func testInitialState() {
        let synced = Synchronized(false)
        
        // Verify the value was stored
        XCTAssertEqual(synced.sync({ $0 }), false)
        
        // Verify the lock is unlocked
        #if os(macOS) || os(iOS)
        XCTAssertTrue(os_unfair_lock_trylock(synced.lock))
        #else
        XCTAssertEqual(pthread_mutex_trylock(synced.lock),0)
        #endif
    }
    
    func testUpdatesWrappedValue() {
        let synced = Synchronized(false)
        synced.sync({ $0 = true })
        XCTAssertEqual(synced.sync({ $0 }), true)
    }
    
    func testUnlocksLockWhenDoneWithWork() {
        let synced = Synchronized(false)
        
        // Run a sync block
        synced.sync({ $0 = true })
        
        // Verify the block was executed
        XCTAssertEqual(synced.sync({ $0 }), true)
        
        // Verify the lock is unlocked after running the block
        #if os(macOS) || os(iOS)
        XCTAssertTrue(os_unfair_lock_trylock(synced.lock))
        #else
        XCTAssertEqual(pthread_mutex_trylock(synced.lock),0)
        #endif
    }
    
    func testLocksLockDuringPerformingWork() {
        let synced = Synchronized(false)
        
        let didTest = expectation(description: "Did test if lock is locked")
        
        let testQueue = DispatchQueue(label: "Lock Test Queue", qos: .default, attributes: .concurrent)

        // Schedule the synchronized block of work asynchronously
        testQueue.async {
            synced.sync { _ in _ = sleep(5) }
        }
        
        // Asynchronously perform a check after 0.25 secs that the lock is locked
        testQueue.asyncAfter(deadline: .now() + 0.25) {
            // Verify the used lock is lock in here
            #if os(macOS) || os(iOS)
            XCTAssertFalse(os_unfair_lock_trylock(synced.lock))
            #else
            XCTAssertNotEqual(pthread_mutex_trylock(synced.lock),0)
            #endif
            didTest.fulfill()
        }

        wait(for: [didTest], timeout: 7)
    }
    
    enum MyError: Foundation.LocalizedError {
        case test
        var errorDescription: String? { return "My test error" }
    }
    
    func testRethrowsAndUnlocks() {
        let synced = Synchronized(false)
        
        XCTAssertThrowsError(try synced.sync({ _ in throw MyError.test }), "withLock() didn't rethrow") { error in
            XCTAssertEqual(error.localizedDescription, "My test error")
        }
        
        // Verify that the lock is unlocked after re-throwing
        #if os(macOS) || os(iOS)
        XCTAssertTrue(os_unfair_lock_trylock(synced.lock))
        #else
        XCTAssertEqual(pthread_mutex_trylock(synced.lock),0)
        #endif
    }

    func testBlocking() {
        let synced = Synchronized(false)
        
        let didTest = expectation(description: "Did test if lock is locked")
        
        let testQueue = DispatchQueue(label: "Lock Test Queue", qos: .default, attributes: .concurrent)

        // Block the access for a second, then update to `true`
        testQueue.async {
            synced.sync {
                _ = sleep(1)
                $0 = true
            }
        }
        
        testQueue.asyncAfter(deadline: .now() + 0.25) {
            // Assert that syncValue() returns when the previous block is finished and updated the value.
            XCTAssertEqual(synced.sync({ $0 }), true)
            didTest.fulfill()
        }

        wait(for: [didTest], timeout: 2)
        
        // The final state of the wrapped value
        XCTAssertEqual(synced.sync({ $0 }), true)
    }
    
    func testGenericLockInitialState() {
        let synced = Lock()
                
        // Verify the lock is unlocked
        #if os(macOS) || os(iOS)
        XCTAssertTrue(os_unfair_lock_trylock(synced.lock))
        #else
        XCTAssertEqual(pthread_mutex_trylock(synced.lock), 0)
        #endif
    }
    
    func testBlockingWithLock() {
        let synced = Lock()
        var value = false
        
        let didTest = expectation(description: "Did test if lock is locked")
        
        let testQueue = DispatchQueue(label: "Lock Test Queue", qos: .default, attributes: .concurrent)

        // Block the access for a second, then update to `true`
        testQueue.async {
            synced.sync {
                _ = sleep(5)
                value = true
            }
        }
        
        testQueue.asyncAfter(deadline: .now() + 0.25) {
            // Assert that the lock is blocking access
            XCTAssertEqual(value, false)
            let syncedValue = synced.sync({ value })
            XCTAssertEqual(syncedValue, true)
            didTest.fulfill()
        }

        wait(for: [didTest], timeout: 7)
        
        // The final state of the value
        XCTAssertEqual(value, true)
    }

}
