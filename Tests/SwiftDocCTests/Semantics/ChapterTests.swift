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
        let (_, context) = try await testBundleAndContext(named: "LegacyBundle_DoNotUseInNewTests")
        
        /*
         The test bundle contains the duplicate tutorial references in TestOverview:
         - @TutorialReference(tutorial: "doc:TestTutorial")
         - @TutorialReference(tutorial: "doc:/TestTutorial")
         
         Although these are spelled differently, they resolve to the same tutorial, so they are treated as duplicates.
         */
        let duplicateDiagnostic = context.diagnostics.filter { $0.identifier == "org.swift.docc.Chapter.Duplicate\(TutorialReference.self)" }
        XCTAssertEqual(1, duplicateDiagnostic.count)
    }
}
