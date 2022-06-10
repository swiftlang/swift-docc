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
        // Verify the bundle doesn't exist in the pool
        XCTAssertFalse(ResolvedTopicReference.sharedPool.sync({ $0.keys.contains(#function) }))
        
        // Enable caching for our test bundle identifier
        ResolvedTopicReference.enableReferenceCaching(for: #function)
        
        // Create a resolved reference
        let ref = ResolvedTopicReference(bundleIdentifier: #function, path: "/path/child", sourceLanguage: .swift)
        _ = ref // to suppress the warning above
        
        // Verify the bundle was added to the pool
        guard let references = ResolvedTopicReference.sharedPool.sync({ $0[#function] }) else {
            XCTFail("Reference bundle was not added to reference cache")
            return
        }
        
        // Verify the child is now in the pool
        XCTAssertEqual(references.contains(where: { pair -> Bool in
            return pair.key.contains("/path/child")
        }), true)
        
        // Clear the cache
        ResolvedTopicReference.purgePool(for: #function)
        
        // Verify there are no references in the pool for that bundle
        XCTAssertFalse(ResolvedTopicReference.sharedPool.sync({ $0.keys.contains(#function) }))
        
        // Re-enable caching for our test bundle identifier
        ResolvedTopicReference.enableReferenceCaching(for: #function)
        
        let ref1 = ResolvedTopicReference(bundleIdentifier: #function, path: "/path/child", sourceLanguage: .swift)
        _ = ref1
        
        // Verify the bundle was added to the pool
        guard let references1 = ResolvedTopicReference.sharedPool.sync({ $0[#function] }) else {
            XCTFail("Reference bundle was not added to reference cache")
            return
        }

        // Verify the pool bucket was re-created and the reference is in the pool
        XCTAssertEqual(references1.contains(where: { pair -> Bool in
            return pair.key.contains("/path/child")
        }), true)
    }
    
    func testReferencesAreNotCachedByDefault() {
        // Verify the bundle doesn't exist in the pool
        XCTAssertFalse(ResolvedTopicReference.sharedPool.sync({ $0.keys.contains(#function) }))
        
        // Create a resolved reference
        let reference = ResolvedTopicReference(
            bundleIdentifier: #function,
            path: "/path/child",
            sourceLanguage: .swift
        )
        
        // Verify the bundle still doesn't exist in the pool
        XCTAssertFalse(ResolvedTopicReference.sharedPool.sync({ $0.keys.contains(#function) }))
        
        // Add a use of 'reference' to suppress Swift's 'reference' was never used warning
        XCTAssertNotNil(reference)
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
