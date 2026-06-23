/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import XCTest
@testable import SwiftDocC
import Markdown
import DocCTestUtilities

class ChapterTests: XCTestCase {
    func testEmpty() async throws {
        let source = """
@Chapter
"""
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let context = try await makeEmptyContext()
        var diagnostics = [Diagnostic]()
        let chapter = Chapter(from: directive, source: nil, for: context.inputs, featureFlags: context.configuration.featureFlags, diagnostics: &diagnostics)
        XCTAssertNil(chapter)
        XCTAssertEqual(3, diagnostics.count)
        XCTAssertEqual(diagnostics.map(\.identifier).sorted(), [
            "org.swift.docc.HasArgument.name",
            "org.swift.docc.HasAtLeastOne<\(Chapter.self), \(TutorialReference.self)>",
            "org.swift.docc.HasExactlyOne<\(Chapter.self), \(ImageMedia.self)>.Missing",
        ])
        XCTAssert(diagnostics.allSatisfy { $0.severity == .warning })
    }
    
    func testMultipleMedia() async throws {
        let chapterName = "Chapter 1"
        let source = """
@Chapter(name: "\(chapterName)") {
   @Image(source: test.png, alt: test)
   @Image(source: test2.png, alt: test2)
   @TutorialReference(tutorial: "MyTutorial")
}
"""
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let context = try await makeEmptyContext()
        var diagnostics = [Diagnostic]()
        let chapter = Chapter(from: directive, source: nil, for: context.inputs, featureFlags: context.configuration.featureFlags, diagnostics: &diagnostics)
        XCTAssertEqual(1, diagnostics.count)
        XCTAssertEqual(diagnostics.first?.identifier, "org.swift.docc.HasExactlyOne<\(Chapter.self), \(ImageMedia.self)>.DuplicateChildren")
        
        XCTAssertNotNil(chapter)
        if let chapter {
            XCTAssertEqual(chapterName, chapter.name)
            XCTAssertEqual(1, chapter.topicReferences.count)
            XCTAssertNotNil(chapter.image)
            chapter.image.map { image in
                XCTAssertEqual("test.png", image.source.path)
            }
        }
    }
    
    func testValid() async throws {
        let chapterName = "Chapter 1"
        let source = """
@Chapter(name: "\(chapterName)") {
   @Image(source: test.png, alt: test)
   @TutorialReference(tutorial: "MyTutorial")
}
"""
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let context = try await makeEmptyContext()
        var diagnostics = [Diagnostic]()
        let chapter = Chapter(from: directive, source: nil, for: context.inputs, featureFlags: context.configuration.featureFlags, diagnostics: &diagnostics)
        XCTAssertTrue(diagnostics.isEmpty)
        XCTAssertNotNil(chapter)
        if let chapter {
            XCTAssertEqual(chapterName, chapter.name)
            XCTAssertEqual(1, chapter.topicReferences.count)
        }
    }
    
    func testDuplicateTutorialReferences() async throws {
        // The catalog contains two `@TutorialReference` directives in a single chapter
        // that resolve to the same tutorial: "doc:TestTutorial" and "doc:/TestTutorial".
        // Even though they're spelled differently, they should be treated as duplicates.
        let catalog = Folder(name: "unit-test.docc") {
            TextFile(name: "TestOverview.tutorial", utf8Content: """
            @Tutorials(name: "Technology X") {
               @Intro(title: "Technology X") {
                  You'll learn all about Technology X.
               }
               @Volume(name: "Volume 1") {
                  @Chapter(name: "Chapter 1") {
                     @Image(source: image.png, alt: image)
                     @TutorialReference(tutorial: "doc:TestTutorial")
                     @TutorialReference(tutorial: "doc:/TestTutorial")
                  }
               }
            }
            """)
            TextFile(name: "TestTutorial.tutorial", utf8Content: """
            @Tutorial(time: 1) {
               @Intro(title: "Tutorial") {
                  An intro.
               }
               @Section(title: "Section") {
                  @ContentAndMedia {
                     Content.
                  }
                  @Steps {
                     @Step {
                        Do something.
                        @Image(source: image.png, alt: image)
                     }
                  }
               }
            }
            """)
            DataFile(name: "image.png", data: Data())
        }
        let (_, context) = try await loadBundle(catalog: catalog)
        
        let duplicateDiagnostic = context.diagnostics.filter { $0.identifier == "org.swift.docc.Chapter.Duplicate\(TutorialReference.self)" }
        XCTAssertEqual(1, duplicateDiagnostic.count)
    }
}
