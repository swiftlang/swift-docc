/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocC
import Markdown

class StackTests: XCTestCase {
    func testEmpty() throws {
        let source = "@Stack"
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0) as? BlockDirective
        XCTAssertNotNil(directive)
        
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        
        directive.map { directive in
            var problems = [Problem]()
            XCTAssertEqual(Stack.directiveName, directive.name)
            let stack = Stack(from: directive, source: nil, for: bundle, in: context, problems: &problems)
            XCTAssertNotNil(stack)
            XCTAssertEqual(1, problems.count)
            XCTAssertEqual(
                ["org.swift.docc.HasAtLeastOne<\(Stack.self), \(ContentAndMedia.self)>"],
                problems.map { $0.diagnostic.identifier }
            )
        }
    }
    
    func testValid() throws {
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
        
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        
        directive.map { directive in
            var problems = [Problem]()
            XCTAssertEqual(Stack.directiveName, directive.name)
            let stack = Stack(from: directive, source: nil, for: bundle, in: context, problems: &problems)
            XCTAssertNotNil(stack)
            XCTAssertEqual(0, problems.count)
        }
    }

    func testTooManyChildren() throws {
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
        
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        
        directive.map { directive in
            var problems = [Problem]()
            XCTAssertEqual(Stack.directiveName, directive.name)
            let stack = Stack(from: directive, source: nil, for: bundle, in: context, problems: &problems)
            XCTAssertNotNil(stack)
            XCTAssertEqual(1, problems.count)
            XCTAssertEqual(
                ["org.swift.docc.HasAtMost<\(Stack.self), \(ContentAndMedia.self)>(\(Stack.childrenLimit))"],
                problems.map { $0.diagnostic.identifier }
            )
        }
    }

}
