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

class VideoMediaTests: XCTestCase {
    func testEmpty() throws {
        let source = """
@Video
"""
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        var problems = [Problem]()
        let video = VideoMedia(from: directive, source: nil, for: bundle, in: context, problems: &problems)
        XCTAssertNil(video)
        XCTAssertEqual(1, problems.count)
        XCTAssertFalse(problems.containsErrors)
        problems.first.map { problem in
            XCTAssertEqual("org.swift.docc.HasArgument.source", problem.diagnostic.identifier)
        }
    }
    
    func testValid() throws {
        let videoSource = "/path/to/video"
        let poster = "/path/to/poster"
        let source = """
@Video(source: "\(videoSource)", poster: "\(poster)")
"""
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        var problems = [Problem]()
        let video = VideoMedia(from: directive, source: nil, for: bundle, in: context, problems: &problems)
        XCTAssertNotNil(video)
        XCTAssertTrue(problems.isEmpty)
        video.map { video in
            XCTAssertEqual(video.source.path, videoSource)
            XCTAssertEqual(video.poster?.path, poster)
        }
    }

    func testSpacesInSourceAndPoster() throws {
        for videoSource in ["my image.mov", "my%20image.mov"] {
            let poster = videoSource.replacingOccurrences(of: ".mov", with: ".png")
            let source = """
            @Video(source: "\(videoSource)", poster: "\(poster)")
            """
            let document = Document(parsing: source, options: .parseBlockDirectives)
            let directive = document.child(at: 0)! as! BlockDirective
            let (bundle, context) = try testBundleAndContext(named: "TestBundle")
            var problems = [Problem]()
            let video = VideoMedia(from: directive, source: nil, for: bundle, in: context, problems: &problems)
            XCTAssertNotNil(video)
            XCTAssertTrue(problems.isEmpty)
            video.map { video in
                XCTAssertEqual(videoSource.removingPercentEncoding!, video.source.path)
                XCTAssertEqual(poster.removingPercentEncoding!, video.poster?.path)
            }
        }
    }
    
    func testIncorrectArgumentLabels() throws {
        let source = """
        @Video(sourceURL: "/video/path", posterURL: "/poster/path")
        """
        
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        var problems = [Problem]()
        let video = VideoMedia(from: directive, source: nil, for: bundle, in: context, problems: &problems)
        XCTAssertNil(video)
        XCTAssertEqual(1, problems.count)
        XCTAssertFalse(problems.containsErrors)
        
        problems.first.map { problem in
            XCTAssertEqual("org.swift.docc.HasArgument.source", problem.diagnostic.identifier)
        }
    }
}
