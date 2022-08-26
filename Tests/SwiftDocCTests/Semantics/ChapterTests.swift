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

class ChapterTests: XCTestCase {
    func testEmpty() throws {
        let source = """
@Chapter
"""
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        var problems = [Problem]()
        let chapter = Chapter(from: directive, source: nil, for: bundle, in: context, problems: &problems)
        XCTAssertNil(chapter)
        XCTAssertEqual(3, problems.count)
        XCTAssertEqual("org.swift.docc.HasArgument.name", problems[0].diagnostic.identifier)
        XCTAssertTrue(problems.map(\.diagnostic.identifier).contains("org.swift.docc.HasAtLeastOne<\(Chapter.self), \(TutorialReference.self)>"))
        XCTAssertTrue(problems.map(\.diagnostic.identifier).contains("org.swift.docc.HasExactlyOne<\(Chapter.self), \(ImageMedia.self)>.Missing"))
        
        XCTAssert(problems.map { $0.diagnostic.severity }.allSatisfy { $0 == .warning })
    }
    
    func testMultipleMedia() throws {
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
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        var problems = [Problem]()
        let chapter = Chapter(from: directive, source: nil, for: bundle, in: context, problems: &problems)
        XCTAssertEqual(1, problems.count)
        problems.first.map { problem in
            XCTAssertEqual("org.swift.docc.HasExactlyOne<\(Chapter.self), \(ImageMedia.self)>.DuplicateChildren", problem.diagnostic.identifier)
        }
        
        XCTAssertNotNil(chapter)
        chapter.map { chapter in
            XCTAssertEqual(chapterName, chapter.name)
            XCTAssertEqual(1, chapter.topicReferences.count)
            XCTAssertNotNil(chapter.image)
            chapter.image.map { image in
                XCTAssertEqual("test.png", image.source.path)
            }
        }
    }
    
    func testValid() throws {
        let chapterName = "Chapter 1"
        let source = """
@Chapter(name: "\(chapterName)") {
   @Image(source: test.png, alt: test)
   @TutorialReference(tutorial: "MyTutorial")
}
"""
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        var problems = [Problem]()
        let chapter = Chapter(from: directive, source: nil, for: bundle, in: context, problems: &problems)
        XCTAssertTrue(problems.isEmpty)
        XCTAssertNotNil(chapter)
        chapter.map { chapter in
            XCTAssertEqual(chapterName, chapter.name)
            XCTAssertEqual(1, chapter.topicReferences.count)
        }
    }
    
    func testDuplicateTutorialReferences() throws {
        let (_, context) = try testBundleAndContext(named: "TestBundle")
        
        /*
         The test bundle contains the duplicate tutorial references in TestOverview:
         - @TutorialReference(tutorial: "doc:TestTutorial")
         - @TutorialReference(tutorial: "doc:/TestTutorial")
         
         Although these are spelled differently, they resolve to the same tutorial, so they are treated as duplicates.
         */
        let duplicateProblems = context.problems.filter {
            $0.diagnostic.identifier == "org.swift.docc.Chapter.Duplicate\(TutorialReference.self)"
        }
        XCTAssertEqual(1, duplicateProblems.count)
    }
}
