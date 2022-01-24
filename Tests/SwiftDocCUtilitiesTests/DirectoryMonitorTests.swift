/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocCUtilities

#if !os(Linux) && !os(Android)
fileprivate extension NSNotification.Name {
    static let testNodeUpdated = NSNotification.Name(rawValue: "testNodeUpdated")
    static let testDirectoryReloaded = NSNotification.Name(rawValue: "testDirectoryReloaded")
}

func fileURLsAreEqual(_ url1: URL, _ url2: URL) -> Bool {
    return url1.resolvingSymlinksInPath().standardizedFileURL.path == 
        url2.resolvingSymlinksInPath().standardizedFileURL.path
}
#endif

class DirectoryMonitorTests: XCTestCase {
    #if !os(Linux) && !os(Android)
    // - MARK: Directory watching test infra
    
    /// Method that automates setting up a directory monitor, setting up the relevant expectations for a test,
    /// then executing a given trigger block and wait for the expectations to fullfill.
    private func monitor(url rootURL: URL, forChangeAtURL expectedChangeOrigin: URL?, withDirectoryTreeReload isTreeReloadExpected: Bool, triggerBlock: () throws -> Void, file: StaticString = #file, line: UInt = #line) throws {
        // Creating a file will generate multiple fs events, we're interested in the fist one only
        // so we're using a Bool flag and a lock.
        let lock = NSLock()
        var hasFulfilledExpectation = false

        // Create a directory monitor and handle its events.
        let monitor = try DirectoryMonitor(root: rootURL) { rootURL, url in
            lock.lock()
            defer {
                lock.unlock()
            }
            
            guard !hasFulfilledExpectation else { return }
            
            if let expectedChangeOrigin = expectedChangeOrigin {
                XCTAssertTrue(fileURLsAreEqual(expectedChangeOrigin, url), "'\(expectedChangeOrigin.path)' is not equal to \(url.path)", file: (file), line: line)
            }

            hasFulfilledExpectation = true
            NotificationCenter.default.post(Notification(name: .testNodeUpdated))
        }
        
        monitor.didReloadWatchedDirectoryTree = { url in
            if isTreeReloadExpected {
                NotificationCenter.default.post(Notification(name: .testDirectoryReloaded))
            }
        }
        
        // Start the monitor
        try monitor.start()
        defer {
            monitor.stop()
        }
        
        var updated: XCTestExpectation!
        var reloaded: XCTestExpectation! 

        // Create the test expectations depending on the parameters
        if expectedChangeOrigin != nil {
            updated = expectation(forNotification: .testNodeUpdated, object: nil, handler: nil)
        }
        if isTreeReloadExpected {
            reloaded = expectation(forNotification: .testDirectoryReloaded, object: nil, handler: nil)
        }
        
        // Run the block that's supposed to create the trigger events in the file system.
        try triggerBlock()
        
        // Wait asynchronously for the expectations to fullfil.
        if expectedChangeOrigin != nil {
            wait(for: [updated], timeout: 5.0)
        }
        
        if isTreeReloadExpected {
            wait(for: [reloaded], timeout: 5.0)
        }
    }
    
    /// - Warning: Please do not overuse this method as it takes 10s of wait time and can potentially slow down running the test suite.
    private func monitorNoUpdates(url: URL, testBlock: @escaping () throws -> Void, file: StaticString = #file, line: UInt = #line) throws {
        let monitor = try DirectoryMonitor(root: url) { rootURL, url in
            XCTFail("Did produce file update event for a hidden file")
        }
        
        try monitor.start()
        defer {
            monitor.stop()
        }
        
        let didNotTriggerUpdateForHiddenFile = expectation(description: "Doesn't trigger update")
        DispatchQueue.global().async {
            try? testBlock()
        }
        
        // For the test purposes we assume a file change event will be delivered within generous 10 seconds.
        DispatchQueue.global().asyncAfter(deadline: .now() + 10) {
            didNotTriggerUpdateForHiddenFile.fulfill()
        }
        
        wait(for: [didNotTriggerUpdateForHiddenFile], timeout: 20)        
    }
    #endif
    
    // - MARK: Directory watching tests

    /// Tests a succession of file system changes and verifies that they produce
    /// the expected monitor events.
    func testMonitorUpdates() throws {
        #if !os(Linux) && !os(Android)

        // Create temp folder & sub-folder.
        let tempSubfolderURL = try createTemporaryDirectory(named: "subfolder")
        let tempFolderURL = tempSubfolderURL.deletingLastPathComponent()
        
        // A file URL to update.
        let updateURL = tempSubfolderURL.appendingPathComponent("test.txt")
        
        // 1) Trigger a directory update event by creating a new file.
        try monitor(url: tempFolderURL, forChangeAtURL: updateURL.deletingLastPathComponent(), withDirectoryTreeReload: true, triggerBlock: {
            // Creating a file will send a directory level event and reload the directory tree.
            try "".write(to: updateURL, atomically: true, encoding: .utf8)
        })
        
        // 2) Trigger a file event by updating an existing file non-atomically.
        try monitor(url: tempFolderURL, forChangeAtURL: updateURL, withDirectoryTreeReload: false, triggerBlock: {
            // Updating a file non-atomically does not change the directory node and does not reload the tree.
            try "non-atomically".write(to: updateURL, atomically: false, encoding: .utf8)
        })
         
        // 3) Trigger a directory event by updating an existing file atomically.
        // Since this action will trigger both file and directory level events we don't assume what the reported
        // change url will be.
        try monitor(url: tempFolderURL, forChangeAtURL: nil, withDirectoryTreeReload: true, triggerBlock: {
            try "atomically".write(to: updateURL, atomically: true, encoding: .utf8)
        })
        
        // 4) Trigger a directory event by renaming a file.
        let renamedURL = updateURL.deletingLastPathComponent().appendingPathComponent("RENAMED")
        try monitor(url: tempFolderURL, forChangeAtURL: updateURL.deletingLastPathComponent(), withDirectoryTreeReload: true, triggerBlock: {
            try FileManager.default.moveItem(at: updateURL, to: renamedURL)
        })
        
        // 5) Trigger a directory event by deleting a file. 
        try monitor(url: tempFolderURL, forChangeAtURL: updateURL.deletingLastPathComponent(), withDirectoryTreeReload: true, triggerBlock: {
            try FileManager.default.removeItem(at: renamedURL)
        })
        
        // 6) Delete the watched directory
        // This check will pass if the monitor simply does not crash when reacting to the change 
        try monitor(url: tempFolderURL, forChangeAtURL: nil, withDirectoryTreeReload: false, triggerBlock: {
            try FileManager.default.removeItem(at: tempFolderURL)
        })
        
        #endif
    }
    
    func testMonitorDoesNotTriggerUpdates() throws {
        #if !os(Linux) && !os(Android)
        
        // Create temp folder & sub-folder.
        let tempSubfolderURL = try createTemporaryDirectory(named: "subfolder")
        let tempFolderURL = tempSubfolderURL.deletingLastPathComponent()

        // 1) Test that creating a hidden file inside the tree will not trigger an update.
        try monitorNoUpdates(url: tempFolderURL, testBlock: { 
            // Create a hidden file in the monitored directory.
            let updateURL = tempSubfolderURL.appendingPathComponent(".DS_Store")
            do {
                try "".write(to: updateURL, atomically: true, encoding: .utf8)
            } catch {
                XCTFail("Could not write test file")
            }
        })

        // 2) Test that creating a sub-directory will not trigger an update
        try monitorNoUpdates(url: tempFolderURL, testBlock: { 
            // Create a hidden file in the monitored directory.
            let updateURL = tempSubfolderURL.appendingPathComponent("sub")
            do {
                try FileManager.default.createDirectory(at: updateURL, withIntermediateDirectories: false, attributes: nil)
            } catch {
                XCTFail("Could not create a test subdirectory")
            }
        })

        #endif
    }
    
    /// Tests a zero sum change aggregation triggers an event.
    func testMonitorZeroSumSizeChangesUpdates() throws {
        #if !os(Linux) && !os(Android)

        // Create temp folder & sub-folder.
        let tempSubfolderURL = try createTemporaryDirectory(named: "subfolder")
        let tempFolderURL = tempSubfolderURL.deletingLastPathComponent()
        
        // A file URL to update.
        let updateURL = tempSubfolderURL.appendingPathComponent("test.txt")
        try "A".write(to: updateURL, atomically: false, encoding: .utf8)
        
        // Wait so the initial file change doesn't interfere with the tests.
        sleep(5)
        
        // 1) Trigger a file event by updating an existing file non-atomically.
        try monitor(url: tempFolderURL, forChangeAtURL: updateURL, withDirectoryTreeReload: false, triggerBlock: {
            // Updating a file non-atomically does not change the directory node and does not reload the tree.
            try "B".write(to: updateURL, atomically: false, encoding: .utf8)
        })

        // 2) Trigger a second file event by updating an existing file non-atomically.
        try monitor(url: tempFolderURL, forChangeAtURL: updateURL, withDirectoryTreeReload: false, triggerBlock: {
            // Updating a file non-atomically does not change the directory node and does not reload the tree.
            try "A".write(to: updateURL, atomically: false, encoding: .utf8)
        })
         
        #endif
    }
}
