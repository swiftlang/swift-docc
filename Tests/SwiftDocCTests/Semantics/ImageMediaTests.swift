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

class ImageMediaTests: XCTestCase {
    func testEmpty() throws {
        let source = """
@Image
"""
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        var problems = [Problem]()
        let image = ImageMedia(from: directive, source: nil, for: bundle, in: context, problems: &problems)
        XCTAssertNil(image)
        XCTAssertEqual(1, problems.count)
        XCTAssertFalse(problems.containsErrors)
        XCTAssertEqual([
            "org.swift.docc.HasArgument.source",
        ], problems.map { $0.diagnostic.identifier })
    }
    
    func testValid() throws {
        let imageSource = "/path/to/image"
        let alt = "This is an image"
        let source = """
@Image(source: "\(imageSource)", alt: "\(alt)")
"""
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        var problems = [Problem]()
        let image = ImageMedia(from: directive, source: nil, for: bundle, in: context, problems: &problems)
        XCTAssertNotNil(image)
        XCTAssertTrue(problems.isEmpty)
        image.map { image in
            XCTAssertEqual(imageSource, image.source.path)
            XCTAssertEqual(alt, image.altText)
        }
    }

    func testSpacesInSource() throws {
        for imageSource in ["my image.png", "my%20image.png"] {
            let alt = "This is an image"
            let source = """
            @Image(source: "\(imageSource)", alt: "\(alt)")
            """
            let document = Document(parsing: source, options: .parseBlockDirectives)
            let directive = document.child(at: 0)! as! BlockDirective
            let (bundle, context) = try testBundleAndContext(named: "TestBundle")
            var problems = [Problem]()
            let image = ImageMedia(from: directive, source: nil, for: bundle, in: context, problems: &problems)
            XCTAssertNotNil(image)
            XCTAssertTrue(problems.isEmpty)
            image.map { image in
                XCTAssertEqual(imageSource.removingPercentEncoding!, image.source.path)
                XCTAssertEqual(alt, image.altText)
            }
        }
    }
    
    func testIncorrectArgumentLabels() throws {
        let source = """
        @Image(imgSource: "/img/path", altText: "Text")
        """
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        var problems = [Problem]()
        let image = ImageMedia(from: directive, source: nil, for: bundle, in: context, problems: &problems)
        XCTAssertNil(image)
        XCTAssertEqual(3, problems.count)
        XCTAssertFalse(problems.containsErrors)
        
        let expectedIds = [
            "org.swift.docc.UnknownArgument",
            "org.swift.docc.HasArgument.source",
        ]
        
        let problemIds = problems.map(\.diagnostic.identifier)
        
        for id in expectedIds {
            XCTAssertTrue(problemIds.contains(id))
        }
    }
    
    func testRenderImageDirectiveInReferenceMarkup() throws {
        do {
            let (renderedContent, problems, image) = try parseDirective(ImageMedia.self, in: "BookLikeContent") {
                """
                @Image(source: "figure1")
                """
            }
            
            XCTAssertNotNil(image)
            
            XCTAssertEqual(problems, [])
            
            XCTAssertEqual(
                renderedContent,
                [
                    RenderBlockContent.paragraph(RenderBlockContent.Paragraph(
                        inlineContent: [.image(
                            identifier: RenderReferenceIdentifier("figure1"),
                            metadata: nil
                        )]
                    ))
                ]
            )
        }
        
        do {
            let (renderedContent, problems, image) = try parseDirective(ImageMedia.self, in: "BookLikeContent") {
                """
                @Image(source: "unknown-image")
                """
            }
            
            XCTAssertNotNil(image)
            
            XCTAssertEqual(problems, ["1: warning – org.swift.docc.unresolvedResource.Image"])
            XCTAssertEqual(renderedContent, [])
        }
    }
    
    func testRenderImageDirectiveWithCaption() throws {
        let (renderedContent, problems, image) = try parseDirective(ImageMedia.self, in: "BookLikeContent") {
            """
            @Image(source: "figure1") {
                This is my caption.
            }
            """
        }
        
        XCTAssertNotNil(image)
        
        XCTAssertEqual(problems, [])
        
        XCTAssertEqual(
            renderedContent,
            [
                RenderBlockContent.paragraph(RenderBlockContent.Paragraph(
                    inlineContent: [.image(
                        identifier: RenderReferenceIdentifier("figure1"),
                        metadata: RenderContentMetadata(abstract: [.text("This is my caption.")])
                    )]
                ))
            ]
        )
    }
    
    func testImageDirectiveDoesNotResolveVideoReference() throws {
        // First check that the Video exists
        let (_, videoProblems, _) = try parseDirective(VideoMedia.self, in: "TestBundle") {
            """
            @Video(source: "introvideo")
            """
        }
        
        XCTAssertEqual(videoProblems, [])
        
        // Then check that it doesn't resolve as an image
        let (renderedContent, imageProblems, image) = try parseDirective(ImageMedia.self, in: "TestBundle") {
            """
            @Image(source: "introvideo")
            """
        }
        
        XCTAssertNotNil(image)
        
        XCTAssertEqual(imageProblems, ["1: warning – org.swift.docc.unresolvedResource.Image"])
        
        XCTAssertEqual(renderedContent, [])
    }
}
