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

class ImageMediaTests: XCTestCase {
    func testEmpty() async throws {
        let source = """
@Image
"""
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let context = try await makeEmptyContext()
        var diagnostics = [Diagnostic]()
        let image = ImageMedia(from: directive, source: nil, for: context.inputs, featureFlags: context.configuration.featureFlags, diagnostics: &diagnostics)
        XCTAssertNil(image)
        XCTAssertEqual(1, diagnostics.count)
        XCTAssertFalse(diagnostics.containsAnyError)
        XCTAssertEqual(diagnostics.map(\.identifier), [
            "org.swift.docc.HasArgument.source",
        ])
    }
    
    func testValid() async throws {
        let imageSource = "/path/to/image"
        let alt = "This is an image"
        let source = """
@Image(source: "\(imageSource)", alt: "\(alt)")
"""
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let context = try await makeEmptyContext()
        var diagnostics = [Diagnostic]()
        let image = ImageMedia(from: directive, source: nil, for: context.inputs, featureFlags: context.configuration.featureFlags, diagnostics: &diagnostics)
        XCTAssertNotNil(image)
        XCTAssertTrue(diagnostics.isEmpty)
        image.map { image in
            XCTAssertEqual(imageSource, image.source.path)
            XCTAssertEqual(alt, image.altText)
        }
    }

    func testSpacesInSource() async throws {
        for imageSource in ["my image.png", "my%20image.png"] {
            let alt = "This is an image"
            let source = """
            @Image(source: "\(imageSource)", alt: "\(alt)")
            """
            let document = Document(parsing: source, options: .parseBlockDirectives)
            let directive = document.child(at: 0)! as! BlockDirective
            let context = try await makeEmptyContext()
            var diagnostics = [Diagnostic]()
            let image = ImageMedia(from: directive, source: nil, for: context.inputs, featureFlags: context.configuration.featureFlags, diagnostics: &diagnostics)
            XCTAssertNotNil(image)
            XCTAssertTrue(diagnostics.isEmpty)
            image.map { image in
                XCTAssertEqual(imageSource.removingPercentEncoding!, image.source.path)
                XCTAssertEqual(alt, image.altText)
            }
        }
    }
    
    func testIncorrectArgumentLabels() async throws {
        let source = """
        @Image(imgSource: "/img/path", altText: "Text")
        """
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let context = try await makeEmptyContext()
        var diagnostics = [Diagnostic]()
        let image = ImageMedia(from: directive, source: nil, for: context.inputs, featureFlags: context.configuration.featureFlags, diagnostics: &diagnostics)
        XCTAssertNil(image)
        XCTAssertEqual(3, diagnostics.count)
        XCTAssertFalse(diagnostics.containsAnyError)
        
        XCTAssertEqual(diagnostics.map(\.identifier).sorted(), [
            "org.swift.docc.HasArgument.source",
            "org.swift.docc.UnknownArgument",
            "org.swift.docc.UnknownArgument",
        ])
    }
    
    func testRenderImageDirectiveInReferenceMarkup() async throws {
        do {
            let (renderedContent, diagnostics, image) = try await parseDirective(ImageMedia.self, withAvailableAssetNames: ["figure1.jpg"]) {
                """
                @Image(source: "figure1")
                """
            }
            
            XCTAssertNotNil(image)
            XCTAssertEqual(diagnostics, [])
            XCTAssertEqual(renderedContent, [
                RenderBlockContent.paragraph(RenderBlockContent.Paragraph(
                    inlineContent: [.image(
                        identifier: RenderReferenceIdentifier("figure1"),
                        metadata: nil
                    )]
                ))
            ])
        }
        
        do {
            let (renderedContent, diagnostics, image) = try await parseDirective(ImageMedia.self, withAvailableAssetNames: []) {
                """
                @Image(source: "unknown-image")
                """
            }
            
            XCTAssertNotNil(image)
            XCTAssertEqual(diagnostics, ["1: warning – org.swift.docc.unresolvedResource.Image"])
            XCTAssertEqual(renderedContent, [])
        }
    }
    
    func testRenderImageDirectiveWithCaption() async throws {
        let (renderedContent, diagnostics, image) = try await parseDirective(ImageMedia.self, withAvailableAssetNames: ["figure1.jpg"]) {
            """
            @Image(source: "figure1") {
                This is my caption.
            }
            """
        }
        
        XCTAssertNotNil(image)
        XCTAssertEqual(diagnostics, [])
        XCTAssertEqual(renderedContent, [
            RenderBlockContent.paragraph(RenderBlockContent.Paragraph(
                inlineContent: [.image(
                    identifier: RenderReferenceIdentifier("figure1"),
                    metadata: RenderContentMetadata(abstract: [.text("This is my caption.")])
                )]
            ))
        ])
    }
    
    func testImageDirectiveDiagnosesDeviceFrameByDefault() async throws {
        let (renderedContent, diagnostics, image) = try await parseDirective(ImageMedia.self, withAvailableAssetNames: ["figure1.jpg"]) {
            """
            @Image(source: "figure1", deviceFrame: phone)
            """
        }
        
        XCTAssertNotNil(image)
        XCTAssertEqual(diagnostics, ["1: warning – org.swift.docc.UnknownArgument"])
        XCTAssertEqual(renderedContent, [
            RenderBlockContent.paragraph(RenderBlockContent.Paragraph(
                inlineContent: [.image(
                    identifier: RenderReferenceIdentifier("figure1"),
                    metadata: nil
                )]
            ))
        ])
    }
    
    func testRenderImageDirectiveWithDeviceFrame() async throws {
        var configuration = DocumentationContext.Configuration()
        configuration.featureFlags.isExperimentalDeviceFrameSupportEnabled = true
        
        let (renderedContent, diagnostics, image) = try await parseDirective(ImageMedia.self, withAvailableAssetNames: ["figure1.jpg"], configuration: configuration) {
            """
            @Image(source: "figure1", deviceFrame: phone)
            """
        }
        
        XCTAssertNotNil(image)
        XCTAssertEqual(diagnostics, [])
        XCTAssertEqual(renderedContent, [
            RenderBlockContent.paragraph(RenderBlockContent.Paragraph(
                inlineContent: [.image(
                    identifier: RenderReferenceIdentifier("figure1"),
                    metadata: RenderContentMetadata(deviceFrame: "phone")
                )]
            ))
        ])
    }
    
    func testRenderImageDirectiveWithDeviceFrameAndCaption() async throws {
        var configuration = DocumentationContext.Configuration()
        configuration.featureFlags.isExperimentalDeviceFrameSupportEnabled = true
        
        let (renderedContent, diagnostics, image) = try await parseDirective(ImageMedia.self, withAvailableAssetNames: ["figure1.jpg"], configuration: configuration) {
            """
            @Image(source: "figure1", deviceFrame: laptop) {
                This is my caption.
            }
            """
        }
        
        XCTAssertNotNil(image)
        XCTAssertEqual(diagnostics, [])
        XCTAssertEqual(renderedContent, [
            RenderBlockContent.paragraph(RenderBlockContent.Paragraph(
                inlineContent: [.image(
                    identifier: RenderReferenceIdentifier("figure1"),
                    metadata: RenderContentMetadata(abstract: [.text("This is my caption.")], deviceFrame: "laptop")
                )]
            ))
        ])
    }
    
    func testImageDirectiveDoesNotResolveVideoReference() async throws {
        // First check that the Video exists
        let (_, videoDiagnostics, _) = try await parseDirective(VideoMedia.self, withAvailableAssetNames: ["introvideo.mp4"]) {
            """
            @Video(source: "introvideo")
            """
        }
        XCTAssertEqual(videoDiagnostics, [])
        
        // Then check that it doesn't resolve as an image
        let (renderedContent, imageDiagnostics, image) = try await parseDirective(ImageMedia.self, withAvailableAssetNames: ["introvideo.mp4"]) {
            """
            @Image(source: "introvideo")
            """
        }
        XCTAssertNotNil(image)
        XCTAssertEqual(imageDiagnostics, ["1: warning – org.swift.docc.unresolvedResource.Image"])
        XCTAssertEqual(renderedContent, [])
    }
}

