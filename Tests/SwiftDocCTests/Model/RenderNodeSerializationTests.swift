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

class RenderNodeSerializationTests: XCTestCase {
    func testRoundTrip() throws {
        let inputIdentifier = ResolvedTopicReference(bundleID: "com.example.docc", path: "/example", sourceLanguage: .swift)
        var inputNode = RenderNode(identifier: inputIdentifier, kind: .tutorial)
        
        let introSection = IntroRenderSection(title: "Basic Augmented Reality App")
        
        inputNode.sections.append(introSection)
        
        let inlines: [RenderInlineContent] = [
            .text("Let's get started building the "),
            .emphasis(inlineContent: [
                .text("Augmented "),
                .strong(inlineContent: [.text("Reality")]),
            ]),
            .text(" app. First, create a new Xcode project. For more information, download "),
            .reference(identifier: .init(forExternalLink: "https://www.example.com/page"), isActive: true, overridingTitle: nil, overridingTitleInlineContent: nil),
            .text(" and then see "),
            .reference(identifier: .init("GettingStartedInXcode.md"), isActive: true, overridingTitle: nil, overridingTitleInlineContent: nil),
            .text(". Then run "),
            .codeVoice(code: "swift package generate-xcodeproj"),
            .text(".")
        ]
        
        let blockContent: [RenderBlockContent] = [
            .paragraph(.init(inlineContent: inlines)),
            .aside(.init(style: .init(rawValue: "Experiment"), content: [
                .paragraph(.init(inlineContent: [
                    .text("Try running the project in the Simulator using the "),
                    .strong(inlineContent: [.text("Project > Run")]),
                    .text(" menu item, or the following code:"),
                ])),
                .codeListing(.init(syntax: "swift", code: ["xcrun xcodebuild -h", "xcrun xcodebuild build -configuration Debug"], metadata: nil, copyToClipboard: true)),
            ]))
        ]
        
        let steps: [RenderBlockContent] = [
            .paragraph(.init(inlineContent: [.text("After you download Xcode, create a project.")])),
            .step(.init(content: [.paragraph(.init(inlineContent: [.text("Lorem ipsum")]))], caption: [.paragraph(.init(inlineContent: [.text("Caption")]))], media: .init("screenshot2.png"), code: nil, runtimePreview: nil)),
            .step(.init(content: [.paragraph(.init(inlineContent: [.text("Lorem ipsum")]))], caption: [], media: nil, code: .init("helloworld.swift"), runtimePreview: .init("screenshot2.png"))),
            .step(.init(content: [.paragraph(.init(inlineContent: [.text("Lorem ipsum")]))], caption: [], media: .init("screenshot3.png"), code: nil, runtimePreview: nil)),
            .aside(.init(style: .init(rawValue: "Note"), content: [.paragraph(.init(inlineContent: [.text("Lorem ipsum dolor emit.")]))])),
            .step(.init(content: [.paragraph(.init(inlineContent: [.text("Lorem ipsum")]))], caption: [], media: .init("screenshot4.png"), code: nil, runtimePreview: nil)),
        ]
        
        var contentAndMedia = ContentAndMediaSection(layout: .horizontal, title: "", media: RenderReferenceIdentifier("screenshot1.png"), mediaPosition: .leading)
        contentAndMedia.content = blockContent
        let tutorialSection = TutorialSectionsRenderSection.Section(title: "Create a new AR project", contentSection: [.contentAndMedia(content: contentAndMedia)], stepsSection: steps, anchor: "")
        var tutorialSection2 = tutorialSection
        var contentAndMedia2 = contentAndMedia
        contentAndMedia2.title = "Initiate ARKit plane detection"
        tutorialSection2.contentSection[0] = .contentAndMedia(content: contentAndMedia2)
        let tutorialSectionsSection = TutorialSectionsRenderSection(sections: [tutorialSection, tutorialSection2])
        
        inputNode.sections.append(tutorialSectionsSection)
        
        let assessment1 = TutorialAssessmentsRenderSection.Assessment(title: [.paragraph(.init(inlineContent: [.text("Lorem ipsum dolor sit amet?")]))],
                                                                     content: nil,
                                                                     choices: [
            .init(content: [.codeListing(.init(syntax: "swift", code: ["override func viewDidLoad() {", "super.viewDidLoad()", "}"], metadata: nil, copyToClipboard: true))], isCorrect: true, justification: [.paragraph(.init(inlineContent: [.text("It's correct because...")]))], reaction: "That's right!"),
            .init(content: [.codeListing(.init(syntax: "swift", code: ["sceneView.delegate = self"], metadata: nil, copyToClipboard: true))], isCorrect: false, justification: [.paragraph(.init(inlineContent: [.text("It's incorrect because...")]))], reaction: "Not quite."),
            .init(content: [.paragraph(.init(inlineContent: [.text("None of the above.")]))], isCorrect: false, justification: [.paragraph(.init(inlineContent: [.text("It's incorrect because...")]))], reaction: nil),
        ])
        
        let assessment2 = TutorialAssessmentsRenderSection.Assessment(title: [.paragraph(.init(inlineContent: [.text("Duis aute irure dolor in reprehenderit?")]))],
                                                                     content: [.paragraph(.init(inlineContent: [.text("What is the airspeed velocity of an unladen swallow?")]))],
                                                                     choices: [
            .init(content: [.codeListing(.init(syntax: "swift", code: ["super.viewWillAppear()"], metadata: nil, copyToClipboard: true))], isCorrect: true, justification: [.paragraph(.init(inlineContent: [.text("It's correct because...")]))], reaction: "Correct."),
            .init(content: [.codeListing(.init(syntax: "swift", code: ["sceneView.delegate = self"], metadata: nil, copyToClipboard: true))], isCorrect: true, justification: [.paragraph(.init(inlineContent: [.text("It's correct because...")]))], reaction: "Yep."),
            .init(content: [.paragraph(.init(inlineContent: [.text("None of the above.")]))], isCorrect: false, justification: [.paragraph(.init(inlineContent: [.text("It's incorrect because...")]))], reaction: "Close!"),
        ])
        
        let assessments = TutorialAssessmentsRenderSection(assessments: [assessment1, assessment2], anchor: "Check-Your-Understanding")
        
        inputNode.sections.append(assessments)
        
        checkRoundTrip(inputNode)
    }
    
    func testBundleRoundTrip() async throws {
        let (bundle, context) = try await testBundleAndContext(named: "LegacyBundle_DoNotUseInNewTests")
        let node = try context.entity(with: ResolvedTopicReference(bundleID: bundle.id, path: "/tutorials/Test-Bundle/TestTutorial", sourceLanguage: .swift))
        
        guard let tutorialDirective = node.markup as? BlockDirective else {
            XCTFail("Unexpected document structure, tutorial not found as first child.")
            return
        }
        
        var problems = [Problem]()
        guard let tutorial = Tutorial(from: tutorialDirective, source: nil, for: bundle, problems: &problems) else {
            XCTFail("Couldn't create tutorial from markup: \(problems)")
            return
        }
        
        XCTAssertEqual(problems.count, 1, "Found problems \(problems.map { DiagnosticConsoleWriter.formattedDescription(for: $0.diagnostic) }) analyzing tutorial markup")
        
        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference)
        
        let renderNode = translator.visit(tutorial) as! RenderNode
        checkRoundTrip(renderNode)
    }
    
    func testTutorialArticleRoundTrip() async throws {
        let (bundle, context) = try await testBundleAndContext(named: "LegacyBundle_DoNotUseInNewTests")
        let node = try context.entity(with: ResolvedTopicReference(bundleID: bundle.id, path: "/tutorials/Test-Bundle/TestTutorialArticle", sourceLanguage: .swift))
        
        guard let articleDirective = node.markup as? BlockDirective else {
            XCTFail("Unexpected document structure, article not found as first child.")
            return
        }
        
        var problems = [Problem]()
        guard let article = TutorialArticle(from: articleDirective, source: nil, for: bundle, problems: &problems) else {
            XCTFail("Couldn't create article from markup: \(problems)")
            return
        }
        
        XCTAssertEqual(problems.count, 0, "Found problems \(problems.map { DiagnosticConsoleWriter.formattedDescription(for: $0.diagnostic) }) analyzing article markup")
        
        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference)
        
        let renderNode = translator.visit(article) as! RenderNode
        checkRoundTrip(renderNode)
    }
    
    func testAssetReferenceDictionary() async throws {
        typealias JSONDictionary = [String: Any]
        
        let (bundle, context) = try await testBundleAndContext(named: "LegacyBundle_DoNotUseInNewTests")
        let node = try context.entity(with: ResolvedTopicReference(bundleID: bundle.id, path: "/tutorials/Test-Bundle/TestTutorial", sourceLanguage: .swift))
        
        guard let tutorialDirective = node.markup as? BlockDirective else {
            XCTFail("Unexpected document structure, tutorial not found as first child.")
            return
        }
        
        var problems = [Problem]()
        guard let tutorial = Tutorial(from: tutorialDirective, source: nil, for: bundle, problems: &problems) else {
            XCTFail("Couldn't create tutorial from markup: \(problems)")
            return
        }
        
        XCTAssertEqual(problems.count, 1, "Found problems \(problems.map { DiagnosticConsoleWriter.formattedDescription(for: $0.diagnostic) }) analyzing tutorial markup")
        
        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference)
        
        let renderNode = translator.visit(tutorial) as! RenderNode
        let data = try encode(renderNode: renderNode)
        
        // Ensure references are correct
        XCTAssertNotNil(renderNode.projectFiles())
        XCTAssertEqual(renderNode.projectFiles()?.url.lastPathComponent, "project.zip")
        
        XCTAssertEqual(renderNode.navigatorChildren(for: nil).count, 0)
        XCTAssertEqual(renderNode.downloadReferences().count, 1)
        
        // Check the output of the dictionary
        let dictionary = try JSONSerialization.jsonObject(with: data, options: []) as! JSONDictionary
        let references = dictionary["references"] as! [String: JSONDictionary]
        for asset in references.values {
            let type = asset["type"] as! String
            if type == "image" {
                let variants = asset["variants"] as! [JSONDictionary]
                for variant in variants {
                    XCTAssertNotNil(variant["traits"])
                    XCTAssertNotNil(variant["url"])
                }
            } else if type == "video" {
                let variants = asset["variants"] as! [JSONDictionary]
                for variant in variants {
                    // Ensure video has no size.
                    XCTAssertNil(variant["size"])
                    XCTAssertNotNil(variant["traits"])
                    XCTAssertNotNil(variant["url"])
                }
            }
        }
    }

    func testDiffAvailability() async throws {
        let (bundle, context) = try await testBundleAndContext(named: "LegacyBundle_DoNotUseInNewTests")
        let node = try context.entity(with: ResolvedTopicReference(bundleID: bundle.id, path: "/tutorials/Test-Bundle/TestTutorialArticle", sourceLanguage: .swift))
        
        guard let articleDirective = node.markup as? BlockDirective else {
            XCTFail("Unexpected document structure, article not found as first child.")
            return
        }
        
        var problems = [Problem]()
        guard let article = TutorialArticle(from: articleDirective, source: nil, for: bundle, problems: &problems) else {
            XCTFail("Couldn't create article from markup: \(problems)")
            return
        }

        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference)

        var renderNode = translator.visit(article) as! RenderNode

        renderNode.diffAvailability = DiffAvailability(
            beta: nil,
            minor: DiffAvailability.Info(change: "modified", platform: "Xcode", versions: ["11.3", "11.4"]),
            major: DiffAvailability.Info(change: "added", platform: "Xcode", versions: ["11.0", "11.4"]),
            sdk: DiffAvailability.Info(change: "deprecated", platform: "Xcode", versions: ["12A123", "12A124"])
        )

        checkRoundTrip(renderNode)
    }

    func testKindTutorialSerialization() throws {
        struct Wrapper: Codable {
            let kind: RenderNode.Kind
        }
        func decodeKind(jsonString: String) throws -> RenderNode.Kind {
            return try JSONDecoder().decode(RenderNode.Kind.self, from: Data(jsonString.utf8))
        }
        
        // Both values can be decoded
        XCTAssertEqual(try decodeKind(jsonString: "\"tutorial\""), .tutorial)
        XCTAssertEqual(try decodeKind(jsonString: "\"project\""), .tutorial)
        
        // A `tutorial` kind is still encoded as "project" for compatibility.
        let decoded = try decodeKind(jsonString: "\"tutorial\"")
        let encoded = try String(data: JSONEncoder().encode(Wrapper(kind: decoded)), encoding: .utf8)
        XCTAssertEqual(encoded, "{\"kind\":\"project\"}")
    }
    
    func testRenderMetadataSerialization() throws {
        func decodeMetadata(jsonString: String) throws -> RenderMetadata {
            return try JSONDecoder().decode(RenderMetadata.self, from: jsonString.data(using: .utf8)!)
        }
        
        // Both values can be decoded, and are decoded as "project".
        XCTAssertEqual(try decodeMetadata(jsonString: "{}").role, nil)
        XCTAssertEqual(try decodeMetadata(jsonString: "{ \"role\" : \"tutorial\" }").role, "project")
        XCTAssertEqual(try decodeMetadata(jsonString: "{ \"role\" : \"project\" }").role, "project")
        
        // A `tutorial` role is still encoded as "project" for compatibility.
        let decoded = try decodeMetadata(jsonString: "{ \"role\" : \"tutorial\" }")
        let encoded = try String(data: JSONEncoder().encode(decoded), encoding: .utf8)
        XCTAssertEqual(encoded, "{\"role\":\"project\"}")
    }
    
    func testRenderHierarchyChapterSerialization() throws {
        func decodeMetadata(jsonString: String) throws -> RenderHierarchyChapter {
            return try JSONDecoder().decode(RenderHierarchyChapter.self, from: jsonString.data(using: .utf8)!)
        }
        
        // Both keys can be decoded, and are decoded as "tutorials".
        XCTAssertEqual(try decodeMetadata(jsonString: """
        {
          "reference" : "chapter-identifier",
          "tutorials" : [
            {
              "reference" : "tutorial-identifier",
              "sections" : []
            }
          ]
        }
        """).tutorials.first?.reference.identifier, "tutorial-identifier")
        XCTAssertEqual(try decodeMetadata(jsonString: """
        {
          "reference" : "chapter-identifier",
          "projects" : [
            {
              "reference" : "tutorial-identifier",
              "sections" : []
            }
          ]
        }
        """).tutorials.first?.reference.identifier, "tutorial-identifier")
        
        // The `tutorials` property is still encoded as "projects" for compatibility.
        let decoded = try decodeMetadata(jsonString: """
        {
          "reference" : "chapter-identifier",
          "tutorials" : []
        }
        """)
        let encoded = try String(data: JSONEncoder().encode(decoded), encoding: .utf8)!
        XCTAssertTrue(encoded.contains("\"projects\":[]"))
        XCTAssertFalse(encoded.contains("\"tutorials\":[]"))
    }
    
    // MARK: - Utility functions

    func checkRoundTrip(_ inputNode: RenderNode, file: StaticString = #filePath, line: UInt = #line) {
        // Make sure we're not using a shared encoder
        let testEncoder = JSONEncoder()
        let testDecoder = JSONDecoder()
        
        let data: Data
        do {
            data = try inputNode.encodeToJSON(with: testEncoder)
        } catch {
            XCTFail("Failed to encode node to JSON: \(error.localizedDescription)", file: (file), line: line)
            return
        }

        let newNode: RenderNode
        do {
            newNode = try RenderNode.decode(fromJSON: data, with: testDecoder)
        } catch {
            let json = String(data: data, encoding: .utf8) ?? ""
            XCTFail("Failed to decode node from JSON: \(error.localizedDescription)\n\(json)", file: (file), line: line)
            return
        }

        do {
            let newData = try newNode.encodeToJSON(with: testEncoder)
            XCTAssertEqual(data.count, newData.count, file: (file), line: line)
        } catch {
            XCTFail("Failed to encode new node back to JSON: \(error.localizedDescription)", file: (file), line: line)
        }
    }

    func encode(renderNode: RenderNode) throws -> Data {
        let encoder = JSONEncoder()
        if #available(OSX 10.13, *) {
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        }
        
        return try encoder.encode(renderNode)
    }
}
