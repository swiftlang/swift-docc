/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Testing
import Foundation
@testable import SwiftDocC
import DocCCommon

struct PresentationURLGeneratorTests {
    @Test
    func generateInternalURLs() {
        let inputsID: DocumentationContext.Inputs.Identifier = "com.example.tests"
        let generator = PresentationURLGenerator(baseURL: URL(string: "https://host:1024/webPrefix")!)
        
        // Test resolved tutorial reference
        let reference = ResolvedTopicReference(bundleID: inputsID, path: "/tutorials/Test-Bundle/TestTutorial", sourceLanguage: .swift)
        #expect(generator.presentationURLForReference(reference).absoluteString == "https://host:1024/webPrefix/tutorials/test-bundle/testtutorial")
        
        // Test resolved symbol reference
        let symbol = ResolvedTopicReference(bundleID: inputsID, path: "/documentation/MyKit/MyClass", sourceLanguage: .swift)
        #expect(generator.presentationURLForReference(symbol).absoluteString == "https://host:1024/webPrefix/documentation/mykit/myclass")
        
        // Test root
        let root = ResolvedTopicReference(bundleID: inputsID, path: "/", sourceLanguage: .swift)
        #expect(generator.presentationURLForReference(root).absoluteString == "https://host:1024/webPrefix/documentation")
        
        // Fragment
        let fragment = ResolvedTopicReference(bundleID: inputsID, path: "/path", fragment: "test URL! FRAGMENT", sourceLanguage: .swift)
        #expect(generator.presentationURLForReference(fragment).absoluteString == "https://host:1024/webPrefix/path#test-URL-FRAGMENT")
    }
}
