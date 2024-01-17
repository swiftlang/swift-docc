/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocC

class IdentifierTests: XCTestCase {

    func testURLReadableFragment() {
        // Test empty
        XCTAssertEqual(urlReadableFragment(""), "")

        // Test trimming invalid characters
        XCTAssertEqual(urlReadableFragment(" ä ö "), "ä-ö")
        XCTAssertEqual(urlReadableFragment(" asdö  "), "asdö")
        
        // Test lowercasing
        XCTAssertEqual(urlReadableFragment(" ASD  "), "ASD")
        
        // Test replacing invalid characters
        XCTAssertEqual(urlReadableFragment(" ASD ASD  "), "ASD-ASD")
        XCTAssertEqual(urlReadableFragment(" 3äêòNS  "), "3äêòNS")

        // Test replacing continuous whitespace
        XCTAssertEqual(urlReadableFragment("    Aä    êò  B   CD    "), "Aä-êò-B-CD")

        // Test replacing quotes
        XCTAssertEqual(urlReadableFragment(" This is a 'test' "), "This-is-a-test")
        XCTAssertEqual(urlReadableFragment(" This is a \"test\" "), "This-is-a-test")
        XCTAssertEqual(urlReadableFragment(" This is a `test` "), "This-is-a-test")
        
        // Test replacing complete sentence.
        XCTAssertEqual(urlReadableFragment("Test replacing 'complete' sentence"), "Test-replacing-complete-sentence")
        
        XCTAssertEqual(urlReadableFragment("💻"), "💻")
    }
    
    func testURLReadableFragmentTwice() {
        XCTAssertEqual(urlReadableFragment(urlReadableFragment("")), "")

        XCTAssertEqual(urlReadableFragment(urlReadableFragment(" ä ö ")), "ä-ö")
        XCTAssertEqual(urlReadableFragment(urlReadableFragment(" asdö  ")), "asdö")
        
        XCTAssertEqual(urlReadableFragment(urlReadableFragment(" ASD  ")), "ASD")
        
        XCTAssertEqual(urlReadableFragment(urlReadableFragment(" ASD ASD  ")), "ASD-ASD")
        XCTAssertEqual(urlReadableFragment(urlReadableFragment(" 3äêòNS  ")), "3äêòNS")

        XCTAssertEqual(urlReadableFragment(urlReadableFragment("    Aä    êò  B   CD    ")), "Aä-êò-B-CD")

        XCTAssertEqual(urlReadableFragment(urlReadableFragment(" This is a 'test' ")), "This-is-a-test")
        XCTAssertEqual(urlReadableFragment(urlReadableFragment(" This is a \"test\" ")), "This-is-a-test")
        XCTAssertEqual(urlReadableFragment(urlReadableFragment(" This is a `test` ")), "This-is-a-test")
        
        XCTAssertEqual(urlReadableFragment(urlReadableFragment("Test replacing 'complete' sentence")), "Test-replacing-complete-sentence")
        
        XCTAssertEqual(urlReadableFragment(urlReadableFragment("💻")), "💻")
    }
    
    func testReusingReferences() {
        let bundleID = #function
        XCTAssertNil(ResolvedTopicReference._numberOfCachedReferences(bundleID: bundleID), "Cache for this bundle shouldn't exist because caching is not enabled by default")
        
        // Add one reference
        ResolvedTopicReference.enableReferenceCaching(for: bundleID)
        XCTAssertEqual(ResolvedTopicReference._numberOfCachedReferences(bundleID: bundleID), 0, "Should have an empty cache after enabling reference caching for this bundle")
        
        // Add the same reference repeatedly
        _ = ResolvedTopicReference(bundleIdentifier: bundleID, path: "/path/to/page", sourceLanguage: .swift)
        XCTAssertEqual(ResolvedTopicReference._numberOfCachedReferences(bundleID: bundleID), 1, "Should have an cached one reference because a reference with this bundle identifier was created")
        
        _ = ResolvedTopicReference(bundleIdentifier: bundleID, path: "/path/to/page", sourceLanguage: .swift)
        _ = ResolvedTopicReference(bundleIdentifier: bundleID, path: "/path/to/page", sourceLanguage: .swift)
        XCTAssertEqual(ResolvedTopicReference._numberOfCachedReferences(bundleID: bundleID), 1, "Should still only have one cached reference because the same reference was created repeatedly")
        
        // Add another reference
        _ = ResolvedTopicReference(bundleIdentifier: bundleID, path: "/path/to/other-page", sourceLanguage: .swift)
        XCTAssertEqual(ResolvedTopicReference._numberOfCachedReferences(bundleID: bundleID), 2, "Should have cached another reference because two different references with this bundle identifier has been created")
        
        // Purge and repeat
        ResolvedTopicReference.purgePool(for: bundleID)
        XCTAssertNil(ResolvedTopicReference._numberOfCachedReferences(bundleID: bundleID), "Cache for this bundle shouldn't have been deleted because the pool was purged")
        
        ResolvedTopicReference.enableReferenceCaching(for: bundleID)
        XCTAssertEqual(ResolvedTopicReference._numberOfCachedReferences(bundleID: bundleID), 0, "Should have an empty cache after enabling reference caching for this bundle")
        
        _ = ResolvedTopicReference(bundleIdentifier: bundleID, path: "/path/to/page", sourceLanguage: .swift)
        XCTAssertEqual(ResolvedTopicReference._numberOfCachedReferences(bundleID: bundleID), 1, "Should have an cached one reference because a reference with this bundle identifier was created")
    }
    
    func testReferencesAreNotCachedByDefault() {
        let bundleID = #function
        XCTAssertNil(ResolvedTopicReference._numberOfCachedReferences(bundleID: bundleID), "References for this bundle shouldn't exist because caching is not enabled by default")
        
        _ = ResolvedTopicReference(bundleIdentifier: bundleID, path: "/path/to/page", sourceLanguage: .swift)
        XCTAssertNil(ResolvedTopicReference._numberOfCachedReferences(bundleID: bundleID), "After creating a reference in this bundle, references still shouldn't exist because caching is not enabled by default")
    }
    
    func testReferenceInitialPathComponents() {
        let ref1 = ResolvedTopicReference(bundleIdentifier: "bundle", path: "/", sourceLanguage: .swift)
        XCTAssertEqual(ref1.pathComponents, ["/"])
        let ref2 = ResolvedTopicReference(bundleIdentifier: "bundle", path: "/MyClass", sourceLanguage: .swift)
        XCTAssertEqual(ref2.pathComponents, ["/", "MyClass"])
        let ref3 = ResolvedTopicReference(bundleIdentifier: "bundle", path: "/MyClass/myFunction", sourceLanguage: .swift)
        XCTAssertEqual(ref3.pathComponents, ["/", "MyClass", "myFunction"])
    }
    
    func testReferenceUpdatedPathComponents() {
        var ref1 = ResolvedTopicReference(bundleIdentifier: "bundle", path: "/", sourceLanguage: .swift)
        XCTAssertEqual(ref1.pathComponents, ["/"])
        ref1 = ref1.appendingPath("MyClass")
        XCTAssertEqual(ref1.pathComponents, ["/", "MyClass"])
        ref1 = ref1.appendingPath("myFunction")
        XCTAssertEqual(ref1.pathComponents, ["/", "MyClass", "myFunction"])
        ref1 = ref1.removingLastPathComponent()
        XCTAssertEqual(ref1.pathComponents, ["/", "MyClass"])
    }

    func testReferenceInitialAbsoluteString() {
        let ref1 = ResolvedTopicReference(bundleIdentifier: "bundle", path: "/", sourceLanguage: .swift)
        XCTAssertEqual(ref1.absoluteString, "doc://bundle/")
        let ref2 = ResolvedTopicReference(bundleIdentifier: "bundle", path: "/MyClass", sourceLanguage: .swift)
        XCTAssertEqual(ref2.absoluteString, "doc://bundle/MyClass")
        let ref3 = ResolvedTopicReference(bundleIdentifier: "bundle", path: "/MyClass/myFunction", sourceLanguage: .swift)
        XCTAssertEqual(ref3.absoluteString, "doc://bundle/MyClass/myFunction")
    }
    
    func testReferenceUpdatedAbsoluteString() {
        var ref1 = ResolvedTopicReference(bundleIdentifier: "bundle", path: "/", sourceLanguage: .swift)
        XCTAssertEqual(ref1.absoluteString, "doc://bundle/")
        ref1 = ref1.appendingPath("MyClass")
        XCTAssertEqual(ref1.absoluteString, "doc://bundle/MyClass")
        ref1 = ref1.appendingPath("myFunction")
        XCTAssertEqual(ref1.absoluteString, "doc://bundle/MyClass/myFunction")
        ref1 = ref1.removingLastPathComponent()
        XCTAssertEqual(ref1.absoluteString, "doc://bundle/MyClass")
    }
    
    func testResolvedTopicReferenceDoesNotCopyStorageIfNotModified() {
         let reference1 = ResolvedTopicReference(bundleIdentifier: "bundle", path: "/", sourceLanguage: .swift)
         let reference2 = reference1

         XCTAssertEqual(
             ObjectIdentifier(reference1._storage),
             ObjectIdentifier(reference2._storage)
         )
    }
    
    func testWithSourceLanguages() {
        let swiftReference = ResolvedTopicReference(
            bundleIdentifier: "bundle",
            path: "/",
            sourceLanguage: .swift
        )
        
        XCTAssertEqual(
            swiftReference.withSourceLanguages([.objectiveC]).sourceLanguages,
            [.objectiveC]
        )
        
        XCTAssertEqual(
            swiftReference.withSourceLanguages([.swift]).sourceLanguages,
            [.swift]
        )
        
        XCTAssertEqual(
            swiftReference.withSourceLanguages([.objectiveC, .swift]).sourceLanguages,
            Set([.swift, .objectiveC])
        )
    }
}
