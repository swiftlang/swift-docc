/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import XCTest

@testable import SwiftDocC

class ResolvedTopicReferenceTests: XCTestCase {
    func testReferenceURL() {
        let firstTopicReference = ResolvedTopicReference(
            bundleIdentifier: "bundleID",
            path: "/path/sub-path",
            fragment: "fragment",
            sourceLanguage: .swift
        )
        XCTAssertEqual(firstTopicReference.absoluteString, "doc://bundleID/path/sub-path#fragment")
        
        let secondTopicReference = ResolvedTopicReference(
            bundleIdentifier: "new-bundleID",
            path: "/new-path/sub-path",
            fragment: firstTopicReference.fragment,
            sourceLanguage: firstTopicReference.sourceLanguage
        )
        XCTAssertEqual(secondTopicReference.absoluteString, "doc://new-bundleID/new-path/sub-path#fragment")
        
        let thirdTopicReference = secondTopicReference.withFragment(nil)
        XCTAssertEqual(thirdTopicReference.absoluteString, "doc://new-bundleID/new-path/sub-path")
        
        // Changing the language does not change the url
        XCTAssertEqual(thirdTopicReference.addingSourceLanguages([.metal]).absoluteString, "doc://new-bundleID/new-path/sub-path")
    }
    
    func testAppendingReferenceWithEmptyPath() {
        // An empty path
        do {
            let resolvedOriginal = ResolvedTopicReference(bundleIdentifier: "bundleID", path: "/path/sub-path", fragment: "fragment", sourceLanguage: .swift)
            
            let unresolved = UnresolvedTopicReference(topicURL: ValidatedURL(parsingExact: "doc://host-name")!)
            XCTAssert(unresolved.path.isEmpty)
            
            let appended = resolvedOriginal.appendingPathOfReference(unresolved)
            XCTAssertEqual(appended.path, resolvedOriginal.path)
        }
        
        // A path with no url path allowed characters
        do {
            let resolvedOriginal = ResolvedTopicReference(bundleIdentifier: "bundleID", path: "/path/sub-path", fragment: "fragment", sourceLanguage: .swift)
            
            let unresolved = UnresolvedTopicReference(topicURL: ValidatedURL(parsingExact: "doc://host.name/;;;")!)
            XCTAssertFalse(unresolved.path.isEmpty)
            
            let appended = resolvedOriginal.appendingPathOfReference(unresolved)
            XCTAssertEqual(appended.path, resolvedOriginal.appendingPath("---").path)
        }
    }
    
    func testStorageIsConcurrentlyAccessible() throws {
        let topicReference = ResolvedTopicReference(
            bundleIdentifier: "com.apple.example",
            path: "/documentation/path/sub-path",
            fragment: nil,
            sourceLanguage: .swift
        )
        
        // TSan should not report a data race for these three accesses.
        // TODO: Run TSan in Swift-CI (rdar://90157829).
        DispatchQueue.concurrentPerform(iterations: 5) { _ in
            _ = topicReference.url
            _ = topicReference.pathComponents
            _ = topicReference.absoluteString
        }
    }
}
