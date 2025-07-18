/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

import XCTest
@testable import SwiftDocC
import Markdown

class RedirectedTests: XCTestCase {
    func testEmpty() async throws {
        let source = "@Redirected"
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let (bundle, _) = try await testBundleAndContext(named: "LegacyBundle_DoNotUseInNewTests")
        var problems = [Problem]()
        let redirected = Redirect(from: directive, source: nil, for: bundle, problems: &problems)
        XCTAssertNil(redirected)
        XCTAssertEqual(1, problems.count)
        XCTAssertFalse(problems.containsErrors)
        XCTAssertEqual("org.swift.docc.HasArgument.from", problems.first?.diagnostic.identifier)
    }
    
    func testValid() async throws {
        let oldPath = "/old/path/to/this/page"
        let source = "@Redirected(from: \(oldPath))"
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let (bundle, _) = try await testBundleAndContext(named: "LegacyBundle_DoNotUseInNewTests")
        var problems = [Problem]()
        let redirected = Redirect(from: directive, source: nil, for: bundle, problems: &problems)
        XCTAssertNotNil(redirected)
        XCTAssertTrue(problems.isEmpty)
        XCTAssertEqual(redirected?.oldPath.path, oldPath)
    }
    
    func testExtraArguments() async throws {
        let oldPath = "/old/path/to/this/page"
        let source = "@Redirected(from: \(oldPath), argument: value)"
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let (bundle, _) = try await testBundleAndContext(named: "LegacyBundle_DoNotUseInNewTests")
        var problems = [Problem]()
        let redirected = Redirect(from: directive, source: nil, for: bundle, problems: &problems)
        XCTAssertNotNil(redirected, "Even if there are warnings we can create a Redirected value")
        XCTAssertFalse(problems.containsErrors)
        XCTAssertEqual(1, problems.count)
        XCTAssertEqual("org.swift.docc.UnknownArgument", problems.first?.diagnostic.identifier)
    }
    
    func testExtraDirective() async throws {
        let oldPath = "/old/path/to/this/page"
        let source = """
        @Redirected(from: \(oldPath)) {
           @Image
        }
        """
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let (bundle, _) = try await testBundleAndContext(named: "LegacyBundle_DoNotUseInNewTests")
        var problems = [Problem]()
        let redirected = Redirect(from: directive, source: nil, for: bundle, problems: &problems)
        XCTAssertNotNil(redirected, "Even if there are warnings we can create a Redirected value")
        XCTAssertEqual(2, problems.count)
        XCTAssertFalse(problems.containsErrors)
        XCTAssertEqual("org.swift.docc.HasOnlyKnownDirectives", problems.first?.diagnostic.identifier)
        XCTAssertEqual("org.swift.docc.Redirected.NoInnerContentAllowed", problems.last?.diagnostic.identifier)
    }
    
    func testExtraContent() async throws {
        let oldPath = "/old/path/to/this/page"
        let source = """
        @Redirected(from: \(oldPath)) {
           Some text
        }
        """
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let (bundle, _) = try await testBundleAndContext(named: "LegacyBundle_DoNotUseInNewTests")
        var problems = [Problem]()
        let redirected = Redirect(from: directive, source: nil, for: bundle, problems: &problems)
        XCTAssertNotNil(redirected, "Even if there are warnings we can create a Redirected value")
        XCTAssertFalse(problems.containsErrors)
        XCTAssertEqual(1, problems.count)
        XCTAssertEqual("org.swift.docc.Redirected.NoInnerContentAllowed", problems.first?.diagnostic.identifier)
    }
    
    // MARK: - Redirect support
    
    func testTechnologySupportsRedirect() async throws {
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
        let (bundle, _) = try await testBundleAndContext(named: "LegacyBundle_DoNotUseInNewTests")
        var problems = [Problem]()
        let tutorialTableOfContents = TutorialTableOfContents(from: directive, source: nil, for: bundle, problems: &problems)
        XCTAssertNotNil(tutorialTableOfContents, "A tutorial table-of-contents value can be created with a Redirected child.")
        XCTAssert(problems.isEmpty, "There shouldn't be any problems. Got:\n\(problems.map { $0.diagnostic.summary })")
        
        var analyzer = SemanticAnalyzer(source: nil, bundle: bundle)
        _ = analyzer.visit(document)
        XCTAssert(analyzer.problems.isEmpty, "Expected no problems. Got \(DiagnosticConsoleWriter.formattedDescription(for:  analyzer.problems))")
    }
    
    func testVolumeAndChapterSupportsRedirect() async throws {
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
        let (bundle, _) = try await testBundleAndContext(named: "LegacyBundle_DoNotUseInNewTests")
        var problems = [Problem]()
        let volume = Volume(from: directive, source: nil, for: bundle, problems: &problems)
        XCTAssertNotNil(volume, "A Volume value can be created with a Redirected child.")
        XCTAssert(problems.isEmpty, "There shouldn't be any problems. Got:\n\(problems.map { $0.diagnostic.summary })")
    }
    
    func testTutorialAndSectionsSupportsRedirect() async throws {
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
        let (bundle, _) = try await testBundleAndContext(named: "LegacyBundle_DoNotUseInNewTests")
        var problems = [Problem]()
        let tutorial = Tutorial(from: directive, source: nil, for: bundle, problems: &problems)
        XCTAssertNotNil(tutorial, "A Tutorial value can be created with a Redirected child.")
        XCTAssert(problems.isEmpty, "There shouldn't be any problems. Got:\n\(problems.map { $0.diagnostic.summary })")
        
        var analyzer = SemanticAnalyzer(source: nil, bundle: bundle)
        _ = analyzer.visit(document)
        XCTAssert(analyzer.problems.isEmpty, "Expected no problems. Got \(DiagnosticConsoleWriter.formattedDescription(for:  analyzer.problems))")
    }
    
    func testTutorialArticleSupportsRedirect() async throws {
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
        let (bundle, _) = try await testBundleAndContext(named: "LegacyBundle_DoNotUseInNewTests")
        var problems = [Problem]()
        let article = TutorialArticle(from: directive, source: nil, for: bundle, problems: &problems)
        XCTAssertNotNil(article, "A TutorialArticle value can be created with a Redirected child.")
        XCTAssert(problems.isEmpty, "There shouldn't be any problems. Got:\n\(problems.map { $0.diagnostic.summary })")
        
        var analyzer = SemanticAnalyzer(source: nil, bundle: bundle)
        _ = analyzer.visit(document)
        XCTAssert(analyzer.problems.isEmpty, "Expected no problems. Got \(DiagnosticConsoleWriter.formattedDescription(for:  analyzer.problems))")
    }
    
    func testResourcesSupportsRedirect() async throws {
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
        let (bundle, _) = try await testBundleAndContext(named: "LegacyBundle_DoNotUseInNewTests")
        var problems = [Problem]()
        let article = Resources(from: directive, source: nil, for: bundle, problems: &problems)
        XCTAssertNotNil(article, "A Resources value can be created with a Redirected child.")
        XCTAssert(problems.isEmpty, "There shouldn't be any problems. Got:\n\(problems.map { $0.diagnostic.summary })")
    }
    
    func testArticleSupportsRedirect() async throws {
        let source = """
        # Plain article
        
        The abstract of this article
        
        @Redirected(from: /old/path/to/this/page)
        @Redirected(from: /another/old/path/to/this/page)

        ## Section Name

        ![full width image](referenced-article-image.png)
        """
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let (bundle, _) = try await testBundleAndContext(named: "LegacyBundle_DoNotUseInNewTests")
        var problems = [Problem]()
        let article = Article(from: document, source: nil, for: bundle, problems: &problems)
        XCTAssertNotNil(article, "An Article value can be created with a Redirected child.")
        XCTAssert(problems.isEmpty, "There shouldn't be any problems. Got:\n\(problems.map { $0.diagnostic.summary })")

        var analyzer = SemanticAnalyzer(source: nil, bundle: bundle)
        _ = analyzer.visit(document)
        XCTAssert(analyzer.problems.isEmpty, "Expected no problems. Got \(DiagnosticConsoleWriter.formattedDescription(for:  analyzer.problems))")

        let redirects = try XCTUnwrap(article?.redirects)
        XCTAssertEqual(2, redirects.count)
        let oldPaths = redirects.map{ $0.oldPath.relativePath }.sorted()
        XCTAssertEqual([
            "/another/old/path/to/this/page",
            "/old/path/to/this/page",
        ], oldPaths)
    }

    func testArticleSupportsRedirectInMetadata() async throws {
        let source = """
        # Plain article

        The abstract of this article

        @Metadata {
            @Redirected(from: /old/path/to/this/page)
            @Redirected(from: /another/old/path/to/this/page)
        }

        ## Section Name

        ![full width image](referenced-article-image.png)
        """
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let (bundle, _) = try await testBundleAndContext(named: "LegacyBundle_DoNotUseInNewTests")
        var problems = [Problem]()
        let article = Article(from: document, source: nil, for: bundle, problems: &problems)
        XCTAssertNotNil(article, "An Article value can be created with a Redirected child.")
        XCTAssert(problems.isEmpty, "There shouldn't be any problems. Got:\n\(problems.map { $0.diagnostic.summary })")

        var analyzer = SemanticAnalyzer(source: nil, bundle: bundle)
        _ = analyzer.visit(document)
        XCTAssert(analyzer.problems.isEmpty, "Expected no problems. Got \(DiagnosticConsoleWriter.formattedDescription(for:  analyzer.problems))")

        let redirects = try XCTUnwrap(article?.redirects)
        XCTAssertEqual(2, redirects.count)
        let oldPaths = redirects.map{ $0.oldPath.relativePath }.sorted()
        XCTAssertEqual([
            "/another/old/path/to/this/page",
            "/old/path/to/this/page",
        ], oldPaths)
    }

    func testArticleSupportsBothRedirects() async throws {
        let source = """
        # Plain article

        The abstract of this article

        @Metadata {
            @Redirected(from: /old/path/to/this/page)
            @Redirected(from: /another/old/path/to/this/page)
        }

        ## Section Name

        @Redirected(from: /third/old/path/to/this/page)

        ![full width image](referenced-article-image.png)
        """
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let (bundle, _) = try await testBundleAndContext(named: "LegacyBundle_DoNotUseInNewTests")
        var problems = [Problem]()
        let article = Article(from: document, source: nil, for: bundle, problems: &problems)
        XCTAssertNotNil(article, "An Article value can be created with a Redirected child.")
        XCTAssert(problems.isEmpty, "There shouldn't be any problems. Got:\n\(problems.map { $0.diagnostic.summary })")
                
        var analyzer = SemanticAnalyzer(source: nil, bundle: bundle)
        _ = analyzer.visit(document)
        XCTAssert(analyzer.problems.isEmpty, "Expected no problems. Got \(DiagnosticConsoleWriter.formattedDescription(for:  analyzer.problems))")

        let redirects = try XCTUnwrap(article?.redirects)
        XCTAssertEqual(3, redirects.count)
        let oldPaths = redirects.map{ $0.oldPath.relativePath }.sorted()
        XCTAssertEqual([
            "/another/old/path/to/this/page",
            "/old/path/to/this/page",
            "/third/old/path/to/this/page",
        ], oldPaths)
    }
    
    func testIncorrectArgumentLabel() async throws {
        let source = "@Redirected(fromURL: /old/path)"
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let (bundle, _) = try await testBundleAndContext(named: "LegacyBundle_DoNotUseInNewTests")
        var problems = [Problem]()
        let redirected = Redirect(from: directive, source: nil, for: bundle, problems: &problems)
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
