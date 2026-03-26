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

class TutorialTests: XCTestCase {
    func testEmpty() async throws {
        let source = "@Tutorial"
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0) as? BlockDirective
        XCTAssertNotNil(directive)
        
        let (bundle, _) = try await testBundleAndContext(named: "LegacyBundle_DoNotUseInNewTests")
        
        directive.map { directive in
            var problems = [Problem]()
            XCTAssertEqual(Tutorial.directiveName, directive.name)
            let tutorial = Tutorial(from: directive, source: nil, for: bundle, problems: &problems)
            XCTAssertNil(tutorial)
            XCTAssertEqual(
                [
                    "org.swift.docc.HasExactlyOne<\(Tutorial.self), \(Intro.self)>.Missing",
                    "org.swift.docc.HasAtLeastOne<\(Tutorial.self), \(TutorialSection.self)>",
                ],
                problems.map { $0.diagnostic.identifier }
            )
            
            XCTAssert(problems.map { $0.diagnostic.severity }.allSatisfy { $0 == .warning })
        }
    }
    
    func testValid() async throws {
        let source = """
@Tutorial(time: 20) {
   @XcodeRequirement(title: "Xcode X.Y Beta Z", destination: "https://www.example.com/download")
   @Intro(title: "Basic Augmented Reality App") {
      @Video(source: test.mp4, poster: poster.png)
      @Image(source: myimage.png, alt: image)
   }
   
   @Section(title: "Create a New AR Project") {
      @ContentAndMedia {
         Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt
         ut labore et dolore magna aliqua. Phasellus faucibus scelerisque eleifend donec pretium.
         Ultrices dui sapien eget mi proin sed libero enim. Quis auctor elit sed vulputate mi sit amet.
          
         @Image(source: figure1.png, alt: figure1)

         ![](https://www.example.com/ac/structured-data/images/knowledge_graph_logo.png)
         
         Quis auctor elit sed vulputate mi sit amet.
      }
      
      @Steps {
         
         Let's get started building the Augmented Reality app.
         
         @Step {
            Lorem ipsum dolor sit amet, consectetur.
            @Image(source: xcode1.png, alt: xcode1)
            @Code(file: code1.swift, name: MyCode.swift) {
               @Image(source: screenshot.png, alt: screenshot)
            }
         }
         @Step {
            Lorem ipsum dolor sit amet, consectetur.
            @Video(source: app.mov)
            @Code(file: code2.swift, name: MyCode.swift, reset: true) {
               @Image(source: screenshot.png, alt: screenshot)
            }
         }
         
         > Experiment: Do something cool.
         
         @Step {
            Lorem ipsum dolor sit amet, consectetur.
            @Video(source: app2.mov)
            @Code(file: othercode1.swift, name: OtherCode.swift)
         }
      }
   }
   
   @Section(title: "Initiate ARKit Plane Detection") {
      @ContentAndMedia {
         Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt
         ut labore et dolore magna aliqua. Phasellus faucibus scelerisque eleifend donec pretium.
          
         Ultrices dui sapien eget mi proin sed libero enim. Quis auctor elit sed vulputate mi sit amet.

         @Image(source: xcode.png, alt: xcode)
      }
      
      @Steps {
            
         Let's get started building the Augmented Reality app.
      
         @Step {
            Lorem ipsum dolor sit amet, consectetur.
            @Image(source: xcode1.png, alt: xcode)
         }
         @Step {
            Lorem ipsum dolor sit amet, consectetur.
            @Video(source: app.mov)
         }
         @Step {
            Lorem ipsum dolor sit amet, consectetur.
            @Video(source: app2.mov)
         }
      }
   }
   
   @Assessments {
      @MultipleChoice {
         Lorem ipsum dolor sit amet?

         Phasellus faucibus scelerisque eleifend donec pretium.
         
         ```swift
         let scene = ARSCNView()
         let anchor = scene.anchor(for: node)
         ```
                  
         @Choice(isCorrect: true) {
            `anchor.hitTest(view)`
            
            @Justification(reaction: "Correct!") {
               This is correct because it is.
            }
         }
         
         @Choice(isCorrect: false) {
            `anchor.intersects(view)`
            
            @Justification {
               This is incorrect because it is.
            }
         }
         
         @Choice(isCorrect: false) {
            `anchor.intersects(view)`
            
            @Justification(reaction: Sorry) {
               This is incorrect because it is.
            }
         }
      }
      
      @MultipleChoice {
         Lorem ipsum dolor sit amet?

         Phasellus faucibus scelerisque eleifend donec pretium.
         
         ```swift
         let scene = ARSCNView()
         let anchor = scene.anchor(for: node)
         ```
                  
         @Choice(isCorrect: true) {
            `anchor.hitTest(view)`
            
            @Justification {
               This is correct because it is.
            }
         }
         
         @Choice(isCorrect: false) {
            `anchor.intersects(view)`
            
            @Justification {
               This is incorrect because it is.
            }
         }
         
         @Choice(isCorrect: false) {
            `anchor.intersects(view)`
            
            @Justification {
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
            
            DataFile(name: "app.mov", data: Data()),
            DataFile(name: "app2.mov", data: Data()),
            DataFile(name: "figure1.png", data: Data()),
            DataFile(name: "myimage.png", data: Data()),
            DataFile(name: "poster.png", data: Data()),
            DataFile(name: "screenshot.png", data: Data()),
            DataFile(name: "xcode.png", data: Data()),
            DataFile(name: "xcode1.png", data: Data()),
            DataFile(name: "test.mp4", data: Data()),
        ]))
        
        directive.map { directive in
            var problems = [Problem]()
            XCTAssertEqual(Tutorial.directiveName, directive.name)
            let tutorial = Tutorial(from: directive, source: nil, for: context.inputs, problems: &problems)
            XCTAssertNotNil(tutorial)
            XCTAssertTrue(problems.isEmpty)
            tutorial.map { tutorial in
                let expectedDump = """
Tutorial @1:1-150:2 projectFiles: nil
├─ Intro @3:4-6:5 title: 'Basic Augmented Reality App'
│  ├─ MarkupContainer (empty)
│  ├─ ImageMedia @5:7-5:46 source: 'ResourceReference(bundleID: org.swift.docc.example, path: "myimage.png")' altText: 'image'
│  └─ VideoMedia @4:7-4:51 source: 'ResourceReference(bundleID: org.swift.docc.example, path: "test.mp4")' poster: 'Optional(SwiftDocC.ResourceReference(bundleID: org.swift.docc.example, path: "poster.png"))'
├─ XcodeRequirement @2:4-2:97 title: 'Xcode X.Y Beta Z' destination: 'https://www.example.com/download'
├─ TutorialSection @8:4-48:5
│  ├─ ContentAndMedia @9:7-19:8 mediaPosition: 'trailing'
│  │  ├─ MarkupContainer (3 elements)
│  │  └─ ImageMedia @14:10-14:51 source: 'ResourceReference(bundleID: org.swift.docc.example, path: "figure1.png")' altText: 'figure1'
│  └─ Steps @21:7-47:8
│     ├─ MarkupContainer (1 element)
│     ├─ Step @25:10-31:11
│     │  ├─ MarkupContainer (1 element)
│     │  ├─ MarkupContainer (empty)
│     │  └─ Code @28:13-30:14 fileReference: ResourceReference(bundleID: org.swift.docc.example, path: "code1.swift") fileName: 'MyCode.swift' shouldResetDiff: false preview: Optional(SwiftDocC.ImageMedia)
│     ├─ Step @32:10-38:11
│     │  ├─ MarkupContainer (1 element)
│     │  ├─ MarkupContainer (empty)
│     │  └─ Code @35:13-37:14 fileReference: ResourceReference(bundleID: org.swift.docc.example, path: "code2.swift") fileName: 'MyCode.swift' shouldResetDiff: true preview: Optional(SwiftDocC.ImageMedia)
│     ├─ MarkupContainer (1 element)
│     └─ Step @42:10-46:11
│        ├─ MarkupContainer (1 element)
│        ├─ MarkupContainer (empty)
│        └─ Code @45:13-45:65 fileReference: ResourceReference(bundleID: org.swift.docc.example, path: "othercode1.swift") fileName: 'OtherCode.swift' shouldResetDiff: false preview: nil
├─ TutorialSection @50:4-77:5
│  ├─ ContentAndMedia @51:7-58:8 mediaPosition: 'trailing'
│  │  ├─ MarkupContainer (2 elements)
│  │  └─ ImageMedia @57:10-57:47 source: 'ResourceReference(bundleID: org.swift.docc.example, path: "xcode.png")' altText: 'xcode'
│  └─ Steps @60:7-76:8
│     ├─ MarkupContainer (1 element)
│     ├─ Step @64:10-67:11
│     │  ├─ MarkupContainer (1 element)
│     │  └─ MarkupContainer (empty)
│     ├─ Step @68:10-71:11
│     │  ├─ MarkupContainer (1 element)
│     │  └─ MarkupContainer (empty)
│     └─ Step @72:10-75:11
│        ├─ MarkupContainer (1 element)
│        └─ MarkupContainer (empty)
└─ Assessments @79:4-149:5
   ├─ MultipleChoice @80:7-113:8 title: 'SwiftDocC.MarkupContainer'
   │  ├─ MarkupContainer (2 elements)
   │  ├─ Choice @90:10-96:11 isCorrect: true
   │  │  ├─ MarkupContainer (1 element)
   │  │  └─ Justification @93:13-95:14 reaction: 'Correct!'
   │  │     └─ MarkupContainer (1 element)
   │  ├─ Choice @98:10-104:11 isCorrect: false
   │  │  ├─ MarkupContainer (1 element)
   │  │  └─ Justification @101:13-103:14
   │  │     └─ MarkupContainer (1 element)
   │  └─ Choice @106:10-112:11 isCorrect: false
   │     ├─ MarkupContainer (1 element)
   │     └─ Justification @109:13-111:14 reaction: 'Sorry'
   │        └─ MarkupContainer (1 element)
   └─ MultipleChoice @115:7-148:8 title: 'SwiftDocC.MarkupContainer'
      ├─ MarkupContainer (2 elements)
      ├─ Choice @125:10-131:11 isCorrect: true
      │  ├─ MarkupContainer (1 element)
      │  └─ Justification @128:13-130:14
      │     └─ MarkupContainer (1 element)
      ├─ Choice @133:10-139:11 isCorrect: false
      │  ├─ MarkupContainer (1 element)
      │  └─ Justification @136:13-138:14
      │     └─ MarkupContainer (1 element)
      └─ Choice @141:10-147:11 isCorrect: false
         ├─ MarkupContainer (1 element)
         └─ Justification @144:13-146:14
            └─ MarkupContainer (1 element)
"""
                XCTAssertEqual(expectedDump, tutorial.dump())
            }
        }
    }
    
    func testDuplicateSectionTitle() async throws {
        let source = """
@Tutorial(time: 20) {
   @XcodeRequirement(title: "Xcode X.Y Beta Z", destination: "https://www.example.com/download")
   @Intro(title: "Basic Augmented Reality App") {
      @Video(source: test.mp4, poster: poster.png)
      @Image(source: myimage.png, alt: image)
   }
   
   @Section(title: "Duplicate Title") {
      @ContentAndMedia {
         Quis auctor elit sed vulputate mi sit amet.
      }
      
      @Steps {
         @Step {
            Lorem ipsum dolor sit amet, consectetur.
         }
      }
   }
   
   @Section(title: "Duplicate Title") {
      @ContentAndMedia {
         Quis auctor elit sed vulputate mi sit amet.
      }
      @Steps {
         @Step {
            Lorem ipsum dolor sit amet, consectetur.
         }
      }
   }

   @Assessments {
      @MultipleChoice {
         Lorem ipsum dolor sit amet?

         Phasellus faucibus scelerisque eleifend donec pretium.
         
         ```swift
         let scene = ARSCNView()
         let anchor = scene.anchor(for: node)
         ```
                  
         @Choice(isCorrect: true) {
            `anchor.hitTest(view)`
            
            @Justification(reaction: "Correct!") {
               This is correct because it is.
            }
         }
         
         @Choice(isCorrect: false) {
            `anchor.intersects(view)`
            
            @Justification {
               This is incorrect because it is.
            }
         }
         
         @Choice(isCorrect: false) {
            `anchor.intersects(view)`
            
            @Justification(reaction: Sorry) {
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
            
            DataFile(name: "myimage.png", data: Data()),
            DataFile(name: "poster.png", data: Data()),
            DataFile(name: "test.mp4", data: Data()),
        ]))
        
        directive.map { directive in
            var problems = [Problem]()
            XCTAssertEqual(Tutorial.directiveName, directive.name)
            let tutorial = Tutorial(from: directive, source: nil, for: context.inputs, problems: &problems)
            XCTAssertNotNil(tutorial)
            XCTAssertEqual(1, tutorial?.sections.count)
            XCTAssertEqual([
                "org.swift.docc.\(Tutorial.self).DuplicateSectionTitle",
            ], problems.map { $0.diagnostic.identifier })
        }
    }

    func testAnalyzeNode() async throws {
        let title = "unreferenced-tutorial"
        let reference = ResolvedTopicReference(bundleID: "org.swift.docc.TopicGraphTests", path: "/\(title)", sourceLanguage: .swift)
        let node = TopicGraph.Node(reference: reference, kind: .tutorialTableOfContents, source: .file(url: URL(fileURLWithPath: "/path/to/\(title)")), title: title)

        let (_, context) = try await testBundleAndContext()
        context.topicGraph.addNode(node)

        let engine = DiagnosticEngine()
        Tutorial.analyze(node, completedContext: context, engine: engine)

        XCTAssertEqual(engine.problems.count, 1)
        XCTAssertEqual(engine.problems.map { $0.diagnostic.identifier }, ["org.swift.docc.UnreferencedTutorial"])
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
        Tutorial.analyze(node, completedContext: context, engine: engine)

        XCTAssertEqual(engine.problems.count, 1)
        XCTAssertEqual(engine.problems.map { $0.diagnostic.identifier }, ["org.swift.docc.UnreferencedTutorial"])
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
        Tutorial.analyze(node, completedContext: context, engine: engine)

        XCTAssertEqual(engine.problems.count, 1)
        XCTAssertEqual(engine.problems.map { $0.diagnostic.identifier }, ["org.swift.docc.UnreferencedTutorial"])
        XCTAssertTrue(engine.problems.allSatisfy { $0.diagnostic.severity == .warning })
        let problem = try XCTUnwrap(engine.problems.first)
        XCTAssertNil(problem.diagnostic.source)
    }

    /// Verify that a `Tutorial` only recognizes chapter, volume, or tutorial table-of-contents nodes as valid parents.
    func testAnalyzeForValidParent() async throws {
        func node(withTitle title: String, ofKind kind: DocumentationNode.Kind) -> TopicGraph.Node {
            let url = URL(fileURLWithPath: "/path/to/\(title)")
            let reference = ResolvedTopicReference(bundleID: "org.swift.docc.TutorialArticleTests", path:  "/\(title)", sourceLanguage: .swift)
            let range = SourceRange.makeEmptyStartOfFileRangeWhenSpecificInformationIsUnavailable(source: url)
            return TopicGraph.Node(reference: reference, kind: kind, source: .range(range, url: url) , title: title)
        }

        let (_, context) = try await testBundleAndContext()

        let tutorialNode = node(withTitle: "tutorial-article", ofKind: .tutorial)

        let validParents: Set<DocumentationNode.Kind> = [.chapter, .tutorialTableOfContents, .volume]
        let otherKinds: Set<DocumentationNode.Kind> = Set(DocumentationNode.Kind.allKnownValues).subtracting(validParents)

        for kind in validParents {
            let parentNode = node(withTitle: "technology-x", ofKind: kind)
            context.topicGraph.addEdge(from: parentNode, to: tutorialNode)

            let engine = DiagnosticEngine()
            Tutorial.analyze(tutorialNode, completedContext: context, engine: engine)
            XCTAssertEqual(engine.problems.count, 0)

            context.topicGraph.removeEdges(from: parentNode)
            context.topicGraph.nodes.removeValue(forKey: parentNode.reference)
            XCTAssert(context.parents(of: tutorialNode.reference).isEmpty)
        }

        for kind in otherKinds {
            let parentNode = node(withTitle: "technology-x", ofKind: kind)
            context.topicGraph.addEdge(from: parentNode, to: tutorialNode)

            let engine = DiagnosticEngine()
            Tutorial.analyze(tutorialNode, completedContext: context, engine: engine)
            XCTAssertEqual(engine.problems.count, 1)
            XCTAssertTrue(engine.problems.allSatisfy { $0.diagnostic.severity == .warning })
            let problem = try XCTUnwrap(engine.problems.first)
            XCTAssertEqual(problem.diagnostic.identifier, "org.swift.docc.UnreferencedTutorial")

            context.topicGraph.removeEdges(from: parentNode)
            context.topicGraph.nodes.removeValue(forKey: parentNode.reference)
            XCTAssert(context.parents(of: tutorialNode.reference).isEmpty)
        }
    }
}
