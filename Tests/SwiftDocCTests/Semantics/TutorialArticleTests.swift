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
import DocCTestUtilities
import DocCCommon

class TutorialArticleTests: XCTestCase {
    func testEmpty() async throws {
        let source = "@Article"
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0) as? BlockDirective
        XCTAssertNotNil(directive)
        
        let (bundle, _) = try await testBundleAndContext(named: "LegacyBundle_DoNotUseInNewTests")
        
        directive.map { directive in
            var problems = [Problem]()
            XCTAssertEqual(TutorialArticle.directiveName, directive.name)
            let article = TutorialArticle(from: directive, source: nil, for: bundle, problems: &problems)
            XCTAssertNotNil(article)
            XCTAssertEqual(2, problems.count)
            XCTAssertEqual([
                "org.swift.docc.HasArgument.time",
                "org.swift.docc.HasExactlyOne<Article, \(Intro.self)>.Missing",
                ],
                           problems.map { $0.diagnostic.identifier })
        }
    }
    
    func testSimpleNoIntro() async throws {
        let source = """
@Article {
   ## The first section
   
   This is content in the first section.
   
   ## The second section
   
   This is content in the section section.
   
   ### A subsection
   
   This article has a subsection in the second section.
}
"""

        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0) as? BlockDirective
        XCTAssertNotNil(directive)
        
        let (bundle, _) = try await testBundleAndContext(named: "LegacyBundle_DoNotUseInNewTests")
        
        directive.map { directive in
            var problems = [Problem]()
            XCTAssertEqual(TutorialArticle.directiveName, directive.name)
            let article = TutorialArticle(from: directive, source: nil, for: bundle, problems: &problems)
            XCTAssertNotNil(article)
            XCTAssertEqual(2, problems.count)
            article.map { article in
                let expectedDump = """
TutorialArticle @1:1-13:2
└─ MarkupContainer (6 elements)
"""
                XCTAssertEqual(expectedDump, article.dump())
            }
        }
    }
    
    /// Tests that we parse correctly and emit proper warnings when the author provides non-sequential headers.
    func testHeaderMix() async throws {
        let source = """
@Article {
   ## The first section
   
   This is content in the first section.
   
   ## Another section
   
   asdf
   
   #### Level 4 section
   
   This is content in the section section.
   
   The second section skips the H3 and goes directly to the H4
   
   ## Jump back to 2
   
   This is ok
   
   # This goes up to an H1
   
   An H1 even though you should only use H2s or below.
}
"""

        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0) as? BlockDirective
        XCTAssertNotNil(directive)
        
        let (bundle, _) = try await testBundleAndContext(named: "LegacyBundle_DoNotUseInNewTests")
        
        directive.map { directive in
            var problems = [Problem]()
            XCTAssertEqual(TutorialArticle.directiveName, directive.name)
            let article = TutorialArticle(from: directive, source: nil, for: bundle, problems: &problems)
            XCTAssertNotNil(article)
            XCTAssertEqual(4, problems.count)
            article.map { article in
                let expectedDump = """
TutorialArticle @1:1-23:2
└─ MarkupContainer (11 elements)
"""
                XCTAssertEqual(expectedDump, article.dump())
            }
        }
    }
    
    func testIntroAndContent() async throws {
        let source = """
@Article(time: 20) {

   @Intro(title: "Basic Augmented Reality App") {
   
      This is some text in an intro.
   
      This is another paragraph of **styled text**.
   
      @Image(source: myimage.png, alt: image)
   }
   
   ## The first section
   
   This is content in the first section.
   
   ## The second section
   
   This is content in the section section.
   
   ### A subsection
   
   This article has a subsection in the second section.
}
"""

        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0) as? BlockDirective
        XCTAssertNotNil(directive)
        
        let (_, context) = try await loadBundle(catalog: Folder(name: "Something.docc", content: [
            InfoPlist(identifier: "org.swift.docc.example"),
            DataFile(name: "myimage.png", data: Data())
        ]))
        
        directive.map { directive in
            var problems = [Problem]()
            XCTAssertEqual(TutorialArticle.directiveName, directive.name)
            let article = TutorialArticle(from: directive, source: nil, for: context.inputs, problems: &problems)
            XCTAssertNotNil(article)
            XCTAssertEqual(0, problems.count)
            article.map { article in
                let expectedDump = """
TutorialArticle @1:1-23:2 title: 'Basic Augmented Reality App' time: '20'
├─ Intro @3:4-10:5 title: 'Basic Augmented Reality App'
│  ├─ MarkupContainer (2 elements)
│  └─ ImageMedia @9:7-9:46 source: 'ResourceReference(bundleID: org.swift.docc.example, path: "myimage.png")' altText: 'image'
└─ MarkupContainer (6 elements)
"""
                XCTAssertEqual(expectedDump, article.dump())
            }
        }
    }
    
    func testLayouts() async throws {
        let source = """
@Article {

   @ContentAndMedia {
      @Image(source: customize-text-view.png, alt: "alt")

      You can customize a view's display by changing your code,
      or by using the inspector to discover what's available and to help you write code.

      As you build the Landmarks app, you can use any combination of editors:
      the source editor, the canvas, or the inspectors.
      Your code stays updated, regardless of which tool you use.
   }
   
   @ContentAndMedia {
      You can customize a view's display by changing your code,
      or by using the inspector to discover what's available and to help you write code.

      As you build the Landmarks app, you can use any combination of editors:
      the source editor, the canvas, or the inspectors.
      Your code stays updated, regardless of which tool you use.
      
      @Image(source: customize-text-view.png, alt: "alt")
   }
   
   Full width inbetween other layouts.
   
   @Stack {
      @ContentAndMedia {
         You can customize a view's display by changing your code,
         or by using the inspector to discover what's available and to help you write code.
         
         @Image(source: this-is-still-trailing.png, alt: "alt")

         As you build the Landmarks app, you can use any combination of editors:
         the source editor, the canvas, or the inspectors.
         Your code stays updated, regardless of which tool you use.
      }
      
      Arbitrary markup between directives is not allowed.

      @ContentAndMedia {
         You can customize a view's display by changing your code,
         or by using the inspector to discover what's available and to help you write code.
         
         As you build the Landmarks app, you can use any combination of editors:
         the source editor, the canvas, or the inspectors.
         Your code stays updated, regardless of which tool you use.
         
         @Image(source: this-is-trailing.png, alt: "alt")
      }
   }
   
   ## A Section
   
   Some full width stuff.
   
   - foo
   - bar
   - baz
   
   @Stack {
      @ContentAndMedia {
         You can customize a view's display by changing your code,
         or by using the inspector to discover what's available and to help you write code.
         
         @Image(source: this-is-still-trailing.png, alt: "alt")

         As you build the Landmarks app, you can use any combination of editors:
         the source editor, the canvas, or the inspectors.
         Your code stays updated, regardless of which tool you use.
      }
      
      @ContentAndMedia {
         @Image(source: this-is-leading.png, alt: "alt")
      }
      
      @ContentAndMedia {
         @Image(source: this-is-leading.png, alt: "alt")
      }
   }
}
"""

        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0) as? BlockDirective
        XCTAssertNotNil(directive)
        
        let (_, context) = try await loadBundle(catalog: Folder(name: "Something.docc", content: [
            InfoPlist(identifier: "org.swift.docc.example"),
            DataFile(name: "customize-text-view.png", data: Data()),
            DataFile(name: "this-is-leading.png", data: Data()),
            DataFile(name: "this-is-trailing.png", data: Data()),
            DataFile(name: "this-is-still-trailing.png", data: Data())
        ]))
        
        directive.map { directive in
            var problems = [Problem]()
            XCTAssertEqual(TutorialArticle.directiveName, directive.name)
            let article = TutorialArticle(from: directive, source: nil, for: context.inputs, problems: &problems)
            XCTAssertNotNil(article)
            XCTAssertEqual(3, problems.count)
            let arbitraryMarkupProblem = problems.first(where: { $0.diagnostic.identifier == "org.swift.docc.Stack.UnexpectedContent" })
            XCTAssertNotNil(arbitraryMarkupProblem)
            XCTAssertEqual(arbitraryMarkupProblem?.diagnostic.summary, "'Stack' contains unexpected content")
            XCTAssertEqual(arbitraryMarkupProblem?.diagnostic.explanation, "Arbitrary markup content is not allowed as a child of the 'Stack' directive.")
            article.map { article in
                let expectedDump = """
TutorialArticle @1:1-81:2
├─ ContentAndMedia @3:4-12:5 mediaPosition: 'leading'
│  ├─ MarkupContainer (2 elements)
│  └─ ImageMedia @4:7-4:58 source: 'ResourceReference(bundleID: org.swift.docc.example, path: "customize-text-view.png")' altText: 'alt'
├─ ContentAndMedia @14:4-23:5 mediaPosition: 'trailing'
│  ├─ MarkupContainer (2 elements)
│  └─ ImageMedia @22:7-22:58 source: 'ResourceReference(bundleID: org.swift.docc.example, path: "customize-text-view.png")' altText: 'alt'
├─ MarkupContainer (1 element)
├─ Stack @27:4-51:5
│  ├─ ContentAndMedia @28:7-37:8 mediaPosition: 'trailing'
│  │  ├─ MarkupContainer (2 elements)
│  │  └─ ImageMedia @32:10-32:64 source: 'ResourceReference(bundleID: org.swift.docc.example, path: "this-is-still-trailing.png")' altText: 'alt'
│  └─ ContentAndMedia @41:7-50:8 mediaPosition: 'trailing'
│     ├─ MarkupContainer (2 elements)
│     └─ ImageMedia @49:10-49:58 source: 'ResourceReference(bundleID: org.swift.docc.example, path: "this-is-trailing.png")' altText: 'alt'
├─ MarkupContainer (3 elements)
└─ Stack @61:4-80:5
   ├─ ContentAndMedia @62:7-71:8 mediaPosition: 'trailing'
   │  ├─ MarkupContainer (2 elements)
   │  └─ ImageMedia @66:10-66:64 source: 'ResourceReference(bundleID: org.swift.docc.example, path: "this-is-still-trailing.png")' altText: 'alt'
   ├─ ContentAndMedia @73:7-75:8 mediaPosition: 'leading'
   │  ├─ MarkupContainer (empty)
   │  └─ ImageMedia @74:10-74:57 source: 'ResourceReference(bundleID: org.swift.docc.example, path: "this-is-leading.png")' altText: 'alt'
   └─ ContentAndMedia @77:7-79:8 mediaPosition: 'leading'
      ├─ MarkupContainer (empty)
      └─ ImageMedia @78:10-78:57 source: 'ResourceReference(bundleID: org.swift.docc.example, path: "this-is-leading.png")' altText: 'alt'
"""
                XCTAssertEqual(expectedDump, article.dump())
            }
        }
    }
    
    func testAssessment() async throws {
            let source = """
@Article(time: 20) {
   @Intro(title: "Basic Augmented Reality App") {

      This is some text in an intro.

      @Image(source: myimage.png, alt: image)
   }

   ## The first section
   
   This is content in the first section.
   
   ## The second section
   
   This is content in the section section.
   
   ### A subsection
   
   This article has a subsection in the second section.

   @Assessments {
      @MultipleChoice {
         This is the first question's phrasing.

         @Choice(isCorrect: true) {
            This the correct answer.
            
            @Justification(reaction: "Nice work!") {
               This is correct because it is.
            }
         }
         
         @Choice(isCorrect: false) {
            `anchor.intersects(view)`
            
            @Justification(reaction: "Maybe next time.") {
               This is incorrect because it is.
            }
         }
      }
   }
}
"""

            let document = Document(parsing: source, options: .parseBlockDirectives)
            let directive = document.child(at: 0) as? BlockDirective
            XCTAssertNotNil(directive)
            
            let (_, context) = try await loadBundle(catalog: Folder(name: "Something.docc", content: [
                InfoPlist(identifier: "org.swift.docc.example"),
                DataFile(name: "myimage.png", data: Data())
            ]))
            
            directive.map { directive in
                var problems = [Problem]()
                XCTAssertEqual(TutorialArticle.directiveName, directive.name)
                let article = TutorialArticle(from: directive, source: nil, for: context.inputs, problems: &problems)
                XCTAssertNotNil(article)
                XCTAssertEqual(0, problems.count)
                article.map { article in
                    let expectedDump = """
TutorialArticle @1:1-42:2 title: 'Basic Augmented Reality App' time: '20'
├─ Intro @2:4-7:5 title: 'Basic Augmented Reality App'
│  ├─ MarkupContainer (1 element)
│  └─ ImageMedia @6:7-6:46 source: 'ResourceReference(bundleID: org.swift.docc.example, path: "myimage.png")' altText: 'image'
├─ MarkupContainer (6 elements)
└─ Assessments @21:4-41:5
   └─ MultipleChoice @22:7-40:8 title: 'SwiftDocC.MarkupContainer'
      ├─ MarkupContainer (empty)
      ├─ Choice @25:10-31:11 isCorrect: true
      │  ├─ MarkupContainer (1 element)
      │  └─ Justification @28:13-30:14 reaction: 'Nice work!'
      │     └─ MarkupContainer (1 element)
      └─ Choice @33:10-39:11 isCorrect: false
         ├─ MarkupContainer (1 element)
         └─ Justification @36:13-38:14 reaction: 'Maybe next time.'
            └─ MarkupContainer (1 element)
"""
                    XCTAssertEqual(expectedDump, article.dump())
                }
            }
        }

    func testAnalyzeNode() async throws {
        let title = "unreferenced-tutorial"
        let reference = ResolvedTopicReference(bundleID: "org.swift.docc.TopicGraphTests", path: "/\(title)", sourceLanguage: .swift)
        let node = TopicGraph.Node(reference: reference, kind: .tutorialTableOfContents, source: .file(url: URL(fileURLWithPath: "/path/to/\(title)")), title: title)

        let (_, context) = try await testBundleAndContext()
        context.topicGraph.addNode(node)

        let engine = DiagnosticEngine()
        TutorialArticle.analyze(node, completedContext: context, engine: engine)

        XCTAssertEqual(engine.problems.count, 1)
        XCTAssertEqual(engine.problems.map { $0.diagnostic.identifier }, ["org.swift.docc.UnreferencedTutorialArticle"])
        XCTAssertTrue(engine.problems.allSatisfy { $0.diagnostic.severity == .warning })
        let problem = try XCTUnwrap(engine.problems.first)
        let source = try XCTUnwrap(problem.diagnostic.source)
        XCTAssertTrue(source.isFileURL)
    }

    func testAnalyzeExternalNode() async throws {
        let title = "unreferenced-tutorial"
        let reference = ResolvedTopicReference(bundleID: "org.swift.docc.TopicGraphTests", path: "/\(title)", sourceLanguage: .swift)
        let node = TopicGraph.Node(reference: reference, kind: .tutorialTableOfContents, source: .external, title: title)

        let (_, context) = try await testBundleAndContext()
        context.topicGraph.addNode(node)

        let engine = DiagnosticEngine()
        TutorialArticle.analyze(node, completedContext: context, engine: engine)

        XCTAssertEqual(engine.problems.count, 1)
        XCTAssertEqual(engine.problems.map { $0.diagnostic.identifier }, ["org.swift.docc.UnreferencedTutorialArticle"])
        XCTAssertTrue(engine.problems.allSatisfy { $0.diagnostic.severity == .warning })
        let problem = try XCTUnwrap(engine.problems.first)
        XCTAssertNil(problem.diagnostic.source)
    }

    func testAnalyzeFragmentNode() async throws {
        let title = "unreferenced-tutorial"
        let url = URL(fileURLWithPath: "/path/to/\(title)")
        let reference = ResolvedTopicReference(bundleID: "org.swift.docc.TopicGraphTests", path: "/\(title)", sourceLanguage: .swift)
        let range = SourceRange.makeEmptyStartOfFileRangeWhenSpecificInformationIsUnavailable(source: url)
        let node = TopicGraph.Node(reference: reference, kind: .tutorialTableOfContents, source: .range(range, url: url) , title: title)

        let (_, context) = try await testBundleAndContext()
        context.topicGraph.addNode(node)

        let engine = DiagnosticEngine()
        TutorialArticle.analyze(node, completedContext: context, engine: engine)

        XCTAssertEqual(engine.problems.count, 1)
        XCTAssertEqual(engine.problems.map { $0.diagnostic.identifier }, ["org.swift.docc.UnreferencedTutorialArticle"])
        XCTAssertTrue(engine.problems.allSatisfy { $0.diagnostic.severity == .warning })
        let problem = try XCTUnwrap(engine.problems.first)
        XCTAssertNil(problem.diagnostic.source)
    }

    /// Verify that a `TutorialArticle` only recognizes chapter, volume, or tutorial table-of-contents nodes as valid parents.
    func testAnalyzeForValidParent() async throws {
        func node(withTitle title: String, ofKind kind: DocumentationNode.Kind) -> TopicGraph.Node {
            let url = URL(fileURLWithPath: "/path/to/\(title)")
            let reference = ResolvedTopicReference(bundleID: "org.swift.docc.TutorialArticleTests", path:  "/\(title)", sourceLanguage: .swift)
            let range = SourceRange.makeEmptyStartOfFileRangeWhenSpecificInformationIsUnavailable(source: url)
            return TopicGraph.Node(reference: reference, kind: kind, source: .range(range, url: url) , title: title)
        }

        let (_, context) = try await testBundleAndContext()

        let tutorialArticleNode = node(withTitle: "tutorial-article", ofKind: .tutorialArticle)

        let validParents: Set<DocumentationNode.Kind> = [.chapter, .tutorialTableOfContents, .volume]
        let otherKinds: Set<DocumentationNode.Kind> = Set(DocumentationNode.Kind.allKnownValues).subtracting(validParents)

        for kind in validParents {
            let parentNode = node(withTitle: "technology-x", ofKind: kind)
            context.topicGraph.addEdge(from: parentNode, to: tutorialArticleNode)

            let engine = DiagnosticEngine()
            TutorialArticle.analyze(tutorialArticleNode, completedContext: context, engine: engine)
            XCTAssertEqual(engine.problems.count, 0)

            context.topicGraph.removeEdges(from: parentNode)
            context.topicGraph.nodes.removeValue(forKey: parentNode.reference)
            XCTAssert(context.parents(of: tutorialArticleNode.reference).isEmpty)
        }

        for kind in otherKinds {
            let parentNode = node(withTitle: "technology-x", ofKind: kind)
            context.topicGraph.addEdge(from: parentNode, to: tutorialArticleNode)

            let engine = DiagnosticEngine()
            TutorialArticle.analyze(tutorialArticleNode, completedContext: context, engine: engine)
            XCTAssertEqual(engine.problems.count, 1)
            XCTAssertTrue(engine.problems.allSatisfy { $0.diagnostic.severity == .warning })
            let problem = try XCTUnwrap(engine.problems.first)
            XCTAssertEqual(problem.diagnostic.identifier, "org.swift.docc.UnreferencedTutorialArticle")

            context.topicGraph.removeEdges(from: parentNode)
            context.topicGraph.nodes.removeValue(forKey: parentNode.reference)
            XCTAssert(context.parents(of: tutorialArticleNode.reference).isEmpty)
        }
    }
}
