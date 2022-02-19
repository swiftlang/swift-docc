/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
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
        let unresolved = UnresolvedTopicReference(topicURL: ValidatedURL(parsing: "doc:/TestTutorial")!)
        let parent = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "", sourceLanguage: .swift)
        
        guard case let .success(resolved) = context.resolve(.unresolved(unresolved), in: parent) else {
            XCTFail("Couldn't resolve \(unresolved)")
            return
        }
        
        XCTAssertEqual(parent.bundleIdentifier, resolved.bundleIdentifier)
        XCTAssertEqual("/tutorials/Test-Bundle/TestTutorial", resolved.path)
        
        // Test lowercasing of path
        let unresolvedUppercase = UnresolvedTopicReference(topicURL: ValidatedURL(parsing: "doc:/TESTTUTORIAL")!)
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
│  │  │  │  └─ Image source: "figure1" title: ""
│  │  │  ├─ Paragraph
│  │  │  │  └─ Image source: "images/figure1" title: ""
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
│  │  │  │  └─ Image source: "something.png" title: ""
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
        
        XCTAssert(
            context.problems.contains { problem in
                problem.diagnostic.identifier == "org.swift.docc.DuplicateReference"
                    && problem.diagnostic.localizedSummary == "Redeclaration of 'TestTutorial.tutorial'; this file will be skipped"
            }
        )
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
        XCTAssertFalse(context.symbolIndex.isEmpty)
        
        // MyClass is loaded
        guard let myClass = context.symbolIndex["s:5MyKit0A5ClassC"] else {
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
        XCTAssertEqual(myClassSymbol.moduleName, "MyKit")
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
        guard let myProtocol = context.symbolIndex["s:5MyKit0A5ProtocolP"],
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
                        """)

        XCTAssertEqual(myProtocolSymbol.declaration.values.first?.declarationFragments.map({ $0.spelling }), ["protocol", " ", "MyProtocol", " : ", "Hashable"])
        XCTAssertEqual(myProtocolSymbol.declaration.values.first?.declarationFragments.map({ $0.preciseIdentifier }), [nil, nil, nil, nil, "p:hPP"])

        XCTAssertEqual(myProtocolSymbol.topics?.taskGroups.first?.heading?.detachedFromParent.debugDescription(),
                        """
                        Heading level: 3
                        └─ Text "Task Group Excercising Symbol Links"
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
        guard let myClass = context.symbolIndex["s:5MyKit0A5ClassC"],
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
        XCTAssertNotNil(context.symbolIndex[myFunctionSymbolPreciseIdentifier], "myFunction which only exist on iOS should be found in the graph")
        XCTAssertNotNil(context.symbolIndex[myPlatformSpecificFunctionSymbol.identifier.precise], "The new platform specific function should be found in the graph")
        
        XCTAssertEqual(
            context.symbolIndex.count,
            graph.symbols.count + 1 /* for the module */ + 1 /* for the new plaform specific function */,
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
        guard let sideClass = context.symbolIndex["s:7SideKit0A5ClassC"],
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
        guard let myClass = context.symbolIndex["s:5MyKit0A5ClassC"],
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
                && $0.localizedSummary.contains("'/mykit'") }
        )
        XCTAssertNotNil(context.problems
            .map { $0.diagnostic }
            .filter { $0.identifier == "org.swift.docc.DuplicateMarkdownTitleSymbolReferences"
                && $0.localizedSummary.contains("'/myprotocol'") }
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
 ╰ doc://org.swift.docc.example/documentation/SideKit/SideProtocol
   ╰ doc://org.swift.docc.example/documentation/SideKit/SideProtocol/func()-6ijsi
     ╰ doc://org.swift.docc.example/documentation/SideKit/SideProtocol/func()-2dxqn
 doc://org.swift.docc.example/documentation/SideKit/NonExistent/UncuratedClass
 doc://org.swift.docc.example/documentation/Test
 ╰ doc://org.swift.docc.example/documentation/Test/FirstGroup
   ╰ doc://org.swift.docc.example/documentation/Test/FirstGroup/MySnippet
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
        XCTAssertEqual(context.pathsTo(ResolvedTopicReference(bundleIdentifier: "org.swift.docc.example", path: "/documentation/MyKit/MyClass", sourceLanguage: .swift)).map { $0.map {$0.absoluteString} },
                       [["doc://org.swift.docc.example/documentation/MyKit"], ["doc://org.swift.docc.example/documentation/MyKit", "doc://org.swift.docc.example/documentation/MyKit/MyProtocol"]])
        
        XCTAssertEqual(context.pathsTo(ResolvedTopicReference(bundleIdentifier: "org.swift.docc.example", path: "/documentation/MyKit/MyClass/init()-33vaw", sourceLanguage: .swift)).map { $0.map {$0.absoluteString} },
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
        
        let canonicalPathCCC = try XCTUnwrap(context.pathsTo(cccNode.reference).first)
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
        
        let canonicalPathFFF = try XCTUnwrap(context.pathsTo(fffNode.reference).first)
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
        
        let canonicalPathCCC = try XCTUnwrap(context.pathsTo(cccNode.reference).first)
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
        
        let canonicalPathFFF = try XCTUnwrap(context.pathsTo(fffNode.reference).first)
        XCTAssertEqual(["/documentation/MyKit"], canonicalPathFFF.map({ $0.path }))
    }

    // Verify that a symbol that has no parents in the symbol graph is automatically curated under the module node.
    func testRootSymbolsAreCureatedInModule() throws {
        let (url, bundle, context) = try testBundleAndContext(copying: "TestBundle")
        defer { try? FileManager.default.removeItem(at: url) }
        
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
    
    /// Tests whether tutoral curated multiple times gets the correct breadcrumbs and hierarchy.
    func testCurateTutorialMultipleTimes() throws {
        // Curate "TestTutorial" under MyKit as well as TechnologyX.
        let (bundleURL, _, context) = try testBundleAndContext(copying: "TestBundle") { root in
            let myKitURL = root.appendingPathComponent("documentation/mykit.md")
            let text = try String(contentsOf: myKitURL).replacingOccurrences(of: "## Topics", with: """
            ## Topics

            ### Tutorials
             - <doc:/tutorials/Test-Bundle/TestTutorial>
             - <doc:/tutorials/Test-Bundle/TestTutorial2>
            """)
            try text.write(to: myKitURL, atomically: true, encoding: .utf8)
        }
        
        defer { try? FileManager.default.removeItem(at: bundleURL) }
        
        // Get a node
        let node = try context.entity(with: ResolvedTopicReference(bundleIdentifier: "org.swift.docc.example", path: "/tutorials/Test-Bundle/TestTutorial", sourceLanguage: .swift))
        
        // Get the breacrumbs as paths
        let paths = context.pathsTo(node.reference).sorted { (path1, path2) -> Bool in
            return path1.count < path2.count
        }
        .map { return $0.map { $0.url.path } }
        
        // Verify the tutorial has multiple paths
        XCTAssertEqual(paths, [["/documentation/MyKit"], ["/documentation/MyKit", "/documentation/Test-Bundle/article"], ["/tutorials/TestOverview", "/tutorials/TestOverview/$volume", "/tutorials/TestOverview/Chapter-1"]])
    }

    func testNonOverloadPaths() throws {
        // Add some symbol collisions to graph
        let (bundleURL, _, context) = try testBundleAndContext(copying: "TestBundle") { root in
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
            """)
            try text.write(to: sideKitURL, atomically: true, encoding: .utf8)
        }
        
        defer { try? FileManager.default.removeItem(at: bundleURL) }
        
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
            context.soleRootModuleReference?.sourceLanguages,
            [.swift],
            "Expected the module to have language 'Swift' since it has 0 symbols."
        )
    }

    func testOverloadPlustNonOverloadCollisionPaths() throws {
        // Add some symbol collisions to graph
        let (bundleURL, _, context) = try testBundleAndContext(copying: "TestBundle") { root in
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
            """)
            try text.write(to: sideKitURL, atomically: true, encoding: .utf8)
        }
        
        defer { try? FileManager.default.removeItem(at: bundleURL) }
        
        // Verify the non-overload collisions were resolved
        XCTAssertNoThrow(try context.entity(with: ResolvedTopicReference(bundleIdentifier: "org.swift.docc.example", path: "/documentation/SideKit/SideClass/Test-swift.enum", sourceLanguage: .swift)))
        XCTAssertNoThrow(try context.entity(with: ResolvedTopicReference(bundleIdentifier: "org.swift.docc.example", path: "/documentation/SideKit/SideClass/tEst-swift.var-9053a", sourceLanguage: .swift)))
        XCTAssertNoThrow(try context.entity(with: ResolvedTopicReference(bundleIdentifier: "org.swift.docc.example", path: "/documentation/SideKit/SideClass/test-swift.var-959hd", sourceLanguage: .swift)))
    }

    func testUnknownSymbolKind() throws {
        // Change the symbol kind to an unknown and load the symbol graph
        let (bundleURL, _, context) = try testBundleAndContext(copying: "TestBundle") { root in
            let myKitURL = root.appendingPathComponent("mykit-iOS.symbols.json")
            let text = try String(contentsOf: myKitURL).replacingOccurrences(of: "\"identifier\" : \"swift.method\"", with: "\"identifier\" : \"blip-blop\"")
            try text.write(to: myKitURL, atomically: true, encoding: .utf8)
        }
        defer { try? FileManager.default.removeItem(at: bundleURL) }
        
        // Get a function node, verify its kind is uknown
        let node = try context.entity(with: ResolvedTopicReference(bundleIdentifier: "org.swift.docc.example", path: "/documentation/MyKit/MyClass/myFunction()", sourceLanguage: .swift))
        XCTAssertEqual(node.kind, .unknown)
    }
    
    func testNonOverloadCollisionFromExtension() throws {
        // Add some symbol collisions to graph
        let (bundleURL, _, context) = try testBundleAndContext(copying: "TestBundle", excludingPaths: ["mykit-iOS.symbols.json"]) { root in
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
        
        defer { try? FileManager.default.removeItem(at: bundleURL) }
        
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
        let (bundleURL, _, context) = try testBundleAndContext(copying: "TestBundle") { root in
            unknownSymbolSidecarURL = root.appendingPathComponent("documentation/unknownSymbol.md")
            otherUnknownSymbolSidecarURL = root.appendingPathComponent("documentation/xanotherSidecarFileForThisUnknownSymbol.md")
            
            try content.write(to: unknownSymbolSidecarURL, atomically: true, encoding: .utf8)
            try content.write(to: otherUnknownSymbolSidecarURL, atomically: true, encoding: .utf8)
        }
        defer { try? FileManager.default.removeItem(at: bundleURL) }
        
        let unmatchedSidecarProblem = context.problems.first(where: { $0.diagnostic.identifier == "org.swift.docc.SymbolUnmatched" })
        
        // Verify the diagnostics have the sidecar source URL
        XCTAssertNotNil(unmatchedSidecarProblem?.diagnostic.source)
        var sidecarFilesForUnknownSymbol: Set<URL?> = [unknownSymbolSidecarURL.standardizedFileURL, otherUnknownSymbolSidecarURL.standardizedFileURL]
        
        XCTAssertNotNil(unmatchedSidecarProblem)
        if let unmatchedSidecarDiagnostic = unmatchedSidecarProblem?.diagnostic {
            XCTAssertTrue(sidecarFilesForUnknownSymbol.contains(unmatchedSidecarDiagnostic.source?.standardizedFileURL), "One of the files should be the diagnostic source")
            XCTAssertEqual(unmatchedSidecarDiagnostic.range, SourceLocation(line: 1, column: 3, source: unmatchedSidecarProblem?.diagnostic.source)..<SourceLocation(line: 1, column: 26, source: unmatchedSidecarProblem?.diagnostic.source))
            XCTAssertEqual(unmatchedSidecarDiagnostic.localizedSummary, "No symbol matched 'MyKit/UnknownSymbol'. This documentation will be ignored.")
            XCTAssertEqual(unmatchedSidecarDiagnostic.severity, .information)
            
            XCTAssertEqual(unmatchedSidecarDiagnostic.notes.count, 1)
            if let note = unmatchedSidecarDiagnostic.notes.first {
                sidecarFilesForUnknownSymbol.remove(unmatchedSidecarDiagnostic.source?.standardizedFileURL)
                XCTAssertTrue(sidecarFilesForUnknownSymbol.contains(note.source.standardizedFileURL), "The other files should be the note's source")
                
                XCTAssertEqual(note.message, "'MyKit/UnknownSymbol' is also documented here.")
            }
        }
    }
    
    func testUncuratedArticleDiagnostics() throws {
        var unknownSymbolSidecarURL: URL!
        
        // Add an article without curating it anywhere
        // This will be uncurated because there's more than one module in TestBundle.
        let (bundleURL, _, context) = try testBundleAndContext(copying: "TestBundle") { root in
            unknownSymbolSidecarURL = root.appendingPathComponent("UncuratedArticle.md")
            
            try """
            # Title of this article
            
            This article won't be curated anywhere.
            """.write(to: unknownSymbolSidecarURL, atomically: true, encoding: .utf8)
        }
        defer { try? FileManager.default.removeItem(at: bundleURL) }
        
        let curationDiagnostics =  context.problems.filter({ $0.diagnostic.identifier == "org.swift.docc.ArticleUncurated" }).map(\.diagnostic)
        let sidecarDiagnostic = try XCTUnwrap(curationDiagnostics.first(where: { $0.source?.standardizedFileURL == unknownSymbolSidecarURL.standardizedFileURL }))
        XCTAssertNil(sidecarDiagnostic.range)
        XCTAssertEqual(sidecarDiagnostic.localizedSummary, "You haven't curated 'doc://org.swift.docc.example/documentation/Test-Bundle/UncuratedArticle'")
        XCTAssertEqual(sidecarDiagnostic.severity, .information)
    }
    
    func testUpdatesReferencesForChildrenOfCollisions() throws {
        // Add some symbol collisions to graph
        let (bundleURL, _, context) = try testBundleAndContext(copying: "TestBundle") { root in
            let sideKitURL = root.appendingPathComponent("sidekit.symbols.json")
            var text = try String(contentsOf: sideKitURL)
            
            text = text.replacingOccurrences(of: "\"relationships\" : [", with: """
            "relationships" : [
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
        
        defer { try? FileManager.default.removeItem(at: bundleURL) }

        // Test that collision symbol reference was updated
        XCTAssertNoThrow(try context.entity(with: ResolvedTopicReference(bundleIdentifier: "org.swift.docc.example", path: "/documentation/SideKit/SideClass/Test-swift.enum", sourceLanguage: .swift)))
        
        // Test that collision symbol child reference was updated
        XCTAssertNoThrow(try context.entity(with: ResolvedTopicReference(bundleIdentifier: "org.swift.docc.example", path: "/documentation/SideKit/SideClass/Test-swift.enum/path", sourceLanguage: .swift)))

        // Test that nested collisions were updated
        XCTAssertNoThrow(try context.entity(with: ResolvedTopicReference(bundleIdentifier: "org.swift.docc.example", path: "/documentation/SideKit/SideClass/Test-swift.enum/NestedEnum-swift.enum", sourceLanguage: .swift)))
        XCTAssertNoThrow(try context.entity(with: ResolvedTopicReference(bundleIdentifier: "org.swift.docc.example", path: "/documentation/SideKit/SideClass/Test-swift.enum/nestedEnum-swift.property", sourceLanguage: .swift)))
        
        // Test that child of nested collision is updated
        XCTAssertNoThrow(try context.entity(with: ResolvedTopicReference(bundleIdentifier: "org.swift.docc.example", path: "/documentation/SideKit/SideClass/Test-swift.enum/NestedEnum-swift.enum/path", sourceLanguage: .swift)))
        
        // Verify that the symbol index has been udpated with the rewritten collision-corrected symbol paths
        XCTAssertEqual(context.symbolIndex["s:7SideKit0A5ClassC10testnEE"]?.reference.path, "/documentation/SideKit/SideClass/Test-swift.enum/nestedEnum-swift.property")
        XCTAssertEqual(context.symbolIndex["s:7SideKit0A5ClassC10testEE"]?.reference.path, "/documentation/SideKit/SideClass/Test-swift.enum/NestedEnum-swift.enum")
        XCTAssertEqual(context.symbolIndex["s:7SideKit0A5ClassC10tEstPP"]?.reference.path, "/documentation/SideKit/SideClass/Test-swift.enum/NestedEnum-swift.enum/path")
        
        XCTAssertEqual(context.symbolIndex["s:5MyKit0A5MyProtocol0Afunc()"]?.reference.path, "/documentation/SideKit/SideProtocol/func()-6ijsi")
        XCTAssertEqual(context.symbolIndex["s:5MyKit0A5MyProtocol0Afunc()DefaultImp"]?.reference.path, "/documentation/SideKit/SideProtocol/func()-2dxqn")
    }

    func testResolvingArticleLinkBeforeCuratingIt() throws {
        var newArticle1URL: URL!
        
        // Add an article without curating it anywhere
        let (bundleURL, _, context) = try testBundleAndContext(copying: "TestBundle") { root in
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
        defer { try? FileManager.default.removeItem(at: bundleURL) }
        
        // Verify that there are no problems for new-article1.md (where we resolve the link to new-article2 before it's curated)
        XCTAssertEqual(context.problems.filter { $0.diagnostic.source?.path.hasSuffix(newArticle1URL.lastPathComponent) == true }.count, 0)
    }

    // Modules that are being extended should not have their own symbol in the current bundle's graph.
    func testNoSymbolForTertiarySymbolGraphModules() throws {
        // Add an article without curating it anywhere
        let (bundleURL, _, context) = try testBundleAndContext(copying: "TestBundle") { root in
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
        defer { try? FileManager.default.removeItem(at: bundleURL) }

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
                ["17:96", "18:23", "18:43", "18:60", "18:89"].sorted()
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
    
    func testContextCachesReferences() throws {
        // Verify there is no pool bucket for the bundle we're about to test
        XCTAssertNil(ResolvedTopicReference.sharedPool.sync({ $0[#function] }))
        
        let (url, _, _) = try testBundleAndContext(copying: "TestBundle", excludingPaths: [], codeListings: [:], configureBundle: { rootURL in
            let infoPlistURL = rootURL.appendingPathComponent("Info.plist", isDirectory: false)
            try! String(contentsOf: infoPlistURL)
                .replacingOccurrences(of: "org.swift.docc.example", with: #function)
                .write(to: infoPlistURL, atomically: true, encoding: .utf8)
        })
        
        defer { try! FileManager.default.removeItem(at: url) }

        // Verify there is a pool bucket for the bundle we've loaded
        XCTAssertNotNil(ResolvedTopicReference.sharedPool.sync({ $0[#function] }))
        
        guard let references = ResolvedTopicReference.sharedPool.sync({ $0[#function] }) else {
            return
        }
        
        let beforeCount = references.count
        
        // Verify a given identifier exists in the pool by creating it and verifying it wasn't added to the pool
        let identifier = ResolvedTopicReference(bundleIdentifier: #function, path: "/tutorials/Test-Bundle/TestTutorial", sourceLanguage: .swift)
        _ = identifier
        
        // Verify create the reference above did not add to the cache
        XCTAssertEqual(beforeCount, ResolvedTopicReference.sharedPool.sync({ $0[#function]!.count }))
        
        // Create a new reference for the same bundle that was not loaded with the context
        let newIdentifier = ResolvedTopicReference(bundleIdentifier: #function, path: "/tutorials/Test-Bundle/TestTutorial/\(#function)", sourceLanguage: .swift)
        _ = newIdentifier
        
        // Verify creating a new reference added to the ones loaded with the context
        XCTAssertNotEqual(beforeCount, ResolvedTopicReference.sharedPool.sync({ $0[#function]!.count }))
        
        // Purge the pool
        ResolvedTopicReference.purgePool(for: #function)
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
        
        let (_, _, context) = try! loadBundle(from: bundleURL)
        
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
        let markupArticle = Article(markup: Document(parsing: source), metadata: nil, redirects: nil)
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
        let (bundleURL, _, context) = try testBundleAndContext(copying: "TestBundle") { url in
            let extensionFile = """
            # ``SideKit/SideClass/myFunction()``

            myFunction abstract

            ## Overview

            This is unresolvable: <doc:Does-Not-Exist>.

            """
            let fileURL = url.appendingPathComponent("documentation").appendingPathComponent("myFunction.md")
            try extensionFile.write(to: fileURL, atomically: true, encoding: .utf8)
        }
        defer { try? FileManager.default.removeItem(at: bundleURL) }
        let problems = context.diagnosticEngine.problems
        let linkResolutionProblems = problems.filter { $0.diagnostic.source?.relativePath.hasSuffix("myFunction.md") == true }
        XCTAssertEqual(linkResolutionProblems.count, 1)
        let problem = try XCTUnwrap(linkResolutionProblems.first)
        XCTAssertEqual(problem.diagnostic.range?.lowerBound.line, 7)
        XCTAssertEqual(problem.diagnostic.range?.lowerBound.column, 23)

        let functionNode = try XCTUnwrap(context.symbolIndex["s:7SideKit0A5ClassC10myFunctionyyF"])
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
        XCTAssertEqual(duplicateMarkdownProblems.count, 2)
        XCTAssertEqual(duplicateMarkdownProblems.first?.diagnostic.localizedSummary, "Multiple occurrences of \'/documentation/MyKit/MyClass/myFunction()\' found")
    }
    
    /// This test verifies that collision nodes and children of collision nodes are correctly
    /// matched with their documentation extension files. Besides verifying the correct content
    /// it verifies also that the curation in these doc extensions is reflected in the topic graph.
    func testMatchesCorrectlyDocExtensionToChildOfCollisionTopic() throws {
        let (bundleURL, bundle, context) = try testBundleAndContext(copying: "OverloadedSymbols") { url in
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
        }
        defer { try? FileManager.default.removeItem(at: bundleURL) }
        
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
        let reference2 = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/ShapeKit/OverloadedParentStruct-1jr3p/fifthTestMember-swift.type.property", sourceLanguage: .swift)
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
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        let moduleReference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/MyKit", sourceLanguage: .swift)
        let moduleTopicGraphNode = try XCTUnwrap(context.topicGraph.nodeWithReference(moduleReference))

        // Add a new resolvable node
        let resolvableReference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/Test-Bundle/resolvable-article", sourceLanguage: .swift)
        let resolvableNode = try DocumentationNode(reference: resolvableReference, article: Article(markup: Document(parsing: "# Article1"), metadata: nil, redirects: nil))
        context.documentationCache[resolvableReference] = resolvableNode
        
        let resolvableTopicGraphNode = TopicGraph.Node(reference: resolvableReference, kind: .article, source: .external, title: "Article1", isResolvable: true)
        context.topicGraph.addEdge(from: moduleTopicGraphNode, to: resolvableTopicGraphNode)
        
        // Try resolving the new resolvable node
        XCTAssertNoThrow(try context.entity(with: resolvableReference))
        switch context.resolve(.unresolved(UnresolvedTopicReference(topicURL: ValidatedURL(parsing: "doc:resolvable-article")!)), in: moduleReference) {
        case .success: break
        case .failure(_, let errorMessage): XCTFail("Did not resolve resolvable link. Error: \(errorMessage)")
        }
    }
    
    // Verifies if the context fails to resolve non-resolvable nodes.
    func testNonLinkableNodes() throws {
        // Create a bundle with variety absolute and relative links and symbol links to a non linkable node.
        let (url, _, context) = try testBundleAndContext(copying: "TestBundle", excludingPaths: [], codeListings: [:], externalResolvers: [:], externalSymbolResolver: nil, configureBundle: { url in
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
        defer { try? FileManager.default.removeItem(at: url) }

        let disabledDestinationProblems = context.problems.filter { p in
            return p.diagnostic.identifier == "org.swift.docc.disabledLinkDestination"
                && p.diagnostic.source?.path.hasSuffix("sideclass.md") == true
        }

        let mapRangeAsString: (Optional<SourceRange>) -> String? = { range in
            guard let range = range else { return nil }
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
            
            let unresolved = TopicReference.unresolved(.init(topicURL: try XCTUnwrap(ValidatedURL(parsing: "doc:Test"))))
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
            
            let unresolved = TopicReference.unresolved(.init(topicURL: try XCTUnwrap(ValidatedURL(parsing: "doc:Test"))))
            let expected = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/Test-Bundle/Test", sourceLanguage: .swift)
            
            let symbolReference = try XCTUnwrap(context.symbolIndex["s:12Minimal_docs4TestV"]?.reference)
            
            // Resolve from various locations in the bundle
            for parent in [bundle.rootReference, bundle.documentationRootReference, bundle.tutorialsRootReference, symbolReference] {
                switch context.resolve(unresolved, in: parent) {
                    case .success(let reference):
                        if reference.path != expected.path {
                            XCTFail("Expected to resolve to \(expected.path) but got \(reference.path)")
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
            // with an explicity preference.
            let unresolvedSymbolRef1 = UnresolvedTopicReference(topicURL: ValidatedURL(parsing: "Test")!)
            switch context.resolve(.unresolved(unresolvedSymbolRef1), in: moduleReference, fromSymbolLink: true) {
                case .failure(_, let errorMessage): XCTFail("Did not resolve a symbol link to the symbol Test. Error: \(errorMessage)")
                default: break
            }
            switch context.resolve(.unresolved(unresolvedSymbolRef1), in: moduleReference, fromSymbolLink: false) {
                case .failure(_, let errorMessage): XCTFail("Did not resolve a topic link to the symbol Test. Error: \(errorMessage)")
                default: break
            }

            let articleRef1 = UnresolvedTopicReference(topicURL: ValidatedURL(parsing: "Article")!)
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
        
        let moduleSymbol = try XCTUnwrap(context.symbolIndex["ExampleDocumentedExecutable"]?.symbol)
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
            context.symbolIndex.count,
            1001,
            "Expected 1000 symbols from the symbol graph + 1 for the module."
        )
        
        XCTAssertEqual(
            context.documentationCache.count,
            1001,
            "Expected 1000 nodes for each symbol of the symbol graph + 1 for the module."
        )
        
        // Create ObjectIdentifier values for the symbols stored in the documentationCache and symbolIndex dictionaries,
        // and verify that the dictionaries contain the same set of Symbol objects.
        
        let symbolsInDocumentationCache = Set(
            context.documentationCache.values
                .lazy
                .compactMap { $0.semantic as? Symbol }
                .map(ObjectIdentifier.init)
        )
        
        let symbolsInSymbolIndex = Set(
            context.symbolIndex.values.compactMap { node -> ObjectIdentifier? in
                guard let symbol = node.semantic as? Symbol else {
                    XCTFail("Node in symbolIndex doesn't have a symbol.")
                    return nil
                }
                return ObjectIdentifier(symbol)
            }
        )
        
        XCTAssertEqual(
            symbolsInDocumentationCache,
            symbolsInSymbolIndex,
            "Expected the symbol instances in the documentationCache and symbolIndex dictionaries to be the same"
        )
    }
    
    func assertArticleAvailableSourceLanguages(
        moduleAvailableLanguages: Set<SourceLanguage>,
        expectedArticleDefaultLanguage: SourceLanguage,
        file: StaticString = #file,
        line: UInt = #line
    ) throws {
        precondition(
            moduleAvailableLanguages.allSatisfy { [.swift, .objectiveC].contains($0) },
            "moduleAvailableLanguages can only contain Swift and Objective-C as languages."
        )
        
        let (_, _, context) = try testBundleAndContext(copying: "MixedLanguageFramework") { url in
            try """
            # MyArticle
            
            The framework this article is documenting is available in the following languages: \
            \(moduleAvailableLanguages.map(\.name).joined(separator: ",")).
            """.write(to: url.appendingPathComponent("myarticle.md"), atomically: true, encoding: .utf8)
            
            func removeSymbolGraph(compiler: String) throws {
                try FileManager.default.removeItem(
                    at: url.appendingPathComponent("symbol-graphs").appendingPathComponent(compiler)
                )
            }
            
            if !moduleAvailableLanguages.contains(.swift) {
                try removeSymbolGraph(compiler: "swift")
            }
            
            if !moduleAvailableLanguages.contains(.objectiveC) {
                try removeSymbolGraph(compiler: "clang")
            }
        }
        
        let articleNode = try XCTUnwrap(
            context.documentationCache.first {
                $0.key.path == "/documentation/MixedLanguageFramework/myarticle"
            }?.value,
            file: file,
            line: line
        )
        
        XCTAssertEqual(
            articleNode.availableSourceLanguages,
            moduleAvailableLanguages,
            "Expected the article's source languages to have inherited from the module's available source languages.",
            file: file,
            line: line
        )
        
        XCTAssertEqual(
            articleNode.sourceLanguage,
            expectedArticleDefaultLanguage,
            file: file,
            line: line
        )
    }
    
    func testArticleAvailableSourceLanguagesIsSwiftInSwiftModule() throws {
        enableFeatureFlag(\.isExperimentalObjectiveCSupportEnabled)
        
        try assertArticleAvailableSourceLanguages(
            moduleAvailableLanguages: [.swift],
            expectedArticleDefaultLanguage: .swift
        )
    }
    
    func testArticleAvailableSourceLanguagesIsMixedLanguageInMixedLanguageModule() throws {
        enableFeatureFlag(\.isExperimentalObjectiveCSupportEnabled)
        
        try assertArticleAvailableSourceLanguages(
            moduleAvailableLanguages: [.swift, .objectiveC],
            expectedArticleDefaultLanguage: .swift
        )
    }
    
    func testArticleAvailableSourceLanguagesIsObjectiveCInObjectiveCModule() throws {
        enableFeatureFlag(\.isExperimentalObjectiveCSupportEnabled)
        
        try assertArticleAvailableSourceLanguages(
            moduleAvailableLanguages: [.objectiveC],
            expectedArticleDefaultLanguage: .objectiveC
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
