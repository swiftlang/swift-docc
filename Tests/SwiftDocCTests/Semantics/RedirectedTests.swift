/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

import XCTest
@testable import SwiftDocC
import Markdown

class RedirectedTests: XCTestCase {
    func testEmpty() throws {
        let source = "@Redirected"
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        var problems = [Problem]()
        let redirected = Redirect(from: directive, source: nil, for: bundle, in: context, problems: &problems)
        XCTAssertNil(redirected)
        XCTAssertEqual(1, problems.count)
        XCTAssertFalse(problems.containsErrors)
        XCTAssertEqual("org.swift.docc.HasArgument.from", problems.first?.diagnostic.identifier)
    }
    
    func testValid() throws {
        let oldPath = "/old/path/to/this/page"
        let source = "@Redirected(from: \(oldPath))"
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        var problems = [Problem]()
        let redirected = Redirect(from: directive, source: nil, for: bundle, in: context, problems: &problems)
        XCTAssertNotNil(redirected)
        XCTAssertTrue(problems.isEmpty)
        XCTAssertEqual(redirected?.oldPath.path, oldPath)
    }
    
    func testInvalidURL() throws {
          let someCharactersThatAreNotAllowedInPaths = "⊂⧺∀ℝ∀⊂⊤∃∫"
          for character in someCharactersThatAreNotAllowedInPaths {
              XCTAssertFalse(CharacterSet.urlPathAllowed.contains(character.unicodeScalars.first!), "Verify that \(character) is invalid")
              
              let pathWithInvalidCharacter = "/path/with/invalid\(character)for/paths"
              let source = "@Redirected(from: \(pathWithInvalidCharacter))"
              let document = Document(parsing: source, options: .parseBlockDirectives)
              let directive = document.child(at: 0)! as! BlockDirective
              let (bundle, context) = try testBundleAndContext(named: "TestBundle")
              var problems = [Problem]()
              let redirected = Redirect(from: directive, source: nil, for: bundle, in: context, problems: &problems)
              XCTAssertNil(redirected?.oldPath.absoluteString, "\(character)")
              XCTAssertFalse(problems.containsErrors)
              XCTAssertEqual(1, problems.count)
              XCTAssertEqual(problems.first?.diagnostic.identifier, "org.swift.docc.HasArgument.from.ConversionFailed")
              XCTAssertEqual(
                  problems.first?.diagnostic.localizedSummary,
                  "Cannot convert '\(pathWithInvalidCharacter)' to type 'URL'"
              )
          }
      }
    
    func testExtraArguments() throws {
        let oldPath = "/old/path/to/this/page"
        let source = "@Redirected(from: \(oldPath), argument: value)"
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        var problems = [Problem]()
        let redirected = Redirect(from: directive, source: nil, for: bundle, in: context, problems: &problems)
        XCTAssertNotNil(redirected, "Even if there are warnings we can create a Redirected value")
        XCTAssertFalse(problems.containsErrors)
        XCTAssertEqual(1, problems.count)
        XCTAssertEqual("org.swift.docc.UnknownArgument", problems.first?.diagnostic.identifier)
    }
    
    func testExtraDirective() throws {
        let oldPath = "/old/path/to/this/page"
        let source = """
        @Redirected(from: \(oldPath)) {
           @Image
        }
        """
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        var problems = [Problem]()
        let redirected = Redirect(from: directive, source: nil, for: bundle, in: context, problems: &problems)
        XCTAssertNotNil(redirected, "Even if there are warnings we can create a Redirected value")
        XCTAssertEqual(2, problems.count)
        XCTAssertFalse(problems.containsErrors)
        XCTAssertEqual("org.swift.docc.HasOnlyKnownDirectives", problems.first?.diagnostic.identifier)
        XCTAssertEqual("org.swift.docc.Redirected.NoInnerContentAllowed", problems.last?.diagnostic.identifier)
    }
    
    func testExtraContent() throws {
        let oldPath = "/old/path/to/this/page"
        let source = """
        @Redirected(from: \(oldPath)) {
           Some text
        }
        """
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        var problems = [Problem]()
        let redirected = Redirect(from: directive, source: nil, for: bundle, in: context, problems: &problems)
        XCTAssertNotNil(redirected, "Even if there are warnings we can create a Redirected value")
        XCTAssertFalse(problems.containsErrors)
        XCTAssertEqual(1, problems.count)
        XCTAssertEqual("org.swift.docc.Redirected.NoInnerContentAllowed", problems.first?.diagnostic.identifier)
    }
    
    // MARK: - Redirect support
    
    func testTechnologySupportsRedirect() throws {
        let source = """
        @Tutorials(name: "Technology X") {
           @Intro(title: "Technology X") {
              You'll learn all about Technology X.
           }
           
           @Redirected(from: /old/path/to/this/page)
           @Redirected(from: /another/old/path/to/this/page)
        }
        """
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        var problems = [Problem]()
        let technology = Technology(from: directive, source: nil, for: bundle, in: context, problems: &problems)
        XCTAssertNotNil(technology, "A Technology value can be created with a Redirected child.")
        XCTAssert(problems.isEmpty, "There shouldn't be any problems. Got:\n\(problems.map { $0.diagnostic.localizedSummary })")
        
        var analyzer = SemanticAnalyzer(source: nil, context: context, bundle: bundle)
        _ = analyzer.visit(document)
        XCTAssert(analyzer.problems.isEmpty, "Expected no problems. Got \(analyzer.problems.localizedDescription)")
    }
    
    func testVolumeAndChapterSupportsRedirect() throws {
        let source = """
        @Volume(name: "Name of this volume") {
           @Image(source: image.png, alt: image)
           
           @Redirected(from: /old/path/to/this/page)
           @Redirected(from: /another/old/path/to/this/page)
           
           @Chapter(name: "Chapter 1") {
              In this chapter, you'll follow Tutorial 1. Feel free to add more `Reference`s below.
              
              @Redirected(from: /old/path/to/this/page)
              @Redirected(from: /another/old/path/to/this/page)

              @Image(source: image.png, alt: image)
              @TutorialReference(tutorial: "doc://com.test.bundle/Tutorial")
           }
        }
        """
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        var problems = [Problem]()
        let volume = Volume(from: directive, source: nil, for: bundle, in: context, problems: &problems)
        XCTAssertNotNil(volume, "A Volume value can be created with a Redirected child.")
        XCTAssert(problems.isEmpty, "There shouldn't be any problems. Got:\n\(problems.map { $0.diagnostic.localizedSummary })")
    }
    
    func testTutorialAndSectionsSupportsRedirect() throws {
        let source = """
        @Tutorial(time: 20, projectFiles: project.zip) {
           @Intro(title: "Basic Augmented Reality App") {
              @Video(source: video.mov)
           }
           
           @Redirected(from: /old/path/to/this/page)
           @Redirected(from: /another/old/path/to/this/page)
           
           @Section(title: "Create a New AR Project") {
              @ContentAndMedia {
                 Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt
                 ut labore et dolore magna aliqua. Phasellus faucibus scelerisque eleifend donec pretium.

                 Ultrices dui sapien eget mi proin sed libero enim. Quis auctor elit sed vulputate mi sit amet.

                 @Image(source: arkit.png, alt: "Description of this image")
              }

              @Redirected(from: /old/path/to/this/page)
              @Redirected(from: /another/old/path/to/this/page)
              
              @Steps {
                 Let's get started building the Augmented Reality app.
              
                 @Step {
                    Lorem ipsum dolor sit amet, consectetur.
                
                    @Image(source: Sierra.jpg, alt: "Description of this image")
                 }
              }
           }
           @Assessments {
              @MultipleChoice {
                 Lorem ipsum dolor sit amet?
                                              
                 @Choice(isCorrect: true) {
                    `anchor.hitTest(view)`
                    
                    @Justification {
                       This is correct because it is.
                    }
                 }

                 @Choice(isCorrect: false) {
                    `anchor.hitTest(view)`
                    
                    @Justification {
                       This is false because it is.
                    }
                 }
              }
           }
        }
        """
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        var problems = [Problem]()
        let tutorial = Tutorial(from: directive, source: nil, for: bundle, in: context, problems: &problems)
        XCTAssertNotNil(tutorial, "A Tutorial value can be created with a Redirected child.")
        XCTAssert(problems.isEmpty, "There shouldn't be any problems. Got:\n\(problems.map { $0.diagnostic.localizedSummary })")
        
        var analyzer = SemanticAnalyzer(source: nil, context: context, bundle: bundle)
        _ = analyzer.visit(document)
        XCTAssert(analyzer.problems.isEmpty, "Expected no problems. Got \(analyzer.problems.localizedDescription)")
    }
    
    func testTutorialArticleSupportsRedirect() throws {
        let source = """
        @Article(time: 20) {
           @Intro(title: "Making an Augmented Reality App") {
              This is an abstract for the intro.
           }

           @Redirected(from: /old/path/to/this/page)
           @Redirected(from: /another/old/path/to/this/page)
           
           ## Section Name
           
           ![full width image](referenced-article-image.png)
        }
        """
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        var problems = [Problem]()
        let article = TutorialArticle(from: directive, source: nil, for: bundle, in: context, problems: &problems)
        XCTAssertNotNil(article, "A TutorialArticle value can be created with a Redirected child.")
        XCTAssert(problems.isEmpty, "There shouldn't be any problems. Got:\n\(problems.map { $0.diagnostic.localizedSummary })")
        
        var analyzer = SemanticAnalyzer(source: nil, context: context, bundle: bundle)
        _ = analyzer.visit(document)
        XCTAssert(analyzer.problems.isEmpty, "Expected no problems. Got \(analyzer.problems.localizedDescription)")
    }
    
    func testResourcesSupportsRedirect() throws {
        let source = """
        @Resources(technology: doc:/TestOverview) {
           Find the tools and a comprehensive set of resources for creating AR experiences on iOS.

           @Redirected(from: /old/path/to/this/page)
           @Redirected(from: /another/old/path/to/this/page)

           @Documentation(destination: "https://www.example.com/documentation/technology") {
              Browse and search detailed API documentation.

              - <doc://org.swift.docc.example/tutorials/Test-Bundle/TestTutorial>
              - <doc://org.swift.docc.example/tutorials/Test-Bundle/TestTutorial2>
           }

           @SampleCode(destination: "https://www.example.com/documentation/technology") {
              Browse and search detailed sample code.

              - <doc://org.swift.docc.example/tutorials/Test-Bundle/TestTutorial>
              - <doc://org.swift.docc.example/tutorials/Test-Bundle/TestTutorial2>
           }

           @Downloads(destination: "https://www.example.com/download") {
              Download Xcode 10, which includes the latest tools and SDKs.
           }

           @Videos(destination: "https://www.example.com/videos") {
              See AR presentation from WWDC and other events.
           }

           @Forums(destination: "https://www.example.com/forums") {
              Discuss AR with Apple engineers and other developers.
           }
        }

        """
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        var problems = [Problem]()
        let article = Resources(from: directive, source: nil, for: bundle, in: context, problems: &problems)
        XCTAssertNotNil(article, "A Resources value can be created with a Redirected child.")
        XCTAssert(problems.isEmpty, "There shouldn't be any problems. Got:\n\(problems.map { $0.diagnostic.localizedSummary })")
    }
    
    func testArticleSupportsRedirect() throws {
        let source = """
        # Plain article
        
        The abstract of this article
        
        @Redirected(from: /old/path/to/this/page)
        @Redirected(from: /another/old/path/to/this/page)
           
        ## Section Name
           
        ![full width image](referenced-article-image.png)
        """
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        var problems = [Problem]()
        let article = Article(from: document, source: nil, for: bundle, in: context, problems: &problems)
        XCTAssertNotNil(article, "An Article value can be created with a Redirected child.")
        XCTAssert(problems.isEmpty, "There shouldn't be any problems. Got:\n\(problems.map { $0.diagnostic.localizedSummary })")
                
        var analyzer = SemanticAnalyzer(source: nil, context: context, bundle: bundle)
        _ = analyzer.visit(document)
        XCTAssert(analyzer.problems.isEmpty, "Expected no problems. Got \(analyzer.problems.localizedDescription)")
    }
    
    func testIncorrectArgumentLabel() throws {
        let source = "@Redirected(fromURL: /old/path)"
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        var problems = [Problem]()
        let redirected = Redirect(from: directive, source: nil, for: bundle, in: context, problems: &problems)
        XCTAssertNil(redirected)
        XCTAssertEqual(2, problems.count)
        XCTAssertFalse(problems.containsErrors)
        
        let expectedIds = [
            "org.swift.docc.UnknownArgument",
            "org.swift.docc.HasArgument.from",
        ]
        
        let problemIds = problems.map(\.diagnostic.identifier)
        
        for id in expectedIds {
            XCTAssertTrue(problemIds.contains(id))
        }
    }
}
