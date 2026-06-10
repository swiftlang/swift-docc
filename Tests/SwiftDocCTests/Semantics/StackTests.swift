/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocC
import Markdown
import DocCTestUtilities

class StackTests: XCTestCase {
    func testEmpty() async throws {
        let source = "@Stack"
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0) as? BlockDirective
        XCTAssertNotNil(directive)
        
        let (_, context) = try await testBundleAndContext(named: "LegacyBundle_DoNotUseInNewTests")
        
        if let directive {
            var diagnostics = [Diagnostic]()
            XCTAssertEqual(Stack.directiveName, directive.name)
            let stack = Stack(from: directive, source: nil, for: context.inputs, featureFlags: context.configuration.featureFlags, diagnostics: &diagnostics)
            XCTAssertNotNil(stack)
            XCTAssertEqual(1, diagnostics.count)
            XCTAssertEqual(
                ["org.swift.docc.HasAtLeastOne<\(Stack.self), \(ContentAndMedia.self)>"],
                diagnostics.map { $0.identifier }
            )
        }
    }
    
    func testValid() async throws {
        let source = """
        @Stack {
          @ContentAndMedia {
            Text.

            @Image(source: code4.png, alt: "alt")
          }
        }
        """
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0) as? BlockDirective
        XCTAssertNotNil(directive)
        
        let (_, context) = try await testBundleAndContext(named: "LegacyBundle_DoNotUseInNewTests")
        
        if let directive {
            var diagnostics = [Diagnostic]()
            XCTAssertEqual(Stack.directiveName, directive.name)
            let stack = Stack(from: directive, source: nil, for: context.inputs, featureFlags: context.configuration.featureFlags, diagnostics: &diagnostics)
            XCTAssertNotNil(stack)
            XCTAssertEqual(0, diagnostics.count)
        }
    }

    func testTooManyChildren() async throws {
        var source = "@Stack {"
        for _ in 0...Stack.childrenLimit {
            source += """
            
            @ContentAndMedia {
              Text.

              @Image(source: code4.png, alt: "alt")
            }
            
            """
        }
        source += "}"

        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0) as? BlockDirective
        XCTAssertNotNil(directive)
        
        let (_, context) = try await loadBundle(catalog: Folder(name: "Something.docc", content: [
            DataFile(name: "code4.png", data: Data())
        ]))
        
        if let directive {
            var diagnostics = [Diagnostic]()
            XCTAssertEqual(Stack.directiveName, directive.name)
            let stack = Stack(from: directive, source: nil, for: context.inputs, featureFlags: context.configuration.featureFlags, diagnostics: &diagnostics)
            XCTAssertNotNil(stack)
            XCTAssertEqual(1, diagnostics.count)
            XCTAssertEqual(
                ["org.swift.docc.HasAtMost<\(Stack.self), \(ContentAndMedia.self)>(\(Stack.childrenLimit))"],
                diagnostics.map { $0.identifier }
            )
        }
    }

}
