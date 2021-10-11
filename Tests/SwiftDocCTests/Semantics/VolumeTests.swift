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

class VolumeTests: XCTestCase {
    func testEmpty() throws {
        let source = """
@Volume
"""
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        var problems = [Problem]()
        let volume = Volume(from: directive, source: nil, for: bundle, in: context, problems: &problems)
        XCTAssertNil(volume)
        XCTAssertEqual(4, problems.count)
        XCTAssertEqual([
            "org.swift.docc.HasArgument.name",
            "org.swift.docc.HasExactlyOne<\(Volume.self), \(ImageMedia.self)>.Missing",
            "org.swift.docc.HasAtLeastOne<\(Volume.self), \(Chapter.self)>",
            "org.swift.docc.Volume.HasContent",
        ], problems.map { $0.diagnostic.identifier })
    }
    
    func testValid() throws {
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
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        var problems = [Problem]()
        let volume = Volume(from: directive, source: nil, for: bundle, in: context, problems: &problems)
        XCTAssertNotNil(volume)
        XCTAssertTrue(problems.isEmpty)
        volume.map { volume in
            XCTAssertEqual(name, volume.name)
            XCTAssertEqual(expectedContent, volume.content?.mapFirst { $0.detachedFromParent.format() })
        }
    }

    func testChapterWithSameName() throws {

        let name = "Always Be Voluming"


        let (_, bundle, context) = try testBundleAndContext(copying: "TestBundle") { root in
            let overviewURL = root.appendingPathComponent("TestOverview.tutorial")
            let text = """
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
            """
            try text.write(to: overviewURL, atomically: true, encoding: .utf8)
        }

        let node = try context.entity(
            with: ResolvedTopicReference(
                bundleIdentifier: bundle.identifier,
                path: "/tutorials/TestOverview",
                sourceLanguage: .swift))

        let tutorial = try XCTUnwrap(node.semantic as? Technology)

        let volume = tutorial.volumes.first
        XCTAssertNotNil(volume)
        XCTAssertEqual(volume?.name, volume?.chapters.first?.name)
    }
}
