/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
import Foundation
@testable import SwiftDocC

class PresentationURLGeneratorTests: XCTestCase {
    func testInternalURLs() throws {
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        let generator = PresentationURLGenerator(context: context, baseURL: URL(string: "https://host:1024/webPrefix")!)
        
        // Test resolved tutorial reference
        let reference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/tutorials/Test-Bundle/TestTutorial", sourceLanguage: .swift)
        XCTAssertEqual(generator.presentationURLForReference(reference).absoluteString, "https://host:1024/webPrefix/tutorials/test-bundle/testtutorial")
        
        // Test resolved symbol reference
        let symbol = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/MyKit/MyClass", sourceLanguage: .swift)
        XCTAssertEqual(generator.presentationURLForReference(symbol).absoluteString, "https://host:1024/webPrefix/documentation/mykit/myclass")
        
        // Test root
        let root = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/", sourceLanguage: .swift)
        XCTAssertEqual(generator.presentationURLForReference(root).absoluteString, "https://host:1024/webPrefix/documentation")
        
        // Fragment
        let fragment = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/path", fragment: "test URL! FRAGMENT", sourceLanguage: .swift)
        XCTAssertEqual(generator.presentationURLForReference(fragment).absoluteString, "https://host:1024/webPrefix/path#test-URL-FRAGMENT")
    }
}
