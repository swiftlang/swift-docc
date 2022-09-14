/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocC

class IndexingTests: XCTestCase {
    
    // MARK: - Tutorial
    func testTutorial() throws {
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        let tutorialReference = ResolvedTopicReference(bundleIdentifier: "org.swift.docc.example", path: "/tutorials/Test-Bundle/TestTutorial", sourceLanguage: .swift)
        let node = try context.entity(with: tutorialReference)
        let tutorial = node.semantic as! Tutorial
        var converter = RenderNodeTranslator(context: context, bundle: bundle, identifier: tutorialReference, source: context.documentURL(for: tutorialReference))
        let renderNode = converter.visit(tutorial) as! RenderNode
        let indexingRecords = try renderNode.indexingRecords(onPage: tutorialReference)
        XCTAssertEqual(4, indexingRecords.count)
        
        XCTAssertEqual(IndexingRecord(kind: .tutorial,
                                      location: .topLevelPage(tutorialReference),
                                      title: tutorial.intro.title,
                                      summary: "This is the tutorial abstract.",
                                      headings: [
                                        "Lorem ipsum dolor sit amet?", // MultipleChoice question title
                                        "Lorem ipsum dolor sit amet?",  // MultipleChoice question title
                                      ],
                                      rawIndexableTextContent: "This is the tutorial abstract. Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Phasellus faucibus scelerisque eleifend donec pretium. Ultrices dui sapien eget mi proin sed libero enim. Quis auctor elit sed vulputate mi sit amet. This section link refers to this section itself: Create a New AR Project 💻. This is an external link to Swift documentation: Swift Documentation. This section link refers to the next section in this file: Initiate ARKit Plane Detection. This link will never resolve: doc:ThisWillNeverResolve. This link needs an external resolver: doc://com.test.external/path/to/external/symbol. This is a note. This is important.   Quis auctor elit sed vulputate mi sit amet. Let’s get started building the Augmented Reality app. Lorem ipsum dolor sit amet, consectetur. Lorem ipsum dolor sit amet, consectetur. This is a step caption. Do something cool. Lorem ipsum dolor sit amet, consectetur. Lorem ipsum dolor sit amet, consectetur. Lorem ipsum dolor sit amet, consectetur. Lorem ipsum dolor sit amet, consectetur. Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Phasellus faucibus scelerisque eleifend donec pretium. This section link refers to the previous section: Create a New AR Project 💻. This section link refers to the first section in another tutorial: Create a New AR Project. Ultrices dui sapien eget mi proin sed libero enim. Quis auctor elit sed vulputate mi sit amet. Let’s get started building the Augmented Reality app. Lorem ipsum dolor sit amet, consectetur. Lorem ipsum dolor sit amet, consectetur. Lorem ipsum dolor sit amet, consectetur. Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Phasellus faucibus scelerisque eleifend donec pretium. Ultrices dui sapien eget mi proin sed libero enim. Quis auctor elit sed vulputate mi sit amet. Let’s get started building the Augmented Reality app. Lorem ipsum dolor sit amet, consectetur. Phasellus faucibus scelerisque eleifend donec pretium.   Phasellus faucibus scelerisque eleifend donec pretium. "),
                       indexingRecords[0])
        
        do {
            let section = tutorial.sections[0]
            let sectionReference = tutorialReference.withFragment(urlReadableFragment(section.title))
            XCTAssertEqual(IndexingRecord(kind: .tutorialSection,
                                          location: .contained(sectionReference, inPage: tutorialReference),
                                          title: section.title,
                                          summary: "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Phasellus faucibus scelerisque eleifend donec pretium. Ultrices dui sapien eget mi proin sed libero enim. Quis auctor elit sed vulputate mi sit amet. This section link refers to this section itself: Create a New AR Project 💻. This is an external link to Swift documentation: Swift Documentation. This section link refers to the next section in this file: Initiate ARKit Plane Detection. This link will never resolve: doc:ThisWillNeverResolve. This link needs an external resolver: doc://com.test.external/path/to/external/symbol.",
                                          headings: [],
                                          rawIndexableTextContent: "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Phasellus faucibus scelerisque eleifend donec pretium. Ultrices dui sapien eget mi proin sed libero enim. Quis auctor elit sed vulputate mi sit amet. This section link refers to this section itself: Create a New AR Project 💻. This is an external link to Swift documentation: Swift Documentation. This section link refers to the next section in this file: Initiate ARKit Plane Detection. This link will never resolve: doc:ThisWillNeverResolve. This link needs an external resolver: doc://com.test.external/path/to/external/symbol. This is a note. This is important.   Quis auctor elit sed vulputate mi sit amet. Let’s get started building the Augmented Reality app. Lorem ipsum dolor sit amet, consectetur. Lorem ipsum dolor sit amet, consectetur. This is a step caption. Do something cool. Lorem ipsum dolor sit amet, consectetur. Lorem ipsum dolor sit amet, consectetur. Lorem ipsum dolor sit amet, consectetur. Lorem ipsum dolor sit amet, consectetur."),
                           indexingRecords[1])
        }
        do {
            let section = tutorial.sections[1]
            let sectionReference = tutorialReference.withFragment(urlReadableFragment(section.title))
            XCTAssertEqual(IndexingRecord(kind: .tutorialSection,
                                          location: .contained(sectionReference, inPage: tutorialReference),
                                          title: section.title,
                                          summary: "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Phasellus faucibus scelerisque eleifend donec pretium. This section link refers to the previous section: Create a New AR Project 💻. This section link refers to the first section in another tutorial: Create a New AR Project.",
                                          headings: [],
                                          rawIndexableTextContent: "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Phasellus faucibus scelerisque eleifend donec pretium. This section link refers to the previous section: Create a New AR Project 💻. This section link refers to the first section in another tutorial: Create a New AR Project. Ultrices dui sapien eget mi proin sed libero enim. Quis auctor elit sed vulputate mi sit amet. Let’s get started building the Augmented Reality app. Lorem ipsum dolor sit amet, consectetur. Lorem ipsum dolor sit amet, consectetur. Lorem ipsum dolor sit amet, consectetur."),
                           indexingRecords[2])
        }
    }
    
    // MARK: - Tutorial Section
    
    func testTutorialSection() throws {
        var contentSection = ContentAndMediaSection(layout: .vertical, title: nil, media: RenderReferenceIdentifier("Image"), mediaPosition: .leading)
        contentSection.content = [.paragraph(.init(inlineContent: [.text("Hello, world!")]))]
        
        let tutorialSectionsSection = TutorialSectionsRenderSection(sections: [
            .init(title: "Section 1", contentSection: [.contentAndMedia(content: contentSection)], stepsSection: [.paragraph(.init(inlineContent: [.text("This is a step.")]))], anchor: "section-1"),
            .init(title: "Section 2", contentSection: [.contentAndMedia(content: contentSection)], stepsSection: [.paragraph(.init(inlineContent: [.text("This is a step.")]))], anchor: "section-2"),
        ])
        let tutorialReference = ResolvedTopicReference(bundleIdentifier: "org.swift.docc.example", path: "/TestTutorial", sourceLanguage: .swift)
        let indexingRecords = try tutorialSectionsSection.indexingRecords(onPage: tutorialReference, references: [:])
        XCTAssertEqual(2, indexingRecords.count)
        
        for i in 0...1 {
            let section = tutorialSectionsSection.tasks[i]
            let sectionReference = tutorialReference.withFragment(section.anchor)
            XCTAssertEqual(IndexingRecord(kind: .tutorialSection,
                                          location: .contained(sectionReference, inPage: tutorialReference),
                                          title: section.title,
                                          summary: "Hello, world!",
                                          headings: [],
                                          rawIndexableTextContent: "Hello, world! This is a step."),
                           indexingRecords[i])
        }
    }
    
    // MARK: - Article
    
    func testArticle() throws {
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        let articleReference = ResolvedTopicReference(bundleIdentifier: "org.swift.docc.example", path: "/tutorials/Test-Bundle/TestTutorialArticle", sourceLanguage: .swift)
        let node = try context.entity(with: articleReference)
        let article = node.semantic as! TutorialArticle
        var converter = RenderNodeTranslator(context: context, bundle: bundle, identifier: articleReference, source: context.documentURL(for: articleReference))
        let renderNode = converter.visit(article) as! RenderNode
        let indexingRecords = try renderNode.indexingRecords(onPage: articleReference)
        
        XCTAssertEqual(1, indexingRecords.count)
        
        XCTAssertEqual(IndexingRecord(kind: .article,
        							  location: .topLevelPage(articleReference),
                                      title: "Making an Augmented Reality App",
                                      summary: "This is an abstract for the intro.",
                                      headings: ["This is an H2", "A Section", "This is an H3"],
                                      rawIndexableTextContent: "This is an abstract for the intro. It can be multiple paragraphs. This is an H2 This is full width paragraph. Some paragraphs of text here.  You can customize a view’s display by changing your code, or by using the inspector to discover what’s available and to help you write code. As you build the Landmarks app, you can use any combination of editors: the source editor, the canvas, or the inspectors. Your code stays updated, regardless of which tool you use. You can customize a view’s display by changing your code, or by using the inspector to discover what’s available and to help you write code. As you build the Landmarks app, you can use any combination of editors: the source editor, the canvas, or the inspectors. Your code stays updated, regardless of which tool you use. Full width inbetween other layouts. You can customize a view’s display by changing your code, or by using the inspector to discover what’s available and to help you write code. As you build the Landmarks app, you can use any combination of editors: the source editor, the canvas, or the inspectors. Your code stays updated, regardless of which tool you use. You can customize a view’s display by changing your code, or by using the inspector to discover what’s available and to help you write code. As you build the Landmarks app, you can use any combination of editors: the source editor, the canvas, or the inspectors. Your code stays updated, regardless of which tool you use. A Section Some full width stuff. foo bar baz You can customize a view’s display by changing your code, or by using the inspector to discover what’s available and to help you write code. As you build the Landmarks app, you can use any combination of editors: the source editor, the canvas, or the inspectors. Your code stays updated, regardless of which tool you use.   Some more paragraphs. This is an H3 Some paragraphs."),
                       indexingRecords[0])
    }
    
    // MARK: - Inlines
    
    func testRenderInlineContentText() {
        let text = RenderInlineContent.text("Hello, world!")
        XCTAssertEqual([], text.headings)
        XCTAssertEqual("Hello, world!", text.rawIndexableTextContent(references: [:]))
    }
    
    func testRenderInlineContentStrong() {
        let strong = RenderInlineContent.strong(inlineContent: [.text("Hello, world!")])
        XCTAssertEqual([], strong.headings)
        XCTAssertEqual("Hello, world!", strong.rawIndexableTextContent(references: [:]))
    }
    
    func testRenderInlineContentReference() {
        let reference = RenderInlineContent.reference(identifier: .init("Test"), isActive: true, overridingTitle: "Hello, world!", overridingTitleInlineContent: [.text("Hello, world!")])
        XCTAssertEqual([], reference.headings)
        XCTAssertEqual("Hello, world!", reference.rawIndexableTextContent(references: [:]))
    }
    
    func testRenderInlineContentEmphasis() {
        let emphasis = RenderInlineContent.emphasis(inlineContent: [.text("Hello, world!")])
        XCTAssertEqual([], emphasis.headings)
        XCTAssertEqual("Hello, world!", emphasis.rawIndexableTextContent(references: [:]))
    }
    
    func testRenderInlineContentCodeVoice() {
        let codeVoice = RenderInlineContent.codeVoice(code: "Code voice.")
        XCTAssertEqual([], codeVoice.headings)
        XCTAssertEqual("Code voice.", codeVoice.rawIndexableTextContent(references: [:]))
    }
    
    // MARK: - Blocks
    
    func testRenderBlockContentUnorderedList() {
        let list = RenderBlockContent.unorderedList(.init(items: [
            .init(content: [
            .paragraph(.init(inlineContent: [.text("Hello, ")])),
                ]),
            .init(content: [
                .paragraph(.init(inlineContent: [.text("world!")])),
                ]),
            ]))
        XCTAssertEqual([], list.headings)
        XCTAssertEqual("Hello,  world!", list.rawIndexableTextContent(references: [:]))
    }
    
    func testRenderBlockContentStep() {
        let step = RenderBlockContent.step(.init(content: [.paragraph(.init(inlineContent: [.text("Hello, world!")]))], caption: [.paragraph(.init(inlineContent: [.text("Step caption")]))], media: RenderReferenceIdentifier("Media"), code: RenderReferenceIdentifier("Code"), runtimePreview: RenderReferenceIdentifier("Preview")))
        XCTAssertEqual([], step.headings)
        XCTAssertEqual("Hello, world! Step caption", step.rawIndexableTextContent(references: [:]))
    }
    
    func testRenderBlockContentParagraph() {
        let paragraph = RenderBlockContent.paragraph(.init(inlineContent: [.text("Hello, world!")]))
        XCTAssertEqual([], paragraph.headings)
        XCTAssertEqual("Hello, world!", paragraph.rawIndexableTextContent(references: [:]))
    }
    
    func testRenderBlockContentOrderedList() {
        let list = RenderBlockContent.orderedList(.init(items: [
            .init(content: [
                .paragraph(.init(inlineContent: [.text("Hello, ")])),
                ]),
            .init(content: [
                .paragraph(.init(inlineContent: [.text("world!")])),
                ]),
            ]))
        XCTAssertEqual([], list.headings)
        XCTAssertEqual("Hello,  world!", list.rawIndexableTextContent(references: [:]))
    }
    
    func testRenderBlockContentAside() {
        let aside = RenderBlockContent.aside(.init(style: .init(rawValue: "Experiment"), content: [.paragraph(.init(inlineContent: [.text("Hello, world!")]))]))
        XCTAssertEqual([], aside.headings)
        XCTAssertEqual("Hello, world!", aside.rawIndexableTextContent(references: [:]))
    }
    
    func testRootPageIndexingRecord() throws {
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        let articleReference = ResolvedTopicReference(bundleIdentifier: "org.swift.docc.example", path: "/documentation/MyKit", sourceLanguage: .swift)
        let node = try context.entity(with: articleReference)
        let article = node.semantic as! Symbol
        var converter = RenderNodeTranslator(context: context, bundle: bundle, identifier: articleReference, source: context.documentURL(for: articleReference))
        let renderNode = converter.visit(article) as! RenderNode
        let indexingRecords = try renderNode.indexingRecords(onPage: articleReference)
        
        XCTAssertEqual(1, indexingRecords.count)
        
        XCTAssertEqual(IndexingRecord(kind: .symbol,
                                      location: .topLevelPage(articleReference),
                                      title: "MyKit",
                                      summary: "MyKit module root symbol",
                                      headings: ["Discussion"],
                                      rawIndexableTextContent: "MyKit module root symbol Discussion MyKit is the best module"),
                       indexingRecords[0])
    }
    
    func testSymbolIndexingRecord() throws {
        let (_, bundle, context) = try testBundleAndContext(copying: "TestBundle") { url in
            // Modify the documentaion to have default availability for MyKit so that there is platform availability
            // information for MyProtocol (both in the render node and in the indexing record.
            let plistURL = url.appendingPathComponent("Info.plist")
            let plistData = try Data(contentsOf: plistURL)
            var plist = try DocumentationBundle.Info(from: plistData)
            let existingAvailability = plist.defaultAvailability?.modules["FillIntroduced"]
            plist.defaultAvailability?.modules["MyKit"] = existingAvailability
            XCTAssertNotNil(plist.defaultAvailability?.modules["MyKit"])
            
            let updatedPlistData = try PropertyListEncoder().encode(plist)
            try updatedPlistData.write(to: plistURL)
        }
        
        let articleReference = ResolvedTopicReference(bundleIdentifier: "org.swift.docc.example", path: "/documentation/MyKit/MyProtocol", sourceLanguage: .swift)
        let node = try context.entity(with: articleReference)
        let article = node.semantic as! Symbol
        var converter = RenderNodeTranslator(context: context, bundle: bundle, identifier: articleReference, source: context.documentURL(for: articleReference))
        let renderNode = converter.visit(article) as! RenderNode
        let indexingRecords = try renderNode.indexingRecords(onPage: articleReference)
        
        XCTAssertEqual(1, indexingRecords.count)
        let expectedPlatformInformation = renderNode.metadata.platforms
        XCTAssertNotNil(expectedPlatformInformation)
        
        XCTAssertEqual(IndexingRecord(kind: .symbol,
                                      location: .topLevelPage(articleReference),
                                      title: "MyProtocol",
                                      summary: "An abstract of a protocol using a String id value.",
                                      headings: ["Return Value", "Discussion"],
                                      rawIndexableTextContent: "An abstract of a protocol using a String id value.  A name of the item to find. Return Value A String id value. Discussion Further discussion. Exercise links to symbols: relative MyClass and absolute MyClass. Exercise unresolved symbols: unresolved MyUnresolvedSymbol. Exercise known unresolvable symbols: know unresolvable NSCodable. Exercise external references: doc://com.test.external/ExternalPage One ordered Two ordered Three ordered One unordered Two unordered Three unordered",
                                     platforms: expectedPlatformInformation),
                       indexingRecords[0])
    }
}
