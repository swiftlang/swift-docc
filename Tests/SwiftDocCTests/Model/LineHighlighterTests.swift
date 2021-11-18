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
import SwiftDocCTestUtilities

class LineHighlighterTests: XCTestCase {
    static let bundleIdentifier = "org.swift.docc.LineHighlighterTests"
    static let defaultOverview = TextFile(name: "TechnologyX.tutorial", utf8Content: """
        @Technology(name: "TechnologyX") {
           @Intro(title: "Technology X") {

              You'll learn all about Technology X.

              @Image(source: arkit.png, alt: arkit)
           }

           @Volume(title: "Volume 1") {
              This volume contains Chapter 1.

              @Chapter(name: "Module 1") {
                 In this chapter, you'll follow Tutorial 1.
                 @TutorialReference(tutorial: Tutorial)
                 @Image(source: blah, alt: blah)
              }
           }
        }
        """)

    static func bundleFolder(overview: TextFile = defaultOverview,
                             tutorial: TextFile,
                             codeFiles: [TextFile]) -> Folder {
        return Folder(name: "TestNoSteps.docc", content: [
            InfoPlist(displayName: "Line Highlighter Tests", identifier: bundleIdentifier),
            Folder(name: "Symbols", content: []),
            Folder(name: "Resources", content: [
                overview,
                tutorial,
                ] + codeFiles),
            ])
    }
    
    func testBundleAndContext(bundleRoot: Folder, bundleIdentifier: BundleIdentifier) throws -> (DocumentationBundle, DocumentationContext) {
        let workspace = DocumentationWorkspace()
        let context = try! DocumentationContext(dataProvider: workspace)
        
        let bundleURL = try bundleRoot.write(inside: createTemporaryDirectory())
        
        let dataProvider = try LocalFileSystemDataProvider(rootURL: bundleURL)
        try workspace.registerProvider(dataProvider)
        let bundle = context.bundle(identifier: bundleIdentifier)!
        return (bundle, context)
    }
    
    func highlights(tutorialFile: TextFile, codeFiles: [TextFile]) throws -> [LineHighlighter.Result] {
        let bundleFolder = LineHighlighterTests.bundleFolder(tutorial: tutorialFile, codeFiles: codeFiles)
        let (bundle, context) = try testBundleAndContext(bundleRoot: bundleFolder, bundleIdentifier: LineHighlighterTests.bundleIdentifier)
        
        let tutorialReference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/tutorials/Line-Highlighter-Tests/Tutorial", fragment: nil, sourceLanguage: .swift)
        let tutorial = try context.entity(with: tutorialReference).semantic as! Tutorial
        let section = tutorial.sections.first!
        return LineHighlighter(context: context, tutorialSection: section).highlights
    }
    
    func testNoSteps() throws {
        let tutorialFile = TextFile(name: "Tutorial.tutorial", utf8Content: """
            @Tutorial(time: 20, projectFiles: nothing.zip) {
               @XcodeRequirement(title: "Xcode X.Y Beta Z", destination: "https://www.example.com/download")
               @Intro(title: "Test Intro")
               @Section(title: "Section with no steps") {
                  @ContentAndMedia {
                     This is an introduction.
                  }
               }
               @Assessments
            }
            """)
        XCTAssertTrue(try highlights(tutorialFile: tutorialFile, codeFiles: []).isEmpty)
    }

    func testOneStep() throws {
        let tutorialFile = TextFile(name: "Tutorial.tutorial", utf8Content: """
            @Tutorial(title: "No Steps", time: 20, projectFiles: nothing.zip) {
               @XcodeRequirement(title: "Xcode X.Y Beta Z", destination: "https://www.example.com/download")
               @Intro(title: "Test Intro")
            @Section(title: "Section with one step") {
               @ContentAndMedia {
                  This is an introduction.
               }
               @Steps {
                  @Step {
                     This is the only step.
                     @Code(file: code1.swift, name: MyCode.swift)
                  }
               }
            }
            @Assessments
            """)
        let code1 = TextFile(name: "code1.swift", utf8Content: "func foo() {}")
        let results = try highlights(tutorialFile: tutorialFile, codeFiles: [code1])
        XCTAssertEqual(1, results.count)
        results.first.map { result in
            XCTAssertEqual(ResourceReference(bundleIdentifier: LineHighlighterTests.bundleIdentifier, path: code1.name), result.file)
            XCTAssertTrue(result.highlights.isEmpty)
        }
    }
    
    func testOneStepWithPrevious() throws {
        let tutorialFile = TextFile(name: "Tutorial.tutorial", utf8Content: """
            @Tutorial(title: "No Steps", time: 20, projectFiles: nothing.zip) {
               @XcodeRequirement(title: "Xcode X.Y Beta Z", destination: "https://www.example.com/download")
               @Intro(title: "Test Intro")
               @Section(title: "Section with one steps") {
                  @ContentAndMedia {
                  This is an introduction.
               }
               
               @Steps {
                  @Step {
                     This is the only step.
                     @Code(file: code1.swift, name: MyCode.swift, previousFile: code0.swift)
                  }
               }
            }
            @Assessments
            """)
        let code0 = TextFile(name: "code0.swift", utf8Content: "func foo() {}")
        let code1 = TextFile(name: "code1.swift", utf8Content: "func foo() {}\nfunc bar() {}")
        let results = try highlights(tutorialFile: tutorialFile, codeFiles: [code0, code1])
        XCTAssertEqual(1, results.count)
        results.first.map { result in
            XCTAssertEqual(ResourceReference(bundleIdentifier: LineHighlighterTests.bundleIdentifier, path: code1.name), result.file)
            XCTAssertEqual(1, result.highlights.count)
            result.highlights.first.map { highlight in
                XCTAssertEqual(2, highlight.line)
                XCTAssertNil(highlight.start)
                XCTAssertNil(highlight.length)
            }
        }
    }
    
    func testNameMismatch() throws {
        let tutorialFile = TextFile(name: "Tutorial.tutorial", utf8Content: """
        @Tutorial(title: "No Steps", time: 20, projectFiles: nothing.zip) {
          @XcodeRequirement(title: "Xcode X.Y Beta Z", destination: "https://www.example.com/download")
          @Intro(title: "Test Intro")
          @Section(title: "Section with two steps") {
            @ContentAndMedia {
              This is an introduction.
            }
            @Steps {
              @Step {
                This is the first step.
                @Code(file: code1.swift, name: somefile.swift)
              }
              @Step {
                This is the second step. This code will not produce diffs because it has a different presentation name.
                @Code(file: code2.swift, name: otherfile.swift)
              }
            }
          }
          @Assessments()
        }
        """)
        
        let code1 = TextFile(name: "code1.swift", utf8Content: "func foo() {}")
        let code2 = TextFile(name: "code2.swift", utf8Content: "func foo() {}\nfunc bar() {}")
        let results = try highlights(tutorialFile: tutorialFile, codeFiles: [code1, code2])
        XCTAssertEqual(2, results.count)
        
        XCTAssertEqual(ResourceReference(bundleIdentifier: LineHighlighterTests.bundleIdentifier, path: code1.name), results[0].file)
        XCTAssertTrue(results[0].highlights.isEmpty)
        
        XCTAssertEqual(ResourceReference(bundleIdentifier: LineHighlighterTests.bundleIdentifier, path: code2.name), results[1].file)
        XCTAssertTrue(results[1].highlights.isEmpty)
    }
    
    func testResetDiffAtStart() throws {
        let tutorialFile = TextFile(name: "Tutorial.tutorial", utf8Content: """
            @Tutorial(title: "No Steps", time: 20, projectFiles: nothing.zip) {
               @XcodeRequirement(title: "Xcode X.Y Beta Z", destination: "https://www.example.com/download")
               @Intro(title: "Test Intro")
            @Section(title: "Task with one step") {
               @ContentAndMedia {
                  This is an introduction.
               }
               @Steps {
                  @Step {
                     This is the only step.
                     @Code(file: code1.swift, name: MyCode.swift, previousFile: code0.swift, reset: true)
                  }
               }
            }
            @Assessments
            """)
        let code0 = TextFile(name: "code0.swift", utf8Content: "func foo() {}")
        let code1 = TextFile(name: "code1.swift", utf8Content: "func foo() {}\nfunc bar() {}")
        let results = try highlights(tutorialFile: tutorialFile, codeFiles: [code0, code1])
        XCTAssertEqual(1, results.count)
        results.first.map { result in
            XCTAssertEqual(ResourceReference(bundleIdentifier: LineHighlighterTests.bundleIdentifier, path: code1.name), result.file)
            XCTAssertTrue(result.highlights.isEmpty)
        }
    }
    
    func testResetDiff() throws {
        let tutorialFile = TextFile(name: "Tutorial.tutorial", utf8Content: """
            @Tutorial(title: "No Steps", time: 20, projectFiles: nothing.zip) {
               @XcodeRequirement(title: "Xcode X.Y Beta Z", destination: "https://www.example.com/download")
               @Intro(title: "Test Intro")
            @Section(title: "Task with two steps") {
               @ContentAndMedia {
                  This is an introduction.
               }
               @Steps {
                  @Step {
                     This is the first step.
                     @Code(file: code1.swift, name: somefile.swift)
                  }
                  @Step {
                     This is the second step. This will not produce diffs because `reset` is `true`.
                     @Code(file: code2.swift, name: somefile.swift, reset: true)
                  }
               }
            }
            @Assessments
            """)
        let code1 = TextFile(name: "code1.swift", utf8Content: "func foo() {}")
        let code2 = TextFile(name: "code2.swift", utf8Content: "func foo() {}\nfunc bar() {}")
        let results = try highlights(tutorialFile: tutorialFile, codeFiles: [code1, code2])
        
        XCTAssertEqual(2, results.count)
        
        XCTAssertEqual(ResourceReference(bundleIdentifier: LineHighlighterTests.bundleIdentifier, path: code1.name), results[0].file)
        XCTAssertTrue(results[0].highlights.isEmpty)
        
        XCTAssertEqual(ResourceReference(bundleIdentifier: LineHighlighterTests.bundleIdentifier, path: code2.name), results[1].file)
        XCTAssertTrue(results[1].highlights.isEmpty)
    }
    
    func testPreviousOverride() throws {
        let tutorialFile = TextFile(name: "Tutorial.tutorial", utf8Content: """
            @Tutorial(title: "No Steps", time: 20, projectFiles: nothing.zip) {
               @XcodeRequirement(title: "Xcode X.Y Beta Z", destination: "https://www.example.com/download")
               @Intro(title: "Test Intro")
            @Section(title: "Section with two steps") {
               @ContentAndMedia {
                  This is an introduction.
               }
               @Steps {
                  @Step {
                     This is the first step.
                     @Code(file: code0.swift, name: somefile.swift)
                  }
                  @Step {
                     This is the second step.
                     Normally, this diff would produce 2 highlighted lines because code0.swift has no lines and code2.swift has two.
                     However, we're overriding the previous file to use for diffing, code1.swift, which has one line, so we expect
                     to see a single line highlight for `func bar() {}` (line 2).
                     @Code(file: code2.swift, name: somefile.swift, previousFile: code1.swift)
                  }
               }
            }
            @Assessments
            """)
        let code0 = TextFile(name: "code0.swift", utf8Content: "")
        let code1 = TextFile(name: "code1.swift", utf8Content: "func foo() {}")
        let code2 = TextFile(name: "code2.swift", utf8Content: "func foo() {}\nfunc bar() {}")
        let results = try highlights(tutorialFile: tutorialFile, codeFiles: [code0, code1, code2])
        
        XCTAssertEqual(2, results.count)
        
        XCTAssertEqual(ResourceReference(bundleIdentifier: LineHighlighterTests.bundleIdentifier, path: code0.name), results[0].file)
        XCTAssertTrue(results[0].highlights.isEmpty)
        
        XCTAssertEqual(ResourceReference(bundleIdentifier: LineHighlighterTests.bundleIdentifier, path: code2.name), results[1].file)
        XCTAssertEqual(1, results[1].highlights.count)
        results[1].highlights.first.map { highlight in
            XCTAssertEqual(2, highlight.line)
            XCTAssertNil(highlight.start)
            XCTAssertNil(highlight.length)
        }
    }
}
