/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocC
import Markdown
import TestUtilities

class VolumeTests: XCTestCase {
    func testEmpty() async throws {
        let source = """
@Volume
"""
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let (bundle, _) = try await testBundleAndContext()
        var problems = [Problem]()
        let volume = Volume(from: directive, source: nil, for: bundle, problems: &problems)
        XCTAssertNil(volume)
        XCTAssertEqual(4, problems.count)
        XCTAssertEqual([
            "org.swift.docc.HasArgument.name",
            "org.swift.docc.HasExactlyOne<\(Volume.self), \(ImageMedia.self)>.Missing",
            "org.swift.docc.HasAtLeastOne<\(Volume.self), \(Chapter.self)>",
            "org.swift.docc.Volume.HasContent",
        ], problems.map { $0.diagnostic.identifier })
    }
    
    func testValid() async throws {
        let name = "Always Be Voluming"
        let expectedContent = "Here is some content explaining what this volume is."
        let source = """
@Volume(name: "\(name)") {
   \(expectedContent)
        
   @Image(source: "figure1.png", alt: "whatever")

   @Chapter(name: "Chapter 1") {
      This is Chapter 1.
      @Image(source: test.png, alt: test)
      @TutorialReference(tutorial: Tutorial1)
   }
}
"""
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let (bundle, _) = try await testBundleAndContext()
        var problems = [Problem]()
        let volume = Volume(from: directive, source: nil, for: bundle, problems: &problems)
        XCTAssertNotNil(volume)
        XCTAssertTrue(problems.isEmpty)
        volume.map { volume in
            XCTAssertEqual(name, volume.name)
            XCTAssertEqual(expectedContent, volume.content?.mapFirst { $0.detachedFromParent.format() })
        }
    }

    func testChapterWithSameName() async throws {
        let name = "Always Be Voluming"

        let catalog = Folder(name: "unit-test.docc", content: [
            TextFile(name: "TestOverview.tutorial", utf8Content: """
            @Tutorials(name: "Technology X") {
               @Intro(title: "Technology X") {

                  You'll learn all about Technology X.

                  @Video(source: introvideo.mp4, poster: introposter.png)
                  @Image(source: intro.png, alt: intro)
               }

               @Volume(name: "\(name)") {

                 This is a `Volume`.

                 @Image(source: figure1.png, alt: "Figure 1")

                 @Chapter(name: "\(name)") {

                    This is a `Chapter`.

                    @Image(source: figure1.png, alt: "Figure 1")

                    @TutorialReference(tutorial: "doc:TestTutorial")
                 }
               }

               @Resources {}
            }
            """)
        ])
        
        let (bundle, context) = try await loadBundle(catalog: catalog)
        let node = try context.entity(
            with: ResolvedTopicReference(bundleID: bundle.id, path: "/tutorials/TestOverview", sourceLanguage: .swift)
        )

        let tutorial = try XCTUnwrap(node.semantic as? TutorialTableOfContents)

        let volume = tutorial.volumes.first
        XCTAssertNotNil(volume)
        XCTAssertEqual(volume?.name, volume?.chapters.first?.name)
    }
}
