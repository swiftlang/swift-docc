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

class HasContentTests: XCTestCase {
    func testEmpty() throws {
        let source = "@dir"
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0) as? BlockDirective
        XCTAssertNotNil(directive)
        
        if let directive {
            var diagnostics = [Diagnostic]()
            let hasContent = Semantic.Analyses.HasContent<Intro>().analyze(directive, children: directive.children, source: nil, diagnostics: &diagnostics)
            XCTAssertTrue(hasContent.isEmpty)
            XCTAssertEqual(1, diagnostics.count)
            XCTAssertEqual(diagnostics.first?.identifier, "org.swift.docc.Intro.HasContent")
        }
    }
    
    func testHasContent() throws {
        let source = """
@dir {
   Some content here.
}
"""
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0) as? BlockDirective
        XCTAssertNotNil(directive)
        
        if let directive {
            var diagnostics = [Diagnostic]()
            let hasContent = Semantic.Analyses.HasContent<Intro>().analyze(directive, children: directive.children, source: nil, diagnostics: &diagnostics)
            XCTAssertFalse(hasContent.isEmpty)
            XCTAssertTrue(diagnostics.isEmpty)
        }
    }
}
