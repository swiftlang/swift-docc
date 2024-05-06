/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
import SymbolKit
@testable import SwiftDocC
import Markdown
import SwiftDocCTestUtilities

func diffDescription(lhs: String, rhs: String) -> String {
    let leftLines = lhs.components(separatedBy: .newlines)
    let rightLines = rhs.components(separatedBy: .newlines)
    let difference = rightLines.difference(from: leftLines)
    return difference.diffDump
}

extension CollectionDifference {
    /// Dump a standard +/- diff line depending on the kind of edit.
    var diffDump: String {
        map { difference -> String in
            switch difference {
            case .insert(_, let element, _):
                return "+ \(element)"
            case .remove(_, let element, _):
                return "- \(element)"
            }
        }.joined(separator: "\n")
    }
}

class DocumentationContextTests: XCTestCase {
    func testResolve() throws {
        let workspace = DocumentationWorkspace()
        let context = try DocumentationContext(dataProvider: workspace)
        let bundle = try testBundle(named: "TestBundle")
        let dataProvider = PrebuiltLocalFileSystemDataProvider(bundles: [bundle])
        try workspace.registerProvider(dataProvider)
        
        // Test resolving
        let unresolved = UnresolvedTopicReference(topicURL: ValidatedURL(parsingExact: "doc:/TestTutorial")!)
        let parent = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "", sourceLanguage: .swift)
        
        guard case let .success(resolved) = context.resolve(.unresolved(unresolved), in: parent) else {
            XCTFail("Couldn't resolve \(unresolved)")
            return
        }
        
        XCTAssertEqual(parent.bundleIdentifier, resolved.bundleIdentifier)
        XCTAssertEqual("/tutorials/Test-Bundle/TestTutorial", resolved.path)
        
        // Test lowercasing of path
        let unresolvedUppercase = UnresolvedTopicReference(topicURL: ValidatedURL(parsingExact: "doc:/TESTTUTORIAL")!)
        guard case .failure = context.resolve(.unresolved(unresolvedUppercase), in: parent) else {
            XCTFail("Did incorrectly resolve \(unresolvedUppercase)")
            return
        }
        
        // Test expected URLs
        let expectedURL = URL(string: "doc://org.swift.docc.example/tutorials/Test-Bundle/TestTutorial")
        XCTAssertEqual(expectedURL, resolved.url)
        
        guard context.documentURL(for: resolved) != nil else {
            XCTFail("Couldn't resolve file URL for \(resolved)")
            return
        }
        
        try workspace.unregisterProvider(dataProvider)
        
        guard case .failure = context.resolve(.unresolved(unresolved), in: parent) else {
            XCTFail("Unexpectedly resolved \(unresolved.topicURL) despite removing a data provider for it")
            return
        }
    }
    
    func testLoadEntity() throws {
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        
        let identifier = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/tutorials/Test-Bundle/TestTutorial", sourceLanguage: .swift)
        
        XCTAssertThrowsError(try context.entity(with: ResolvedTopicReference(bundleIdentifier: "some.other.bundle", path: "/tutorials/Test-Bundle/TestTutorial", sourceLanguage: .swift)))
        
        XCTAssertThrowsError(try context.entity(with: ResolvedTopicReference(bundleIdentifier: "org.swift.docc.example", path: "/Test-Bundle/wrongIdentifier", sourceLanguage: .swift)))

        let node = try context.entity(with: identifier)
                
        // FIXME: The ranges for Link destination elements is offset by 2.
        
        let expectedDump = """
├─ BlockDirective name: "Tutorial"
│  ├─ Argument text segments:
│  |    "time: 20, projectFiles: project.zip"
│  ├─ BlockDirective name: "Comment"
│  │  └─ Paragraph
│  │     └─ Text "This is a comment."
│  ├─ BlockDirective name: "XcodeRequirement"
│  │  ├─ Argument text segments:
│  │  |    "title: \\"Xcode X.Y Beta Z\\", destination: \\"https://www.example.com/download\\" "
│  ├─ BlockDirective name: "Comment"
│  │  ├─ Paragraph
│  │  │  └─ Text "This is a comment."
│  │  ├─ Paragraph
│  │  │  └─ Text "This Intro should not get picked up."
│  │  └─ BlockDirective name: "Intro"
│  │     ├─ Argument text segments:
│  │     |    "title: \\"Basic Augmented Reality App\\""
│  │     ├─ Paragraph
│  │     │  └─ Text "This is the tutorial abstract."
│  │     ├─ BlockDirective name: "Comment"
│  │     │  └─ Paragraph
│  │     │     └─ Text "This is a comment."
│  │     └─ BlockDirective name: "Video"
│  │        ├─ Argument text segments:
│  │        |    "source: introvideo.mp4, poster: introposter.png "
│  ├─ BlockDirective name: "Intro"
│  │  ├─ Argument text segments:
│  │  |    "title: \\"Basic Augmented Reality App\\""
│  │  ├─ Paragraph
│  │  │  └─ Text "This is the tutorial abstract."
│  │  ├─ BlockDirective name: "Comment"
│  │  │  └─ Paragraph
│  │  │     └─ Text "This is a comment."
│  │  └─ BlockDirective name: "Video"
│  │     ├─ Argument text segments:
│  │     |    "source: introvideo.mp4, poster: introposter.png "
│  ├─ BlockDirective name: "Section"
│  │  ├─ Argument text segments:
│  │  |    "title: \\"Create a New AR Project 💻\\""
│  │  ├─ BlockDirective name: "ContentAndMedia"
│  │  │  ├─ Paragraph
│  │  │  │  ├─ Text "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt"
│  │  │  │  ├─ SoftBreak
│  │  │  │  ├─ Text "ut labore et dolore magna aliqua. Phasellus faucibus scelerisque eleifend donec pretium."
│  │  │  │  ├─ SoftBreak
│  │  │  │  ├─ Text "Ultrices dui sapien eget mi proin sed libero enim. Quis auctor elit sed vulputate mi sit amet."
│  │  │  │  ├─ SoftBreak
│  │  │  │  ├─ Text "This section link refers to this section itself: "
│  │  │  │  ├─ Link destination: "doc:/tutorials/Test-Bundle/TestTutorial#Create-a-New-AR-Project-%F0%9F%92%BB"
│  │  │  │  │  └─ Text "doc:/tutorials/Test-Bundle/TestTutorial#Create-a-New-AR-Project-%F0%9F%92%BB"
│  │  │  │  ├─ Text "."
│  │  │  │  ├─ SoftBreak
│  │  │  │  ├─ Text "This is an external link to Swift documentation: "
│  │  │  │  ├─ Link destination: "https://swift.org/documentation/"
│  │  │  │  │  └─ Text "Swift Documentation"
│  │  │  │  ├─ Text "."
│  │  │  │  ├─ SoftBreak
│  │  │  │  ├─ Text "This section link refers to the next section in this file: "
│  │  │  │  ├─ Link destination: "doc:/tutorials/Test-Bundle/TestTutorial#Initiate-ARKit-Plane-Detection"
│  │  │  │  │  └─ Text "doc:/tutorials/Test-Bundle/TestTutorial#Initiate-ARKit-Plane-Detection"
│  │  │  │  ├─ Text "."
│  │  │  │  ├─ SoftBreak
│  │  │  │  ├─ Text "This link will never resolve: "
│  │  │  │  ├─ Link destination: "doc:ThisWillNeverResolve"
│  │  │  │  │  └─ Text "doc:ThisWillNeverResolve"
│  │  │  │  ├─ Text "."
│  │  │  │  ├─ SoftBreak
│  │  │  │  ├─ Text "This link needs an external resolver: "
│  │  │  │  ├─ Link destination: "doc://com.test.external/path/to/external/symbol"
│  │  │  │  │  └─ Text "doc://com.test.external/path/to/external/symbol"
│  │  │  │  └─ Text "."
│  │  │  ├─ BlockDirective name: "Comment"
│  │  │  │  └─ Paragraph
│  │  │  │     └─ Text "This is a comment."
│  │  │  ├─ BlockQuote
│  │  │  │  └─ Paragraph
│  │  │  │     └─ Text "Note: This is a note."
│  │  │  ├─ BlockQuote
│  │  │  │  └─ Paragraph
│  │  │  │     └─ Text "Important: This is important."
│  │  │  ├─ BlockDirective name: "Image"
│  │  │  │  ├─ Argument text segments:
│  │  │  │  |    "source: figure1.png, alt: figure1 "
│  │  │  ├─ Paragraph
│  │  │  │  └─ Image source: "figure1"
│  │  │  ├─ Paragraph
│  │  │  │  └─ Image source: "images/figure1"
│  │  │  └─ Paragraph
│  │  │     └─ Text "Quis auctor elit sed vulputate mi sit amet."
│  │  ├─ BlockDirective name: "Comment"
│  │  │  └─ Paragraph
│  │  │     └─ Text "This is a comment."
│  │  └─ BlockDirective name: "Steps"
│  │     ├─ Paragraph
│  │     │  └─ Text "Let’s get started building the Augmented Reality app."
│  │     ├─ BlockDirective name: "Step"
│  │     │  ├─ Paragraph
│  │     │  │  └─ Text "Lorem ipsum dolor sit amet, consectetur."
│  │     │  └─ BlockDirective name: "Image"
│  │     │     ├─ Argument text segments:
│  │     │     |    "source: step.png, alt: step "
│  │     ├─ BlockDirective name: "Step"
│  │     │  ├─ Paragraph
│  │     │  │  └─ Text "Lorem ipsum dolor sit amet, consectetur."
│  │     │  ├─ BlockDirective name: "Comment"
│  │     │  │  └─ Paragraph
│  │     │  │     └─ Text "This is a comment."
│  │     │  ├─ Paragraph
│  │     │  │  └─ Text "This is a step caption."
│  │     │  └─ BlockDirective name: "Code"
│  │     │     ├─ Argument text segments:
│  │     │     |    "file: helloworld1.swift, name: MyCode.swift"
│  │     │     └─ BlockDirective name: "Image"
│  │     │        ├─ Argument text segments:
│  │     │        |    "source: step.png, alt: step "
│  │     ├─ BlockQuote
│  │     │  └─ Paragraph
│  │     │     └─ Text "Experiment: Do something cool."
│  │     ├─ BlockDirective name: "Step"
│  │     │  ├─ Paragraph
│  │     │  │  └─ Text "Lorem ipsum dolor sit amet, consectetur."
│  │     │  └─ BlockDirective name: "Code"
│  │     │     ├─ Argument text segments:
│  │     │     |    "file: helloworld2.swift, name: MyCode.swift"
│  │     │     └─ BlockDirective name: "Image"
│  │     │        ├─ Argument text segments:
│  │     │        |    "source: intro.png, alt: intro "
│  │     ├─ BlockDirective name: "Step"
│  │     │  ├─ Paragraph
│  │     │  │  └─ Text "Lorem ipsum dolor sit amet, consectetur."
│  │     │  └─ BlockDirective name: "Image"
│  │     │     ├─ Argument text segments:
│  │     │     |    "source: step.png, alt: step "
│  │     ├─ BlockDirective name: "Step"
│  │     │  ├─ Paragraph
│  │     │  │  └─ Text "Lorem ipsum dolor sit amet, consectetur."
│  │     │  └─ BlockDirective name: "Code"
│  │     │     ├─ Argument text segments:
│  │     │     |    "file: helloworld3.swift, name: MyCode.swift"
│  │     │     └─ BlockDirective name: "Image"
│  │     │        ├─ Argument text segments:
│  │     │        |    "source: titled2up.png, alt: titled2up "
│  │     └─ BlockDirective name: "Step"
│  │        ├─ Paragraph
│  │        │  └─ Text "Lorem ipsum dolor sit amet, consectetur."
│  │        └─ BlockDirective name: "Code"
│  │           ├─ Argument text segments:
│  │           |    "file: helloworld4.swift, name: MyCode.swift"
│  │           └─ BlockDirective name: "Image"
│  │              ├─ Argument text segments:
│  │              |    "source: titled2up.png, alt: titled2up "
│  ├─ BlockDirective name: "Section"
│  │  ├─ Argument text segments:
│  │  |    "title: \\"Initiate ARKit Plane Detection\\""
│  │  ├─ BlockDirective name: "Comment"
│  │  │  └─ Paragraph
│  │  │     └─ Text "This is a comment."
│  │  ├─ BlockDirective name: "ContentAndMedia"
│  │  │  ├─ Paragraph
│  │  │  │  ├─ Text "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt"
│  │  │  │  ├─ SoftBreak
│  │  │  │  ├─ Text "ut labore et dolore magna aliqua. Phasellus faucibus scelerisque eleifend donec pretium."
│  │  │  │  ├─ SoftBreak
│  │  │  │  ├─ Text "This section link refers to the previous section: "
│  │  │  │  ├─ Link destination: "doc:/tutorials/Test-Bundle/TestTutorial#Create-a-New-AR-Project-%F0%9F%92%BB"
│  │  │  │  │  └─ Text "doc:/tutorials/Test-Bundle/TestTutorial#Create-a-New-AR-Project-%F0%9F%92%BB"
│  │  │  │  ├─ Text "."
│  │  │  │  ├─ SoftBreak
│  │  │  │  ├─ Text "This section link refers to the first section in another tutorial: "
│  │  │  │  ├─ Link destination: "doc:/tutorials/Test-Bundle/TestTutorial2#Create-a-New-AR-Project"
│  │  │  │  │  └─ Text "doc:/tutorials/Test-Bundle/TestTutorial2#Create-a-New-AR-Project"
│  │  │  │  └─ Text "."
│  │  │  ├─ Paragraph
│  │  │  │  └─ Text "Ultrices dui sapien eget mi proin sed libero enim. Quis auctor elit sed vulputate mi sit amet."
│  │  │  └─ BlockDirective name: "Image"
│  │  │     ├─ Argument text segments:
│  │  │     |    "source: titled2up.png, alt: titled2up "
│  │  └─ BlockDirective name: "Steps"
│  │     ├─ Paragraph
│  │     │  └─ Text "Let’s get started building the Augmented Reality app."
│  │     ├─ BlockDirective name: "Step"
│  │     │  ├─ Paragraph
│  │     │  │  └─ Text "Lorem ipsum dolor sit amet, consectetur."
│  │     │  └─ BlockDirective name: "Image"
│  │     │     ├─ Argument text segments:
│  │     │     |    "source: xcode.png, alt: xcode "
│  │     ├─ BlockDirective name: "Step"
│  │     │  ├─ Paragraph
│  │     │  │  └─ Text "Lorem ipsum dolor sit amet, consectetur."
│  │     │  └─ BlockDirective name: "Video"
│  │     │     ├─ Argument text segments:
│  │     │     |    "source: app.mov "
│  │     └─ BlockDirective name: "Step"
│  │        ├─ Paragraph
│  │        │  └─ Text "Lorem ipsum dolor sit amet, consectetur."
│  │        └─ BlockDirective name: "Video"
│  │           ├─ Argument text segments:
│  │           |    "source: app2.mov "
│  ├─ BlockDirective name: "Section"
│  │  ├─ Argument text segments:
│  │  |    "title: \\"Duplicate\\""
│  │  ├─ BlockDirective name: "ContentAndMedia"
│  │  │  ├─ Paragraph
│  │  │  │  ├─ Text "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt"
│  │  │  │  ├─ SoftBreak
│  │  │  │  └─ Text "ut labore et dolore magna aliqua. Phasellus faucibus scelerisque eleifend donec pretium."
│  │  │  ├─ Paragraph
│  │  │  │  └─ Text "Ultrices dui sapien eget mi proin sed libero enim. Quis auctor elit sed vulputate mi sit amet."
│  │  │  └─ BlockDirective name: "Image"
│  │  │     ├─ Argument text segments:
│  │  │     |    "source: titled2up.png, alt: titled2up "
│  │  └─ BlockDirective name: "Steps"
│  │     ├─ Paragraph
│  │     │  └─ Text "Let’s get started building the Augmented Reality app."
│  │     └─ BlockDirective name: "Step"
│  │        ├─ Paragraph
│  │        │  └─ Text "Lorem ipsum dolor sit amet, consectetur."
│  │        └─ BlockDirective name: "Image"
│  │           ├─ Argument text segments:
│  │           |    "source: xcode.png, alt: xcode "
│  ├─ BlockDirective name: "Section"
│  │  ├─ Argument text segments:
│  │  |    "title: \\"Duplicate\\""
│  │  ├─ BlockDirective name: "ContentAndMedia"
│  │  │  ├─ Paragraph
│  │  │  │  ├─ Text "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt"
│  │  │  │  ├─ SoftBreak
│  │  │  │  └─ Text "ut labore et dolore magna aliqua. Phasellus faucibus scelerisque eleifend donec pretium."
│  │  │  ├─ Paragraph
│  │  │  │  └─ Text "Ultrices dui sapien eget mi proin sed libero enim. Quis auctor elit sed vulputate mi sit amet."
│  │  │  └─ BlockDirective name: "Image"
│  │  │     ├─ Argument text segments:
│  │  │     |    "source: titled2up.png, alt: titled2up "
│  │  └─ BlockDirective name: "Steps"
│  │     ├─ Paragraph
│  │     │  └─ Text "Let’s get started building the Augmented Reality app."
│  │     └─ BlockDirective name: "Step"
│  │        ├─ Paragraph
│  │        │  └─ Text "Lorem ipsum dolor sit amet, consectetur."
│  │        └─ BlockDirective name: "Image"
│  │           ├─ Argument text segments:
│  │           |    "source: xcode.png, alt: xcode "
│  ├─ BlockDirective name: "Assessments"
│  │  ├─ BlockDirective name: "Comment"
│  │  │  └─ Paragraph
│  │  │     └─ Text "This is a comment."
│  │  ├─ BlockDirective name: "MultipleChoice"
│  │  │  ├─ Paragraph
│  │  │  │  └─ Text "Lorem ipsum dolor sit amet?"
│  │  │  ├─ Paragraph
│  │  │  │  └─ Text "Phasellus faucibus scelerisque eleifend donec pretium."
│  │  │  ├─ Paragraph
│  │  │  │  └─ Image source: "something.png"
│  │  │  │     └─ Text "Diagram"
│  │  │  ├─ CodeBlock language: swift
│  │  │  │  let scene = ARSCNView()
│  │  │  │  let anchor = scene.anchor(for: node)
│  │  │  ├─ BlockDirective name: "Choice"
│  │  │  │  ├─ Argument text segments:
│  │  │  │  |    "isCorrect: true"
│  │  │  │  ├─ Paragraph
│  │  │  │  │  └─ InlineCode `anchor.hitTest(view)`
│  │  │  │  └─ BlockDirective name: "Justification"
│  │  │  │     └─ Paragraph
│  │  │  │        └─ Text "This is correct because it is."
│  │  │  ├─ BlockDirective name: "Choice"
│  │  │  │  ├─ Argument text segments:
│  │  │  │  |    "isCorrect: false"
│  │  │  │  ├─ Paragraph
│  │  │  │  │  └─ InlineCode `anchor.intersects(view)`
│  │  │  │  └─ BlockDirective name: "Justification"
│  │  │  │     └─ Paragraph
│  │  │  │        └─ Text "This is incorrect because it is."
│  │  │  └─ BlockDirective name: "Choice"
│  │  │     ├─ Argument text segments:
│  │  │     |    "isCorrect: false"
│  │  │     ├─ Paragraph
│  │  │     │  └─ InlineCode `anchor.intersects(view)`
│  │  │     └─ BlockDirective name: "Justification"
│  │  │        └─ Paragraph
│  │  │           └─ Text "This is incorrect because it is."
│  │  └─ BlockDirective name: "MultipleChoice"
│  │     ├─ Paragraph
│  │     │  └─ Text "Lorem ipsum dolor sit amet?"
│  │     ├─ Paragraph
│  │     │  └─ Text "Phasellus faucibus scelerisque eleifend donec pretium."
│  │     ├─ CodeBlock language: swift
│  │     │  let scene = ARSCNView()
│  │     │  let anchor = scene.anchor(for: node)
│  │     ├─ BlockDirective name: "Choice"
│  │     │  ├─ Argument text segments:
│  │     │  |    "isCorrect: true"
│  │     │  ├─ Paragraph
│  │     │  │  └─ InlineCode `anchor.hitTest(view)`
│  │     │  └─ BlockDirective name: "Justification"
│  │     │     └─ Paragraph
│  │     │        └─ Text "This is correct because it is."
│  │     ├─ BlockDirective name: "Choice"
│  │     │  ├─ Argument text segments:
│  │     │  |    "isCorrect: false"
│  │     │  ├─ Paragraph
│  │     │  │  └─ InlineCode `anchor.intersects(view)`
│  │     │  └─ BlockDirective name: "Justification"
│  │     │     └─ Paragraph
│  │     │        └─ Text "This is incorrect because it is."
│  │     └─ BlockDirective name: "Choice"
│  │        ├─ Argument text segments:
│  │        |    "isCorrect: false"
│  │        ├─ Paragraph
│  │        │  └─ InlineCode `anchor.intersects(view)`
│  │        └─ BlockDirective name: "Justification"
│  │           └─ Paragraph
│  │              └─ Text "This is incorrect because it is."
│  └─ BlockDirective name: "Image"
│     ├─ Argument text segments:
│     |    "source: introposter2.png, alt: \\"Titled 2-up\\" "
"""
        XCTAssertEqual(expectedDump, node.markup.debugDescription(), diffDescription(lhs: expectedDump, rhs: node.markup.debugDescription()))
    }
        
    func testThrowsErrorForMissingResource() throws {
        let workspace = DocumentationWorkspace()
        let context = try DocumentationContext(dataProvider: workspace)
        XCTAssertThrowsError(try context.resource(with: ResourceReference(bundleIdentifier: "com.example.missing", path: "/missing.swift")), "Expected requesting an unknown file to result in an error.")
    }

    func testThrowsErrorForQualifiedImagePaths() throws {
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        let id = bundle.identifier

        let figure = ResourceReference(bundleIdentifier: id, path: "figure1.jpg")
        let imageFigure = ResourceReference(bundleIdentifier: id, path: "images/figure1.jpg")

        XCTAssertNoThrow(try context.resource(with: figure), "\(figure.path) expected in \(bundle.displayName)")
        XCTAssertThrowsError(try context.resource(with: imageFigure), "Images should be registered (and referred to) by their name, not by their path.")
    }
    
    func testResourceExists() throws {
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        
        let existingImageReference = ResourceReference(
            bundleIdentifier: bundle.identifier,
            path: "introposter"
        )
        let nonexistentImageReference = ResourceReference(
            bundleIdentifier: bundle.identifier,
            path: "nonexistent-image"
        )
        XCTAssertTrue(
            context.resourceExists(with: existingImageReference),
            "\(existingImageReference.path) expected in \(bundle.displayName)"
        )
        XCTAssertFalse(
            context.resourceExists(with: nonexistentImageReference),
            "\(nonexistentImageReference.path) does not exist in \(bundle.displayName)"
        )
        
        let correctImageReference = ResourceReference(
            bundleIdentifier: bundle.identifier,
            path: "figure1.jpg"
        )
        let incorrectImageReference = ResourceReference(
            bundleIdentifier: bundle.identifier,
            path: "images/figure1.jpg"
        )
        XCTAssertTrue(
            context.resourceExists(with: correctImageReference),
            "\(correctImageReference.path) expected in \(bundle.displayName)"
        )
        XCTAssertFalse(
            context.resourceExists(with: incorrectImageReference),
            "Images are registered and referenced by name, not path."
        )
    }
    
    func testURLs() throws {
        let exampleDocumentation = Folder(name: "unit-test.docc", content: [
            Folder(name: "Symbols", content: []),
            Folder(name: "Resources", content: [
                // This whitespace and punctuation in this *file name* will be replaced by dashes in its identifier.
                // No content in this file result in identifiers.
                TextFile(name: "Technology file: with - whitespace, and_punctuation.tutorial", utf8Content: """
                @Tutorials(name: "Technology Name") {
                   @Intro(title: "Intro Title") {
                      @Video(source: introvideo.mp4, poster: introposter.png)
                      @Image(source: intro.png ,alt: "Intro alt text")
                   }

                   @Volume(name: "Volume_Section Title: with - various! whitespace, and/punctuation") {
                      The whiteapace and punctuation in the title above will be replaced with dashes in the volume's identifier.

                      @Chapter(name: "Chapter_Title: with - various! whitespace, and/punctuation") {
                         The whiteapace and punctuation in the name above will be replaced with dashes in the chapter's identifier.

                         @Image(source: image-name.png, alt: "Chapter image alt text")
                      }
                   }
                }
                """),
            ]),
            InfoPlist(displayName: "TestBundle", identifier: "com.test.example"),
        ])
        let tempURL = try createTemporaryDirectory()
        
        let bundleURL = try exampleDocumentation.write(inside: tempURL)

        // Parse this test content
        let workspace = DocumentationWorkspace()
        let context = try DocumentationContext(dataProvider: workspace)
        let dataProvider = try LocalFileSystemDataProvider(rootURL: bundleURL)
        try workspace.registerProvider(dataProvider)
        
        // Verify all the reference identifiers for this content
        XCTAssertEqual(context.knownIdentifiers.count, 3)
        let identifierPaths = context.knownIdentifiers.map { $0.path }.sorted(by: { lhs, rhs in lhs.count < rhs.count })
        XCTAssertEqual(identifierPaths, [
            // From the two file names
            "/tutorials/Technology-file:-with---whitespace,-and_punctuation",
            // From the volume's title and the chapter's names, appended to their technology's identifier
            "/tutorials/Technology-file:-with---whitespace,-and_punctuation/Volume_Section-Title:-with---various!-whitespace,-and/punctuation",
            "/tutorials/Technology-file:-with---whitespace,-and_punctuation/Volume_Section-Title:-with---various!-whitespace,-and/punctuation/Chapter_Title:-with---various!-whitespace,-and/punctuation"
        ])
    }
    
    func testRegisteredImages() throws {
        let workspace = DocumentationWorkspace()
        let context = try DocumentationContext(dataProvider: workspace)
        let bundle = try testBundle(named: "TestBundle")
        let dataProvider = PrebuiltLocalFileSystemDataProvider(bundles: [bundle])
        try workspace.registerProvider(dataProvider)
        
        let imagesRegistered = context
            .registeredImageAssets(forBundleID: bundle.identifier)
            .flatMap { $0.variants.map { $0.value.lastPathComponent } }
            .sorted()
        
        XCTAssertEqual(
            [
                "figure1.jpg",
                "figure1.png",
                "figure1~dark.png",
                "intro.png",
                "introposter.png",
                "introposter2.png",
                "something@2x.png",
                "step.png",
                "titled2up.png",
                "titled2upCapital.PNG",
                "with spaces.png",
                "with spaces@2x.png",
            ],
            imagesRegistered.sorted()
        )
    }
    
    func testExternalAssets() throws {
        let workspace = DocumentationWorkspace()
        let context = try DocumentationContext(dataProvider: workspace)
        let bundle = try testBundle(named: "TestBundle")
        
        let image = context.resolveAsset(named: "https://example.com/figure.png", in: bundle.rootReference)
        XCTAssertNotNil(image)
        guard let image else {
            return
        }
        XCTAssertEqual(image.context, .display)
        XCTAssertEqual(image.variants, [DataTraitCollection(userInterfaceStyle: .light, displayScale: .standard): URL(string: "https://example.com/figure.png")!])
        
        let video = context.resolveAsset(named: "https://example.com/introvideo.mp4", in: bundle.rootReference)
        XCTAssertNotNil(video)
        guard let video else { return }
        XCTAssertEqual(video.context, .display)
        XCTAssertEqual(video.variants, [DataTraitCollection(userInterfaceStyle: .light, displayScale: .standard): URL(string: "https://example.com/introvideo.mp4")!])
    }
    
    func testDownloadAssets() throws {
        let workspace = DocumentationWorkspace()
        let context = try DocumentationContext(dataProvider: workspace)
        let bundle = try testBundle(named: "TestBundle")
        let dataProvider = PrebuiltLocalFileSystemDataProvider(bundles: [bundle])
        try workspace.registerProvider(dataProvider)

        let downloadsBefore = context.registeredDownloadsAssets(forBundleID: bundle.identifier)
        XCTAssertEqual(downloadsBefore.count, 1)
        XCTAssertEqual(downloadsBefore.first?.variants.values.first?.lastPathComponent, "project.zip")
        
        guard var assetOriginal = context
            .registeredImageAssets(forBundleID: bundle.identifier)
            .first(where: { asset -> Bool in
                return asset.variants.values.first(where: { url -> Bool in
                    return url.path.contains("intro.png")
                }) != nil
            }) else {
            XCTFail("Failed to find the required registered image")
            return
        }
        
        // Update the asset.
        assetOriginal.context = .download
        context.updateAsset(named: "intro.png", asset: assetOriginal, in: bundle.rootReference)
        
        guard let assetUpdated = context
            .registeredImageAssets(forBundleID: bundle.identifier)
            .first(where: { asset -> Bool in
                return asset.variants.values.first(where: { url -> Bool in
                    return url.path.contains("intro.png")
                }) != nil
            }) else {
            XCTFail("Failed to find the required registered image")
            return
        }
        
        // Verify we got back the updated asset.
        XCTAssertEqual(assetUpdated.context, .download)
        
        // Verify the asset is accessible in the downloads collection.
        var downloadsAfter = context.registeredDownloadsAssets(forBundleID: bundle.identifier)
        XCTAssertEqual(downloadsAfter.count, 2)
        downloadsAfter.removeAll(where: { $0.variants.values.first?.lastPathComponent == "project.zip" })
        XCTAssertEqual(downloadsAfter.count, 1)
        XCTAssertEqual(downloadsAfter.first?.variants.values.first?.lastPathComponent, "intro.png")
    }

    func testCreatesCorrectIdentifiers() throws {
        let testBundleLocation = Bundle.module.url(
            forResource: "TestBundle", withExtension: "docc", subdirectory: "Test Bundles")!
        let workspaceContent = Folder(name: "TestWorkspace", content: [
            CopyOfFolder(original: testBundleLocation),
            
            Folder(name: "TestBundle2.docc", content: [
                InfoPlist(displayName: "Test Bundle", identifier: "com.example.bundle2"),
                CopyOfFolder(original: testBundleLocation, newName: "Subfolder", filter: { $0.lastPathComponent != "Info.plist" }),
            ])
        ])
        
        let tempURL = try createTemporaryDirectory()
        
        let workspaceURL = try workspaceContent.write(inside: tempURL)
        let dataProvider = try LocalFileSystemDataProvider(rootURL: workspaceURL)

        let workspace = DocumentationWorkspace()
        try workspace.registerProvider(dataProvider)
        
        let context = try DocumentationContext(dataProvider: workspace)
        let identifiers = context.knownIdentifiers
        let identifierSet = Set(identifiers)
        XCTAssertEqual(identifiers.count, identifierSet.count, "Found duplicate identifiers.")
    }
    
    func testDetectsReferenceCollision() throws {
        let (_, context) = try testBundleAndContext(named: "TestBundleWithDupe")

        let problemWithDuplicate = context.problems.filter { $0.diagnostic.identifier == "org.swift.docc.DuplicateReference" }

        XCTAssertEqual(problemWithDuplicate.count, 1)

        let localizedSummary = try XCTUnwrap(problemWithDuplicate.first?.diagnostic.summary)
        XCTAssertEqual(localizedSummary, "Redeclaration of 'TestTutorial.tutorial'; this file will be skipped")

    }
    
    func testDetectsMultipleMDfilesWithSameName() throws {
        let (_, context) = try testBundleAndContext(named: "TestBundleWithDupMD")

        let problemWithDuplicateReference = context.problems.filter { $0.diagnostic.identifier == "org.swift.docc.DuplicateReference" }

        XCTAssertEqual(problemWithDuplicateReference.count, 2)

        let localizedSummary = try XCTUnwrap(problemWithDuplicateReference.first?.diagnostic.summary)
        XCTAssertEqual(localizedSummary, "Redeclaration of \'overview.md\'; this file will be skipped")

        let localizedSummarySecond = try XCTUnwrap(problemWithDuplicateReference[1].diagnostic.summary)
        XCTAssertEqual(localizedSummarySecond, "Redeclaration of \'overview.md\'; this file will be skipped")
    }
    
    func testUsesMultipleDocExtensionFilesWithSameName() throws {
        
        // Generate 2 different symbols with the same name.
        let someSymbol = makeSymbol(name: "MyEnum", identifier: "someEnumSymbol-id", kind: .init(rawValue: "enum"), pathComponents: ["SomeDirectory", "MyEnum"])
        let anotherSymbol = makeSymbol(name: "MyEnum", identifier: "anotherEnumSymbol-id", kind: .init(rawValue: "enum"), pathComponents: ["AnotherDirectory", "MyEnum"])
        let symbols: [SymbolGraph.Symbol] = [someSymbol, anotherSymbol]
        
        // Create a catalog with doc extension files with the same filename for each symbol.
        let tempURL = try createTempFolder(content: [
            Folder(name: "unit-test.docc", content: [
                JSONFile(name: "ModuleName.symbols.json", content: makeSymbolGraph(
                    moduleName: "ModuleName",
                    symbols: symbols
                )),
                
                Folder(name: "SomeDirectory", content: [
                    TextFile(name: "MyEnum.md", utf8Content:
                        """
                        # ``SomeDirectory/MyEnum``
                        
                        A documentation extension for my enum.
                        """
                    )
                ]),
                
                Folder(name: "AnotherDirectory", content: [
                    TextFile(name: "MyEnum.md", utf8Content:
                        """
                        # ``AnotherDirectory/MyEnum``
                        
                        A documentation extension for an unrelated enum.
                        """
                    )
                ]),
                
                // An unrelated article that happens to have the same filename
                TextFile(name: "MyEnum.md", utf8Content:
                    """
                    # MyEnum
                    
                    Here is a regular article about MyEnum.
                    """
                )
            ])
        ])
        
        let (_, _, context) = try loadBundle(from: tempURL)

        // Since documentation extensions' filenames have no impact on the URL of pages, we should not see warnings enforcing unique filenames for them.
        let problemWithDuplicateReference = context.problems.filter { $0.diagnostic.identifier == "org.swift.docc.DuplicateReference" }
        XCTAssertEqual(problemWithDuplicateReference.count, 0)
        
        // Ensure the content from both documentation extensions was used.
        let someEnumNode = try XCTUnwrap(context.documentationCache["someEnumSymbol-id"])
        let someEnumSymbol = try XCTUnwrap(someEnumNode.semantic as? Symbol)
        XCTAssertEqual(someEnumSymbol.abstract?.plainText, "A documentation extension for my enum.", "The abstract should be from the symbol's documentation extension.")
        
        let anotherEnumNode = try XCTUnwrap(context.documentationCache["anotherEnumSymbol-id"])
        let anotherEnumSymbol = try XCTUnwrap(anotherEnumNode.semantic as? Symbol)
        XCTAssertEqual(anotherEnumSymbol.abstract?.plainText, "A documentation extension for an unrelated enum.", "The abstract should be from the symbol's documentation extension.")
    }

    func testGraphChecks() throws {
        let workspace = DocumentationWorkspace()
        let context = try DocumentationContext(dataProvider: workspace)
        context.addGlobalChecks([{ (context, reference) -> [Problem] in
            return [Problem(diagnostic: Diagnostic(source: reference.url, severity: DiagnosticSeverity.error, range: nil, identifier: "com.tests.testGraphChecks", summary: "test error"), possibleSolutions: [])]
        }])
        let bundle = try testBundle(named: "TestBundle")
        let dataProvider = PrebuiltLocalFileSystemDataProvider(bundles: [bundle])
        try workspace.registerProvider(dataProvider)
        
        /// Checks if the custom check added problems to the context.
        let testProblems = context.problems.filter({ (problem) -> Bool in
            return problem.diagnostic.identifier == "com.tests.testGraphChecks"
        })
        XCTAssertTrue(!testProblems.isEmpty)
    }
    
    func testSupportedAssetTypes() throws {
        for ext in ["jpg", "jpeg", "png", "JPG", "PNG", "PnG", "jPg", "svg", "gif"] {
            XCTAssertTrue(DocumentationContext.isFileExtension(ext, supported: .image))
        }
        for ext in ["", "aaa", "cookie", "test"] {
            XCTAssertFalse(DocumentationContext.isFileExtension(ext, supported: .image))
        }
        for ext in ["mov", "mp4", "MOV", "Mp4"] {
            XCTAssertTrue(DocumentationContext.isFileExtension(ext, supported: .video))
        }
        for ext in ["", "aaa", "cookie", "test"] {
            XCTAssertFalse(DocumentationContext.isFileExtension(ext, supported: .video))
        }
    }
    
    func testIgnoresUnknownMarkupFiles() throws {
        let testBundle = Folder(name: "TestIgnoresUnknownMarkupFiles.docc", content: [
            InfoPlist(displayName: "TestIgnoresUnknownMarkupFiles", identifier: "com.example.documentation"),
            Folder(name: "Resources", content: [
                TextFile(name: "Article1.tutorial", utf8Content: "@Article"),
                TextFile(name: "Article2.md", utf8Content: "notvalid"),
            ])
        ])
        
        let tempURL = try createTemporaryDirectory()
        let bundleURL = try testBundle.write(inside: tempURL)

        let workspace = DocumentationWorkspace()
        let context = try DocumentationContext(dataProvider: workspace)
        let dataProvider = try LocalFileSystemDataProvider(rootURL: bundleURL)
        try workspace.registerProvider(dataProvider)
        
        XCTAssertEqual(context.knownPages.map { $0.path }, ["/tutorials/TestIgnoresUnknownMarkupFiles/Article1"])
        XCTAssertTrue(context.problems.map { $0.diagnostic.identifier }.contains("org.swift.docc.Article.Title.NotFound"))
    }
    
    func testLoadsSymbolData() throws {
        let testBundle = Folder(name: "TestIgnoresUnknownMarkupFiles.docc", content: [
            InfoPlist(displayName: "TestIgnoresUnknownMarkupFiles", identifier: "com.example.documentation"),
            Folder(name: "Resources", content: [
                CopyOfFile(original: Bundle.module.url(
                    forResource: "TestBundle", withExtension: "docc", subdirectory: "Test Bundles")!
                    .appendingPathComponent("documentation")
                    .appendingPathComponent("myprotocol.md")),
            ]),
            Folder(name: "Symbols", content: [
                CopyOfFile(original: Bundle.module.url(
                    forResource: "TestBundle", withExtension: "docc", subdirectory: "Test Bundles")!
                    .appendingPathComponent("mykit-iOS.symbols.json")),
            ])
        ])
        
        let tempURL = try createTemporaryDirectory()
        let bundleURL = try testBundle.write(inside: tempURL)

        let workspace = DocumentationWorkspace()
        let context = try DocumentationContext(dataProvider: workspace)
        let dataProvider = try LocalFileSystemDataProvider(rootURL: bundleURL)
        try workspace.registerProvider(dataProvider)
        
        // Symbols are loaded
        XCTAssertFalse(context.documentationCache.isEmpty)
        
        // MyClass is loaded
        guard let myClass = context.documentationCache["s:5MyKit0A5ClassC"] else {
            XCTFail("`MyClass` not found in symbol graph")
            return
        }
        
        //
        // Test the MyClass documentation node
        //
        let markupModel = DocumentationMarkup(markup: myClass.markup)
        
        XCTAssertEqual(myClass.name.description, "MyClass")
        XCTAssertEqual(myClass.reference.absoluteString, "doc://com.example.documentation/documentation/MyKit/MyClass")
        XCTAssertNil(markupModel.abstractSection)
        XCTAssertNil(markupModel.discussionSection)
        XCTAssertNil(markupModel.seeAlsoSection)
        XCTAssertEqual(myClass.kind, DocumentationNode.Kind.class)
        XCTAssertEqual(myClass.sourceLanguage, SourceLanguage.swift)
        
        // Verify topics are empty
        XCTAssertNil(markupModel.topicsSection)
        XCTAssertNil(markupModel.seeAlsoSection)
        
        XCTAssertTrue(myClass.semantic is Symbol)
        guard let myClassSymbol = myClass.semantic as? Symbol else { return }
        
        //
        // Test the MyClass Symbol
        //

        // The two types are equatable but XCTAssertEqual doesn't catch that.
        XCTAssertTrue(myClassSymbol.kind.identifier == SymbolGraph.Symbol.KindIdentifier.class)
        XCTAssertNotNil(myClassSymbol.availability?.availability.first(where: { (availability) -> Bool in
            if let domain = availability.domain, let introduced = availability.introducedVersion, domain.rawValue == "macOS", introduced.major == 10, introduced.minor == 15 {
                return true
            }
            return false
        }))
        
        XCTAssertEqual(Array(myClassSymbol.declaration.keys), [[PlatformName(operatingSystemName: "ios")]])
        XCTAssertEqual(myClassSymbol.declaration[[PlatformName(operatingSystemName: "ios")]]?.declarationFragments.map { $0.spelling }.joined(), "class MyClass")
        XCTAssertEqual(myClassSymbol.moduleReference.absoluteString, "doc://com.example.documentation/documentation/MyKit")
        XCTAssertTrue(myClassSymbol.relationships.groups.contains { group -> Bool in
            return group.kind == .conformsTo && Array(group.destinations.map({ $0.url?.absoluteString })) == ["doc://com.example.documentation/documentation/MyKit/MyProtocol"]
        })
        XCTAssertEqual(myClassSymbol.platformName, PlatformName(operatingSystemName: "ios"))
        XCTAssertEqual(myClassSymbol.roleHeading, "Class")
        XCTAssertEqual(myClassSymbol.title, "MyClass")
        
        //
        // Test MyClass' children
        //
        
        let functionChildrenRefs = context.children(of: myClass.reference)
        
        // Find a match with the specific path as `functionChildrenRefs` order is random.
        guard let childReference = functionChildrenRefs.first(where: { $0.reference.path == "/documentation/MyKit/MyClass/myFunction()" })?.reference else {
            XCTFail("No children found of MyClass")
            return
        }
        
        guard let parent = context.parents(of: childReference).first else {
            XCTFail("No parent found for myFunction()")
            return
        }
        XCTAssertTrue(parent.path.hasSuffix("MyKit/MyClass"))
        
        //
        // Test sidecar documentation
        //
        
        // MyProtocol is loaded
        guard let myProtocol = context.documentationCache["s:5MyKit0A5ProtocolP"],
            let myProtocolSymbol = myProtocol.semantic as? Symbol else {
            XCTFail("`MyProtocol` not found in symbol graph")
            return
        }
        
        XCTAssertEqual(myProtocolSymbol.title, "MyProtocol")
        XCTAssertEqual(myProtocolSymbol.abstractSection?.content.map { $0.detachedFromParent.debugDescription() }.joined(separator: "\n"),
                       """
                       Text "An abstract of a protocol using a "
                       InlineCode `String`
                       Text " id value."
                       """)


        XCTAssertEqual(myProtocolSymbol.discussion?.content.map { $0.detachedFromParent.debugDescription() }.joined(separator: "\n\n"),
                        """
                        Heading level: 2
                        └─ Text "Discussion"

                        Paragraph
                        └─ Text "Further discussion."

                        Paragraph
                        ├─ Text "Exercise links to symbols: relative "
                        ├─ SymbolLink destination: doc://com.example.documentation/documentation/MyKit/MyClass
                        ├─ Text " and absolute "
                        ├─ SymbolLink destination: doc://com.example.documentation/documentation/MyKit/MyClass
                        └─ Text "."

                        Paragraph
                        ├─ Text "Exercise unresolved symbols: unresolved "
                        ├─ SymbolLink destination: MyUnresolvedSymbol
                        └─ Text "."

                        Paragraph
                        ├─ Text "Exercise known unresolvable symbols: know unresolvable "
                        ├─ SymbolLink destination: NSCodable
                        └─ Text "."

                        Paragraph
                        ├─ Text "Exercise external references: "
                        └─ Link destination: "doc://com.test.external/ExternalPage"
                           └─ Text "doc://com.test.external/ExternalPage"

                        OrderedList
                        ├─ ListItem
                        │  └─ Paragraph
                        │     └─ Text "One ordered"
                        ├─ ListItem
                        │  └─ Paragraph
                        │     └─ Text "Two ordered"
                        └─ ListItem
                           └─ Paragraph
                              └─ Text "Three ordered"

                        UnorderedList
                        ├─ ListItem
                        │  └─ Paragraph
                        │     └─ Text "One unordered"
                        ├─ ListItem
                        │  └─ Paragraph
                        │     └─ Text "Two unordered"
                        └─ ListItem
                           └─ Paragraph
                              └─ Text "Three unordered"

                        OrderedList startIndex: 2
                        ├─ ListItem
                        │  └─ Paragraph
                        │     └─ Text "Two ordered with custom start"
                        ├─ ListItem
                        │  └─ Paragraph
                        │     └─ Text "Three ordered with custom start"
                        └─ ListItem
                           └─ Paragraph
                              └─ Text "Four ordered with custom start"
                        """)

        XCTAssertEqual(myProtocolSymbol.declaration.values.first?.declarationFragments.map({ $0.spelling }), ["protocol", " ", "MyProtocol", " : ", "Hashable"])
        XCTAssertEqual(myProtocolSymbol.declaration.values.first?.declarationFragments.map({ $0.preciseIdentifier }), [nil, nil, nil, nil, "p:hPP"])

        XCTAssertEqual(myProtocolSymbol.topics?.taskGroups.first?.heading?.detachedFromParent.debugDescription(),
                        """
                        Heading level: 3
                        └─ Text "Task Group Exercising Symbol Links"
                        """)
        XCTAssertEqual(myProtocolSymbol.topics?.taskGroups.first?.links.count, 3)
        XCTAssertEqual(myProtocolSymbol.topics?.taskGroups.first?.links[0].destination, "doc://com.example.documentation/documentation/MyKit/MyClass")
        XCTAssertEqual(myProtocolSymbol.topics?.taskGroups.first?.links[1].destination, "doc://com.example.documentation/documentation/MyKit/MyClass")
        XCTAssertEqual(myProtocolSymbol.topics?.taskGroups.first?.links[2].destination, "doc://com.example.documentation/documentation/MyKit/MyClass")

        XCTAssertEqual(myProtocolSymbol.seeAlso?.taskGroups.first?.heading?.detachedFromParent.debugDescription(),
        """
        Heading level: 3
        └─ Text "Related Documentation"
        """)
        XCTAssertEqual(myProtocolSymbol.seeAlso?.taskGroups.first?.links.count, 5)
        XCTAssertEqual(myProtocolSymbol.seeAlso?.taskGroups.first?.links.first?.destination, "doc://com.example.documentation/documentation/MyKit/MyClass")

        XCTAssertEqual(myProtocolSymbol.returnsSection?.content.map { $0.detachedFromParent.debugDescription() }.joined(separator: "\n"),
                       """
                       Paragraph
                       ├─ Text "A "
                       ├─ InlineCode `String`
                       └─ Text " id value."
                       """)

        XCTAssertEqual(myProtocolSymbol.parametersSection?.parameters.first?.contents.map { $0.detachedFromParent.debugDescription() }.joined(separator: "\n"),
                       """
                       Paragraph
                       └─ Text "A name of the item to find."
                       """)

        //
        // Test doc comments are parsed correctly
        //
        
        guard let functionSymbol = try context.entity(with: childReference).semantic as? Symbol else {
            XCTFail("myFunction() not resolved")
            return
        }
        
        XCTAssertEqual(functionSymbol.abstractSection?.content.map { $0.detachedFromParent.debugDescription() }.joined(separator: "\n"),
                       """
                       Text "A cool API to call."
                       """)
        XCTAssertEqual(functionSymbol.discussion?.content.isEmpty, true)
        guard let parameter = functionSymbol.parametersSection?.parameters.first else {
            XCTFail("myFunction() parameter not found")
            return
        }
        XCTAssertEqual(parameter.name, "name")
        XCTAssertEqual(parameter.contents.map { $0.detachedFromParent.debugDescription() }.joined(separator: "\n"),
                       """
                       Paragraph
                       └─ Text "A parameter"
                       """)
        XCTAssertEqual(functionSymbol.returnsSection?.content.map { $0.detachedFromParent.debugDescription() }.joined(separator: "\n"),
                       """
                       Paragraph
                       └─ Text "Return value"
                       """)
    }
    
    func testMergesMultipleSymbolDeclarations() throws {
        let graphContentiOS = try String(contentsOf: Bundle.module.url(
            forResource: "TestBundle", withExtension: "docc", subdirectory: "Test Bundles")!
            .appendingPathComponent("mykit-iOS.symbols.json"))

        let graphContentmacOS = graphContentiOS
            .replacingOccurrences(of: "\"name\" : \"ios\"", with: "\"name\" : \"macosx\"")

        let graphContenttvOS = graphContentiOS
            .replacingOccurrences(of: "\"name\" : \"ios\"", with: "\"name\" : \"tvos\"")
            .replacingOccurrences(of: "\"spelling\" : \"MyClass\"", with: "\"spelling\" : \"MyClassTV\"")
        
        let testBundle = Folder(name: "TestIgnoresUnknownMarkupFiles.docc", content: [
            InfoPlist(displayName: "TestIgnoresUnknownMarkupFiles", identifier: "com.example.documentation"),
            Folder(name: "Symbols", content: [
                TextFile(name: "mykit-iOS.symbols.json", utf8Content: graphContentiOS),
                TextFile(name: "mykit-macOS.symbols.json", utf8Content: graphContentmacOS),
                TextFile(name: "mykit-tvOS.symbols.json", utf8Content: graphContenttvOS),
            ]),
        ])
        
        let tempURL = try createTemporaryDirectory()
        let bundleURL = try testBundle.write(inside: tempURL)

        let workspace = DocumentationWorkspace()
        let context = try DocumentationContext(dataProvider: workspace)
        let dataProvider = try LocalFileSystemDataProvider(rootURL: bundleURL)
        try workspace.registerProvider(dataProvider)
        
        // MyClass is loaded
        guard let myClass = context.documentationCache["s:5MyKit0A5ClassC"],
            let myClassSymbol = myClass.semantic as? Symbol else {
            XCTFail("`MyClass` not found in symbol graph")
            return
        }
        
        // Test that the declarations are grouped correctly
        XCTAssertNotNil(myClassSymbol.declaration[[PlatformName(operatingSystemName: "tvos")]])
        
        // The order of the platforms is not guaranteed.
        XCTAssertNotNil(myClassSymbol.declaration[[PlatformName(operatingSystemName: "ios"), PlatformName(operatingSystemName: "macos")]] ?? myClassSymbol.declaration[[PlatformName(operatingSystemName: "macos"), PlatformName(operatingSystemName: "ios")]])
    }
    
    func testMergedMultipleSymbolDeclarationsIncludesPlatformSpecificSymbols() throws {
        let iOSGraphURL = Bundle.module.url(
            forResource: "TestBundle", withExtension: "docc", subdirectory: "Test Bundles")!
            .appendingPathComponent("mykit-iOS.symbols.json")
        let graphContentiOS = try String(contentsOf: iOSGraphURL)

        var graph = try JSONDecoder().decode(SymbolGraph.self, from: Data(contentsOf: iOSGraphURL))
        // Remove the original MyClass symbol
        let myFunctionSymbolPreciseIdentifier = "s:5MyKit0A5ClassC10myFunctionyyF"
        guard let myFunctionSymbol = graph.symbols.removeValue(forKey: myFunctionSymbolPreciseIdentifier) else {
            XCTFail("`myFunction` not found in iOS symbol graph")
            return
        }
        
        // Add a modified PlatformSpecificFunctionSymbolPreciseIdentifier symbol
        var myPlatformSpecificFunctionSymbol = myFunctionSymbol
        let myplatformSpecificFunctionName = "myPlatformSpecificFunction"
        myPlatformSpecificFunctionSymbol.names.title = myplatformSpecificFunctionName
        myPlatformSpecificFunctionSymbol.identifier.precise = "s:5MyKit0A\(myplatformSpecificFunctionName.count)\(myplatformSpecificFunctionName)C"
        
        graph.symbols[myPlatformSpecificFunctionSymbol.identifier.precise] = myPlatformSpecificFunctionSymbol
        
        // Change the graph platform
        graph.module = SymbolGraph.Module(
            name: graph.module.name,
            platform: .init(architecture: "x86_64", vendor: "apple", operatingSystem: .init(name: "macos")),
            version: .init(major: 10, minor: 15, patch: 0)
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let newGraphContent = try String(data: encoder.encode(graph), encoding: .utf8)!
        
        let testBundle = Folder(name: "TestIgnoresUnknownMarkupFiles.docc", content: [
            InfoPlist(displayName: "TestIgnoresUnknownMarkupFiles", identifier: "com.example.documentation"),
            Folder(name: "Symbols", content: [
                TextFile(name: "mykit-iOS.symbols.json", utf8Content: graphContentiOS),
                TextFile(name: "mykit-macOS.symbols.json", utf8Content: newGraphContent),
            ])
        ])
        
        let tempURL = try createTemporaryDirectory()
        let bundleURL = try testBundle.write(inside: tempURL)
        
        let workspace = DocumentationWorkspace()
        let context = try DocumentationContext(dataProvider: workspace)
        let dataProvider = try LocalFileSystemDataProvider(rootURL: bundleURL)
        try workspace.registerProvider(dataProvider)
        
        // MyFunction is loaded
        XCTAssertNotNil(context.documentationCache[myFunctionSymbolPreciseIdentifier], "myFunction which only exist on iOS should be found in the graph")
        XCTAssertNotNil(context.documentationCache[myPlatformSpecificFunctionSymbol.identifier.precise], "The new platform specific function should be found in the graph")
        
        XCTAssertEqual(
            context.documentationCache.count,
            graph.symbols.count + 1 /* for the module */ + 1 /* for the new platform specific function */,
            "Together the two graphs contain one symbol more than they do individually"
        )
    }
    
    func testResolvesSymbolsBetweenSymbolGraphs() throws {
        let testBundle = Folder(name: "CrossGraphResolving.docc", content: [
            InfoPlist(displayName: "CrossGraphResolving", identifier: "com.example.documentation"),
            Folder(name: "Resources", content: [
            ]),
            Folder(name: "Symbols", content: [
                CopyOfFile(original: Bundle.module.url(
                    forResource: "TestBundle", withExtension: "docc", subdirectory: "Test Bundles")!
                    .appendingPathComponent("mykit-iOS.symbols.json")),
                CopyOfFile(original: Bundle.module.url(
                    forResource: "TestBundle", withExtension: "docc", subdirectory: "Test Bundles")!
                    .appendingPathComponent("sidekit.symbols.json")),
            ])
        ])
        
        let tempURL = try createTemporaryDirectory()
        let bundleURL = try testBundle.write(inside: tempURL)

        let workspace = DocumentationWorkspace()
        let context = try DocumentationContext(dataProvider: workspace)
        let dataProvider = try LocalFileSystemDataProvider(rootURL: bundleURL)
        try workspace.registerProvider(dataProvider)
        
        // SideClass is loaded
        guard let sideClass = context.documentationCache["s:7SideKit0A5ClassC"],
            let sideClassSymbol = sideClass.semantic as? Symbol else {
            XCTFail("`SideClass` not found in symbol graph")
            return
        }
        
        // Test that the relationship has been resolved correctly
        XCTAssertNotNil(sideClassSymbol.relationships.groups.first { (group) -> Bool in
            return group.kind == .conformsTo && group.destinations.map({ $0.url?.absoluteString }) == ["doc://com.example.documentation/documentation/MyKit/MyProtocol"]
        })
    }

    func testLoadsDeclarationWithNoOS() throws {
        var graphContentiOS = try String(contentsOf: Bundle.module.url(
            forResource: "TestBundle", withExtension: "docc", subdirectory: "Test Bundles")!
            .appendingPathComponent("mykit-iOS.symbols.json"))
        
        // "remove" the operating system information
        graphContentiOS = graphContentiOS.replacingOccurrences(of: "\"operatingSystem\"", with: "\"ignored\"")
        
        let testBundle = Folder(name: "NoOSDeclaration.docc", content: [
            InfoPlist(displayName: "NoOSDeclaration", identifier: "com.example.documentation"),
            Folder(name: "Resources", content: []),
            Folder(name: "Symbols", content: [
                TextFile(name: "mykit-iOS.symbols.json", utf8Content: graphContentiOS),
            ])
        ])
        
        let tempURL = try createTemporaryDirectory()
        let bundleURL = try testBundle.write(inside: tempURL)

        let workspace = DocumentationWorkspace()
        let context = try DocumentationContext(dataProvider: workspace)
        let dataProvider = try LocalFileSystemDataProvider(rootURL: bundleURL)
        try workspace.registerProvider(dataProvider)
        
        // MyClass is loaded
        guard let myClass = context.documentationCache["s:5MyKit0A5ClassC"],
            let myClassSymbol = myClass.semantic as? Symbol else {
            XCTFail("`MyClass` not found in symbol graph")
            return
        }
        
        // Test that the declarations are grouped correctly
        XCTAssertNotNil(myClassSymbol.declaration[[nil]])
    }
    
    func testDetectsDuplicateSymbolArticles() throws {
        let documentationURL = Bundle.module.url(
            forResource: "TestBundle", withExtension: "docc", subdirectory: "Test Bundles")!
            .appendingPathComponent("documentation")
    
        let myKitURL = documentationURL.appendingPathComponent("mykit.md")
        
        let testBundle = Folder(name: "TestDetectsDuplicateSymbolArticles.docc", content: [
            InfoPlist(displayName: "TestDetectsDuplicateSymbolArticles", identifier: "com.example.documentation"),
            Folder(name: "Resources", content: [
                CopyOfFile(original: myKitURL, newName: "mykit.md"),
                CopyOfFile(original: myKitURL, newName: "mykit-duplicate.md"),
                CopyOfFile(original: myKitURL, newName: "myprotocol.md"),
                CopyOfFile(original: myKitURL, newName: "myprotocol-duplicateddm"),
            ]),
            Folder(name: "Symbols", content: [
                CopyOfFile(original: Bundle.module.url(
                    forResource: "TestBundle", withExtension: "docc", subdirectory: "Test Bundles")!
                    .appendingPathComponent("mykit-iOS.symbols.json")),
            ])
        ])
        
        let tempURL = try createTemporaryDirectory()
        let bundleURL = try testBundle.write(inside: tempURL)

        let workspace = DocumentationWorkspace()
        let context = try DocumentationContext(dataProvider: workspace)
        let dataProvider = try LocalFileSystemDataProvider(rootURL: bundleURL)
        try workspace.registerProvider(dataProvider)

        XCTAssertNotNil(context.problems
            .map { $0.diagnostic }
            .filter { $0.identifier == "org.swift.docc.DuplicateMarkdownTitleSymbolReferences"
                && $0.summary.contains("'/mykit'") }
        )
        XCTAssertNotNil(context.problems
            .map { $0.diagnostic }
            .filter { $0.identifier == "org.swift.docc.DuplicateMarkdownTitleSymbolReferences"
                && $0.summary.contains("'/myprotocol'") }
        )
    }
    
    func testCanResolveArticleFromTutorial() throws {
        struct TestData {
            let symbolGraphNames: [String]
            
            var symbolGraphFiles: [File] {
                return symbolGraphNames.map { name in
                    CopyOfFile(original: Bundle.module.url(forResource: "TestBundle", withExtension: "docc", subdirectory: "Test Bundles")!
                        .appendingPathComponent(name + ".symbols.json"))
                }
            }
                
            var expectsToResolveArticleReference: Bool {
                return symbolGraphNames.count == 1
            }
        }
        
        // Verify that the article can be resolved when there's a single module but not otherwise.
        let combinationsToTest = [
            TestData(symbolGraphNames: []),
            TestData(symbolGraphNames: ["mykit-iOS"]),
            TestData(symbolGraphNames: ["sidekit"]),
            TestData(symbolGraphNames: ["mykit-iOS", "sidekit"]),
        ]
        
        for testData in combinationsToTest {
            let testBundle = Folder(name: "TestCanResolveArticleFromTutorial.docc", content: [
                InfoPlist(displayName: "TestCanResolveArticleFromTutorial", identifier: "com.example.documentation"),
                
                TextFile(name: "extra-article.md", utf8Content: """
                # Extra article
                
                This is an extra article that will be automatically curated.
                """),
                    
                TextFile(name: "TestOverview.tutorial", utf8Content: """
                @Tutorials(name: "Technology X") {
                   @Intro(title: "Technology X") {
                      Reference the extra article in tutorial content: <doc:extra-article>
                   }
                }
                """),
            ] + testData.symbolGraphFiles)
            
            let tempURL = try createTemporaryDirectory()
            let bundleURL = try testBundle.write(inside: tempURL)
            
            let workspace = DocumentationWorkspace()
            let context = try DocumentationContext(dataProvider: workspace)
            let dataProvider = try LocalFileSystemDataProvider(rootURL: bundleURL)
            try workspace.registerProvider(dataProvider)
            
            let bundle = try XCTUnwrap(workspace.bundles.values.first)
            let renderContext = RenderContext(documentationContext: context, bundle: bundle)
            
            let identifier = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/tutorials/TestOverview", sourceLanguage: .swift)
            let node = try context.entity(with: identifier)
            
            let converter = DocumentationContextConverter(bundle: bundle, context: context, renderContext: renderContext)
            
            let source = context.documentURL(for: identifier)
            let renderNode = try XCTUnwrap(converter.renderNode(for: node, at: source))
            
            XCTAssertEqual(
                !testData.expectsToResolveArticleReference,
                context.problems.contains(where: { $0.diagnostic.identifier == "org.swift.docc.unresolvedTopicReference" }),
                "Expected to \(testData.expectsToResolveArticleReference ? "resolve" : "not resolve") article reference from tutorial content when there are \(testData.symbolGraphNames.count) modules."
            )
            XCTAssertEqual(
                testData.expectsToResolveArticleReference,
                renderNode.references.keys.contains("doc://com.example.documentation/documentation/TestCanResolveArticleFromTutorial/extra-article"),
                "Expected to \(testData.expectsToResolveArticleReference ? "find" : "not find") article among the tutorial's references when there are \(testData.symbolGraphNames.count) modules."
            )
        }
    }
    
    func testCuratesSymbolsAndArticlesCorrectly() throws {
        let (_, context) = try testBundleAndContext(named: "TestBundle")

        // Sort the edges for each node to get consistent results, no matter the order that the symbols were processed.
        for (source, targets) in context.topicGraph.edges {
            context.topicGraph.edges[source] = targets.sorted(by: { $0.absoluteString < $1.absoluteString })
        }
        
let expected = """
 doc://org.swift.docc.example/documentation/FillIntroduced
 ├ doc://org.swift.docc.example/documentation/FillIntroduced/iOSMacOSOnly()
 ├ doc://org.swift.docc.example/documentation/FillIntroduced/iOSOnlyDeprecated()
 ├ doc://org.swift.docc.example/documentation/FillIntroduced/iOSOnlyIntroduced()
 ├ doc://org.swift.docc.example/documentation/FillIntroduced/macCatalystOnlyDeprecated()
 ├ doc://org.swift.docc.example/documentation/FillIntroduced/macCatalystOnlyIntroduced()
 ├ doc://org.swift.docc.example/documentation/FillIntroduced/macOSOnlyDeprecated()
 ╰ doc://org.swift.docc.example/documentation/FillIntroduced/macOSOnlyIntroduced()
 doc://org.swift.docc.example/documentation/MyKit
 ├ doc://org.swift.docc.example/documentation/MyKit/MyClass
 │ ├ doc://org.swift.docc.example/documentation/MyKit/MyClass/init()-33vaw
 │ ├ doc://org.swift.docc.example/documentation/MyKit/MyClass/init()-3743d
 │ ╰ doc://org.swift.docc.example/documentation/MyKit/MyClass/myFunction()
 ├ doc://org.swift.docc.example/documentation/MyKit/MyProtocol
 │ ╰ doc://org.swift.docc.example/documentation/MyKit/MyClass
 │   ├ doc://org.swift.docc.example/documentation/MyKit/MyClass/init()-33vaw
 │   ├ doc://org.swift.docc.example/documentation/MyKit/MyClass/init()-3743d
 │   ╰ doc://org.swift.docc.example/documentation/MyKit/MyClass/myFunction()
 ├ doc://org.swift.docc.example/documentation/MyKit/globalFunction(_:considering:)
 ├ doc://org.swift.docc.example/documentation/SideKit/UncuratedClass/angle
 ├ doc://org.swift.docc.example/documentation/Test-Bundle/Default-Code-Listing-Syntax
 ├ doc://org.swift.docc.example/documentation/Test-Bundle/article
 │ ├ doc://org.swift.docc.example/documentation/Test-Bundle/article2
 │ ├ doc://org.swift.docc.example/documentation/Test-Bundle/article3
 │ ╰ doc://org.swift.docc.example/tutorials/Test-Bundle/TestTutorial
 │   ├ doc://org.swift.docc.example/tutorials/Test-Bundle/TestTutorial#Create-a-New-AR-Project-%F0%9F%92%BB
 │   ├ doc://org.swift.docc.example/tutorials/Test-Bundle/TestTutorial#Duplicate
 │   ╰ doc://org.swift.docc.example/tutorials/Test-Bundle/TestTutorial#Initiate-ARKit-Plane-Detection
 ╰ doc://org.swift.docc.example/documentation/Test-Bundle/article2
 doc://org.swift.docc.example/documentation/SideKit
 ├ doc://org.swift.docc.example/documentation/SideKit/SideClass
 │ ├ doc://org.swift.docc.example/documentation/SideKit/SideClass/Element
 │ │ ╰ doc://org.swift.docc.example/documentation/SideKit/SideClass/Element/Protocol-Implementations
 │ │   ╰ doc://org.swift.docc.example/documentation/SideKit/SideClass/Element/inherited()
 │ ├ doc://org.swift.docc.example/documentation/SideKit/SideClass/Value(_:)
 │ ├ doc://org.swift.docc.example/documentation/SideKit/SideClass/init()
 │ ├ doc://org.swift.docc.example/documentation/SideKit/SideClass/myFunction()
 │ ├ doc://org.swift.docc.example/documentation/SideKit/SideClass/path
 │ ╰ doc://org.swift.docc.example/documentation/SideKit/SideClass/url
 ├ doc://org.swift.docc.example/documentation/SideKit/SideProtocol
 │ ╰ doc://org.swift.docc.example/documentation/SideKit/SideProtocol/func()-6ijsi
 │   ╰ doc://org.swift.docc.example/documentation/SideKit/SideProtocol/func()-2dxqn
 ╰ doc://org.swift.docc.example/documentation/SideKit/UncuratedClass
 doc://org.swift.docc.example/tutorials/TestOverview
 ╰ doc://org.swift.docc.example/tutorials/TestOverview/$volume
   ╰ doc://org.swift.docc.example/tutorials/TestOverview/Chapter-1
     ├ doc://org.swift.docc.example/tutorials/Test-Bundle/TestTutorial
     │ ├ doc://org.swift.docc.example/tutorials/Test-Bundle/TestTutorial#Create-a-New-AR-Project-%F0%9F%92%BB
     │ ├ doc://org.swift.docc.example/tutorials/Test-Bundle/TestTutorial#Duplicate
     │ ╰ doc://org.swift.docc.example/tutorials/Test-Bundle/TestTutorial#Initiate-ARKit-Plane-Detection
     ├ doc://org.swift.docc.example/tutorials/Test-Bundle/TestTutorial2
     │ ╰ doc://org.swift.docc.example/tutorials/Test-Bundle/TestTutorial2#Create-a-New-AR-Project
     ├ doc://org.swift.docc.example/tutorials/Test-Bundle/TestTutorialArticle
     │ ├ doc://org.swift.docc.example/tutorials/Test-Bundle/TestTutorialArticle#A-Section
     │ ├ doc://org.swift.docc.example/tutorials/Test-Bundle/TestTutorialArticle#This-is-an-H2
     │ ╰ doc://org.swift.docc.example/tutorials/Test-Bundle/TestTutorialArticle#This-is-an-H3
     ╰ doc://org.swift.docc.example/tutorials/Test-Bundle/TutorialMediaWithSpaces
       ╰ doc://org.swift.docc.example/tutorials/Test-Bundle/TutorialMediaWithSpaces#Create-a-New-AR-Project
"""

        assertEqualDumps(context.dumpGraph(), expected)
        
        // Test correct symbol hierarchy in context
        XCTAssertEqual(context.finitePaths(to: ResolvedTopicReference(bundleIdentifier: "org.swift.docc.example", path: "/documentation/MyKit/MyClass", sourceLanguage: .swift)).map { $0.map {$0.absoluteString} },
                       [["doc://org.swift.docc.example/documentation/MyKit"], ["doc://org.swift.docc.example/documentation/MyKit", "doc://org.swift.docc.example/documentation/MyKit/MyProtocol"]])
        
        XCTAssertEqual(context.finitePaths(to: ResolvedTopicReference(bundleIdentifier: "org.swift.docc.example", path: "/documentation/MyKit/MyClass/init()-33vaw", sourceLanguage: .swift)).map { $0.map {$0.absoluteString} },
                       [["doc://org.swift.docc.example/documentation/MyKit", "doc://org.swift.docc.example/documentation/MyKit/MyClass"], ["doc://org.swift.docc.example/documentation/MyKit", "doc://org.swift.docc.example/documentation/MyKit/MyProtocol", "doc://org.swift.docc.example/documentation/MyKit/MyClass"]])
    }
    
    func createNode(in context: DocumentationContext, bundle: DocumentationBundle, parent: ResolvedTopicReference, name: String) throws -> (DocumentationNode, TopicGraph.Node) {
        let reference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/MyKit/\(name)", sourceLanguage: .swift)
        let node = DocumentationNode(reference: reference, kind: .article, sourceLanguage: .swift, name: .conceptual(title: name), markup: Document(parsing: "# \(name)"), semantic: nil)
        let tgNode = TopicGraph.Node(reference: reference, kind: .article, source: .external, title: name)
        
        context.documentationCache[reference] = node
        context.topicGraph.addNode(tgNode)
        let parentNode = try XCTUnwrap(context.topicGraph.nodeWithReference(parent))
        context.topicGraph.addEdge(from: parentNode, to: tgNode)
        
        return (node, tgNode)
    }
    
    func testSortingBreadcrumbsOfEqualDistanceToRoot() throws {
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        
        let mykit = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/MyKit", sourceLanguage: .swift)
        
        ///
        /// Create nodes in alphabetical order
        ///

        /// Create /documentation/MyKit/AAA & /documentation/MyKit/BBB
        let (aaaNode, _) = try createNode(in: context, bundle: bundle, parent: mykit, name: "AAA")
        let (_, bbbTgNode) = try createNode(in: context, bundle: bundle, parent: mykit, name: "BBB")
        /// Create /documentation/MyKit/AAA/CCC, curate also under BBB
        let (cccNode, cccTgNode) = try createNode(in: context, bundle: bundle, parent: aaaNode.reference, name: "CCC")
        context.topicGraph.addEdge(from: bbbTgNode, to: cccTgNode)
        
        let canonicalPathCCC = try XCTUnwrap(context.shortestFinitePath(to: cccNode.reference))
        XCTAssertEqual(["/documentation/MyKit", "/documentation/MyKit/AAA"], canonicalPathCCC.map({ $0.path }))
        
        ///
        /// Create nodes in non-alphabetical order
        ///

        /// Create /documentation/MyKit/DDD & /documentation/MyKit/EEE
        let (_, dddTgNode) = try createNode(in: context, bundle: bundle, parent: mykit, name: "DDD")
        let (eeeNode, _) = try createNode(in: context, bundle: bundle, parent: mykit, name: "EEE")
        /// Create /documentation/MyKit/DDD/FFF, curate also under EEE
        let (fffNode, fffTgNode) = try createNode(in: context, bundle: bundle, parent: eeeNode.reference, name: "FFF")
        context.topicGraph.addEdge(from: dddTgNode, to: fffTgNode)
        
        let canonicalPathFFF = try XCTUnwrap(context.shortestFinitePath(to: fffNode.reference))
        XCTAssertEqual(["/documentation/MyKit", "/documentation/MyKit/DDD"], canonicalPathFFF.map({ $0.path }))
    }
    
    func testSortingBreadcrumbsOfDifferentDistancesToRoot() throws {
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        
        let mykit = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/MyKit", sourceLanguage: .swift)
        let tgMykitNode = try XCTUnwrap(context.topicGraph.nodeWithReference(mykit))
        
        ///
        /// Create nodes in order
        ///

        /// Create /documentation/MyKit/AAA & /documentation/MyKit/BBB
        let (aaaNode, aaaTgNode) = try createNode(in: context, bundle: bundle, parent: mykit, name: "AAA")
        let (_, bbbTgNode) = try createNode(in: context, bundle: bundle, parent: mykit, name: "BBB")
        /// Create /documentation/MyKit/AAA/CCC and also curate under /documentation/MyKit
        let (cccNode, cccTgNode) = try createNode(in: context, bundle: bundle, parent: aaaNode.reference, name: "CCC")
        context.topicGraph.addEdge(from: tgMykitNode, to: cccTgNode)
        context.topicGraph.addEdge(from: aaaTgNode, to: cccTgNode)
        context.topicGraph.addEdge(from: bbbTgNode, to: cccTgNode)
        
        let canonicalPathCCC = try XCTUnwrap(context.shortestFinitePath(to: cccNode.reference))
        XCTAssertEqual(["/documentation/MyKit"], canonicalPathCCC.map({ $0.path }))
        
        ///
        /// Create nodes not in order
        ///

        /// Create /documentation/MyKit/DDD & /documentation/MyKit/EEE
        let (_, dddTgNode) = try createNode(in: context, bundle: bundle, parent: mykit, name: "DDD")
        let (eeeNode, eeeTgNode) = try createNode(in: context, bundle: bundle, parent: mykit, name: "EEE")
        /// Create /documentation/MyKit/DDD/FFF, curate also under /documentation/MyKit
        let (fffNode, fffTgNode) = try createNode(in: context, bundle: bundle, parent: eeeNode.reference, name: "FFF")
        context.topicGraph.addEdge(from: eeeTgNode, to: fffTgNode)
        context.topicGraph.addEdge(from: dddTgNode, to: fffTgNode)
        context.topicGraph.addEdge(from: tgMykitNode, to: fffTgNode)
        
        let canonicalPathFFF = try XCTUnwrap(context.shortestFinitePath(to: fffNode.reference))
        XCTAssertEqual(["/documentation/MyKit"], canonicalPathFFF.map({ $0.path }))
    }

    // Verify that a symbol that has no parents in the symbol graph is automatically curated under the module node.
    func testRootSymbolsAreCuratedInModule() throws {
        let (url, bundle, context) = try testBundleAndContext(copying: "TestBundle")
        
        // Verify that SideClass doesn't have a memberOf relationship at all.
        let graphData = try Data(contentsOf: url.appendingPathComponent("sidekit.symbols.json"))
        let graph = try JSONDecoder().decode(SymbolGraph.self, from: graphData)
        XCTAssertNil(graph.relationships.first { (relationship) -> Bool in
            return relationship.kind == .memberOf && relationship.source == "5SideKit0A5SideClassC"
        })
        
        // Verify the node is a child of the module node when the graph is loaded.
        let sideClassReference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/SideKit/SideClass", sourceLanguage: .swift)
        let parents = context.parents(of: sideClassReference)
        XCTAssertEqual(parents.map {$0.path}, ["/documentation/SideKit"])
    }
    
    /// Tests whether tutorial curated multiple times gets the correct breadcrumbs and hierarchy.
    func testCurateTutorialMultipleTimes() throws {
        // Curate "TestTutorial" under MyKit as well as TechnologyX.
        let (_, _, context) = try testBundleAndContext(copying: "TestBundle") { root in
            let myKitURL = root.appendingPathComponent("documentation/mykit.md")
            let text = try String(contentsOf: myKitURL).replacingOccurrences(of: "## Topics", with: """
            ## Topics

            ### Tutorials
             - <doc:/tutorials/Test-Bundle/TestTutorial>
             - <doc:/tutorials/Test-Bundle/TestTutorial2>
            """)
            try text.write(to: myKitURL, atomically: true, encoding: .utf8)
        }
        
        // Get a node
        let node = try context.entity(with: ResolvedTopicReference(bundleIdentifier: "org.swift.docc.example", path: "/tutorials/Test-Bundle/TestTutorial", sourceLanguage: .swift))
        
        // Get the breadcrumbs as paths
        let paths = context.finitePaths(to: node.reference).sorted { (path1, path2) -> Bool in
            return path1.count < path2.count
        }
        .map { return $0.map { $0.url.path } }
        
        // Verify the tutorial has multiple paths
        XCTAssertEqual(paths, [["/documentation/MyKit"], ["/documentation/MyKit", "/documentation/Test-Bundle/article"], ["/tutorials/TestOverview", "/tutorials/TestOverview/$volume", "/tutorials/TestOverview/Chapter-1"]])
    }

    func testNonOverloadPaths() throws {
        // Add some symbol collisions to graph
        let (_, _, context) = try testBundleAndContext(copying: "TestBundle") { root in
            let sideKitURL = root.appendingPathComponent("sidekit.symbols.json")
            let text = try String(contentsOf: sideKitURL).replacingOccurrences(of: "\"symbols\" : [", with: """
            "symbols" : [
            {
              "accessLevel" : "public",
              "kind" : {
                "identifier" : "swift.enum.case",
                "displayName" : "Enumeration Case"
              },
              "names" : { "title" : "test" },
              "pathComponents" : [ "SideClass", "test" ],
              "identifier" : {
                "precise" : "s:7SideKit0A5ClassC10testEC",
                "interfaceLanguage": "swift"
              }
            },
            {
              "accessLevel" : "public",
              "kind" : {
                "identifier" : "swift.var",
                "displayName" : "Variable"
              },
              "names" : { "title" : "test" },
              "pathComponents" : [ "SideClass", "test" ],
              "identifier" : {
                "precise" : "s:7SideKit0A5ClassC10testV",
                "interfaceLanguage": "swift"
              }
            },
            """).replacingOccurrences(of: "\"relationships\" : [", with: """
            "relationships" : [
            {
              "kind" : "memberOf",
              "source" : "s:7SideKit0A5ClassC10testEC",
              "target" : "s:7SideKit0A5ClassC"
            },
            {
              "kind" : "memberOf",
              "source" : "s:7SideKit0A5ClassC10testV",
              "target" : "s:7SideKit0A5ClassC"
            },
            """)
            try text.write(to: sideKitURL, atomically: true, encoding: .utf8)
        }
        
        // Verify the non-overload collisions were resolved
        XCTAssertNoThrow(try context.entity(with: ResolvedTopicReference(bundleIdentifier: "org.swift.docc.example", path: "/documentation/SideKit/SideClass/test-swift.enum.case", sourceLanguage: .swift)))
        XCTAssertNoThrow(try context.entity(with: ResolvedTopicReference(bundleIdentifier: "org.swift.docc.example", path: "/documentation/SideKit/SideClass/test-swift.var", sourceLanguage: .swift)))
    }
    
    func testModuleLanguageFallsBackToSwiftIfItHasNoSymbols() throws {
        let (_, _, context) = try testBundleAndContext(copying: "TestBundle") { root in
            // Delete all the symbol graph files.
            let symbolGraphFiles = try XCTUnwrap(
                FileManager.default.enumerator(
                    at: root,
                    includingPropertiesForKeys: [.isRegularFileKey],
                    options: []
                )?.compactMap { item in
                    item as? URL
                }.filter { url in
                    url.absoluteString.hasSuffix(".symbols.json")
                }
            )
            
            for symbolGraphFile in symbolGraphFiles {
                try FileManager.default.removeItem(at: symbolGraphFile)
            }
            
            // Add a symbol graph file with no symbols.
            try """
            {
              "metadata": {
                "formatVersion": {
                  "major": 0,
                  "minor": 5,
                  "patch": 0
                },
                "generator": "MyGenerator"
              },
              "module" : {
                "name" : "MyKit",
                "platform" : {
                  "architecture" : "x86_64",
                  "vendor" : "apple",
                  "operatingSystem" : {
                    "name" : "ios",
                    "minimumVersion" : {
                      "major" : 13,
                      "minor" : 0,
                      "patch" : 0
                    }
                  }
                }
              },
              "relationships": [],
              "symbols": []
            }
            """.write(to: root.appendingPathComponent("MyKit.symbols.json"), atomically: true, encoding: .utf8)
        }
        
        XCTAssertEqual(
            context.soleRootModuleReference.map { context.sourceLanguages(for: $0) },
            [.swift],
            "Expected the module to have language 'Swift' since it has 0 symbols."
        )
    }
    
    func testOverloadPlusNonOverloadCollisionPaths() throws {
        // Add some symbol collisions to graph
        let (_, _, context) = try testBundleAndContext(copying: "TestBundle") { root in
            let sideKitURL = root.appendingPathComponent("sidekit.symbols.json")
            let text = try String(contentsOf: sideKitURL).replacingOccurrences(of: "\"symbols\" : [", with: """
            "symbols" : [
            {
              "accessLevel" : "public",
              "kind" : {
                "identifier" : "swift.enum",
                "displayName" : "Enumeration"
              },
              "names" : { "title" : "Test" },
              "pathComponents" : [ "SideClass", "Test" ],
              "identifier" : {
                "precise" : "s:7SideKit0A5ClassC10testE",
                "interfaceLanguage": "swift"
              }
            },
            {
              "accessLevel" : "public",
              "kind" : {
                "identifier" : "swift.var",
                "displayName" : "Type Variable"
              },
              "names" : { "title" : "test" },
              "pathComponents" : [ "SideClass", "test" ],
              "identifier" : {
                "precise" : "s:7SideKit0A5ClassC10testSV",
                "interfaceLanguage": "swift"
              }
            },
            {
              "accessLevel" : "public",
              "kind" : {
                "identifier" : "swift.var",
                "displayName" : "Type Variable"
              },
              "names" : { "title" : "tEst" },
              "pathComponents" : [ "SideClass", "tEst" ],
              "identifier" : {
                "precise" : "s:7SideKit0A5ClassC10tEstV",
                "interfaceLanguage": "swift"
              }
            },
            """).replacingOccurrences(of: "\"relationships\" : [", with: """
            "relationships" : [
            {
              "kind" : "memberOf",
              "source" : "s:7SideKit0A5ClassC10testE",
              "target" : "s:7SideKit0A5ClassC"
            },
            {
              "kind" : "memberOf",
              "source" : "s:7SideKit0A5ClassC10testSV",
              "target" : "s:7SideKit0A5ClassC"
            },
            {
              "kind" : "memberOf",
              "source" : "s:7SideKit0A5ClassC10tEstV",
              "target" : "s:7SideKit0A5ClassC"
            },
            """)
            try text.write(to: sideKitURL, atomically: true, encoding: .utf8)
        }
        
        // Verify the non-overload collisions were resolved
        XCTAssertNoThrow(try context.entity(with: ResolvedTopicReference(bundleIdentifier: "org.swift.docc.example", path: "/documentation/SideKit/SideClass/Test-swift.enum", sourceLanguage: .swift)))
        XCTAssertNoThrow(try context.entity(with: ResolvedTopicReference(bundleIdentifier: "org.swift.docc.example", path: "/documentation/SideKit/SideClass/tEst-9053a", sourceLanguage: .swift)))
        XCTAssertNoThrow(try context.entity(with: ResolvedTopicReference(bundleIdentifier: "org.swift.docc.example", path: "/documentation/SideKit/SideClass/test-959hd", sourceLanguage: .swift)))
    }

    func testUnknownSymbolKind() throws {
        // Change the symbol kind to an unknown and load the symbol graph
        let (_, _, context) = try testBundleAndContext(copying: "TestBundle") { root in
            let myKitURL = root.appendingPathComponent("mykit-iOS.symbols.json")
            let text = try String(contentsOf: myKitURL).replacingOccurrences(of: "\"identifier\" : \"swift.method\"", with: "\"identifier\" : \"blip-blop\"")
            try text.write(to: myKitURL, atomically: true, encoding: .utf8)
        }
        
        // Get a function node, verify its kind is unknown
        let node = try context.entity(with: ResolvedTopicReference(bundleIdentifier: "org.swift.docc.example", path: "/documentation/MyKit/MyClass/myFunction()", sourceLanguage: .swift))
        XCTAssertEqual(node.kind, .unknown)
    }
    
    func testCuratingSymbolsWithSpecialCharacters() throws {
        let (_, _, context) = try testBundleAndContext(copying: "InheritedOperators") { root in
            try """
            # ``Operators/MyNumber``
            
            A documentation extension that curates symbols with characters not allowed in a resolved reference URL.

            ## Topics
            
            ### Operator name only
            
            - ``<(_:_:)``
            - ``>(_:_:)``
            - ``<=(_:_:)``
            - ``>=(_:_:)``
            - ``-(_:_:)-22pw2``
            - ``-(_:)-9xdx0``
            - ``-=(_:_:)-7w3vn``
            - ``/(_:_:)``
            - ``/=(_:_:)``
            
            ### Prefixes with containing type name
            
            - ``MyNumber/<(_:_:)``
            - ``MyNumber/>(_:_:)``
            - ``MyNumber/<=(_:_:)``
            - ``MyNumber/>=(_:_:)``
            - ``MyNumber/-(_:_:)-22pw2``
            - ``MyNumber/-(_:)-9xdx0``
            - ``MyNumber/-=(_:_:)-7w3vn``
            - ``MyNumber//(_:_:)``
            - ``MyNumber//=(_:_:)``
            """.write(to: root.appendingPathComponent("doc-extension.md"), atomically: true, encoding: .utf8)
        }
        
        let unresolvedTopicProblems = context.problems.filter({ $0.diagnostic.identifier == "org.swift.docc.unresolvedTopicReference" })
        XCTAssertEqual(unresolvedTopicProblems.map(\.diagnostic.summary), [], "All links should resolve without warnings")
    }
    
    func testOperatorReferences() throws {
        let (_, context) = try testBundleAndContext(named: "InheritedOperators")
        
        let pageIdentifiersAndNames = Dictionary(uniqueKeysWithValues: try context.knownPages.map { reference in
            (key: reference.path, value: try context.entity(with: reference).name.description)
        })
        
        // Operators where all characters in the operator name are also allowed in URL paths
        XCTAssertEqual("!=(_:_:)",  pageIdentifiersAndNames["/documentation/Operators/MyNumber/!=(_:_:)"])
        XCTAssertEqual("*(_:_:)",   pageIdentifiersAndNames["/documentation/Operators/MyNumber/*(_:_:)"])
        XCTAssertEqual("*=(_:_:)",  pageIdentifiersAndNames["/documentation/Operators/MyNumber/*=(_:_:)"])
        XCTAssertEqual("+(_:)",     pageIdentifiersAndNames["/documentation/Operators/MyNumber/+(_:)"])
        XCTAssertEqual("+(_:_:)",   pageIdentifiersAndNames["/documentation/Operators/MyNumber/+(_:_:)"])
        XCTAssertEqual("+=(_:_:)",  pageIdentifiersAndNames["/documentation/Operators/MyNumber/+=(_:_:)"])
        XCTAssertEqual("-(_:)",     pageIdentifiersAndNames["/documentation/Operators/MyNumber/-(_:)"])
        XCTAssertEqual("-(_:_:)",   pageIdentifiersAndNames["/documentation/Operators/MyNumber/-(_:_:)"])
        XCTAssertEqual("-=(_:_:)",  pageIdentifiersAndNames["/documentation/Operators/MyNumber/-=(_:_:)"])
        XCTAssertEqual("...(_:_:)", pageIdentifiersAndNames["/documentation/Operators/MyNumber/...(_:_:)"])
        XCTAssertEqual("..<(_:)",   pageIdentifiersAndNames["/documentation/Operators/MyNumber/.._(_:)"])
        XCTAssertEqual("..<(_:_:)", pageIdentifiersAndNames["/documentation/Operators/MyNumber/.._(_:_:)"])
        // Operators with the same name have disambiguation in their paths
        XCTAssertEqual("...(_:)",   pageIdentifiersAndNames["/documentation/Operators/MyNumber/...(_:)-28faz"])
        XCTAssertEqual("...(_:)",   pageIdentifiersAndNames["/documentation/Operators/MyNumber/...(_:)-8ooeh"])
        
        // Characters that are not allowed in URL paths are replaced with "_" (adding disambiguation if the replacement introduces conflicts)
        XCTAssertEqual("<(_:_:)",   pageIdentifiersAndNames["/documentation/Operators/MyNumber/_(_:_:)-736gk"])
        XCTAssertEqual("<=(_:_:)",  pageIdentifiersAndNames["/documentation/Operators/MyNumber/_=(_:_:)-9uewk"])
        XCTAssertEqual(">(_:_:)",   pageIdentifiersAndNames["/documentation/Operators/MyNumber/_(_:_:)-21jxf"])
        XCTAssertEqual(">=(_:_:)",  pageIdentifiersAndNames["/documentation/Operators/MyNumber/_=(_:_:)-70j0d"])
        
        // "/" is a separator in URL paths so it's replaced with with "_" (adding disambiguation if the replacement introduces conflicts)
        XCTAssertEqual("/(_:_:)",   pageIdentifiersAndNames["/documentation/Operators/MyNumber/_(_:_:)-7am4"])
        XCTAssertEqual("/=(_:_:)",  pageIdentifiersAndNames["/documentation/Operators/MyNumber/_=(_:_:)-3m4ko"])
    }
    
    func testFileNamesWithDifferentPunctuation() throws {
        let tempURL = try createTempFolder(content: [
            Folder(name: "unit-test.docc", content: [
                TextFile(name: "Hello-world.md", utf8Content: """
                # Dash
                
                No whitespace in the file name
                """),
                
                TextFile(name: "Hello world.md", utf8Content: """
                # Only space
                
                This has the same reference as "Hello-world.md" and will raise a warning.
                """),
                
                TextFile(name: "Hello  world.md", utf8Content: """
                # Multiple spaces
                
                Each space is replaced with a dash in the reference, so this has a unique reference.
                """),
                
                TextFile(name: "Hello, world!.md", utf8Content: """
                # Space and punctuation
                
                The punctuation is not removed from the reference, so this has a unique reference.
                """),
                
                TextFile(name: "Hello. world?.md", utf8Content: """
                # Space and different punctuation
                
                The punctuation is not removed from the reference, so this has a unique reference.
                """),
            ])
        ])
        let (_, _, context) = try loadBundle(from: tempURL)

        XCTAssertEqual(context.problems.map(\.diagnostic.summary), ["Redeclaration of 'Hello world.md'; this file will be skipped"])
        
        XCTAssertEqual(context.knownPages.map(\.absoluteString).sorted(), [
            "doc://unit-test/documentation/unit-test",
            "doc://unit-test/documentation/unit-test/Hello,-world!",
            "doc://unit-test/documentation/unit-test/Hello--world",
            "doc://unit-test/documentation/unit-test/Hello-world",
            "doc://unit-test/documentation/unit-test/Hello.-world-",
        ])
    }
    
    func testSpecialCharactersInLinks() throws {
        let originalSymbolGraph = Bundle.module.url(forResource: "TestBundle", withExtension: "docc", subdirectory: "Test Bundles")!.appendingPathComponent("mykit-iOS.symbols.json")
        
        let testBundle = Folder(name: "special-characters.docc", content: [
            try TextFile(name: "mykit.symbols.json", utf8Content: String(contentsOf: originalSymbolGraph).replacingOccurrences(of: "myFunction", with: "myFunc🙂")),
            
            TextFile(name: "article-with-emoji-in-heading.md", utf8Content: """
            # Article with emoji in heading
            
            Abstract
            
            ### Hello 🌍
            """),
            
            TextFile(name: "article-with-😃-in-filename.md", utf8Content: """
            # Article with 😃 emoji in its filename
            
            Abstract
            
            ### Hello world
            """),
            
            TextFile(name: "Article: with - various! whitespace & punctuation. in, filename.md", utf8Content: """
            # Article with various whitespace and punctuation in its filename
            
            Abstract
            
            ### Hello world
            """),
            
            TextFile(name: "MyKit.md", utf8Content: """
            # ``MyKit``
            
            Test linking to articles, symbols, and headings with special characters;
            
            - ``MyClass/myFunc🙂()``
            - <doc:article-with-emoji-in-heading#Hello-🌍>
            - <doc:article-with-😃-in-filename>
            - <doc:article-with-😃-in-filename#Hello-world>
            - <doc:Article:-with-various!-whitespace-&-punctuation.-in,-filename>
            - <doc:Article:-with-various!-whitespace-&-punctuation.-in,-filename#Hello-world>
            
            Now test the same links in topic curation.
            
            ## Topics
            
            Only curate the pages. Headings don't support curation.
            
            - ``MyClass/myFunc🙂()``
            - <doc:article-with-😃-in-filename>
            - <doc:Article:-with-various!-whitespace-&-punctuation.-in,-filename>
            """),
        ])
        let bundleURL = try testBundle.write(inside: createTemporaryDirectory())
        let (_, bundle, context) = try loadBundle(from: bundleURL)

        let problems = context.problems
        XCTAssertEqual(problems.count, 0, "Unexpected problems: \(problems.map(\.diagnostic.summary).sorted())")
        
        let moduleReference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/MyKit", sourceLanguage: .swift)
        let entity = try context.entity(with: moduleReference)
        
        let moduleSymbol = try XCTUnwrap(entity.semantic as? Symbol)
        let topicSection = try XCTUnwrap(moduleSymbol.topics?.taskGroups.first)

        // Verify that all the links in the topic section resolved
        XCTAssertEqual(topicSection.links.map(\.destination), [
            "doc://special-characters/documentation/MyKit/MyClass/myFunc_()",
            "doc://special-characters/documentation/special-characters/article-with---in-filename",
            "doc://special-characters/documentation/special-characters/Article:-with---various!-whitespace-&-punctuation.-in,-filename",
        ])
        
        // Verify that all resolved link exist in the context.
        for reference in topicSection.links {
            XCTAssertNotNil(reference.destination)
            XCTAssert(context.knownPages.contains(where: { $0.absoluteString == reference.destination })
                   || context.nodeAnchorSections.keys.contains(where: { $0.absoluteString == reference.destination })
            )
        }
        
        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: moduleReference, source: nil)
        let renderNode = translator.visit(moduleSymbol) as! RenderNode
        
        // Verify that the resolved links rendered as links
        XCTAssertEqual(renderNode.topicSections.first?.identifiers.count, 3)
        XCTAssertEqual(renderNode.topicSections.first?.identifiers, [
            "doc://special-characters/documentation/MyKit/MyClass/myFunc_()",
            "doc://special-characters/documentation/special-characters/article-with---in-filename",
            "doc://special-characters/documentation/special-characters/Article:-with---various!-whitespace-&-punctuation.-in,-filename",
        ])
        
        
        let contentSection = try XCTUnwrap(renderNode.primaryContentSections.first as? ContentRenderSection)
        let lists: [RenderBlockContent.UnorderedList] = contentSection.content.compactMap({ (content: RenderBlockContent) -> RenderBlockContent.UnorderedList? in
            if case let .unorderedList(list) = content {
                return list
            } else {
                return nil
            }
        })
        
        XCTAssertEqual(lists.count, 1)
        let list = try XCTUnwrap(lists.first)
        XCTAssertEqual(list.items.count, 6, "Unexpected list items: \(list.items.map(\.content))")
        
        func withContentAsReference(_ listItem: RenderBlockContent.ListItem?, verify: (RenderReferenceIdentifier, Bool, String?, [RenderInlineContent]?) -> Void) {
            guard let listItem else {
                XCTFail("Missing list item")
                return
            }
            if case let .paragraph(paragraph) = listItem.content.first,
               case let .reference(identifier, isActive, overridingTitle, overridingTitleInlineContent) = paragraph.inlineContent.first {
                verify(identifier, isActive, overridingTitle, overridingTitleInlineContent)
            } else {
                XCTFail("Unexpected list item kind: \(listItem.content)")
            }
        }
        
        // First
        withContentAsReference(list.items.first) { identifier, isActive, overridingTitle, overridingTitleInlineContent in
            XCTAssertEqual(identifier.identifier, "doc://special-characters/documentation/MyKit/MyClass/myFunc_()")
            XCTAssertEqual(isActive, true)
            XCTAssertEqual(overridingTitle, nil)
            XCTAssertEqual(overridingTitleInlineContent, nil)
        }
        withContentAsReference(list.items.dropFirst().first) { identifier, isActive, overridingTitle, overridingTitleInlineContent in
            XCTAssertEqual(identifier.identifier, "doc://special-characters/documentation/special-characters/article-with-emoji-in-heading#Hello-%F0%9F%8C%8D")
            XCTAssertEqual(isActive, true)
            XCTAssertEqual(overridingTitle, nil)
            XCTAssertEqual(overridingTitleInlineContent, nil)
        }
        withContentAsReference(list.items.dropFirst(2).first) { identifier, isActive, overridingTitle, overridingTitleInlineContent in
            XCTAssertEqual(identifier.identifier, "doc://special-characters/documentation/special-characters/article-with---in-filename")
            XCTAssertEqual(isActive, true)
            XCTAssertEqual(overridingTitle, nil)
            XCTAssertEqual(overridingTitleInlineContent, nil)
        }
        withContentAsReference(list.items.dropFirst(3).first) { identifier, isActive, overridingTitle, overridingTitleInlineContent in
            XCTAssertEqual(identifier.identifier, "doc://special-characters/documentation/special-characters/article-with---in-filename#Hello-world")
            XCTAssertEqual(isActive, true)
            XCTAssertEqual(overridingTitle, nil)
            XCTAssertEqual(overridingTitleInlineContent, nil)
        }
        withContentAsReference(list.items.dropFirst(4).first) { identifier, isActive, overridingTitle, overridingTitleInlineContent in
            XCTAssertEqual(identifier.identifier, "doc://special-characters/documentation/special-characters/Article:-with---various!-whitespace-&-punctuation.-in,-filename")
            XCTAssertEqual(isActive, true)
            XCTAssertEqual(overridingTitle, nil)
            XCTAssertEqual(overridingTitleInlineContent, nil)
        }
        withContentAsReference(list.items.dropFirst(5).first) { identifier, isActive, overridingTitle, overridingTitleInlineContent in
            XCTAssertEqual(identifier.identifier, "doc://special-characters/documentation/special-characters/Article:-with---various!-whitespace-&-punctuation.-in,-filename#Hello-world")
            XCTAssertEqual(isActive, true)
            XCTAssertEqual(overridingTitle, nil)
            XCTAssertEqual(overridingTitleInlineContent, nil)
        }
    
        // Verify that the topic render references have titles with special characters when the original content contained special characters
        XCTAssertEqual(
            (renderNode.references["doc://special-characters/documentation/MyKit/MyClass/myFunc_()"] as? TopicRenderReference)?.title,
            "myFunc🙂()"
        )
        XCTAssertEqual(
            (renderNode.references["doc://special-characters/documentation/special-characters/article-with-emoji-in-heading#Hello-%F0%9F%8C%8D"] as? TopicRenderReference)?.title,
            "Hello 🌍"
        )
        XCTAssertEqual(
            (renderNode.references["doc://special-characters/documentation/special-characters/article-with---in-filename"] as? TopicRenderReference)?.title,
            "Article with 😃 emoji in its filename"
        )
        XCTAssertEqual(
            (renderNode.references["doc://special-characters/documentation/special-characters/article-with---in-filename#Hello-world"] as? TopicRenderReference)?.title,
            "Hello world"
        )
        XCTAssertEqual(
            (renderNode.references["doc://special-characters/documentation/special-characters/Article:-with---various!-whitespace-&-punctuation.-in,-filename"] as? TopicRenderReference)?.title,
            "Article with various whitespace and punctuation in its filename"
        )
        XCTAssertEqual(
            (renderNode.references["doc://special-characters/documentation/special-characters/Article:-with---various!-whitespace-&-punctuation.-in,-filename#Hello-world"] as? TopicRenderReference)?.title,
            "Hello world"
        )
    }
    
    func testNonOverloadCollisionFromExtension() throws {
        // Add some symbol collisions to graph
        let (_, _, context) = try testBundleAndContext(copying: "TestBundle", excludingPaths: ["mykit-iOS.symbols.json"]) { root in
            let sideKitURL = root.appendingPathComponent("something@SideKit.symbols.json")
            let text = """
            {
              "metadata": { "formatVersion" : { "major" : 1 }, "generator" : "app/1.0" },
              "relationships" : [ ],
              "module" : {
                "name" : "Something",
                "platform" : {
                  "architecture" : "x86_64",
                  "vendor" : "apple",
                  "operatingSystem" : {
                    "name" : "ios",
                    "version" : {
                      "major" : 10,
                      "minor" : 15,
                      "patch" : 0
                    }
                  }
                }
              },
              "symbols" : [
                  {
                    "accessLevel" : "public",
                    "kind" : {
                      "identifier" : "swift.var",
                      "displayName" : "Variable"
                    },
                    "names" : {
                      "title" : "sideClass"
                    },
                    "pathComponents": [
                      "sideClass"
                    ],
                    "identifier" : {
                      "precise" : "s:5SideKit0A5SideClassVV",
                      "interfaceLanguage": "swift"
                    },
                    "declarationFragments" : [
                      {
                        "kind" : "text",
                        "spelling" : "var sideClass: String"
                      }
                    ]
                 }
              ]
            }
            """
            try text.write(to: sideKitURL, atomically: true, encoding: .utf8)
        }
        
        let symbolGraphProblems = context.problems
            .filter { $0.diagnostic.source?.lastPathComponent.hasSuffix(".symbols.json") ?? false }
            .filter { $0.diagnostic.severity != .information }
        XCTAssert(symbolGraphProblems.isEmpty, "There shouldn't be any errors or warnings in the symbol graphs")
        
        // Verify the non-overload collisions form different symbol graph files were resolved
        XCTAssertNoThrow(try context.entity(with: ResolvedTopicReference(bundleIdentifier: "org.swift.docc.example", path: "/documentation/SideKit/SideClass-swift.class", sourceLanguage: .swift)))
        XCTAssertNoThrow(try context.entity(with: ResolvedTopicReference(bundleIdentifier: "org.swift.docc.example", path: "/documentation/SideKit/SideClass-swift.class/path", sourceLanguage: .swift)))
        XCTAssertNoThrow(try context.entity(with: ResolvedTopicReference(bundleIdentifier: "org.swift.docc.example", path: "/documentation/SideKit/sideClass-swift.var", sourceLanguage: .swift)))
    }

    func testUnresolvedSidecarDiagnostics() throws {
        var unknownSymbolSidecarURL: URL!
        var otherUnknownSymbolSidecarURL: URL!
        
        let content = """
        # ``MyKit/UnknownSymbol``
        
        This symbol doesn't exist in the symbol graph.
        """
        
        // Add a sidecar file for a symbol that doesn't exist
        let (_, _, context) = try testBundleAndContext(copying: "TestBundle") { root in
            unknownSymbolSidecarURL = root.appendingPathComponent("documentation/unknownSymbol.md")
            otherUnknownSymbolSidecarURL = root.appendingPathComponent("documentation/anotherSidecarFileForThisUnknownSymbol.md")
            
            try content.write(to: unknownSymbolSidecarURL, atomically: true, encoding: .utf8)
            try content.write(to: otherUnknownSymbolSidecarURL, atomically: true, encoding: .utf8)
        }
        
        let unmatchedSidecarProblem = try XCTUnwrap(context.problems.first(where: { $0.diagnostic.identifier == "org.swift.docc.SymbolUnmatched" }))
        
        // Verify the diagnostics have the sidecar source URL
        XCTAssertNotNil(unmatchedSidecarProblem.diagnostic.source)
        let sidecarFilesForUnknownSymbol: Set<URL?> = [unknownSymbolSidecarURL.standardizedFileURL, otherUnknownSymbolSidecarURL.standardizedFileURL]
        
        XCTAssertNotNil(unmatchedSidecarProblem)
        let unmatchedSidecarDiagnostic = unmatchedSidecarProblem.diagnostic
        XCTAssertTrue(sidecarFilesForUnknownSymbol.contains(unmatchedSidecarDiagnostic.source?.standardizedFileURL), "One of the files should be the diagnostic source")
        XCTAssertEqual(unmatchedSidecarDiagnostic.range, SourceLocation(line: 1, column: 3, source: unmatchedSidecarProblem.diagnostic.source)..<SourceLocation(line: 1, column: 26, source: unmatchedSidecarProblem.diagnostic.source))
        
        XCTAssertEqual(unmatchedSidecarDiagnostic.summary, "No symbol matched 'MyKit/UnknownSymbol'. 'UnknownSymbol' doesn't exist at '/MyKit'.")
        XCTAssertEqual(unmatchedSidecarDiagnostic.severity, .warning)
    }
    
    func testExtendingSymbolWithSpaceInName() throws {
        let exampleDocumentation = Folder(name: "unit-test.docc", content: [
            JSONFile(name: "ModuleName.symbols.json", content: makeSymbolGraph(
                moduleName: "ModuleName",
                symbols: [
                    SymbolGraph.Symbol(
                        identifier: .init(precise: "symbol-id", interfaceLanguage: "swift"),
                        names: .init(title: "Symbol Name", navigator: nil, subHeading: nil, prose: nil),
                        pathComponents: ["Symbol Name"],
                        docComment: nil,
                        accessLevel: .public,
                        kind: .init(parsedIdentifier: .class, displayName: "Kind Display Name"),
                        mixins: [:]
                    )
                ]
            )),
            
            TextFile(name: "Extension.md", utf8Content: """
            # ``Symbol Name``
            
            Extend a symbol with a space in its name.
            """),
            
            TextFile(name: "Article.md", utf8Content: """
            # Article
            
            Link in content to a symbol with a space in its name: ``Symbol Name``.
            """),
        ])
        
        let tempURL = try createTempFolder(content: [exampleDocumentation])
        let (_, bundle, context) = try loadBundle(from: tempURL)
        
        XCTAssert(context.problems.isEmpty, "Unexpected problems: \(context.problems.map(\.diagnostic.summary).joined(separator: "\n"))")
        
        let reference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/ModuleName/Symbol_Name", sourceLanguage: .swift)
        let node = try context.entity(with: reference)
        
        XCTAssertEqual((node.semantic as? Symbol)?.abstract?.plainText, "Extend a symbol with a space in its name.")
    }

    func testDeprecationSummaryWithLocalLink() throws {
        let exampleDocumentation = Folder(name: "unit-test.docc", content: [
            JSONFile(name: "ModuleName.symbols.json", content: makeSymbolGraph(
                moduleName: "ModuleName",
                symbols: ["Old", "New"].map {
                    SymbolGraph.Symbol(
                        identifier: .init(precise: "\($0.lowercased())-symbol-id", interfaceLanguage: "swift"),
                        names: .init(title: "\($0)Symbol", navigator: nil, subHeading: nil, prose: nil),
                        pathComponents: ["\($0)Symbol"],
                        docComment: nil,
                        accessLevel: .public,
                        kind: .init(parsedIdentifier: .class, displayName: "Kind Display Name"),
                        mixins: [:]
                    )
                }
            )),
            
            TextFile(name: "Extension.md", utf8Content: """
            # ``OldSymbol``
            
            @DeprecationSummary {
              Use ``NewSymbol`` instead.
            }
            
            Deprecate a symbol and link to its replacement in the deprecation message.
            """),
            
            TextFile(name: "Article.md", utf8Content: """
            # Article
            
            @DeprecationSummary {
              Use ``NewSymbol`` instead.
            }
            
            Link to external content in an article deprecation message.
            """),
        ])
        
        let tempURL = try createTempFolder(content: [exampleDocumentation])
        let (_, bundle, context) = try loadBundle(from: tempURL)
        
        XCTAssert(context.problems.isEmpty, "Unexpected problems:\n\(context.problems.map(\.diagnostic.summary).joined(separator: "\n"))")
        
        do {
            let reference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/ModuleName/OldSymbol", sourceLanguage: .swift)
            let node = try context.entity(with: reference)
            
            let deprecatedSection = try XCTUnwrap((node.semantic as? Symbol)?.deprecatedSummary)
            XCTAssertEqual(deprecatedSection.content.count, 1)
            XCTAssertEqual(deprecatedSection.content.first?.format().trimmingCharacters(in: .whitespaces), "Use ``doc://unit-test/documentation/ModuleName/NewSymbol`` instead.", "The link should have been resolved")
        }
        
        do {
            let reference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/unit-test/Article", sourceLanguage: .swift)
            let node = try context.entity(with: reference)
            
            let deprecatedSection = try XCTUnwrap((node.semantic as? Article)?.deprecationSummary)
            XCTAssertEqual(deprecatedSection.count, 1)
            XCTAssertEqual(deprecatedSection.first?.format().trimmingCharacters(in: .whitespaces), "Use ``doc://unit-test/documentation/ModuleName/NewSymbol`` instead.", "The link should have been resolved")
        }
    }
    
    func testUncuratedArticleDiagnostics() throws {
        var unknownSymbolSidecarURL: URL!
        
        // Add an article without curating it anywhere
        // This will be uncurated because there's more than one module in TestBundle.
        let (_, _, context) = try testBundleAndContext(copying: "TestBundle") { root in
            unknownSymbolSidecarURL = root.appendingPathComponent("UncuratedArticle.md")
            
            try """
            # Title of this article
            
            This article won't be curated anywhere.
            """.write(to: unknownSymbolSidecarURL, atomically: true, encoding: .utf8)
        }
        
        let curationDiagnostics =  context.problems.filter({ $0.diagnostic.identifier == "org.swift.docc.ArticleUncurated" }).map(\.diagnostic)
        let sidecarDiagnostic = try XCTUnwrap(curationDiagnostics.first(where: { $0.source?.standardizedFileURL == unknownSymbolSidecarURL.standardizedFileURL }))
        XCTAssertNil(sidecarDiagnostic.range)
        XCTAssertEqual(sidecarDiagnostic.summary, "You haven't curated 'doc://org.swift.docc.example/documentation/Test-Bundle/UncuratedArticle'")
        XCTAssertEqual(sidecarDiagnostic.severity, .information)
    }
    
    func testUpdatesReferencesForChildrenOfCollisions() throws {
        // Add some symbol collisions to graph
        let (_, _, context) = try testBundleAndContext(copying: "TestBundle") { root in
            let sideKitURL = root.appendingPathComponent("sidekit.symbols.json")
            var text = try String(contentsOf: sideKitURL)
            
            text = text.replacingOccurrences(of: "\"relationships\" : [", with: """
            "relationships" : [
            {
              "source" : "s:7SideKit0A5ClassC10testSV",
              "target" : "s:7SideKit0A5ClassC",
              "kind" : "memberOf"
            },
            {
              "source" : "s:7SideKit0A5ClassC10testE",
              "target" : "s:7SideKit0A5ClassC",
              "kind" : "memberOf"
            },
            {
              "source" : "s:7SideKit0A5ClassC10tEstP",
              "target" : "s:7SideKit0A5ClassC10testE",
              "kind" : "memberOf"
            },
            {
              "source" : "s:7SideKit0A5ClassC10testEE",
              "target" : "s:7SideKit0A5ClassC10testE",
              "kind" : "memberOf"
            },
            {
              "source" : "s:7SideKit0A5ClassC10tEstPP",
              "target" : "s:7SideKit0A5ClassC10testEE",
              "kind" : "memberOf"
            },
            {
              "source" : "s:7SideKit0A5ClassC10testnEE",
              "target" : "s:7SideKit0A5ClassC10testE",
              "kind" : "memberOf"
            },
            """)
            
            text = text.replacingOccurrences(of: "\"symbols\" : [", with: """
            "symbols" : [
            {
              "accessLevel" : "public",
              "kind" : {
                "identifier" : "swift.enum",
                "displayName" : "Enumeration"
              },
              "names" : { "title" : "Test" },
              "pathComponents" : [ "SideClass", "Test" ],
              "identifier" : {
                "precise" : "s:7SideKit0A5ClassC10testE",
                "interfaceLanguage": "swift"
              }
            },
            {
              "accessLevel" : "public",
              "kind" : {
                "identifier" : "swift.variable",
                "displayName" : "Type Variable"
              },
              "names" : { "title" : "test" },
              "pathComponents" : [ "SideClass", "test" ],
              "identifier" : {
                "precise" : "s:7SideKit0A5ClassC10testSV",
                "interfaceLanguage": "swift"
              }
            },
            {
              "accessLevel" : "public",
              "kind" : {
                "identifier" : "swift.variable",
                "displayName" : "Type Variable"
              },
              "names" : { "title" : "path" },
              "pathComponents" : [ "SideClass", "Test", "path" ],
              "identifier" : {
                "precise" : "s:7SideKit0A5ClassC10tEstP",
                "interfaceLanguage": "swift"
              }
            },
            {
              "accessLevel" : "public",
              "kind" : {
                "identifier" : "swift.enum",
                "displayName" : "Enumeration"
              },
              "names" : { "title" : "NestedEnum" },
              "pathComponents" : [ "SideClass", "Test", "NestedEnum" ],
              "identifier" : {
                "precise" : "s:7SideKit0A5ClassC10testEE",
                "interfaceLanguage": "swift"
              }
            },
            {
              "accessLevel" : "public",
              "kind" : {
                "identifier" : "swift.property",
                "displayName" : "Instance Property"
              },
              "names" : { "title" : "nestedEnum" },
              "pathComponents" : [ "SideClass", "Test", "nestedEnum" ],
              "identifier" : {
                "precise" : "s:7SideKit0A5ClassC10testnEE",
                "interfaceLanguage": "swift"
              }
            },
            {
              "accessLevel" : "public",
              "kind" : {
                "identifier" : "swift.variable",
                "displayName" : "Type Variable"
              },
              "names" : { "title" : "path" },
              "pathComponents" : [ "SideClass", "Test", "NestedEnum", "path" ],
              "identifier" : {
                "precise" : "s:7SideKit0A5ClassC10tEstPP",
                "interfaceLanguage": "swift"
              }
            },
            """)
            try text.write(to: sideKitURL, atomically: true, encoding: .utf8)
        }

        // Test that collision symbol reference was updated
        XCTAssertNoThrow(try context.entity(with: ResolvedTopicReference(bundleIdentifier: "org.swift.docc.example", path: "/documentation/SideKit/SideClass/Test-swift.enum", sourceLanguage: .swift)))
        
        // Test that collision symbol child reference was updated
        XCTAssertNoThrow(try context.entity(with: ResolvedTopicReference(bundleIdentifier: "org.swift.docc.example", path: "/documentation/SideKit/SideClass/Test-swift.enum/path", sourceLanguage: .swift)))

        // Test that nested collisions were updated
        XCTAssertNoThrow(try context.entity(with: ResolvedTopicReference(bundleIdentifier: "org.swift.docc.example", path: "/documentation/SideKit/SideClass/Test-swift.enum/NestedEnum-swift.enum", sourceLanguage: .swift)))
        XCTAssertNoThrow(try context.entity(with: ResolvedTopicReference(bundleIdentifier: "org.swift.docc.example", path: "/documentation/SideKit/SideClass/Test-swift.enum/nestedEnum-swift.property", sourceLanguage: .swift)))
        
        // Test that child of nested collision is updated
        XCTAssertNoThrow(try context.entity(with: ResolvedTopicReference(bundleIdentifier: "org.swift.docc.example", path: "/documentation/SideKit/SideClass/Test-swift.enum/NestedEnum-swift.enum/path", sourceLanguage: .swift)))
        
        // Verify that the symbol index has been updated with the rewritten collision-corrected symbol paths
        XCTAssertEqual(context.documentationCache.reference(symbolID: "s:7SideKit0A5ClassC10testnEE")?.path, "/documentation/SideKit/SideClass/Test-swift.enum/nestedEnum-swift.property")
        XCTAssertEqual(context.documentationCache.reference(symbolID: "s:7SideKit0A5ClassC10testEE")?.path, "/documentation/SideKit/SideClass/Test-swift.enum/NestedEnum-swift.enum")
        XCTAssertEqual(context.documentationCache.reference(symbolID: "s:7SideKit0A5ClassC10tEstPP")?.path, "/documentation/SideKit/SideClass/Test-swift.enum/NestedEnum-swift.enum/path")
        
        XCTAssertEqual(context.documentationCache.reference(symbolID: "s:5MyKit0A5MyProtocol0Afunc()")?.path, "/documentation/SideKit/SideProtocol/func()-6ijsi")
        XCTAssertEqual(context.documentationCache.reference(symbolID: "s:5MyKit0A5MyProtocol0Afunc()DefaultImp")?.path, "/documentation/SideKit/SideProtocol/func()-2dxqn")
    }

    func testResolvingArticleLinkBeforeCuratingIt() throws {
        var newArticle1URL: URL!
        
        // Add an article without curating it anywhere
        let (_, _, context) = try testBundleAndContext(copying: "TestBundle") { root in
            /// Curate MyKit -> new-article1
            let myKitURL = root.appendingPathComponent("documentation").appendingPathComponent("mykit.md")
            try """
                # ``MyKit``
                
                ## Topics
                ### New articles
                - <doc:new-article1>
                - <doc:new-article2>
                """
                .write(to: myKitURL, atomically: true, encoding: .utf8)
            /// Curate new-article1 -> new-article2
            newArticle1URL = root.appendingPathComponent("documentation").appendingPathComponent("new-article1.md")
            try """
                # New Article 1
                Abstracts can't have links.

                Paragraph with a link to <doc:new-article2>
                """
                .write(to: newArticle1URL, atomically: true, encoding: .utf8)
            
            /// Add new-article2
            let newArticle2URL = root.appendingPathComponent("documentation").appendingPathComponent("new-article2.md")
            try """
                # New Article 2
                Placeholder abstract.
                """
                .write(to: newArticle2URL, atomically: true, encoding: .utf8)
        }
        
        // Verify that there are no problems for new-article1.md (where we resolve the link to new-article2 before it's curated)
        XCTAssertEqual(context.problems.filter { $0.diagnostic.source?.path.hasSuffix(newArticle1URL.lastPathComponent) == true }.count, 0)
    }

    func testPrefersNonSymbolsInDocLink() throws {
        let (_, bundle, context) = try testBundleAndContext(copying: "SymbolsWithSameNameAsModule") { url in
            // This bundle has a top-level struct named "Wrapper". Adding an article named "Wrapper.md" introduces a possibility for a link collision
            try """
            # An article
            
            This is an article with the same name as a top-level symbol
            """.write(to: url.appendingPathComponent("Wrapper.md"), atomically: true, encoding: .utf8)
            
            // Also change the display name so that the article container has the same name as the module.
            try InfoPlist(displayName: "Something", identifier: "com.example.Something").write(inside: url)
            
            // Use a doc-link to curate the article.
            try """
            # ``Something``
            
            Curate the article and the symbol top-level.
            
            ## Topics
            
            - <doc:Wrapper>
            """.write(to: url.appendingPathComponent("Something.md"), atomically: true, encoding: .utf8)
        }
        
        let moduleReference = try XCTUnwrap(context.rootModules.first)
        let moduleNode = try context.entity(with: moduleReference)
        
        let renderContext = RenderContext(documentationContext: context, bundle: bundle)
        let converter = DocumentationContextConverter(bundle: bundle, context: context, renderContext: renderContext)
        let source = context.documentURL(for: moduleReference)
        
        let renderNode = try XCTUnwrap(converter.renderNode(for: moduleNode, at: source))
        let curatedTopic = try XCTUnwrap(renderNode.topicSections.first?.identifiers.first)
        
        let topicReference = try XCTUnwrap(renderNode.references[curatedTopic] as? TopicRenderReference)
        XCTAssertEqual(topicReference.title, "An article")
        
        // This test also reproduce https://github.com/apple/swift-docc/issues/593
        // When that's fixed this test should also use a symbol link to curate the top-level symbol and verify that
        // the symbol link resolves to the symbol.
    }
    
    // Modules that are being extended should not have their own symbol in the current bundle's graph.
    func testNoSymbolForTertiarySymbolGraphModules() throws {
        // Add an article without curating it anywhere
        let (_, _, context) = try testBundleAndContext(copying: "TestBundle") { root in
            /// Create an extension only symbol graph.
            let tertiaryURL = root.appendingPathComponent("Tertiary@MyKit.symbols.json")
            try """
                {
                  "metadata": {
                    "formatVersion": { "major": 48, "minor": 1516, "patch": 2342 },
                    "generator": "Apple Swift version 5.3-dev (LLVM f7753df930, Swift a3cf3737d4)"
                  },
                  "module": {
                    "name": "Tertiary",
                    "platform": {
                      "architecture": "x86_64",
                      "vendor": "apple",
                      "operatingSystem": {
                        "name": "macosx",
                        "minimumVersion": { "major": 10, "minor": 10, "patch": 0
                        }
                      }
                    }
                  },
                  "symbols": [],
                  "relationships": []
                }
                """
                .write(to: tertiaryURL, atomically: true, encoding: .utf8)
        }

        // Verify that the Tertiary framework has no symbol in the graph
        XCTAssertNotNil(try? context.entity(with: ResolvedTopicReference(bundleIdentifier: "org.swift.docc.example", path: "/documentation/MyKit", sourceLanguage: .swift)))
        XCTAssertNil(try? context.entity(with: ResolvedTopicReference(bundleIdentifier: "org.swift.docc.example", path: "/documentation/Tertiary", sourceLanguage: .swift)))
    }
    
    func testDeclarationTokenKinds() throws {
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        
        let myFunc = try context.entity(with: ResolvedTopicReference(bundleIdentifier: "org.swift.docc.example", path: "/documentation/MyKit/MyClass/myFunction()", sourceLanguage: .swift))
        
        // Symbol graph declaration tokens, including more esoteric kinds like internalParam, externalParam, and unknown kinds.
        let tokens = (myFunc.symbol!.mixins[SymbolGraph.Symbol.DeclarationFragments.mixinKey] as? SymbolGraph.Symbol.DeclarationFragments)?
            .declarationFragments
            .map({ fragment -> String in
                return fragment.kind.rawValue
            })
        XCTAssertEqual(tokens, ["keyword", "text", "identifier", "text", "externalParam", "text", "internalParam", "unhandledTokenKind", "text"])
        
        // Render declaration and compare token kinds with symbol graph
        let symbol = myFunc.semantic as! Symbol
        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: myFunc.reference, source: nil)
        let renderNode = translator.visitSymbol(symbol) as! RenderNode
        
        let declarationTokens = renderNode.primaryContentSections.mapFirst { section -> [String]? in
            guard section.kind == .declarations,
                let declarations = section as? DeclarationsRenderSection,
                let declaration = declarations.declarations.first
                else { return nil }
            return declaration.tokens.map({ token in return token.kind.rawValue })
        }
        
        // Verify the unhandled token kind is defaulting to "text"
        XCTAssertEqual(declarationTokens, tokens?.map({ return $0 == "unhandledTokenKind" ? "text" : $0 }))
    }
    
    // Test reference resolving in symbol graph docs
    func testReferenceResolvingDiagnosticsInSourceDocs() throws {
        for (source, expectedDiagnosticSource) in [
            ("file:///path/to/file.swift", "file:///path/to/file.swift"),
            // Test the scenario where the symbol graph file contains invalid URLs (rdar://77335208).
            ("file:///path with spaces/to/file.swift", "file:///path%20with%20spaces/to/file.swift"),
        ] {
            // Create an empty bundle
            let targetURL = try createTemporaryDirectory(named: "test.docc")
            
            // Copy test Info.plist
            try FileManager.default.copyItem(at: Bundle.module.url(
                forResource: "TestBundle", withExtension: "docc", subdirectory: "Test Bundles")!
                                                .appendingPathComponent("Info.plist"),
                                             to: targetURL.appendingPathComponent("Info.plist")
            )
            
            // Create symbol graph
            let referencesURL = targetURL.appendingPathComponent("references.symbols.json")
            let text = """
            {
              "metadata": { "formatVersion" : { "major" : 1 }, "generator" : "app/1.0" },
              "module" : {
                "name" : "References",
                "platform" : {
                  "architecture" : "x86_64",
                  "vendor" : "apple",
                  "operatingSystem" : { "name" : "ios", "version" : { "major" : 48, "minor" : 1516, "patch" : 2342 } }
                }
              },
              "relationships" : [
                
              ],
              "symbols" : [
                   {
                     "accessLevel" : "public",
                     "kind" : { "identifier" : "swift.class", "displayName" : "Class" },
                     "names" : { "title" : "RefClass" },
                     "pathComponents": [ "RefClass" ],
                     "identifier" : {
                       "precise" : "RefClass",
                       "interfaceLanguage": "swift"
                     },
                     "docComment" : {
                       "lines" : [
                         {
                             "range": {
                               "start": { "line": 16, "character": 8 },
                               "end": { "line": 16, "character": 56 }
                             },
                             "text" : "Resolvable: ``refVariable``, ``References``, ``References/refVariable``. Unresolvable: ``Foundation/URL``."
                         }
                       ]
                    },
                    "location": {
                      "uri": "\(source)",
                      "position": { "line": 10, "character": 10 }
                    }
                  },
            
                  {
                    "accessLevel" : "public",
                    "kind" : { "identifier" : "swift.var", "displayName" : "Variable" },
                    "names" : { "title" : "refVariable" },
                    "pathComponents": [ "refVariable" ],
                    "identifier" : {
                      "precise" : "refVariable",
                      "interfaceLanguage": "swift"
                    },
                    "docComment" : {
                      "lines" : [
                        {
                            "range": {
                              "start": { "line": 16, "character": 8 },
                              "end": { "line": 16, "character": 56 }
                            },
                            "text" : "Resolvable: ``refVariable``, ``References``, ``References/refVariable``, ``RefClass``"
                        },
                        {
                          "range": {
                            "start": { "line": 17, "character": 8 },
                            "end": { "line": 17, "character": 56 }
                          },
                          "text" : "Unresolvable: ``refVariable123``, ``References1``, ``References1/refVariable``, ``RefClass/refVariable``"
                        }
                      ]
                    },
                    "location": {
                      "uri": "\(source)",
                      "position": { "line": 20, "character": 10 }
                    }
                 }
              ]
            }
            """
            try text.write(to: referencesURL, atomically: true, encoding: .utf8)
            
            // Load the bundle & reference resolve symbol graph docs
            let (_, _, context) = try loadBundle(from: targetURL, codeListings: [:])
            
            guard context.problems.count == 5 else {
                XCTFail("Expected 5 problems during reference resolving; got \(context.problems.count)")
                return
            }
            
            // All problems should be unresolved references
            XCTAssertTrue(context.problems.allSatisfy({ $0.diagnostic.identifier == "org.swift.docc.unresolvedTopicReference" }))
            
            XCTAssert(context.problems.allSatisfy { $0.diagnostic.source?.absoluteString == expectedDiagnosticSource })
            
            // Verify the expected source ranges
            XCTAssertEqual(
                context.problems.map { "\($0.diagnostic.range!.lowerBound.line):\($0.diagnostic.range!.lowerBound.column)" }.sorted(),
                ["17:98", "18:100", "18:25", "18:45", "18:62"].sorted()
            )
        }
    }
    
    func renderNodeForPath(path: String) throws -> (DocumentationNode, RenderNode) {
        let workspace = DocumentationWorkspace()
        let context = try DocumentationContext(dataProvider: workspace)
        let bundle = try testBundle(named: "TestBundle")
        let dataProvider = PrebuiltLocalFileSystemDataProvider(bundles: [bundle])
        try workspace.registerProvider(dataProvider)
        
        let reference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: path, sourceLanguage: .swift)
        let node = try context.entity(with: reference)

        let symbol = node.semantic as! Symbol
        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: reference, source: nil)
        let renderNode = translator.visitSymbol(symbol) as! RenderNode

        return (node, renderNode)
    }
    
    func testNavigatorTitle() throws {
        do {
            let (node, renderNode) = try renderNodeForPath(path: "/documentation/MyKit/MyClass")

            // Testing the model is parsing both subHeading and navigator keys correctly
            XCTAssertEqual((node.semantic as? Symbol)?.subHeading?.map { $0.spelling }, ["class", " ", "MyClass"])
            XCTAssertEqual((node.semantic as? Symbol)?.navigator?.map { $0.spelling }, ["MyClassNavigator"])
            
            // Testing correct rendering of the metadata keys
            XCTAssertEqual(renderNode.metadata.fragments?.map { $0.text }, ["class", " ", "MyClass"])
            XCTAssertEqual(renderNode.metadata.navigatorTitle?.map { $0.text }, ["MyClassNavigator"])
        }
        
        do {
            let (_, renderNode) = try renderNodeForPath(path: "/documentation/MyKit")

            guard let renderReference = renderNode.references["doc://org.swift.docc.example/documentation/MyKit/MyClass"] as? TopicRenderReference else {
                XCTFail("MyClass render reference not found")
                return
            }
            
            // Testing correct rendering of the render reference keys
            XCTAssertEqual(renderReference.fragments?.map { $0.text }, ["class", " ", "MyClass"])
            XCTAssertEqual(renderReference.navigatorTitle?.map { $0.text }, ["MyClassNavigator"])
        }
    }
    
    func testCrossSymbolGraphPathCollisions() throws {
        // Create temp folder
        let tempURL = try createTemporaryDirectory()

        // Create test bundle
        let bundleURL = try Folder(name: "collisions.docc", content: [
            InfoPlist(displayName: "Collisions", identifier: "com.test.collisions"),
            CopyOfFile(original: Bundle.module.url(
                        forResource: "Collisions-iOS.symbols", withExtension: "json",
                        subdirectory: "Test Resources")!),
            CopyOfFile(original: Bundle.module.url(
                        forResource: "Collisions-macOS.symbols", withExtension: "json",
                        subdirectory: "Test Resources")!),
        ]).write(inside: tempURL)
        
        // Load test bundle
        let (_, _, context) = try loadBundle(from: bundleURL)
        
        let referenceForPath: (String) -> ResolvedTopicReference = { path in
            return ResolvedTopicReference(bundleIdentifier: "com.test.collisions", path: "/documentation" + path, sourceLanguage: .swift)
        }
        
        // Verify that:
        // 1. Symbol collisions from different graphs "Collisions-iOS.symbols.json" and "Collisions-macOS.symbols.json"
        // were detected and resolved
        XCTAssertNotNil(try context.entity(with: referenceForPath("/Collisions/SharedStruct/testFunc(_:)-73bpa")))
        XCTAssertNotNil(try context.entity(with: referenceForPath("/Collisions/SharedStruct/testFunc(_:)-734tu")))

        // 2. The same symbol from different graphs was not detected as a collision
        XCTAssertNotNil(try context.entity(with: referenceForPath("/Collisions/SharedStruct")))

        // 3. The symbols from all graphs are merged into the topic graph
        XCTAssertNotNil(try context.entity(with: referenceForPath("/Collisions/SharedStruct/iOSVar")))
    }
    
    func testLinkToSymbolWithoutPage() throws {
        let inheritedDefaultImplementationsSGF = Bundle.module.url(
            forResource: "InheritedDefaultImplementations.symbols",
            withExtension: "json",
            subdirectory: "Test Resources"
        )!
        let inheritedDefaultImplementationsAtSwiftSGF = Bundle.module.url(
            forResource: "InheritedDefaultImplementations@Swift.symbols",
            withExtension: "json",
            subdirectory: "Test Resources"
        )!
        
        let testBundle = try Folder(
            name: "unit-test.docc",
            content: [
                CopyOfFile(original: inheritedDefaultImplementationsSGF),
                CopyOfFile(original: inheritedDefaultImplementationsAtSwiftSGF),
                TextFile(name: "doc-extension.md", utf8Content: """
                # ``FirstTarget``
                
                Link to a default implementation symbol that doesn't have a page in this build.
                
                - ``Comparable/localDefaultImplementation()``
                """)
            ]
        ).write(inside: createTemporaryDirectory())
        
        let (_, _, context) = try loadBundle(from: testBundle)
        
        let problem = try XCTUnwrap(context.problems.first(where: { $0.diagnostic.identifier == "org.swift.docc.unresolvedTopicReference" }))
        XCTAssertEqual(problem.diagnostic.summary, "'FirstTarget/Comparable/localDefaultImplementation()' has no page and isn't available for linking.")
    }
    
    func testContextCachesReferences() throws {
        let bundleID = #function
        // Verify there is no pool bucket for the bundle we're about to test
        XCTAssertNil(ResolvedTopicReference._numberOfCachedReferences(bundleID: bundleID))
        
        let (_, _, _) = try testBundleAndContext(copying: "TestBundle", excludingPaths: [], codeListings: [:], configureBundle: { rootURL in
            let infoPlistURL = rootURL.appendingPathComponent("Info.plist", isDirectory: false)
            try! String(contentsOf: infoPlistURL)
                .replacingOccurrences(of: "org.swift.docc.example", with: bundleID)
                .write(to: infoPlistURL, atomically: true, encoding: .utf8)
        })

        // Verify there is a pool bucket for the bundle we've loaded
        XCTAssertNotNil(ResolvedTopicReference._numberOfCachedReferences(bundleID: bundleID))
        
        let beforeCount = try XCTUnwrap(ResolvedTopicReference._numberOfCachedReferences(bundleID: bundleID))
        
        // Verify a given identifier exists in the pool by creating it and verifying it wasn't added to the pool
        _ = ResolvedTopicReference(bundleIdentifier: bundleID, path: "/tutorials/Test-Bundle/TestTutorial", sourceLanguage: .swift)
        
        // Verify create the reference above did not add to the cache
        XCTAssertEqual(beforeCount, ResolvedTopicReference._numberOfCachedReferences(bundleID: bundleID))
        
        // Create a new reference for the same bundle that was not loaded with the context
        _ = ResolvedTopicReference(bundleIdentifier: bundleID, path: "/tutorials/Test-Bundle/TestTutorial/\(#function)", sourceLanguage: .swift)
        
        // Verify creating a new reference added to the ones loaded with the context
        XCTAssertNotEqual(beforeCount, ResolvedTopicReference._numberOfCachedReferences(bundleID: bundleID))
        
        ResolvedTopicReference.purgePool(for: bundleID)
    }
    
    func testAbstractAfterMetadataDirective() throws {
        let (_, context) = try testBundleAndContext(named: "TestBundle")
        
        // Get the SideKit/SideClass/init() node and verify it has an abstract and no discussion.
        // We're verifying that the metadata directive between the title and the abstract didn't cause
        // the content to overflow into the discussion.
        let node = try context.entity(with: ResolvedTopicReference(bundleIdentifier: "org.swift.docc.example", path: "/documentation/SideKit/SideClass/init()", sourceLanguage: .swift))
        let markupModel = DocumentationMarkup(markup: node.markup)
        XCTAssertNotNil(markupModel.abstractSection)
        
        // FIXME: A Discussion section is incorrectly getting created because of a comment. Comments shouldn't be
        // considered as content and hence not create a Discussion section. (rdar://79719308)
        // XCTAssertNil(markupModel.discussionSection)
    }

    /// rdar://69242313
    func testLinkResolutionDoesNotSkipSymbolGraph() throws {
        let tempURL = try createTemporaryDirectory()
        
        let bundleURL = try Folder(name: "Missing.docc", content: [
            InfoPlist(displayName: "MissingDocs", identifier: "com.test.missing-docs"),
            CopyOfFile(original: Bundle.module.url(
                        forResource: "MissingDocs.symbols", withExtension: "json",
                        subdirectory: "Test Resources")!),
        ]).write(inside: tempURL)
        
        let (_, _, context) = try XCTUnwrap(loadBundle(from: bundleURL))
        
        // MissingDocs contains a struct that has a link to a non-existent type.
        // If there are no problems, that indicates that symbol graph link
        // resolution was skipped.
        XCTAssertEqual(context.problems.count, 1)
    }
    
    func testCreatingAnArticleNode() throws {
        // Create documentation node from markup
        let reference = ResolvedTopicReference(bundleIdentifier: "com.testbundle", path: "/documentation/NewArticle", fragment: nil, sourceLanguage: .swift)
        
        let source = """
        # New Article
        Article Abstract.
        """
        // Assert we can create a documentation node from markup
        let markupArticle = Article(markup: Document(parsing: source), metadata: nil, redirects: nil, options: [:])
        XCTAssertNoThrow(try DocumentationNode(reference: reference, article: markupArticle))
        
        // Assert we cannot create new nodes from semantic article data
        let semanticArticle = Article(title: Heading(level: 1, [Text("New Article")]), abstractSection: nil, discussion: nil, topics: nil, seeAlso: nil, deprecationSummary: nil, metadata: nil, redirects: nil)
        XCTAssertThrowsError(try DocumentationNode(reference: reference, article: semanticArticle))
    }
    
    func testTaskGroupsPersistInitialRangesFromMarkup() throws {
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")

        // Verify task group ranges are persisted for symbol docs
        let symbolReference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/MyKit", sourceLanguage: .swift)
        let symbol = try XCTUnwrap((try? context.entity(with: symbolReference))?.semantic as? Symbol)
        let symbolTopics = try XCTUnwrap(symbol.topics)
        symbolTopics.originalLinkRangesByGroup.forEach { group in
            XCTAssertTrue(group.allSatisfy({ $0 != nil }))
        }
        
        // Verify task group ranges are persisted for articles
        let articleReference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/Test-Bundle/article", sourceLanguage: .swift)
        let article = try XCTUnwrap((try? context.entity(with: articleReference))?.semantic as? Article)
        let articleTopics = try XCTUnwrap(article.topics)
        articleTopics.originalLinkRangesByGroup.forEach { group in
            XCTAssertTrue(group.allSatisfy({ $0 != nil }))
        }
    }
    
    func testTaskGroupsOverwriteInitialRanges() throws {
        let newTopics = TopicsSection(content: [], originalLinkRangesByGroup: [[
            SourceLocation(line: 9, column: 41, source: URL(fileURLWithPath: "/howardst/747.md"))..<SourceLocation(line: 9, column: 42, source: URL(fileURLWithPath: "/howardst/747.md")),
        ]])
        
        guard let range = try XCTUnwrap(newTopics.originalLinkRangesByGroup.first?.first) else {
            XCTFail("Did not find original range")
            return
        }
        
        XCTAssertEqual(range.lowerBound.line, 9)
        XCTAssertEqual(range.lowerBound.column, 41)
        XCTAssertEqual(range.lowerBound.source?.path, "/howardst/747.md")
    }

    /// Tests that diagnostics raised during link resolution for symbols have the correct source URLs
    /// - Bug: rdar://63288817
    func testDiagnosticsForSymbolsHaveCorrectSource() throws {
        let (_, _, context) = try testBundleAndContext(copying: "TestBundle") { url in
            let extensionFile = """
            # ``SideKit/SideClass/myFunction()``

            myFunction abstract

            ## Overview

            This is unresolvable: <doc:Does-Not-Exist>.

            """
            let fileURL = url.appendingPathComponent("documentation").appendingPathComponent("myFunction.md")
            try extensionFile.write(to: fileURL, atomically: true, encoding: .utf8)
        }
        let problems = context.diagnosticEngine.problems
        let linkResolutionProblems = problems.filter { $0.diagnostic.source?.relativePath.hasSuffix("myFunction.md") == true }
        XCTAssertEqual(linkResolutionProblems.count, 1)
        let problem = try XCTUnwrap(linkResolutionProblems.first)
        XCTAssertEqual(problem.diagnostic.range?.lowerBound.line, 7)
        XCTAssertEqual(problem.diagnostic.range?.lowerBound.column, 28)
        XCTAssertEqual(problem.diagnostic.range?.upperBound.line, 7)
        XCTAssertEqual(problem.diagnostic.range?.upperBound.column, 42)

        let functionNode = try XCTUnwrap(context.documentationCache["s:7SideKit0A5ClassC10myFunctionyyF"])
        XCTAssertEqual(functionNode.docChunks.count, 2)
        let docCommentChunks = functionNode.docChunks.compactMap { chunk -> DocumentationNode.DocumentationChunk? in
            switch chunk.source {
            case .sourceCode: return chunk
            default: return nil
            }
        }
        XCTAssertEqual(docCommentChunks.count, 1)

        let extensionFileChunks = functionNode.docChunks.compactMap { chunk -> DocumentationNode.DocumentationChunk? in
            switch chunk.source {
            case .documentationExtension: return chunk
            default: return nil
            }
        }
        XCTAssertEqual(extensionFileChunks.count, 1)
    }

    func testLinkResolutionDiagnosticsEmittedForTechnologyPages() throws {
        let tempURL = try createTemporaryDirectory()

        let bundleURL = try Folder(name: "module-links.docc", content: [
            InfoPlist(displayName: "Test", identifier: "com.test.docc"),
            CopyOfFile(original: Bundle.module.url(
                forResource: "TestBundle",
                withExtension: "docc",
                subdirectory: "Test Bundles"
            )!.appendingPathComponent("sidekit.symbols.json")),
            TextFile(name: "sidekit.md", utf8Content: """
                # ``SideKit``

                SideKit module root symbol

                ## Overview

                This link can't be resolved: <doc:Does-Not-Exist>

                ## Topics

                ### Basics

                - ``SideClass``
                - ``SideProtocol``
                """),
        ]).write(inside: tempURL)

        let (_, _, context) = try loadBundle(from: bundleURL)
        let problems = context.diagnosticEngine.problems
        let linkResolutionProblems = problems.filter { $0.diagnostic.source?.relativePath.hasSuffix("sidekit.md") == true }
        XCTAssertEqual(linkResolutionProblems.count, 1)
        XCTAssertEqual(linkResolutionProblems.first?.diagnostic.identifier, "org.swift.docc.unresolvedTopicReference")
    }
    
    func testResolvingLinksToHeaders() throws {
        let tempURL = try createTemporaryDirectory()

        let bundleURL = try Folder(name: "module-links.docc", content: [
            InfoPlist(displayName: "Test", identifier: "com.test.docc"),
            TextFile(name: "article.md", utf8Content: """
                # Top Level Article
                
                @Metadata {
                  @TechnologyRoot
                }
                
                A top level article with various headers with special characters
                
                ## Overview
                
                All these header can be linked to
                
                ### Comma: first, second
                
                ### Apostrophe: first's second
                
                ### Prime: first′s second
                
                ### En dash: first–second
                
                ### Double hyphen: first--second
                
                ### Em dash: first—second
                                                
                ### Triple hyphen: first---second
                
                ### Emoji: 💻
                
                ## Topics
                
                ### Links to on-page headings
                
                - <doc:article#Comma:-first,-second>
                - <doc:article#Comma:-first-second>
                
                - <doc:article#Apostrophe:-first's-second>
                - <doc:article#Apostrophe:-firsts-second>
                
                - <doc:article#Prime:-first′s-second>
                - <doc:article#Prime:-firsts-second>
                
                - <doc:article#En-dash:-first–second>
                - <doc:article#En-dash:-first-second>
                
                - <doc:article#Double-hyphen:-first--second>
                - <doc:article#Double-hyphen:-first-second>
                
                - <doc:article#Em-dash:-first-second>
                - <doc:article#Em-dash:-first---second>
                
                - <doc:article#Triple-hyphen:-first---second>
                - <doc:article#Triple-hyphen:-first-second>
                
                - <doc:article#Emoji:-💻>
                - <doc:article#Emoji:-%F0%9F%92%BB>
                
                """),
        ]).write(inside: tempURL)

        let (_, _, context) = try loadBundle(from: bundleURL)
        
        let articleReference = try XCTUnwrap(context.knownPages.first)
        let node = try context.entity(with: articleReference)
        let article = try XCTUnwrap(node.semantic as? Article)
        
        let taskGroup = try XCTUnwrap(article.topics?.taskGroups.first)
        XCTAssertEqual(taskGroup.heading?.plainText, "Links to on-page headings")
        XCTAssertEqual(taskGroup.links.count, 16)
        
        XCTAssertEqual(node.anchorSections.first?.title, "Overview")
        for (index, anchor) in node.anchorSections.dropFirst().dropLast().enumerated() {
            XCTAssertEqual(taskGroup.links.dropFirst(index * 2 + 0).first?.destination, anchor.reference.absoluteString)
            XCTAssertEqual(taskGroup.links.dropFirst(index * 2 + 1).first?.destination, anchor.reference.absoluteString)
        }
        
        XCTAssertEqual(node.anchorSections.dropFirst().first?.reference.absoluteString, "doc://com.test.docc/documentation/article#Comma-first-second")
        XCTAssertEqual(node.anchorSections.dropFirst(2).first?.reference.absoluteString, "doc://com.test.docc/documentation/article#Apostrophe-firsts-second")
        XCTAssertEqual(node.anchorSections.dropFirst(3).first?.reference.absoluteString, "doc://com.test.docc/documentation/article#Prime-firsts-second")
        
        XCTAssertEqual(node.anchorSections.dropLast(3).last?.reference.absoluteString, "doc://com.test.docc/documentation/article#Em-dash-first-second")
        XCTAssertEqual(node.anchorSections.dropLast(2).last?.reference.absoluteString, "doc://com.test.docc/documentation/article#Triple-hyphen-first-second")
        XCTAssertEqual(node.anchorSections.dropLast().last?.reference.absoluteString, "doc://com.test.docc/documentation/article#Emoji-%F0%9F%92%BB")
    }

    func testResolvingLinksToTopicSections() throws {
        let fileSystem = try TestFileSystem(folders: [
            Folder(name: "unit-test.docc", content: [
                JSONFile(name: "ModuleName.symbols.json", content: makeSymbolGraph(moduleName: "ModuleName")),
                
                TextFile(name: "ModuleName.md", utf8Content: """
                # ``ModuleName``
                
                A symbol with two topic section
                
                ## Topics
                
                ### One
                
                - <doc:First>
                
                ### Two
                
                - <doc:Second>
                """),
                
                TextFile(name: "First.md", utf8Content: """
                # The first article
                
                An article with a top-level topic section
                
                ## Topics
                
                - <doc:Third>
                """),
                
                TextFile(name: "Second.md", utf8Content: """
                # The second article
                
                An article with a named topic section
                
                ## Topics
                
                ### Some, topic - section!
                
                - <doc:Third>
                """),
                
                TextFile(name: "Third.md", utf8Content: """
                # The third article
                
                An article that links to the various topic sections
                
                - <doc:ModuleName#One>
                - <doc:ModuleName#Two>
                - <doc:First#Topics>
                - <doc:Second#Some-topic-section>
                - <doc:Third#Another-topic-section>
                - <doc:#Another-topic-section>
                
                ## Topics
                
                ### Another topic section
                
                - <doc:Fourth>
                """),
                
                TextFile(name: "Fourth.md", utf8Content: """
                # The fourth article
                
                An article that only exists to be linked to
                """),
            ])
        ])
        
        let workspace = DocumentationWorkspace()
        let context = try DocumentationContext(dataProvider: workspace)
        try workspace.registerProvider(fileSystem)
        
        XCTAssert(context.problems.isEmpty, "Unexpected problems: \(context.problems.map(\.diagnostic.summary).sorted())")
        
        let reference = try XCTUnwrap(context.knownPages.first(where: { $0.lastPathComponent == "Third" }))
        let entity = try context.entity(with: reference)
        
        struct LinkAggregator: MarkupWalker {
            var destinations: [String] = []
            
            mutating func visitLink(_ link: Link) -> () {
                if let destination = link.destination {
                    destinations.append(destination)
                }
            }
            mutating func visitSymbolLink(_ symbolLink: SymbolLink) -> () {
                if let destination = symbolLink.destination {
                    destinations.append(destination)
                }
            }
        }
        
        // Verify that the links are resolved in the in-memory model
        
        var linkAggregator = LinkAggregator()
        let list = try XCTUnwrap((entity.semantic as? Article)?.discussion?.content.first as? UnorderedList)
        linkAggregator.visit(list)
        
        XCTAssertEqual(linkAggregator.destinations, [
            "doc://unit-test/documentation/ModuleName#One",
            "doc://unit-test/documentation/ModuleName#Two",
            "doc://unit-test/documentation/unit-test/First#Topics",
            "doc://unit-test/documentation/unit-test/Second#Some-topic-section",
            "doc://unit-test/documentation/unit-test/Third#Another-topic-section",
            "doc://unit-test/documentation/unit-test/Third#Another-topic-section",
        ])
        
        // Verify that the links are resolved in the render model.
        let bundle = try XCTUnwrap(context.registeredBundles.first)
        let converter = DocumentationNodeConverter(bundle: bundle, context: context)
        let renderNode = try converter.convert(entity, at: nil)
        
        XCTAssertEqual(renderNode.topicSections.map(\.anchor), [
            "Another-topic-section"
        ])
        
        let firstReference = try XCTUnwrap(context.knownPages.first(where: { $0.lastPathComponent == "First" }))
        let firstRenderNode = try converter.convert(context.entity(with: firstReference), at: nil)
        XCTAssertEqual(firstRenderNode.topicSections.map(\.anchor), [
            "Topics"
        ])
        
        let secondReference = try XCTUnwrap(context.knownPages.first(where: { $0.lastPathComponent == "Second" }))
        let secondRenderNode = try converter.convert(context.entity(with: secondReference), at: nil)
        XCTAssertEqual(secondRenderNode.topicSections.map(\.anchor), [
            "Some-topic-section"
        ])
        
        let overviewSection = try XCTUnwrap(renderNode.primaryContentSections.first as? ContentRenderSection)
        guard case .unorderedList(let unorderedList) = overviewSection.content.dropFirst().first else {
            XCTFail("The first element of the Overview section (after the heading) should be an unordered list")
            return
        }
        
        XCTAssertEqual(unorderedList.items.map(\.content.firstParagraph.first), [
            .reference(identifier: RenderReferenceIdentifier("doc://unit-test/documentation/ModuleName#One"), isActive: true, overridingTitle: nil, overridingTitleInlineContent: nil),
            .reference(identifier: RenderReferenceIdentifier("doc://unit-test/documentation/ModuleName#Two"), isActive: true, overridingTitle: nil, overridingTitleInlineContent: nil),
            .reference(identifier: RenderReferenceIdentifier("doc://unit-test/documentation/unit-test/First#Topics"), isActive: true, overridingTitle: nil, overridingTitleInlineContent: nil),
            .reference(identifier: RenderReferenceIdentifier("doc://unit-test/documentation/unit-test/Second#Some-topic-section"), isActive: true, overridingTitle: nil, overridingTitleInlineContent: nil),
            .reference(identifier: RenderReferenceIdentifier("doc://unit-test/documentation/unit-test/Third#Another-topic-section"), isActive: true, overridingTitle: nil, overridingTitleInlineContent: nil),
            .reference(identifier: RenderReferenceIdentifier("doc://unit-test/documentation/unit-test/Third#Another-topic-section"), isActive: true, overridingTitle: nil, overridingTitleInlineContent: nil),
        ])
    }
    
    func testExtensionCanUseLanguageSpecificRelativeLinks() throws {
        // This test uses a symbol with different names in Swift and Objective-C, each with a member that's only available in that language.
        let symbolID = "some-symbol-id"
        let fileSystem = try TestFileSystem(folders: [
            Folder(name: "unit-test.docc", content: [
                Folder(name: "swift", content: [
                    JSONFile(name: "ModuleName.symbols.json", content: makeSymbolGraph(
                        moduleName: "ModuleName",
                        symbols: [
                            .init(
                                identifier: .init(precise: symbolID, interfaceLanguage: SourceLanguage.swift.id),
                                names: .init(title: "SwiftName", navigator: nil, subHeading: nil, prose: nil),
                                pathComponents: ["SwiftName"],
                                docComment: nil,
                                accessLevel: .public,
                                kind: .init(parsedIdentifier: .class, displayName: "Kind Display Name"),
                                mixins: [:]
                            ),
                            .init(
                                identifier: .init(precise: "swift-only-member-id", interfaceLanguage: SourceLanguage.swift.id),
                                names: .init(title: "swiftOnlyMemberName", navigator: nil, subHeading: nil, prose: nil),
                                pathComponents: ["SwiftName", "swiftOnlyMemberName"],
                                docComment: nil,
                                accessLevel: .public,
                                kind: .init(parsedIdentifier: .property, displayName: "Kind Display Name"),
                                mixins: [:]
                            ),
                        ], relationships: [
                            .init(source: "swift-only-member-id", target: symbolID, kind: .memberOf, targetFallback: nil)
                        ])
                    ),
                ]),
                
                Folder(name: "clang", content: [
                    JSONFile(name: "ModuleName.symbols.json", content: makeSymbolGraph(
                        moduleName: "ModuleName",
                        symbols: [
                            .init(
                                identifier: .init(precise: symbolID, interfaceLanguage: SourceLanguage.objectiveC.id),
                                names: .init(title: "ObjectiveCName", navigator: nil, subHeading: nil, prose: nil),
                                pathComponents: ["ObjectiveCName"],
                                docComment: nil,
                                accessLevel: .public,
                                kind: .init(parsedIdentifier: .class, displayName: "Kind Display Name"),
                                mixins: [:]
                            ),
                            .init(
                                identifier: .init(precise: "objc-only-member-id", interfaceLanguage: SourceLanguage.objectiveC.id),
                                names: .init(title: "objectiveCOnlyMemberName", navigator: nil, subHeading: nil, prose: nil),
                                pathComponents: ["ObjectiveCName", "objectiveCOnlyMemberName"],
                                docComment: nil,
                                accessLevel: .public,
                                kind: .init(parsedIdentifier: .property, displayName: "Kind Display Name"),
                                mixins: [:]
                            ),
                        ], relationships: [
                            .init(source: "objc-only-member-id", target: symbolID, kind: .memberOf, targetFallback: nil)
                        ])
                    ),
                ]),
                
                TextFile(name: "Extension.md", utf8Content: """
                # ``SwiftName``
                
                A documentation extension that uses both language's language specific links to curate the same symbol 6 times (2 that fail with warnings)
                
                ## Topics
                
                ### Relative links
                
                - ``swiftOnlyMemberName``
                - ``objectiveCOnlyMemberName``
                
                ### Correct absolute links
                
                - ``SwiftName/swiftOnlyMemberName``
                - ``ObjectiveCName/objectiveCOnlyMemberName``
                
                ### Incorrect absolute links
                
                - ``ObjectiveCName/swiftOnlyMemberName``
                - ``SwiftName/objectiveCOnlyMemberName``
                """),
            ])
        ])
        
        let workspace = DocumentationWorkspace()
        let context = try DocumentationContext(dataProvider: workspace)
        try workspace.registerProvider(fileSystem)
        
        XCTAssertEqual(context.problems.map(\.diagnostic.summary).sorted(), [
            "'objectiveCOnlyMemberName' doesn't exist at '/ModuleName/SwiftName'",
            "'swiftOnlyMemberName' doesn't exist at '/ModuleName/ObjectiveCName'",
        ])
        
        let reference = ResolvedTopicReference(bundleIdentifier: "unit-test", path: "/documentation/ModuleName/SwiftName", sourceLanguage: .swift)
        let entity = try context.entity(with: reference)
        let symbol = try XCTUnwrap(entity.semantic as? Symbol)
        let taskGroups = try XCTUnwrap(symbol.topics).taskGroups
        
        XCTAssertEqual(taskGroups.map { $0.links.map(\.destination) }, [
            // Relative links
            [
                "doc://unit-test/documentation/ModuleName/SwiftName/swiftOnlyMemberName",
                "doc://unit-test/documentation/ModuleName/ObjectiveCName/objectiveCOnlyMemberName",
            ],
            // Correct absolute links
            [
                "doc://unit-test/documentation/ModuleName/SwiftName/swiftOnlyMemberName",
                "doc://unit-test/documentation/ModuleName/ObjectiveCName/objectiveCOnlyMemberName",
            ],
            // Incorrect absolute links
            [
                // This links remain as they were authored because they didn't resolve
                "ObjectiveCName/swiftOnlyMemberName",
                "SwiftName/objectiveCOnlyMemberName",
            ]
        ])
    }
    
    func testWarnOnMultipleMarkdownExtensions() throws {
        let fileContent = """
        # ``MyKit/MyClass/myFunction()``

        A cool function

        ## Overview
        The function overview
        """
        let exampleDocumentation = Folder(name: "MyKit.docc", content: [
            Folder(name: "Symbols", content: [
                CopyOfFile(original: Bundle.module.url(forResource: "mykit-one-symbol.symbols", withExtension: "json", subdirectory: "Test Resources")!),
            ]),
            Folder(name: "MyKit", content: [
                TextFile(name: "MyFunc.md", utf8Content: fileContent),
                TextFile(name: "MyFunc2.md", utf8Content: fileContent),
            ]),
            TextFile(name: "MyKit.md", utf8Content: """
            # ``MyKit``

            Some cool docs

            ## Topics

            ### Articles
            - ``MyKit/MyClass/myFunction()``
            """),
            InfoPlist(displayName: "MyKit", identifier: "com.test.MyKit"),
        ])
        let tempURL = try createTemporaryDirectory()
        let bundleURL = try exampleDocumentation.write(inside: tempURL)

        // Parse this test content
        let (_, _, context) = try loadBundle(from: bundleURL)

        let identifier = "org.swift.docc.DuplicateMarkdownTitleSymbolReferences"
        let duplicateMarkdownProblems = context.problems.filter({ $0.diagnostic.identifier == identifier })
        XCTAssertEqual(duplicateMarkdownProblems.count, 1)
        XCTAssertEqual(duplicateMarkdownProblems.first?.diagnostic.summary, "Multiple documentation extensions matched 'MyKit/MyClass/myFunction()'.")
        XCTAssertEqual(duplicateMarkdownProblems.first?.diagnostic.notes.count, 1)
        XCTAssertEqual(duplicateMarkdownProblems.first?.diagnostic.notes.first?.message, "'MyKit/MyClass/myFunction()' is also documented here.")
    }
    
    /// This test verifies that collision nodes and children of collision nodes are correctly
    /// matched with their documentation extension files. Besides verifying the correct content
    /// it verifies also that the curation in these doc extensions is reflected in the topic graph.
    func testMatchesCorrectlyDocExtensionToChildOfCollisionTopic() throws {
        let fifthTestMemberPath = "ShapeKit/OverloadedParentStruct-1jr3p/fifthTestMember"
        
        let (_, bundle, context) = try testBundleAndContext(copying: "OverloadedSymbols") { url in
            // Add an article to be curated from collided nodes' doc extensions.
            try """
            # New Article
            Article abstract.
            """.write(to: url.appendingPathComponent("NewArticle.md"), atomically: true, encoding: .utf8)
            
            // Add doc extension file for a collision symbol
            try """
            # ``ShapeKit/OverloadedParentStruct-1jr3p``
            OverloadedParentStruct abstract.
            ## Topics
            ### Basics
            - <doc:NewArticle>
            """.write(to: url.appendingPathComponent("OverloadedParentStruct.md"), atomically: true, encoding: .utf8)

            // Add doc extension file for a child of a collision symbol
            try """
            # ``ShapeKit/OverloadedParentStruct-1jr3p/fifthTestMember-swift.type.property``
            fifthTestMember abstract.
            ## Topics
            ### Basics
            - <doc:NewArticle>
            """.write(to: url.appendingPathComponent("fifthTestMember.md"), atomically: true, encoding: .utf8)
            
            // Add doc extension file for a child of a collision symbol
            try """
            # ``\(fifthTestMemberPath)``
            fifthTestMember abstract.
            ## Topics
            ### Basics
            - <doc:NewArticle>
            """.write(to: url.appendingPathComponent("fifthTestMember.md"), atomically: true, encoding: .utf8)
        }
        
        let articleReference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/ShapeKit/NewArticle", sourceLanguage: .swift)
        
        // Fetch the "OverloadedParentStruct" node
        let reference1 = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/ShapeKit/OverloadedParentStruct-1jr3p", sourceLanguage: .swift)
        let node1 = try context.entity(with: reference1)
        let symbol1 = try XCTUnwrap(node1.semantic as? Symbol)
        
        // Verify the doc extension content was loaded.
        XCTAssertEqual(symbol1.abstract?.plainText, "OverloadedParentStruct abstract.")

        // Verify the doc extension curation, thanks to the new link resolving this is an absolute identifier.
        XCTAssertEqual(symbol1.topics?.taskGroups.first?.links.first?.destination, "doc://com.shapes.ShapeKit/documentation/ShapeKit/NewArticle")
        let tgNode1 = try XCTUnwrap(context.topicGraph.edges[reference1])
        XCTAssertTrue(tgNode1.contains(articleReference))
        
        // Fetch the "fifthTestMember" node
        let reference2 = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/\(fifthTestMemberPath)", sourceLanguage: .swift)
       
        let node2 = try context.entity(with: reference2)
        let symbol2 = try XCTUnwrap(node2.semantic as? Symbol)
        
        // Verify the doc extension content was loaded.
        XCTAssertEqual(symbol2.abstract?.plainText, "fifthTestMember abstract.")

        // Verify the doc extension curation, thanks to the new link resolving this is an absolute identifier.
        XCTAssertEqual(symbol2.topics?.taskGroups.first?.links.first?.destination, "doc://com.shapes.ShapeKit/documentation/ShapeKit/NewArticle")

        // Verify the correct topic graph parent <-> child relationship is created.
        let tgNode2 = try XCTUnwrap(context.topicGraph.edges[reference2])
        XCTAssertTrue(tgNode2.contains(articleReference))
    }
    
    func testMatchesDocumentationExtensionsAsSymbolLinks() throws {
        let (_, bundle, context) = try testBundleAndContext(copying: "MixedLanguageFrameworkWithLanguageRefinements") { url in
            // Two colliding symbols that differ by capitalization.
            try """
            # ``MixedFramework/CollisionsWithDifferentCapitalization/someThing``
            
            @Metadata {
              @DocumentationExtension(mergeBehavior: override)
            }
            
            some thing
            
            This documentation extension link doesn't need disambiguation because "someThing" is capitalized differently than "something".
            """.write(to: url.appendingPathComponent("some-thing.md"), atomically: true, encoding: .utf8)
            
            try """
            # ``MixedFramework/CollisionsWithDifferentCapitalization/something``
            
            @Metadata {
              @DocumentationExtension(mergeBehavior: override)
            }

            something
            
            This documentation extension link doesn't need disambiguation because "something" is capitalized differently than "someThing".
            """.write(to: url.appendingPathComponent("something.md"), atomically: true, encoding: .utf8)
            
            // Three colliding symbols that differ by symbol kind.
            try """
            # ``MixedFramework/CollisionsWithEscapedKeywords/subscript()-method``
            
            @Metadata {
              @DocumentationExtension(mergeBehavior: override)
            }
            
            method
            
            This documentation extension link can be disambiguated with only the kind information (without the language).
            """.write(to: url.appendingPathComponent("method.md"), atomically: true, encoding: .utf8)

            try """
            # ``MixedFramework/CollisionsWithEscapedKeywords/subscript()-subscript``

            @Metadata {
              @DocumentationExtension(mergeBehavior: override)
            }
            
            subscript
            
            This documentation extension link can be disambiguated with only the kind information (without the language).
            """.write(to: url.appendingPathComponent("subscript.md"), atomically: true, encoding: .utf8)

            try """
            # ``MixedFramework/CollisionsWithEscapedKeywords/subscript()-type.method``
            
            @Metadata {
              @DocumentationExtension(mergeBehavior: override)
            }
            
            type method
            
            This documentation extension link can be disambiguated with only the kind information (without the language).
            """.write(to: url.appendingPathComponent("type-method.md"), atomically: true, encoding: .utf8)
        }
        
        do {
            // The resolved reference needs more disambiguation than the documentation extension link did.
            let reference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/MixedFramework/CollisionsWithDifferentCapitalization/someThing-90i4h", sourceLanguage: .swift)
            
            let node = try context.entity(with: reference)
            let symbol = try XCTUnwrap(node.semantic as? Symbol)
            XCTAssertEqual(symbol.abstract?.plainText, "some thing", "The abstract should be from the overriding documentation extension.")
        }
        
        do {
            // The resolved reference needs more disambiguation than the documentation extension link did.
            let reference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/MixedFramework/CollisionsWithDifferentCapitalization/something-2c4k6", sourceLanguage: .swift)
            
            let node = try context.entity(with: reference)
            let symbol = try XCTUnwrap(node.semantic as? Symbol)
            XCTAssertEqual(symbol.abstract?.plainText, "something", "The abstract should be from the overriding documentation extension.")
        }
        
        do {
            // The resolved reference needs the language info alongside the symbol kind info.
            let reference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/MixedFramework/CollisionsWithEscapedKeywords/subscript()-swift.method", sourceLanguage: .swift)
            
            let node = try context.entity(with: reference)
            let symbol = try XCTUnwrap(node.semantic as? Symbol)
            XCTAssertEqual(symbol.abstract?.plainText, "method", "The abstract should be from the overriding documentation extension.")
        }
        
        do {
            // The resolved reference needs the language info alongside the symbol kind info.
            let reference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/MixedFramework/CollisionsWithEscapedKeywords/subscript()-swift.subscript", sourceLanguage: .swift)
            
            let node = try context.entity(with: reference)
            let symbol = try XCTUnwrap(node.semantic as? Symbol)
            XCTAssertEqual(symbol.abstract?.plainText, "subscript", "The abstract should be from the overriding documentation extension.")
        }
        
        do {
            // The resolved reference needs the language info alongside the symbol kind info.
            let reference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/MixedFramework/CollisionsWithEscapedKeywords/subscript()-swift.type.method", sourceLanguage: .swift)
            
            let node = try context.entity(with: reference)
            let symbol = try XCTUnwrap(node.semantic as? Symbol)
            XCTAssertEqual(symbol.abstract?.plainText, "type method", "The abstract should be from the overriding documentation extension.")
        }
    }
    
    func testMatchesDocumentationExtensionsWithSourceLanguageSpecificLinks() throws {
        let (_, bundle, context) = try testBundleAndContext(copying: "MixedLanguageFrameworkWithLanguageRefinements") { url in
            // typedef NS_OPTIONS(NSInteger, MyObjectiveCOption) {
            //     MyObjectiveCOptionNone                                      = 0,
            //     MyObjectiveCOptionFirst                                     = 1 << 0,
            //     MyObjectiveCOptionSecond NS_SWIFT_NAME(secondCaseSwiftName) = 1 << 1
            // };
            try """
            # ``MixedFramework/MyObjectiveCOption/MyObjectiveCOptionFirst``
            
            @Metadata {
              @DocumentationExtension(mergeBehavior: override)
            }
            
            Objective-C option case
            
            This documentation extension link uses the Objective-C spelling to refer to the "first" option case.
            """.write(to: url.appendingPathComponent("objc-case.md"), atomically: true, encoding: .utf8)
            
            try """
            # ``MixedFramework/MyObjectiveCOption/secondCaseSwiftName``
            
            @Metadata {
              @DocumentationExtension(mergeBehavior: override)
            }
            
            Swift spelling of Objective-C option case
            
            This documentation extension link uses the customized Swift spelling to refer to the "second" option case.
            """.write(to: url.appendingPathComponent("objc-case-swift-name.md"), atomically: true, encoding: .utf8)
            
            // NS_SWIFT_NAME(MyObjectiveCClassSwiftName)
            // @interface MyObjectiveCClassObjectiveCName : NSObject
            //
            // @property (copy, readonly) NSString * myPropertyObjectiveCName NS_SWIFT_NAME(myPropertySwiftName);
            //
            // - (void)myMethodObjectiveCName NS_SWIFT_NAME(myMethodSwiftName());
            // - (void)myMethodWithArgument:(NSString *)argument NS_SWIFT_NAME(myMethod(argument:));
            //
            // @end
            try """
            # ``MixedFramework/MyObjectiveCClassObjectiveCName/myMethodWithArgument:``
            
            @Metadata {
              @DocumentationExtension(mergeBehavior: override)
            }
            
            Objective-C method with one argument
            
            This documentation extension link uses the Objective-C spelling to refer to the method with an argument.
            """.write(to: url.appendingPathComponent("objc-method.md"), atomically: true, encoding: .utf8)
            
            try """
            # ``MixedFramework/MyObjectiveCClassSwiftName/myMethodSwiftName()``
            
            @Metadata {
              @DocumentationExtension(mergeBehavior: override)
            }
            
            Swift spelling for Objective-C method without arguments
            
            This documentation extension link uses the customized Swift spelling to refer to the method without an argument.
            """.write(to: url.appendingPathComponent("objc-method-swift-name.md"), atomically: true, encoding: .utf8)
        }
        
        do {
            // The resolved reference needs more disambiguation than the documentation extension link did.
            let reference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/MixedFramework/MyObjectiveCOption/first", sourceLanguage: .swift)
            
            let node = try context.entity(with: reference)
            let symbol = try XCTUnwrap(node.semantic as? Symbol)
            XCTAssertEqual(symbol.abstract?.plainText, "Objective-C option case", "The abstract should be from the overriding documentation extension.")
        }
        
        do {
            // The resolved reference needs more disambiguation than the documentation extension link did.
            let reference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/MixedFramework/MyObjectiveCOption/secondCaseSwiftName", sourceLanguage: .swift)
            
            let node = try context.entity(with: reference)
            let symbol = try XCTUnwrap(node.semantic as? Symbol)
            XCTAssertEqual(symbol.abstract?.plainText, "Swift spelling of Objective-C option case", "The abstract should be from the overriding documentation extension.")
        }
        
        do {
            // The resolved reference needs the language info alongside the symbol kind info.
            let reference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/MixedFramework/MyObjectiveCClassSwiftName/myMethod(argument:)", sourceLanguage: .swift)
            
            let node = try context.entity(with: reference)
            let symbol = try XCTUnwrap(node.semantic as? Symbol)
            XCTAssertEqual(symbol.abstract?.plainText, "Objective-C method with one argument", "The abstract should be from the overriding documentation extension.")
        }
        
        do {
            // The resolved reference needs the language info alongside the symbol kind info.
            let reference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/MixedFramework/MyObjectiveCClassSwiftName/myMethodSwiftName()", sourceLanguage: .swift)
            
            let node = try context.entity(with: reference)
            let symbol = try XCTUnwrap(node.semantic as? Symbol)
            XCTAssertEqual(symbol.abstract?.plainText, "Swift spelling for Objective-C method without arguments", "The abstract should be from the overriding documentation extension.")
        }
    }
    
    func testMatchesDocumentationExtensionsRelativeToModule() throws {
        let (_, bundle, context) = try testBundleAndContext(copying: "MixedLanguageFrameworkWithLanguageRefinements") { url in
            // Top level symbols, omitting the module name
            try """
            # ``MyStruct/myStructProperty``
            
            @Metadata {
              @DocumentationExtension(mergeBehavior: override)
            }
            
            my struct property
            """.write(to: url.appendingPathComponent("struct-property.md"), atomically: true, encoding: .utf8)
            
            try """
            # ``MyTypeAlias``
            
            @Metadata {
              @DocumentationExtension(mergeBehavior: override)
            }
            
            my type alias
            """.write(to: url.appendingPathComponent("alias.md"), atomically: true, encoding: .utf8)
        }
        
        do {
            // The resolved reference needs more disambiguation than the documentation extension link did.
            let reference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/MixedFramework/MyStruct/myStructProperty", sourceLanguage: .swift)
            
            let node = try context.entity(with: reference)
            let symbol = try XCTUnwrap(node.semantic as? Symbol)
            XCTAssertEqual(symbol.abstract?.plainText, "my struct property", "The abstract should be from the overriding documentation extension.")
        }
        
        do {
            // The resolved reference needs more disambiguation than the documentation extension link did.
            let reference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/MixedFramework/MyTypeAlias", sourceLanguage: .swift)
            
            let node = try context.entity(with: reference)
            let symbol = try XCTUnwrap(node.semantic as? Symbol)
            XCTAssertEqual(symbol.abstract?.plainText, "my type alias", "The abstract should be from the overriding documentation extension.")
        }
    }
    
    func testCurationOfSymbolsWithSameNameAsModule() throws {
        let (_, bundle, context) = try testBundleAndContext(copying: "SymbolsWithSameNameAsModule") { url in
            // Top level symbols, omitting the module name
            try """
            # ``Something``
            
            This documentation extension covers the module symbol
            
            ## Topics
            
            This link curates the top-level struct
            
            - ``Something``
            """.write(to: url.appendingPathComponent("something.md"), atomically: true, encoding: .utf8)
        }
        
        do {
            // The resolved reference needs more disambiguation than the documentation extension link did.
            let reference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/Something", sourceLanguage: .swift)
            
            let node = try context.entity(with: reference)
            let symbol = try XCTUnwrap(node.semantic as? Symbol)
            XCTAssertEqual(symbol.abstract?.plainText, "This documentation extension covers the module symbol", "The abstract should be from the overriding documentation extension.")
            
            let topics = try XCTUnwrap(symbol.topics?.taskGroups.first)
            XCTAssertEqual(topics.abstract?.paragraph.plainText, "This link curates the top-level struct")
            XCTAssertEqual(topics.links.first?.destination, "doc://SymbolsWithSameNameAsModule/documentation/Something/Something")
        }
    }
    
    func testMultipleDocumentationExtensionMatchDiagnostic() throws {
        let (_, _, context) = try testBundleAndContext(copying: "MixedLanguageFrameworkWithLanguageRefinements") { url in
            // typedef NS_OPTIONS(NSInteger, MyObjectiveCOption) {
            //     MyObjectiveCOptionNone                                      = 0,
            //     MyObjectiveCOptionFirst                                     = 1 << 0,
            //     MyObjectiveCOptionSecond NS_SWIFT_NAME(secondCaseSwiftName) = 1 << 1
            // };
            try """
            # ``MixedFramework/MyObjectiveCOption/MyObjectiveCOptionFirst``
            
            This documentation extension link uses the Objective-C spelling to refer to the "first" option case.
            """.write(to: url.appendingPathComponent("objc-case.md"), atomically: true, encoding: .utf8)
            
            try """
            # ``MixedFramework/MyObjectiveCOption/first``
            
            This documentation extension link uses the customized Swift spelling to refer to the "first" option case.
            """.write(to: url.appendingPathComponent("objc-case-swift-name.md"), atomically: true, encoding: .utf8)
            
            // NS_SWIFT_NAME(MyObjectiveCClassSwiftName)
            // @interface MyObjectiveCClassObjectiveCName : NSObject
            //
            // @property (copy, readonly) NSString * myPropertyObjectiveCName NS_SWIFT_NAME(myPropertySwiftName);
            //
            // - (void)myMethodObjectiveCName NS_SWIFT_NAME(myMethodSwiftName());
            // - (void)myMethodWithArgument:(NSString *)argument NS_SWIFT_NAME(myMethod(argument:));
            //
            // @end
            try """
            # ``MixedFramework/MyObjectiveCClassObjectiveCName/myMethodWithArgument:``
            
            This documentation extension link uses the Objective-C spelling to refer to the method with an argument.
            """.write(to: url.appendingPathComponent("objc-method.md"), atomically: true, encoding: .utf8)
            
            try """
            # ``MixedFramework/MyObjectiveCClassSwiftName/myMethod(argument:)``
            
            This documentation extension link uses the customized Swift spelling to refer to the method with an argument.
            """.write(to: url.appendingPathComponent("objc-method-swift-name.md"), atomically: true, encoding: .utf8)
        }
        
        let multipleDocExtensionProblems = context.problems.filter({ $0.diagnostic.identifier == "org.swift.docc.DuplicateMarkdownTitleSymbolReferences" })
        XCTAssertEqual(multipleDocExtensionProblems.count, 2)
        
        let enumCaseMultipleMatchProblem = try XCTUnwrap(multipleDocExtensionProblems.first(where: { $0.diagnostic.summary == "Multiple documentation extensions matched 'MixedFramework/MyObjectiveCOption/first'." }))
        XCTAssert(["objc-case.md", "objc-case-swift-name.md"].contains(enumCaseMultipleMatchProblem.diagnostic.source?.lastPathComponent ?? ""), "The warning should refer to one of the documentation extensions files")
        XCTAssertEqual(enumCaseMultipleMatchProblem.diagnostic.notes.count, 1)
        XCTAssert(["objc-case.md", "objc-case-swift-name.md"].contains(enumCaseMultipleMatchProblem.diagnostic.notes.first?.source.lastPathComponent ?? ""), "The note should refer to one of the documentation extension files")
        XCTAssertNotEqual(enumCaseMultipleMatchProblem.diagnostic.source, enumCaseMultipleMatchProblem.diagnostic.notes.first?.source, "The warning and the note should refer to different documentation extension files")
        
        let methodMultipleMatchProblem = try XCTUnwrap(multipleDocExtensionProblems.first(where: { $0.diagnostic.summary == "Multiple documentation extensions matched 'MixedFramework/MyObjectiveCClassSwiftName/myMethod(argument:)'." }))
        XCTAssert(["objc-method.md", "objc-method-swift-name.md"].contains(methodMultipleMatchProblem.diagnostic.source?.lastPathComponent ?? ""), "The warning should refer to one of the documentation extensions files")
        XCTAssertEqual(methodMultipleMatchProblem.diagnostic.notes.count, 1)
        XCTAssert(["objc-method.md", "objc-method-swift-name.md"].contains(methodMultipleMatchProblem.diagnostic.notes.first?.source.lastPathComponent ?? ""), "The note should refer to one of the documentation extension files")
        XCTAssertNotEqual(methodMultipleMatchProblem.diagnostic.source, methodMultipleMatchProblem.diagnostic.notes.first?.source, "The warning and the note should refer to different documentation extension files")
    }
    
    func testAutomaticallyCuratesArticles() throws {
        let articleOne = TextFile(name: "Article1.md", utf8Content: """
            # Article 1

            ## Topics
            ### Group
            - <doc:DoesNotResolve>
            """)
        
        let articleTwo = TextFile(name: "Article2.md", utf8Content: """
            # Article 2

            ## Topics
            ### Group
            - <doc:Article1>
            """)
        
        do {
            let tempURL = try createTemporaryDirectory()
            
            let bundleURL = try Folder(name: "Module.docc", content: [
                InfoPlist(displayName: "Module", identifier: "org.swift.docc.example"),
                TextFile(name: "Module.md", utf8Content: """
                # Autocurated Articles

                @Metadata {
                  @TechnologyRoot
                }
                
                This bundle contains a single module, and the articles should be automatically curated.
                """),
                articleOne,
                articleTwo,
            ]).write(inside: tempURL)
            let (_, bundle, context) = try loadBundle(from: bundleURL)
            
            let identifiers = context.problems.map(\.diagnostic.identifier)
            XCTAssertFalse(identifiers.contains(where: { $0 == "org.swift.docc.ArticleUncurated" }))
            
            let rootReference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/Module", sourceLanguage: .swift)
            let docNode = try context.entity(with: rootReference)
            let article = try XCTUnwrap(docNode.semantic as? Article)
            XCTAssertNil(article.topics)

            XCTAssertEqual(article.automaticTaskGroups.count, 1)
            
            let taskGroup = try XCTUnwrap(article.automaticTaskGroups.first)
            XCTAssertEqual(taskGroup.title, "Articles")
            XCTAssertEqual(taskGroup.references.count, 2)
            XCTAssert(taskGroup.references.map(\.absoluteString).contains("doc://org.swift.docc.example/documentation/Module/Article1"))
            XCTAssert(taskGroup.references.map(\.absoluteString).contains("doc://org.swift.docc.example/documentation/Module/Article2"))
        }
        
        do {
            let tempURL = try createTemporaryDirectory()
            
            let bundleURL = try Folder(name: "Module.docc", content: [
                InfoPlist(displayName: "Module", identifier: "org.swift.docc.example"),
                TextFile(name: "Module.md", utf8Content: """
                    # Autocurated Articles

                    @Metadata {
                      @TechnologyRoot
                    }
                    
                    This bundle contains a single module, and the articles should be automatically curated.
                    
                    ## Topics
                    ### Links
                    - <doc:Article2>
                    """),
                articleOne,
                articleTwo,
            ]).write(inside: tempURL)
            let (_, bundle, context) = try loadBundle(from: bundleURL)
            
            let rootReference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/Module", sourceLanguage: .swift)
            let docNode = try context.entity(with: rootReference)
            let article = try XCTUnwrap(docNode.semantic as? Article)
            XCTAssertNotNil(article.topics)
            XCTAssertTrue(article.automaticTaskGroups.isEmpty, "No automatic task groups should have been created as there are no uncurated articles left after curating Article2.")
        }
    }
    
    func testAutomaticTaskGroupsPlacedAfterManualCuration() throws {
        let tempURL = try createTemporaryDirectory()
        
        let bundleURL = try Folder(name: "Module.docc", content: [
            InfoPlist(displayName: "Module", identifier: "org.swift.docc.example"),
            TextFile(name: "Module.md", utf8Content: """
                # Autocurated Articles

                @Metadata {
                  @TechnologyRoot
                }
                
                This bundle contains a single module, and the articles should be automatically curated.
                
                ## Topics
                ### Links
                - <doc:Article1>
                """),
            TextFile(name: "Article1.md", utf8Content: """
                # Article 1

                ## Topics
                ### Group
                - <doc:DoesNotResolve>
                """),
            TextFile(name: "Article2.md", utf8Content: """
                # Article 2
                
                ## Topics
                ### Group
                - <doc:Article1>
                """),
        ]).write(inside: tempURL)
        let (_, bundle, context) = try loadBundle(from: bundleURL)
        
        let rootReference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/Module", sourceLanguage: .swift)
        let docNode = try context.entity(with: rootReference)
        let article = try XCTUnwrap(docNode.semantic as? Article)
        
        let topics = try XCTUnwrap(article.topics)
        XCTAssertEqual(topics.taskGroups.count, 1)
        let manualTaskGroup = try XCTUnwrap(topics.taskGroups.first)
        XCTAssertEqual(manualTaskGroup.heading?.title, "Links")
        XCTAssertEqual(manualTaskGroup.links.count, 1)
        XCTAssertEqual(manualTaskGroup.links.first?.destination, "doc://org.swift.docc.example/documentation/Module/Article1")
        
        XCTAssertEqual(article.automaticTaskGroups.count, 1)
        
        let taskGroup = try XCTUnwrap(article.automaticTaskGroups.first)
        XCTAssertEqual(taskGroup.title, "Articles")
        XCTAssertEqual(taskGroup.references.count, 1)
        XCTAssert(taskGroup.references.map(\.absoluteString).contains("doc://org.swift.docc.example/documentation/Module/Article2"))
    }
    
    // Verifies if the context resolves linkable nodes.
    func testLinkableNodes() throws {
        let (_, bundle, context) = try testBundleAndContext(copying: "TestBundle") { url in
            try "# Article1".write(to: url.appendingPathComponent("resolvable-article.md"), atomically: true, encoding: .utf8)
            let myKitURL = url.appendingPathComponent("documentation").appendingPathComponent("mykit.md")
            try String(contentsOf: myKitURL)
                .replacingOccurrences(of: " - <doc:article>", with: " - <doc:resolvable-article>")
                .write(to: myKitURL, atomically: true, encoding: .utf8)
        }
        let moduleReference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/MyKit", sourceLanguage: .swift)

        // Try resolving the new resolvable node
        switch context.resolve(.unresolved(UnresolvedTopicReference(topicURL: ValidatedURL(parsingExact: "doc:resolvable-article")!)), in: moduleReference) {
        case .success(let resolvedReference):
            XCTAssertEqual(resolvedReference.absoluteString, "doc://\(bundle.identifier)/documentation/Test-Bundle/resolvable-article")
            XCTAssertNoThrow(try context.entity(with: resolvedReference))
        case .failure(_, let errorMessage):
            XCTFail("Did not resolve resolvable link. Error: \(errorMessage)")
        }
    }
    
    // Verifies if the context fails to resolve non-resolvable nodes.
    func testNonLinkableNodes() throws {
        // Create a bundle with variety absolute and relative links and symbol links to a non linkable node.
        let (_, _, context) = try testBundleAndContext(copying: "TestBundle", excludingPaths: [], codeListings: [:], externalResolvers: [:], externalSymbolResolver: nil, configureBundle: { url in
            try """
            # ``SideKit/SideClass``
            Abstract.
            ## Discussion
            This is a link to <doc:/documentation/SideKit/SideClass/Element/Protocol-Implementations>.
            ## Topics
            ### Basics
             - <doc:documentation/SideKit/SideClass/Element/Protocol-Implementations>
             - <doc:Element/Protocol-Implementations>
            """.write(to: url.appendingPathComponent("sideclass.md"), atomically: true, encoding: .utf8)
        })

        let disabledDestinationProblems = context.problems.filter { p in
            return p.diagnostic.identifier == "org.swift.docc.disabledLinkDestination"
                && p.diagnostic.source?.path.hasSuffix("sideclass.md") == true
        }

        let mapRangeAsString: (SourceRange?) -> String? = { range in
            guard let range else { return nil }
            return "\(range.lowerBound.line):\(range.lowerBound.column) - \(range.upperBound.line):\(range.upperBound.column)"
        }
        
        // Verify that all links in source have been detected and the special diagnostic is emitted.
        XCTAssertEqual(Set(disabledDestinationProblems.map({ mapRangeAsString($0.diagnostic.range) })), [
            "4:19 - 4:90",
            "7:4 - 7:74",
            "8:4 - 8:42",
        ])
    }
    
    // Fixtures to exercise resolving links vs. symbol links.

    /// Empty symbol graph with a single symbol called "Test"
    private let testSymbolGraphSource = """
     {
       "metadata": {
         "formatVersion": { "major": 0, "minor": 5, "patch": 2 },
         "generator": "App"
       },
       "module": {
         "name": "Minimal_docs",
         "platform": {
           "architecture": "x86_64",
           "vendor": "apple",
           "operatingSystem": {
             "name": "macosx",
             "minimumVersion": { "major": 10, "minor": 10, "patch": 0 }
           }
         }
       },
       "symbols": [
         {
           "kind": {
             "identifier": "swift.struct",
             "displayName": "Structure"
           },
           "identifier": {
             "precise": "s:12Minimal_docs4TestV",
             "interfaceLanguage": "swift"
           },
           "pathComponents": [
             "Test"
           ],
           "names": {
             "title": "Test"
           },
           "declarationFragments": [
             {
               "kind": "keyword",
               "spelling": "struct"
             },
             {
               "kind": "text",
               "spelling": " "
             },
             {
               "kind": "identifier",
               "spelling": "Test"
             }
           ],
           "accessLevel": "public"
         }
       ],
       "relationships": []
     }
     """
    private let testRootPageSource = """
     # Root
     @Metadata {
        @TechnologyRoot
     }
     ## Topics
     ### Articles
      - <doc:/documentation/Test-Bundle/Test>
     """
    
    private let testArticleSource = """
     # Test Article
     Test Article abstract.
     """
    
    private let testTechnologySource = """
     @Tutorials(name: "Test Technology") {
        @Intro(title: "Introduction") { }
     
        @Chapter(name: "Essentials") {
           @TutorialReference(tutorial: "doc:tutorials/Test-Bundle/Test")
        }
     }
     """
    
    private let testTutorialSource = """
     @Tutorial {
        @Intro(title: "Test Tutorial") { }
        @Assessments { }
     }
     """

    /// Verify we resolve a relative link to the article if we have
    /// an article, a tutorial, and a symbol with the *same* names.
    func testResolvePrecedenceArticleOverTutorialOverSymbol() throws {
        // Verify resolves correctly between a bundle with an article and a tutorial.
        do {
            let infoPlistURL = try XCTUnwrap(Bundle.module.url(forResource: "Info+Availability", withExtension: "plist", subdirectory: "Test Resources"))
            let testBundle = Folder(name: "test.docc", content: [
                CopyOfFile(original: infoPlistURL, newName: "Info.plist"),
                TextFile(name: "TestRoot.md", utf8Content: testRootPageSource),
                TextFile(name: "Test.md", utf8Content: testArticleSource),
                TextFile(name: "TestTechnology.tutorial", utf8Content: testTechnologySource),
                TextFile(name: "Test.tutorial", utf8Content: testTutorialSource),
            ])
            let tempFolderURL = try createTemporaryDirectory().appendingPathComponent("test.docc")
            try testBundle.write(to: tempFolderURL)
            
            // Load the bundle
            let (_, bundle, context) = try loadBundle(from: tempFolderURL)
            // Verify the context contains the conflicting topic names
            // Article
            XCTAssertNotNil(context.documentationCache[ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/Test-Bundle/Test", sourceLanguage: .swift)])
            // Tutorial
            XCTAssertNotNil(context.documentationCache[ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/tutorials/Test-Bundle/Test", sourceLanguage: .swift)])
            
            let unresolved = TopicReference.unresolved(.init(topicURL: try XCTUnwrap(ValidatedURL(parsingExact: "doc:Test"))))
            let expected = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/Test-Bundle/Test", sourceLanguage: .swift)

            // Resolve from various locations in the bundle
            for parent in [bundle.rootReference, bundle.documentationRootReference, bundle.tutorialsRootReference] {
                switch context.resolve(unresolved, in: parent) {
                    case .success(let reference):
                        if reference.path != expected.path {
                            XCTFail("Expected to resolve to \(expected.path) in parent path '\(parent.path)' but got \(reference.path)")
                        }
                    case .failure(_, let errorMessage): XCTFail("Didn't resolve to expected reference path \(expected.path). Error: \(errorMessage)")
                }
            }
        }
        
        // Verify resolves correctly between a bundle with an article, a tutorial, and a symbol
        do {
            let infoPlistURL = try XCTUnwrap(Bundle.module.url(forResource: "Info+Availability", withExtension: "plist", subdirectory: "Test Resources"))
            let testBundle = Folder(name: "test.docc", content: [
                CopyOfFile(original: infoPlistURL, newName: "Info.plist"),
                TextFile(name: "TestRoot.md", utf8Content: testRootPageSource),
                TextFile(name: "Test.md", utf8Content: testArticleSource),
                TextFile(name: "TestFramework.symbols.json", utf8Content: testSymbolGraphSource),
                TextFile(name: "TestTechnology.tutorial", utf8Content: testTechnologySource),
                TextFile(name: "Test.tutorial", utf8Content: testTutorialSource),
            ])
            let tempFolderURL = try createTemporaryDirectory().appendingPathComponent("test.docc")
            try testBundle.write(to: tempFolderURL)
            
            // Load the bundle
            let (_, bundle, context) = try loadBundle(from: tempFolderURL)
            // Verify the context contains the conflicting topic names
            // Article
            XCTAssertNotNil(context.documentationCache[ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/Test-Bundle/Test", sourceLanguage: .swift)])
            // Tutorial
            XCTAssertNotNil(context.documentationCache[ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/tutorials/Test-Bundle/Test", sourceLanguage: .swift)])
            // Symbol
            XCTAssertNotNil(context.documentationCache[ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/Minimal_docs/Test", sourceLanguage: .swift)])
            
            let unresolved = TopicReference.unresolved(.init(topicURL: try XCTUnwrap(ValidatedURL(parsingExact: "doc:Test"))))
            let expected = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/Test-Bundle/Test", sourceLanguage: .swift)
            
            let symbolReference = try XCTUnwrap(context.documentationCache.reference(symbolID: "s:12Minimal_docs4TestV"))
            

            // Resolve from various locations in the bundle
            for parent in [bundle.rootReference, bundle.documentationRootReference, bundle.tutorialsRootReference, symbolReference] {
                switch context.resolve(unresolved, in: parent) {
                    case .success(let reference):
                        if reference.path != expected.path {
                            XCTFail("Expected to resolve to \(expected.path) in parent path '\(parent.path)' but got \(reference.path)")
                        }
                    case .failure(_, let errorMessage): XCTFail("Didn't resolve to expected reference path \(expected.path). Error: \(errorMessage)")
                }
            }
        }
    }

    func testResolvePrecedenceSymbolInBackticks() throws {
        // Verify resolves correctly a double-backtick link.
        do {
            let infoPlistURL = try XCTUnwrap(Bundle.module.url(forResource: "Info+Availability", withExtension: "plist", subdirectory: "Test Resources"))
            let testBundle = Folder(name: "test.docc", content: [
                CopyOfFile(original: infoPlistURL, newName: "Info.plist"),
                TextFile(name: "Minimal_docs.md", utf8Content:
                            """
                             # ``Minimal_docs``
                             Module abstract.
                             
                             ``Test``
                             ## Topics
                             ### Articles
                              - <doc:Article>
                             """),
                TextFile(name: "TestRoot.md", utf8Content: testRootPageSource),
                TextFile(name: "Article.md", utf8Content: "# Article"),
                TextFile(name: "Test.md", utf8Content:
                            """
                             # Test Article
                             Article abstract.
                             
                             ``Test``
                             """),
                TextFile(name: "TestFramework.symbols.json", utf8Content: testSymbolGraphSource),
                TextFile(name: "TestTechnology.tutorial", utf8Content: testTechnologySource),
                TextFile(name: "Test.tutorial", utf8Content: testTutorialSource),
            ])
            let tempFolderURL = try createTemporaryDirectory().appendingPathComponent("test.docc")
            try testBundle.write(to: tempFolderURL)
            
            // Load the bundle
            let (_, bundle, context) = try loadBundle(from: tempFolderURL)
            
            let symbolReference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/Minimal_docs/Test", sourceLanguage: .swift)
            let moduleReference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/Minimal_docs", sourceLanguage: .swift)
            let articleReference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/Test-Bundle/Test", sourceLanguage: .swift)

            // Verify we resolve/not resolve non-symbols when calling directly context.resolve(...)
            // with an explicit preference.
            let unresolvedSymbolRef1 = UnresolvedTopicReference(topicURL: ValidatedURL(parsingExact: "Test")!)
            switch context.resolve(.unresolved(unresolvedSymbolRef1), in: moduleReference, fromSymbolLink: true) {
                case .failure(_, let errorMessage): XCTFail("Did not resolve a symbol link to the symbol Test. Error: \(errorMessage)")
                default: break
            }
            switch context.resolve(.unresolved(unresolvedSymbolRef1), in: moduleReference, fromSymbolLink: false) {
                case .failure(_, let errorMessage): XCTFail("Did not resolve a topic link to the symbol Test. Error: \(errorMessage)")
                default: break
            }

            let articleRef1 = UnresolvedTopicReference(topicURL: ValidatedURL(parsingExact: "Article")!)
            switch context.resolve(.unresolved(articleRef1), in: moduleReference, fromSymbolLink: true) {
                case .success: XCTFail("Did resolve a symbol link to an article")
                default: break
            }
            switch context.resolve(.unresolved(articleRef1), in: moduleReference, fromSymbolLink: false) {
                case .failure(_, let errorMessage): XCTFail("Did not resolve a topic link to an article. Error: \(errorMessage)")
                default: break
            }

            // Verify the context contains the conflicting topic names
            // Tutorial
            XCTAssertNotNil(context.documentationCache[ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/tutorials/Test-Bundle/Test", sourceLanguage: .swift)])
            // Symbol
            XCTAssertNotNil(context.documentationCache[symbolReference])
            
            // Verify the symbol link resolved correctly to the symbol
            let node = try context.entity(with: moduleReference)
            let symbol = try XCTUnwrap(node.semantic as? Symbol)
            let discussion = try XCTUnwrap(symbol.discussion)
            
            let resolvedSymbolLink = try XCTUnwrap(discussion.content.first)
            // Verify the reference has been expanded to the absolute path to the symbol when resolved.
            XCTAssertEqual(resolvedSymbolLink.format(), "``\(symbolReference.absoluteString)``")
            
            // Verify the symbol link will not resolve from elsewhere (i.e. if the relative link isn't resolvable in the parent symbol)
            let node1 = try context.entity(with: articleReference)
            let article = try XCTUnwrap(node1.semantic as? Article)
            let discussion1 = try XCTUnwrap(article.discussion)
            
            let unresolvedSymbolLink = try XCTUnwrap(discussion1.content.first)
            XCTAssertEqual(unresolvedSymbolLink.format(), "``Test``")
        }
    }
    
    func testSymbolMatchingModuleName() throws {
        // Verify as top-level symbol with name matching the module name
        // does not trip the context when building the topic graph
        do {
            // Rename a top-level symbol to match the framework name.
            let symbolGraphFixture = testSymbolGraphSource
                .replacingOccurrences(of: #"Test"#, with: #"Minimal_docs"#)
        
            let infoPlistURL = try XCTUnwrap(Bundle.module.url(forResource: "Info+Availability", withExtension: "plist", subdirectory: "Test Resources"))
            let testBundle = Folder(name: "test.docc", content: [
                CopyOfFile(original: infoPlistURL, newName: "Info.plist"),
                TextFile(name: "TestFramework.symbols.json", utf8Content: symbolGraphFixture),
            ])
            let tempFolderURL = try createTemporaryDirectory().appendingPathComponent("test.docc")
            try testBundle.write(to: tempFolderURL)
            
            // Load the bundle
            let (_, bundle, context) = try loadBundle(from: tempFolderURL)
            
            // Verify the module and symbol node kinds.
            let symbolReference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/Minimal_docs/Minimal_docs", sourceLanguage: .swift)
            let moduleReference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/Minimal_docs", sourceLanguage: .swift)

            XCTAssertEqual(context.topicGraph.nodeWithReference(symbolReference)?.kind, .structure)
            XCTAssertEqual(context.topicGraph.nodeWithReference(moduleReference)?.kind, .module)
        }
    }
    
    /// Verifies that we emit a warning about a link that resolves in its context
    /// but is then inherited and will not resolve in its inherited context.
    ///
    /// The tested `InheritedDocs-RelativeLinks.symbols.json` symbol graph
    /// is generated from the following source:
    ///
    /// ```swift
    /// public protocol A {
    ///    /// Requirement method: ``method(_:)-7mctk``.
    ///    func method(_ param: String)
    /// }
    ///
    /// public extension A {
    ///    func method(_ param: String) { }
    ///    func method(_ param: Int) { }
    /// }
    ///
    /// public struct MyStruct: A {
    ///    public func method(_ param: String) { }
    /// }
    /// ```
    func testWarningForUnresolvableLinksInInheritedDocs() throws {
        // Create temp folder
        let tempURL = try createTemporaryDirectory()

        // Create test bundle
        let bundleURL = try Folder(name: "InheritedDocs.docc", content: [
            InfoPlist(displayName: "Inheritance", identifier: "com.test.inheritance"),
            CopyOfFile(original: Bundle.module.url(
                        forResource: "InheritedDocs-RelativeLinks.symbols", withExtension: "json",
                        subdirectory: "Test Resources")!),
        ]).write(inside: tempURL)
        
        // Load the test bundle
        let (_, _, context) = try loadBundle(from: bundleURL)
        
        // Get the emitted diagnostic and verify it contains a solution and replacement fix-it.
        let problem = try XCTUnwrap(context.problems.first(where: { p in
            return p.diagnostic.identifier == "org.swift.docc.UnresolvableLinkWhenInherited"
                && !p.possibleSolutions.isEmpty
                && !p.possibleSolutions[0].replacements.isEmpty
        }))
        
        // Verify the diagnostic is at the expected range.
        let range = try XCTUnwrap(problem.diagnostic.range)
        
        XCTAssertEqual(range.lowerBound.line, 4)
        XCTAssertEqual(range.lowerBound.column, 29)
        XCTAssertEqual(range.upperBound.line, 4)
        XCTAssertEqual(range.upperBound.column, 49)

        // Verify the replacement range is at the expected location.
        let replacementRange = try XCTUnwrap(problem.possibleSolutions[0].replacements[0].range)
        
        XCTAssertEqual(replacementRange.lowerBound.line, 4)
        XCTAssertEqual(replacementRange.lowerBound.column, 29)
        XCTAssertEqual(replacementRange.upperBound.line, 4)
        XCTAssertEqual(replacementRange.upperBound.column, 49)

        // Verify the solution proposes the expected absolute link replacement.
        XCTAssertEqual(problem.possibleSolutions[0].replacements[0].replacement, "<doc:/documentation/Minimal_docs/A/method(_:)-7mctk>")
    }
    
    func testCustomModuleKind() throws {
        let (bundle, context) = try testBundleAndContext(named: "BundleWithExecutableModuleKind")
        XCTAssertEqual(bundle.info.defaultModuleKind, "Executable")
        
        let moduleSymbol = try XCTUnwrap(context.documentationCache["ExampleDocumentedExecutable"]?.symbol)
        XCTAssertEqual(moduleSymbol.kind.identifier.identifier, "module")
        XCTAssertEqual(moduleSymbol.kind.displayName, "Executable")
    }
    
    /// Verifies that the number of symbols registered in the documentation context is consistent with
    /// the number of symbols in the symbol graph files.
    func testSymbolsCountIsConsistentWithSymbolGraphData() throws {
        let exampleDocumentation = Folder(name: "unit-test.docc", content: [
            Folder(name: "Symbols", content: [
                JSONFile(
                    name: "module.symbols.json",
                    content: SymbolGraph(
                        metadata: .init(formatVersion: .init(string: "1.0.0")!, generator: "generator"),
                        module: .init(name: "module", platform: .init(), version: nil, bystanders: nil),
                        symbols: (1...1000).map { index in
                            SymbolGraph.Symbol(
                                identifier: .init(precise: UUID().uuidString, interfaceLanguage: "swift"),
                                names: .init(
                                    title: "Symbol \(index)",
                                    navigator: nil,
                                    subHeading: [],
                                    prose: "Symbol \(index)"
                                ),
                                pathComponents: ["Module", "Symbol\(index)"],
                                docComment: nil,
                                accessLevel: .init(rawValue: "public"),
                                kind: .init(parsedIdentifier: .struct, displayName: "Struct"),
                                mixins: [:]
                            )
                        },
                        relationships: []
                    )
                )
            ]),
            InfoPlist(displayName: "TestBundle", identifier: "com.test.example")
        ])
        
        let tempURL = try createTemporaryDirectory()
        let bundleURL = try exampleDocumentation.write(inside: tempURL)

        let workspace = DocumentationWorkspace()
        let context = try DocumentationContext(dataProvider: workspace)
        let dataProvider = try LocalFileSystemDataProvider(rootURL: bundleURL)
        try workspace.registerProvider(dataProvider)
        
        XCTAssertEqual(
            context.documentationCache.count,
            1001,
            "Expected 1000 nodes for each symbol of the symbol graph + 1 for the module."
        )
    }
    
    func testDocumentationExtensionURLForReferenceReturnsURLForSymbolReference() throws {
        let (bundleURL, _, context) = try testBundleAndContext(copying: "TestBundle")
        
        XCTAssertEqual(
            context.documentationExtensionURL(
                for: ResolvedTopicReference(
                    bundleIdentifier: "org.swift.docc.example",
                    path: "/documentation/MyKit/MyClass",
                    fragment: nil,
                    sourceLanguage: .swift
                )
            ),
            bundleURL
                .appendingPathComponent("documentation")
                .appendingPathComponent("myclass.md")
        )
    }
    
    func testDocumentationExtensionURLForReferenceReturnsNilForTutorialReference() throws {
        let (_, _, context) = try testBundleAndContext(copying: "TestBundle")
        
        XCTAssertNil(
            context.documentationExtensionURL(
                for: ResolvedTopicReference(
                    bundleIdentifier: "org.swift.docc.example",
                    path: "/tutorials/TestOverview",
                    fragment: nil,
                    sourceLanguage: .swift
                )
            ),
            "Expectedly returned non-nil value for non-symbol content."
        )
    }

    func testAddingProtocolExtensionMemberConstraint() throws {
        // This fixture contains a protocol extension:
        // extension Swift.Collection {
        //   public func fixture() -> String {
        //     return "collection"
        //   }
        // }
        let (_, _, context) = try testBundleAndContext(copying: "ModuleWithProtocolExtensions")

        // The member function of the protocol extension
        // should have a constraint: Self is Collection
        var memberIdentifier = "s:Sl28ModuleWithProtocolExtensionsE7fixtureSSyF"
        var memberNode = try XCTUnwrap(context.documentationCache[memberIdentifier])
        var memberSymbol = memberNode.semantic as! Symbol
        var constraints = try XCTUnwrap(memberSymbol.constraints)
        XCTAssertEqual(1, constraints.count)
        var constraint = constraints.first!
        XCTAssertEqual(constraint.kind, .sameType)
        XCTAssertEqual(constraint.leftTypeName, "Self")
        XCTAssertEqual(constraint.rightTypeName, "Collection")

        // This fixture also contains a structure extension:
        // extension Set.Iterator {
        //     public func fixture() -> String {
        //         return "set iterator"
        //     }
        // }

        // The member function of the structure extension
        // should NOT have a constraint, since it wouldn't
        // make sense for a structure or for any types other
        // than protocols: Self is Set.Iterator
        memberIdentifier = "s:Sh8IteratorV28ModuleWithProtocolExtensionsE7fixtureSSyF"
        memberNode = try XCTUnwrap(context.documentationCache[memberIdentifier])
        memberSymbol = memberNode.semantic as! Symbol
        constraints = try XCTUnwrap(memberSymbol.constraints)
        // Contains existing constraint Element conforms to Hashable,
        // but did not receive a new constraint Self Is Iterator.
        XCTAssertEqual(1, constraints.count)
        constraint = constraints.first!
        XCTAssertEqual(constraint.kind, .conformance)
        XCTAssertEqual(constraint.leftTypeName, "Element")
        XCTAssertEqual(constraint.rightTypeName, "Hashable")
    }

    func testDiagnosticLocations() throws {
        // The ObjCFrameworkWithInvalidLink.docc test bundle contains symbol
        // graphs for both Obj-C and Swift, built after setting:
        //   "Build Multi-Language Documentation for Objective-C Only Targets" = true.
        // One doc comment in the Obj-C header file contains an invalid doc
        // link on line 24, columns 56-63:
        // "Log a hello world message. This line contains an ``invalid`` link."
        let (_, context) = try testBundleAndContext(named: "ObjCFrameworkWithInvalidLink")
        let problems = context.problems
        if FeatureFlags.current.isParametersAndReturnsValidationEnabled {
            XCTAssertEqual(4, problems.count)
        } else {
            XCTAssertEqual(1, problems.count)
        }
        let problem = try XCTUnwrap(problems.first(where: { $0.diagnostic.identifier == "org.swift.docc.unresolvedTopicReference" }))
        let basename = try XCTUnwrap(problem.diagnostic.source?.lastPathComponent)
        XCTAssertEqual("HelloWorldFramework.h", basename)
        let start = Markdown.SourceLocation(line: 24, column: 56, source: nil)
        let end = Markdown.SourceLocation(line: 24, column: 63, source: nil)
        let range = try XCTUnwrap(problem.diagnostic.range)
        XCTAssertEqual(start..<end, range)
    }
    
    func testPathsToHandlesCyclicCuration() throws {
        let tempURL = try createTempFolder(content: [
            Folder(name: "unit-test.docc", content: [
                Folder(name: "clang", content: [
                    JSONFile(name: "ModuleName.symbols.json", content: makeSymbolGraph(
                        moduleName: "ModuleName",
                        symbols: [
                            // Any class declaration.
                            makeSymbol(
                                name: "SomeClass",
                                identifier: "some-class-id",
                                language: .objectiveC,
                                kind: .class
                            ),
                            
                            // extern NSErrorDomain const SomeErrorDomain;
                            makeSymbol(
                                name: "SomeErrorDomain",
                                identifier: "some-error-domain-id",
                                language: .objectiveC,
                                kind: .var
                            ),
                            
                            // typedef NS_ERROR_ENUM(SomeErrorDomain, SomeErrorCode) {
                            //     SomeErrorCodeSomeCase = 1
                            // };
                            makeSymbol(
                                name: "SomeErrorCode",
                                identifier: "some-error-code-id",
                                language: .objectiveC,
                                kind: .enum
                            ),
                            makeSymbol(
                                name: "SomeErrorCodeSomeCase",
                                identifier: "some-error-code-case-id",
                                language: .objectiveC,
                                kind: .case,
                                pathComponents: ["SomeErrorCode", "SomeErrorCodeSomeCase"]
                            ),
                        ],
                        relationships: [
                            .init(source: "some-error-code-case-id", target: "some-error-code-id", kind: .memberOf, targetFallback: nil),
                        ]
                    ))
                ]),
                
                Folder(name: "swift", content: [
                    JSONFile(name: "ModuleName.symbols.json", content: makeSymbolGraph(
                        moduleName: "ModuleName",
                        symbols: [
                            // The Swift representation of the Objective-C class above.
                            makeSymbol(
                                name: "SomeClass",
                                identifier: "some-class-id",
                                kind: .class
                            ),
                            
                            // The domain defined using NS_ERROR_ENUM translates to a struct with an 'errorDomain' and 'code'. Something like:
                            //
                            // let SomeErrorDomain: String
                            // struct SomeError: CustomNSError, Error {
                            //     static var errorDomain: String
                            //     static var code: Code
                            //     enum Code {
                            //         someCase = 1
                            //     }
                            // }
                            makeSymbol(
                                name: "SomeErrorDomain",
                                identifier: "some-error-domain-id",
                                kind: .var
                            ),
                            
                            makeSymbol(
                                name: "SomeError",
                                identifier: "some-error-id",
                                kind: .struct
                            ),
                            makeSymbol(
                                name: "errorDomain",
                                identifier: "some-error-domain-property-id",
                                kind: .typeProperty,
                                pathComponents: ["SomeError", "errorDomain"]
                            ),
                            makeSymbol(
                                name: "code",
                                identifier: "some-error-code-property-id",
                                kind: .typeProperty,
                                pathComponents: ["SomeError", "code"]
                            ),
                            makeSymbol(
                                name: "Code",
                                identifier: "some-error-code-id",
                                kind: .enum,
                                pathComponents: ["SomeError", "Code"]
                            ),
                            makeSymbol(
                                name: "someCase",
                                identifier: "some-error-code-case-id",
                                kind: .case,
                                pathComponents: ["SomeError", "Code", "someCase"]
                            ),
                        ],
                        relationships: [
                            // static properties are members of struct
                            .init(source: "some-error-domain-property-id", target: "some-error-id", kind: .memberOf, targetFallback: nil),
                            .init(source: "some-error-code-property-id", target: "some-error-id", kind: .memberOf, targetFallback: nil),
                            // enum is member of struct
                            .init(source: "some-error-code-id", target: "some-error-id", kind: .memberOf, targetFallback: nil),
                            // case is member of enum
                            .init(source: "some-error-code-case-id", target: "some-error-code-id", kind: .memberOf, targetFallback: nil),
                        ]
                    ))
                ]),
                
                // In addition to the automatic curation (thin lines) where all symbols are members of the module (SomeErrorCode is a top-level enum in Objective-C),
                // Add manual curation (thick lines) from `SomeClass` to `SomeError` and from `SomeError/Code` to `SomeClass`, creating a cycle in the total curation.
                //
                //            ModuleName
                //                 │
                //     ┌───────┬───┴───┬─────────────┐
                //     ▼       │       ▼             ▼
                // SomeClass━━━━━━▶SomeError  SomeErrorDomain
                //     ▲       │       │
                //     ┃       ▼       │
                //     ┗━━━━━Code◀─────┘
                //             │
                //             ▼
                //          someCase
                
                TextFile(name: "SomeClass.md", utf8Content: """
                # ``SomeClass``
                
                Curate the error
                
                ## Topics
                
                - ``SomeError``
                """),
                
                TextFile(name: "SomeErrorCode.md", utf8Content: """
                # ``SomeError/Code``
                
                Curate the class
                
                ## Topics
                
                - ``SomeClass``
                """),
            ])
        ])
        let (_, bundle, context) = try loadBundle(from: tempURL)
        let reference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/ModuleName/SomeError/Code-swift.enum/someCase", sourceLanguage: .swift)
        
        XCTAssertEqual(
            context.topicGraph.reverseEdgesGraph.cycles(from: reference).map { $0.map(\.lastPathComponent) },
            [ ["Code-swift.enum", "SomeError", "SomeClass"] ],
            "There is one cyclic path encountered while traversing the reverse edges from the 'someCase' enum case."
        )
        
        XCTAssertEqual(
            context.finitePaths(to: reference).map { $0.map(\.lastPathComponent) },
            [ ["ModuleName", "Code-swift.enum"] ],
            "There is only one _finite_ path from the 'someCase' enum case, through the reverse edges in the topic graph."
        )
    }
    
    func testUnresolvedLinkWarnings() throws {
        var (_, _, context) = try testBundleAndContext(copying: "TestBundle") { url in
            let extensionFile = """
            # ``SideKit``

            myFunction abstract

            ## Overview

            This is unresolvable: <doc:Does-Not-Exist>.
            
            ## Topics
            
            - <doc:NonExistingDoc>

            """
            let fileURL = url.appendingPathComponent("documentation").appendingPathComponent("myFunction.md")
            try extensionFile.write(to: fileURL, atomically: true, encoding: .utf8)
        }
        var problems = context.diagnosticEngine.problems
        var linkResolutionProblems = problems.filter { $0.diagnostic.source?.relativePath.hasSuffix("myFunction.md") == true }
        XCTAssertEqual(linkResolutionProblems.count, 3)
        var problem = try XCTUnwrap(linkResolutionProblems.last)
        XCTAssertEqual(problem.diagnostic.summary, "\'NonExistingDoc\' doesn\'t exist at \'/SideKit\'")
        (_, _, context) = try testBundleAndContext(copying: "BookLikeContent") { url in
            let extensionFile = """
            # My Article

            Abstract

            ## Overview

            Overview
            
            ## Topics
            
            - <doc:NonExistingDoc>

            """
            let fileURL = url.appendingPathComponent("MyArticle.md")
            try extensionFile.write(to: fileURL, atomically: true, encoding: .utf8)
        }
        problems = context.diagnosticEngine.problems
        linkResolutionProblems = problems.filter { $0.diagnostic.source?.relativePath.hasSuffix("MyArticle.md") == true }
        XCTAssertEqual(linkResolutionProblems.count, 1)
        problem = try XCTUnwrap(linkResolutionProblems.last)
        XCTAssertEqual(problem.diagnostic.summary, "\'NonExistingDoc\' doesn\'t exist at \'/BestBook/MyArticle\'")
    }
    
    func testContextRecognizesOverloads() throws {
        enableFeatureFlag(\.isExperimentalOverloadedSymbolPresentationEnabled)
        
        let overloadableKindIDs = SymbolGraph.Symbol.KindIdentifier.allCases.filter { $0.isOverloadableKind }
        // Generate a 4 symbols with the same name for every overloadable symbol kind
        let symbols: [SymbolGraph.Symbol] = overloadableKindIDs.flatMap { [
            makeSymbol(identifier: "first-\($0.identifier)-id", kind: $0),
            makeSymbol(identifier: "second-\($0.identifier)-id", kind: $0),
            makeSymbol(identifier: "third-\($0.identifier)-id", kind: $0),
            makeSymbol(identifier: "fourth-\($0.identifier)-id", kind: $0),
        ] }
        
        let tempURL = try createTempFolder(content: [
            Folder(name: "unit-test.docc", content: [
                JSONFile(name: "ModuleName.symbols.json", content: makeSymbolGraph(
                    moduleName: "ModuleName",
                    symbols: symbols
                ))
            ])
        ])
        let (_, bundle, context) = try loadBundle(from: tempURL)
        let moduleReference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/ModuleName", sourceLanguage: .swift)

        for kindID in overloadableKindIDs {
            var seenIndices = Set<Int>()
            // Find the 4 symbols of this specific kind. SymbolKit will have assigned a display
            // index based on their sorted USRs, so sort them ahead of time based on that
            let overloadedReferences = try symbols.filter { $0.kind.identifier == kindID }.sorted(by: \.identifier.precise)
                .map { try XCTUnwrap(context.documentationCache.reference(symbolID: $0.identifier.precise)) }

            let overloadGroupNode: DocumentationNode
            let overloadGroupSymbol: Symbol
            let overloadGroupReferences: Symbol.Overloads
            switch context.resolve(.unresolved(.init(topicURL: .init(symbolPath: "SymbolName-\(kindID.identifier)"))), in: moduleReference, fromSymbolLink: true) {
            case let .failure(_, errorMessage):
                XCTFail("Could not resolve overload group page for \(kindID.identifier). Error message: \(errorMessage)")
                continue
            case let .success(overloadGroupReference):
                overloadGroupNode = try context.entity(with: overloadGroupReference)
                overloadGroupSymbol = try XCTUnwrap(overloadGroupNode.semantic as? Symbol)
                overloadGroupReferences = try XCTUnwrap(overloadGroupSymbol.overloadsVariants.firstValue)

                XCTAssertEqual(overloadGroupReferences.displayIndex, 0)
            }

            // Check that each symbol lists the other 3 overloads
            for (index, reference) in overloadedReferences.indexed() {
                let overloadedDocumentationNode = try XCTUnwrap(context.documentationCache[reference])
                let overloadedSymbol = try XCTUnwrap(overloadedDocumentationNode.semantic as? Symbol)
                
                let overloads = try XCTUnwrap(overloadedSymbol.overloadsVariants.firstValue)
                
                // Make sure that each symbol contains all of its sibling overloads.
                XCTAssertEqual(overloads.references.count, overloadedReferences.count - 1)
                for (otherIndex, otherReference) in overloadedReferences.indexed() where otherIndex != index {
                    XCTAssert(overloads.references.contains(otherReference))
                }
                
                // Each symbol needs to tell the renderer where it belongs in the array of overloaded declarations.
                XCTAssertFalse(seenIndices.contains(overloads.displayIndex))
                XCTAssertEqual(overloads.displayIndex, index)
                seenIndices.insert(overloads.displayIndex)

                if overloads.displayIndex == 0 {
                    // The first declaration in the display list should be the same declaration as
                    // the overload group page
                    XCTAssertEqual(overloadedSymbol.declaration.first?.value.declarationFragments, overloadGroupSymbol.declaration.first?.value.declarationFragments)
                } else {
                    // Otherwise, this reference should also be referenced by the overload group
                    XCTAssert(overloadGroupReferences.references.contains(reference))
                }
            }
            // Check that all the overloads was encountered
            for index in overloadedReferences.indices {
                XCTAssert(seenIndices.contains(index))
            }
        }
    }

    func testContextRecognizesOverloadsFromPlistFlag() throws {
        let overloadableKindIDs = SymbolGraph.Symbol.KindIdentifier.allCases.filter { $0.isOverloadableKind }
        // Generate a 4 symbols with the same name for every overloadable symbol kind
        let symbols: [SymbolGraph.Symbol] = overloadableKindIDs.flatMap { [
            makeSymbol(identifier: "first-\($0.identifier)-id", kind: $0),
            makeSymbol(identifier: "second-\($0.identifier)-id", kind: $0),
            makeSymbol(identifier: "third-\($0.identifier)-id", kind: $0),
            makeSymbol(identifier: "fourth-\($0.identifier)-id", kind: $0),
        ] }

        let tempURL = try createTempFolder(content: [
            Folder(name: "unit-test.docc", content: [
                JSONFile(name: "ModuleName.symbols.json", content: makeSymbolGraph(
                    moduleName: "ModuleName",
                    symbols: symbols
                )),
                DataFile(name: "Info.plist", data: Data("""
                <plist version="1.0">
                <dict>
                    <key>CDExperimentalFeatureFlags</key>
                    <dict>
                        <key>ExperimentalOverloadedSymbolPresentation</key>
                        <true/>
                    </dict>
                </dict>
                </plist>
                """.utf8))
            ])
        ])
        let (_, bundle, context) = try loadBundle(from: tempURL)
        let moduleReference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/ModuleName", sourceLanguage: .swift)

        for kindID in overloadableKindIDs {
            switch context.resolve(.unresolved(.init(topicURL: .init(symbolPath: "SymbolName-\(kindID.identifier)"))), in: moduleReference, fromSymbolLink: true) {
            case let .failure(_, errorMessage):
                XCTFail("Could not resolve overload group page for \(kindID.identifier). Error message: \(errorMessage)")
                continue
            case let .success(overloadGroupReference):
                let overloadGroupNode = try context.entity(with: overloadGroupReference)
                let overloadGroupSymbol = try XCTUnwrap(overloadGroupNode.semantic as? Symbol)
                let overloadGroupReferences = try XCTUnwrap(overloadGroupSymbol.overloadsVariants.firstValue)

                XCTAssertEqual(overloadGroupReferences.displayIndex, 0)
            }
        }
    }

    // The overload behavior doesn't apply to symbol kinds that don't support overloading
    func testContextDoesNotRecognizeNonOverloadableSymbolKinds() throws {
        enableFeatureFlag(\.isExperimentalOverloadedSymbolPresentationEnabled)
        
        let nonOverloadableKindIDs = SymbolGraph.Symbol.KindIdentifier.allCases.filter { !$0.isOverloadableKind }
        // Generate a 4 symbols with the same name for every non overloadable symbol kind
        let symbols: [SymbolGraph.Symbol] = nonOverloadableKindIDs.flatMap { [
            makeSymbol(identifier: "first-\($0.identifier)-id", kind: $0),
            makeSymbol(identifier: "second-\($0.identifier)-id", kind: $0),
            makeSymbol(identifier: "third-\($0.identifier)-id", kind: $0),
            makeSymbol(identifier: "fourth-\($0.identifier)-id", kind: $0),
        ] }
        
        let tempURL = try createTempFolder(content: [
            Folder(name: "unit-test.docc", content: [
                JSONFile(name: "ModuleName.symbols.json", content: makeSymbolGraph(
                    moduleName: "ModuleName",
                    symbols: symbols
                ))
            ])
        ])
        let (_, _, context) = try loadBundle(from: tempURL)
        
        for kindID in nonOverloadableKindIDs {
            // Find the 4 symbols of this specific kind
            let overloadedReferences = try symbols.filter { $0.kind.identifier == kindID }
                .map { try XCTUnwrap(context.documentationCache.reference(symbolID: $0.identifier.precise)) }
            
            // Check that none of the symbols lists any overloads
            for reference in overloadedReferences {
                let documentationNode = try XCTUnwrap(context.documentationCache[reference])
                let overloadedSymbol = try XCTUnwrap(documentationNode.semantic as? Symbol)
                XCTAssertNil(overloadedSymbol.overloadsVariants.firstValue)
            }
        }
    }

    func testWarnsOnUnknownPlistFeatureFlag() throws {
        let tempURL = try createTempFolder(content: [
            Folder(name: "unit-test.docc", content: [
                DataFile(name: "Info.plist", data: Data("""
                <plist version="1.0">
                <dict>
                    <key>CDExperimentalFeatureFlags</key>
                    <dict>
                        <key>NonExistentFeature</key>
                        <true/>
                    </dict>
                </dict>
                </plist>
                """.utf8))
            ])
        ])
        let (_, _, context) = try loadBundle(from: tempURL)

        let unknownFeatureFlagProblems = context.problems.filter({ $0.diagnostic.identifier == "org.swift.docc.UnknownBundleFeatureFlag" })
        XCTAssertEqual(unknownFeatureFlagProblems.count, 1)
        let problem = try XCTUnwrap(unknownFeatureFlagProblems.first)

        XCTAssertEqual(problem.diagnostic.severity, .warning)
        XCTAssertEqual(problem.diagnostic.summary, "Unknown feature flag in Info.plist: 'NonExistentFeature'")
    }

    func testUnknownFeatureFlagSuggestsOtherFlags() throws {
        let tempURL = try createTempFolder(content: [
            Folder(name: "unit-test.docc", content: [
                DataFile(name: "Info.plist", data: Data("""
                <plist version="1.0">
                <dict>
                    <key>CDExperimentalFeatureFlags</key>
                    <dict>
                        <key>ExperimenalOverloadedSymbolPresentation</key>
                        <true/>
                    </dict>
                </dict>
                </plist>
                """.utf8))
            ])
        ])
        let (_, _, context) = try loadBundle(from: tempURL)

        let unknownFeatureFlagProblems = context.problems.filter({ $0.diagnostic.identifier == "org.swift.docc.UnknownBundleFeatureFlag" })
        XCTAssertEqual(unknownFeatureFlagProblems.count, 1)
        let problem = try XCTUnwrap(unknownFeatureFlagProblems.first)

        XCTAssertEqual(problem.diagnostic.severity, .warning)
        XCTAssertEqual(
            problem.diagnostic.summary,
            "Unknown feature flag in Info.plist: 'ExperimenalOverloadedSymbolPresentation'. Possible suggestions: 'ExperimentalOverloadedSymbolPresentation'")
    }

    // A test helper that creates a symbol with a given identifier and kind.
    private func makeSymbol(
        name: String = "SymbolName",
        identifier: String,
        language: SourceLanguage = .swift,
        kind: SymbolGraph.Symbol.KindIdentifier,
        pathComponents: [String]? = nil
    ) -> SymbolGraph.Symbol {
        return SymbolGraph.Symbol(
            identifier: .init(precise: identifier, interfaceLanguage: language.id),
            names: .init(title: name, navigator: nil, subHeading: nil, prose: nil),
            pathComponents: pathComponents ?? [name],
            docComment: nil,
            accessLevel: .public,
            kind: .init(parsedIdentifier: kind, displayName: "Kind Display Name"),
            mixins: [:]
        )
    }
}

func assertEqualDumps(_ lhs: String, _ rhs: String, file: StaticString = #file, line: UInt = #line) {
    // The default message by XCTAssertEqual isn't helpful in this case as it dumps both values in the console
    // and is difficult to track any changes
    guard lhs.removingLeadingSpaces == rhs.removingLeadingSpaces else {
        XCTFail("\n" + diffDescription(lhs: lhs.removingLeadingSpaces, rhs: rhs.removingLeadingSpaces), file: (file), line: line)
        XCTFail("\n" + diffDescription(lhs: lhs.removingLeadingSpaces, rhs: rhs.removingLeadingSpaces), file: (file), line: line)
        return
    }
}

extension String {
    func trimmingLines() -> String {
        return components(separatedBy: .newlines)
            .filter { !$0.isEmpty }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .joined(separator: "\n")
    }
    
    var removingLeadingSpaces: String {
        var result = self
        var count = 0
        
        while result.hasPrefix(" ") {
            result = String(result.dropFirst())
            count += 1
        }
        
        return components(separatedBy: .newlines)
            .filter({ !$0.isEmpty })
            .map({ return String($0.dropFirst(count)) })
            .joined(separator: "\n")
    }
}
