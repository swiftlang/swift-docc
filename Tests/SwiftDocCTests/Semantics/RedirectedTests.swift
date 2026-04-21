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

class RedirectedTests: XCTestCase {
    func testEmpty() async throws {
        let source = "@Redirected"
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let (_, context) = try await testBundleAndContext(named: "LegacyBundle_DoNotUseInNewTests")
        var diagnostics = [Diagnostic]()
        let redirected = Redirect(from: directive, source: nil, for: context.inputs, featureFlags: context.configuration.featureFlags, diagnostics: &diagnostics)
        XCTAssertNil(redirected)
        XCTAssertEqual(1, diagnostics.count)
        XCTAssertFalse(diagnostics.containsError)
        XCTAssertEqual(diagnostics.first?.identifier, "org.swift.docc.HasArgument.from")
    }
    
    func testValid() async throws {
        let oldPath = "/old/path/to/this/page"
        let source = "@Redirected(from: \(oldPath))"
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let (_, context) = try await testBundleAndContext(named: "LegacyBundle_DoNotUseInNewTests")
        var diagnostics = [Diagnostic]()
        let redirected = Redirect(from: directive, source: nil, for: context.inputs, featureFlags: context.configuration.featureFlags, diagnostics: &diagnostics)
        XCTAssertNotNil(redirected)
        XCTAssertTrue(diagnostics.isEmpty)
        XCTAssertEqual(redirected?.oldPath.path, oldPath)
    }
    
    func testExtraArguments() async throws {
        let oldPath = "/old/path/to/this/page"
        let source = "@Redirected(from: \(oldPath), argument: value)"
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let (_, context) = try await testBundleAndContext(named: "LegacyBundle_DoNotUseInNewTests")
        var diagnostics = [Diagnostic]()
        let redirected = Redirect(from: directive, source: nil, for: context.inputs, featureFlags: context.configuration.featureFlags, diagnostics: &diagnostics)
        XCTAssertNotNil(redirected, "Even if there are warnings we can create a Redirected value")
        XCTAssertFalse(diagnostics.containsError)
        XCTAssertEqual(1, diagnostics.count)
        XCTAssertEqual(diagnostics.first?.identifier, "org.swift.docc.UnknownArgument")
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
        let (_, context) = try await testBundleAndContext(named: "LegacyBundle_DoNotUseInNewTests")
        var diagnostics = [Diagnostic]()
        let redirected = Redirect(from: directive, source: nil, for: context.inputs, featureFlags: context.configuration.featureFlags, diagnostics: &diagnostics)
        XCTAssertNotNil(redirected, "Even if there are warnings we can create a Redirected value")
        XCTAssertEqual(2, diagnostics.count)
        XCTAssertFalse(diagnostics.containsError)
        XCTAssertEqual(diagnostics.first?.identifier, "org.swift.docc.HasOnlyKnownDirectives")
        XCTAssertEqual(diagnostics.last?.identifier,  "org.swift.docc.Redirected.NoInnerContentAllowed")
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
        let (_, context) = try await testBundleAndContext(named: "LegacyBundle_DoNotUseInNewTests")
        var diagnostics = [Diagnostic]()
        let redirected = Redirect(from: directive, source: nil, for: context.inputs, featureFlags: context.configuration.featureFlags, diagnostics: &diagnostics)
        XCTAssertNotNil(redirected, "Even if there are warnings we can create a Redirected value")
        XCTAssertFalse(diagnostics.containsError)
        XCTAssertEqual(1, diagnostics.count)
        XCTAssertEqual(diagnostics.first?.identifier, "org.swift.docc.Redirected.NoInnerContentAllowed")
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
        let (_, context) = try await testBundleAndContext(named: "LegacyBundle_DoNotUseInNewTests")
        var diagnostics = [Diagnostic]()
        let tutorialTableOfContents = TutorialTableOfContents(from: directive, source: nil, for: context.inputs, featureFlags: context.configuration.featureFlags, diagnostics: &diagnostics)
        XCTAssertNotNil(tutorialTableOfContents, "A tutorial table-of-contents value can be created with a Redirected child.")
        XCTAssert(diagnostics.isEmpty, "There shouldn't be any diagnostics. Got:\n\(diagnostics.map(\.summary))")
        
        var analyzer = SemanticAnalyzer(source: nil, bundle: context.inputs, featureFlags: context.configuration.featureFlags)
        _ = analyzer.visit(document)
        XCTAssert(analyzer.diagnostics.isEmpty, "Expected no diagnostics. Got\n\(analyzer.diagnostics.map(\.summary))")
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
        let (_, context) = try await testBundleAndContext(named: "LegacyBundle_DoNotUseInNewTests")
        var diagnostics = [Diagnostic]()
        let volume = Volume(from: directive, source: nil, for: context.inputs, featureFlags: context.configuration.featureFlags, diagnostics: &diagnostics)
        XCTAssertNotNil(volume, "A Volume value can be created with a Redirected child.")
        XCTAssert(diagnostics.isEmpty, "There shouldn't be any diagnostics. Got:\n\(diagnostics.map(\.summary))")
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
        let (_, context) = try await testBundleAndContext(named: "LegacyBundle_DoNotUseInNewTests")
        var diagnostics = [Diagnostic]()
        let tutorial = Tutorial(from: directive, source: nil, for: context.inputs, featureFlags: context.configuration.featureFlags, diagnostics: &diagnostics)
        XCTAssertNotNil(tutorial, "A Tutorial value can be created with a Redirected child.")
        XCTAssert(diagnostics.isEmpty, "There shouldn't be any diagnostics. Got:\n\(diagnostics.map(\.summary))")
        
        var analyzer = SemanticAnalyzer(source: nil, bundle: context.inputs, featureFlags: context.configuration.featureFlags)
        _ = analyzer.visit(document)
        XCTAssert(analyzer.diagnostics.isEmpty, "Expected no diagnostics. Got \(analyzer.diagnostics.map(\.summary))")
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
        let (_, context) = try await testBundleAndContext(named: "LegacyBundle_DoNotUseInNewTests")
        var diagnostics = [Diagnostic]()
        let article = TutorialArticle(from: directive, source: nil, for: context.inputs, featureFlags: context.configuration.featureFlags, diagnostics: &diagnostics)
        XCTAssertNotNil(article, "A TutorialArticle value can be created with a Redirected child.")
        XCTAssert(diagnostics.isEmpty, "There shouldn't be any diagnostics. Got:\n\(diagnostics.map(\.summary))")
        
        var analyzer = SemanticAnalyzer(source: nil, bundle: context.inputs, featureFlags: context.configuration.featureFlags)
        _ = analyzer.visit(document)
        XCTAssert(analyzer.diagnostics.isEmpty, "Expected no diagnostics. Got\n\(analyzer.diagnostics.map(\.summary))")
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
        let (_, context) = try await testBundleAndContext(named: "LegacyBundle_DoNotUseInNewTests")
        var diagnostics = [Diagnostic]()
        let article = Resources(from: directive, source: nil, for: context.inputs, featureFlags: context.configuration.featureFlags, diagnostics: &diagnostics)
        XCTAssertNotNil(article, "A Resources value can be created with a Redirected child.")
        XCTAssert(diagnostics.isEmpty, "There shouldn't be any diagnostics. Got:\n\(diagnostics.map(\.summary))")
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
        let (_, context) = try await testBundleAndContext(named: "LegacyBundle_DoNotUseInNewTests")
        var diagnostics = [Diagnostic]()
        let article = Article(from: document, source: nil, for: context.inputs, featureFlags: context.configuration.featureFlags, diagnostics: &diagnostics)
        XCTAssertNotNil(article, "An Article value can be created with a Redirected child.")
        XCTAssert(diagnostics.isEmpty, "There shouldn't be any diagnostics. Got:\n\(diagnostics.map(\.summary))")

        var analyzer = SemanticAnalyzer(source: nil, bundle: context.inputs, featureFlags: context.configuration.featureFlags)
        _ = analyzer.visit(document)
        XCTAssert(analyzer.diagnostics.isEmpty, "Expected no diagnostics. Got:\n\(analyzer.diagnostics.map(\.summary))")

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
        let (_, context) = try await testBundleAndContext(named: "LegacyBundle_DoNotUseInNewTests")
        var diagnostics = [Diagnostic]()
        let article = Article(from: document, source: nil, for: context.inputs, featureFlags: context.configuration.featureFlags, diagnostics: &diagnostics)
        XCTAssertNotNil(article, "An Article value can be created with a Redirected child.")
        XCTAssert(diagnostics.isEmpty, "There shouldn't be any diagnostics. Got:\n\(diagnostics.map(\.summary))")

        var analyzer = SemanticAnalyzer(source: nil, bundle: context.inputs, featureFlags: context.configuration.featureFlags)
        _ = analyzer.visit(document)
        XCTAssert(analyzer.diagnostics.isEmpty, "Expected no diagnostics. Got:\n\(analyzer.diagnostics.map(\.summary))")

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
        let (_, context) = try await testBundleAndContext(named: "LegacyBundle_DoNotUseInNewTests")
        var diagnostics = [Diagnostic]()
        let article = Article(from: document, source: nil, for: context.inputs, featureFlags: context.configuration.featureFlags, diagnostics: &diagnostics)
        XCTAssertNotNil(article, "An Article value can be created with a Redirected child.")
        XCTAssert(diagnostics.isEmpty, "There shouldn't be any diagnostics. Got:\n\(diagnostics.map(\.summary))")
                
        var analyzer = SemanticAnalyzer(source: nil, bundle: context.inputs, featureFlags: context.configuration.featureFlags)
        _ = analyzer.visit(document)
        XCTAssert(analyzer.diagnostics.isEmpty, "Expected no diagnostics. Got:\n\(analyzer.diagnostics.map(\.summary))")

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
        let (_, context) = try await testBundleAndContext(named: "LegacyBundle_DoNotUseInNewTests")
        var diagnostics = [Diagnostic]()
        let redirected = Redirect(from: directive, source: nil, for: context.inputs, featureFlags: context.configuration.featureFlags, diagnostics: &diagnostics)
        XCTAssertNil(redirected)
        XCTAssertEqual(2, diagnostics.count)
        XCTAssertFalse(diagnostics.containsError)
        
        XCTAssertEqual(diagnostics.map(\.identifier).sorted(), [
            "org.swift.docc.HasArgument.from",
            "org.swift.docc.UnknownArgument",
        ])
    }
}
