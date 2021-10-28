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

class IntroTests: XCTestCase {
    func testEmpty() throws {
        let source = "@Intro"
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        var problems = [Problem]()
        let intro = Intro(from: directive, source: nil, for: bundle, in: context, problems: &problems)
        XCTAssertNil(intro)
        XCTAssertEqual(1, problems.count)
        XCTAssertFalse(problems.containsErrors)
        XCTAssertEqual("org.swift.docc.HasArgument.title", problems[0].diagnostic.identifier)
    }
    
    func testValid() throws {
        let videoPath = "/path/to/video"
        let imagePath = "/path/to/image"
        let posterPath = "/path/to/poster"
        let title = "Intro Title"
        let source = """
@Intro(title: "\(title)") {
        
   Here is a paragraph.
        
   @Video(source: "\(videoPath)", poster: \(posterPath))
   @Image(source: "\(imagePath)", alt: text)
}
"""
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        var problems = [Problem]()
        let intro = Intro(from: directive, source: nil, for: bundle, in: context, problems: &problems)
        XCTAssertNotNil(intro)
        XCTAssertTrue(problems.isEmpty)
        intro.map { intro in
            XCTAssertEqual(title, intro.title)
            XCTAssertNotNil(intro.video)
            XCTAssertEqual(intro.video?.source.path, videoPath)
            XCTAssertEqual(intro.video?.poster?.path, posterPath)
            XCTAssertEqual(1, intro.content.elements.count)
        }
    }
    
    func testIncorrectArgumentLabel() throws {
        let source = """
        @Intro(titleText: "Title") {
          Here is a paragraph.
            
          @Video(source: "/video/path", poster: /poster/path)
          @Image(source: "/image/path", alt: text)
        }
        """
        
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        var problems = [Problem]()
        let intro = Intro(from: directive, source: nil, for: bundle, in: context, problems: &problems)
        XCTAssertNil(intro)
        XCTAssertEqual(2, problems.count)
        XCTAssertFalse(problems.containsErrors)
        
        let expectedIds = [
            "org.swift.docc.UnknownArgument",
            "org.swift.docc.HasArgument.title",
        ]
        
        let problemIds = problems.map(\.diagnostic.identifier)
        
        for id in expectedIds {
            XCTAssertTrue(problemIds.contains(id))
        }
    }
}
