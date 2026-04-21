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

class IntroTests: XCTestCase {
    func testEmpty() async throws {
        let source = "@Intro"
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let context = try await makeEmptyContext()
        var diagnostics = [Diagnostic]()
        let intro = Intro(from: directive, source: nil, for: context.inputs, featureFlags: context.configuration.featureFlags, diagnostics: &diagnostics)
        XCTAssertNil(intro)
        XCTAssertEqual(1, diagnostics.count)
        XCTAssertFalse(diagnostics.containsError)
        XCTAssertEqual(diagnostics.first?.identifier, "org.swift.docc.HasArgument.title")
    }
    
    func testValid() async throws {
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
        let context = try await makeEmptyContext()
        var diagnostics = [Diagnostic]()
        let intro = Intro(from: directive, source: nil, for: context.inputs, featureFlags: context.configuration.featureFlags, diagnostics: &diagnostics)
        XCTAssertNotNil(intro)
        XCTAssertTrue(diagnostics.isEmpty)
        if let intro {
            XCTAssertEqual(title, intro.title)
            XCTAssertNotNil(intro.video)
            XCTAssertEqual(intro.video?.source.path, videoPath)
            XCTAssertEqual(intro.video?.poster?.path, posterPath)
            XCTAssertEqual(1, intro.content.elements.count)
        }
    }
    
    func testIncorrectArgumentLabel() async throws {
        let source = """
        @Intro(titleText: "Title") {
          Here is a paragraph.
            
          @Video(source: "/video/path", poster: /poster/path)
          @Image(source: "/image/path", alt: text)
        }
        """
        
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let context = try await makeEmptyContext()
        var diagnostics = [Diagnostic]()
        let intro = Intro(from: directive, source: nil, for: context.inputs, featureFlags: context.configuration.featureFlags, diagnostics: &diagnostics)
        XCTAssertNil(intro)
        XCTAssertEqual(2, diagnostics.count)
        XCTAssertFalse(diagnostics.containsError)
        
        XCTAssertEqual(diagnostics.map(\.identifier), [
            "org.swift.docc.UnknownArgument",
            "org.swift.docc.HasArgument.title",
        ])
    }
}
