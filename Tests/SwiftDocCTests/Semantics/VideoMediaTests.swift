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
        XCTAssertEqual(3, problems.count)
        XCTAssertFalse(problems.containsErrors)
        
        XCTAssertEqual(
            problems.map(\.diagnostic.identifier),
            [
                "org.swift.docc.UnknownArgument",
                "org.swift.docc.UnknownArgument",
                "org.swift.docc.HasArgument.source",
            ]
        )
    }
    
    func testRenderVideoDirectiveInReferenceMarkup() throws {
        do {
            let (renderedContent, problems, video) = try parseDirective(VideoMedia.self, in: "TestBundle") {
                """
                @Video(source: "introvideo")
                """
            }
            
            XCTAssertNotNil(video)
            
            XCTAssertEqual(problems, [])
            
            XCTAssertEqual(
                renderedContent,
                [
                    RenderBlockContent.video(RenderBlockContent.Video(
                        identifier: RenderReferenceIdentifier("introvideo"),
                        metadata: nil
                    ))
                ]
            )
        }
        
        do {
            let (renderedContent, problems, video) = try parseDirective(VideoMedia.self, in: "TestBundle") {
                """
                @Video(source: "unknown-video")
                """
            }
            
            XCTAssertNotNil(video)
            
            XCTAssertEqual(problems, ["1: warning – org.swift.docc.unresolvedResource.Video"])
            
            XCTAssertEqual(renderedContent, [])
        }
        
        do {
            let (renderedContent, problems, video) = try parseDirective(VideoMedia.self, in: "TestBundle") {
                """
                @Video(source: "introvideo", poster: "unknown-poster")
                """
            }
            
            XCTAssertNotNil(video)
            
            XCTAssertEqual(problems, ["1: warning – org.swift.docc.unresolvedResource.Image"])
            
            XCTAssertEqual(
                renderedContent,
                [
                    RenderBlockContent.video(RenderBlockContent.Video(
                        identifier: RenderReferenceIdentifier("introvideo"),
                        metadata: nil
                    ))
                ]
            )
        }
    }
    
    func testRenderVideoDirectiveWithCaption() throws {
        let (renderedContent, problems, video) = try parseDirective(VideoMedia.self, in: "TestBundle") {
            """
            @Video(source: "introvideo") {
                This is my caption.
            }
            """
        }
        
        XCTAssertNotNil(video)
        
        XCTAssertEqual(problems, [])
        
        XCTAssertEqual(
            renderedContent,
            [
                RenderBlockContent.video(RenderBlockContent.Video(
                    identifier: RenderReferenceIdentifier("introvideo"),
                    metadata: RenderContentMetadata(abstract: [.text("This is my caption.")])
                ))
            ]
        )
    }
    
    func testRenderVideoDirectiveWithCaptionAndPosterImage() throws {
        let (renderedContent, problems, video, references) = try parseDirective(VideoMedia.self, in: "TestBundle") {
            """
            @Video(source: "introvideo", alt: "An introductory video", poster: "introposter") {
                This is my caption.
            }
            """
        }
        
        XCTAssertNotNil(video)
        
        XCTAssertEqual(problems, [])
        
        XCTAssertEqual(
            renderedContent,
            [
                RenderBlockContent.video(RenderBlockContent.Video(
                    identifier: RenderReferenceIdentifier("introvideo"),
                    metadata: RenderContentMetadata(abstract: [.text("This is my caption.")])
                ))
            ]
        )
        
        XCTAssertEqual(references.count, 2)
        
        let videoReference = try XCTUnwrap(references["introvideo"] as? VideoReference)
        XCTAssertEqual(videoReference.poster, RenderReferenceIdentifier("introposter"))
        XCTAssertEqual(videoReference.altText, "An introductory video")
        
        XCTAssertTrue(references.keys.contains("introposter"))
    }
    
    func testVideoDirectiveDoesNotResolveImageMedia() throws {
        // The rest of the test in this file will fail if 'introposter' and 'introvideo'
        // do not exist. We just reverse them here to make sure the reference resolving is
        // media-type specific.
        let (renderedContent, problems, video) = try parseDirective(VideoMedia.self, in: "TestBundle") {
            """
            @Video(source: "introposter", poster: "introvideo")
            """
        }
        
        XCTAssertNotNil(video)
        
        XCTAssertEqual(
            problems,
            [
                "1: warning – org.swift.docc.unresolvedResource.Image",
                "1: warning – org.swift.docc.unresolvedResource.Video"
            ]
        )
        
        XCTAssertEqual(renderedContent, [])
    }
}
