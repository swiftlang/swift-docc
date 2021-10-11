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
        var reference = ResolvedTopicReference(bundleIdentifier: "bundleID", path: "/path/sub-path", fragment: "fragment", sourceLanguage: .swift)
        XCTAssertEqual(reference.absoluteString, "doc://bundleID/path/sub-path#fragment")
        
        reference.bundleIdentifier = "new-bundleID"
        XCTAssertEqual(reference.absoluteString, "doc://new-bundleID/path/sub-path#fragment")
        
        reference.path = "/new-path/sub-path"
        XCTAssertEqual(reference.absoluteString, "doc://new-bundleID/new-path/sub-path#fragment")
        
        reference.fragment = nil
        XCTAssertEqual(reference.absoluteString, "doc://new-bundleID/new-path/sub-path")
        
        // Changing the language does not change the url
        reference.sourceLanguage = .metal
        XCTAssertEqual(reference.absoluteString, "doc://new-bundleID/new-path/sub-path")
    }
    
    func testAppendingReferenceWithEmptyPath() {
        // An empty path
        do {
            let resolvedOriginal = ResolvedTopicReference(bundleIdentifier: "bundleID", path: "/path/sub-path", fragment: "fragment", sourceLanguage: .swift)
            
            let unresolved = UnresolvedTopicReference(topicURL: ValidatedURL("doc://host-name")!)
            XCTAssert(unresolved.path.isEmpty)
            
            let appended = resolvedOriginal.appendingPathOfReference(unresolved)
            XCTAssertEqual(appended.path, resolvedOriginal.path)
        }
        
        // A path with no url path allowed characters
        do {
            let resolvedOriginal = ResolvedTopicReference(bundleIdentifier: "bundleID", path: "/path/sub-path", fragment: "fragment", sourceLanguage: .swift)
            
            let unresolved = UnresolvedTopicReference(topicURL: ValidatedURL("doc://host.name/;;;")!)
            XCTAssertFalse(unresolved.path.isEmpty)
            
            let appended = resolvedOriginal.appendingPathOfReference(unresolved)
            XCTAssertEqual(appended.path, resolvedOriginal.appendingPath("---").path)
        }
    }
}
