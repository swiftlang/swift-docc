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

class ContentAndMediaTests: XCTestCase {
    func testEmpty() throws {
        let source = """
@ContentAndMedia {
"""
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        var problems = [Problem]()
        let contentAndMedia = ContentAndMedia(from: directive, source: nil, for: bundle, in: context, problems: &problems)
        XCTAssertNotNil(contentAndMedia)
        XCTAssertEqual(0, problems.count)
    }
    
    func testValid() throws {
        let source = """
@ContentAndMedia {
   
   @Image(source: "/path/to/image", alt: blah)

   Blah.
}
"""
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        var problems = [Problem]()
        let contentAndMedia = ContentAndMedia(from: directive, source: nil, for: bundle, in: context, problems: &problems)
        XCTAssertNotNil(contentAndMedia)
        XCTAssertTrue(problems.isEmpty)
        contentAndMedia.map { contentAndMedia in
            XCTAssertEqual(.leading, contentAndMedia.mediaPosition)
        }
    }
    
    func testTrailingMiddleMediaPosition() throws {
        let source = """
@ContentAndMedia {
   
   Blah.
   
   @Image(source: "/path/to/image", alt: blah)
}
"""
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        var problems = [Problem]()
        let contentAndMedia = ContentAndMedia(from: directive, source: nil, for: bundle, in: context, problems: &problems)
        XCTAssertNotNil(contentAndMedia)
        XCTAssertTrue(problems.isEmpty)
        contentAndMedia.map { contentAndMedia in
            XCTAssertEqual(.trailing, contentAndMedia.mediaPosition)
        }
    }
    
    func testTrailingMediaPosition() throws {
        let source = """
@ContentAndMedia {
   
   Foo.
   
   @Image(source: "/path/to/image", alt: blah)

   Blah.
}
"""
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        var problems = [Problem]()
        let contentAndMedia = ContentAndMedia(from: directive, source: nil, for: bundle, in: context, problems: &problems)
        XCTAssertNotNil(contentAndMedia)
        XCTAssertTrue(problems.isEmpty)
        contentAndMedia.map { contentAndMedia in
            XCTAssertEqual(.trailing, contentAndMedia.mediaPosition)
        }
    }

    func testDeprecatedArguments() throws {
        let source = """
@ContentAndMedia(layout: horizontal, eyebrow: eyebrow, title: title) {

   @Image(source: "/path/to/image", alt: blah)

   Blah.
}
"""
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        var problems = [Problem]()
        let contentAndMedia = ContentAndMedia(from: directive, source: nil, for: bundle, in: context, problems: &problems)
        XCTAssertNotNil(contentAndMedia)
        XCTAssertEqual(problems.count, 3)
        XCTAssertEqual(
            [
                "org.swift.docc.DeprecatedArgument.eyebrow",
                "org.swift.docc.DeprecatedArgument.title",
                "org.swift.docc.DeprecatedArgument.layout",
            ],
            problems.map { $0.diagnostic.identifier }
        )
        contentAndMedia.map { contentAndMedia in
            XCTAssertEqual(.leading, contentAndMedia.mediaPosition)
        }
    }
}
