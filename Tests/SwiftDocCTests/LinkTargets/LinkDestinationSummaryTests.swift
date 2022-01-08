/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocC
import SwiftDocCTestUtilities

class ExternalLinkableTests: XCTestCase {
    
    // Write example documentation bundle with a minimal Tutorials page
    let bundleFolderHierarchy = Folder(name: "unit-test.docc", content: [
        Folder(name: "Symbols", content: []),
        Folder(name: "Resources", content: [
            TextFile(name: "TechnologyX.tutorial", utf8Content: """
                @Tutorials(name: "TechnologyX") {
                   @Intro(title: "Technology X") {

                      You'll learn all about Technology X.

                      @Image(source: arkit.png, alt: arkit)
                   }

                   @Redirected(from: "old/path/to/this/page")
                   @Redirected(from: "even/older/path/to/this/page")

                   @Volume(name: "Volume 1") {
                      This volume contains Chapter 1.

                      @Chapter(name: "Chapter 1") {
                         In this chapter, you'll follow Tutorial 1.
                         @TutorialReference(tutorial: Tutorial)
                         @Image(source: blah, alt: blah)
                      }
                   }
                }
                """),
            TextFile(name: "Tutorial.tutorial", utf8Content: """
                @Tutorial(time: 20, projectFiles: project.zip) {
                   @XcodeRequirement(title: "Xcode 10.2 Beta 3", destination: "https://www.example.com/download")
                   @Intro(title: "Basic Augmented Reality App", background: image.jpg) {
                      @Video(source: video.mov)
                   }
                   
                   @Section(title: "Create a New AR Project") {
                      @ContentAndMedia(layout: vertical) {
                         Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt
                         ut labore et dolore magna aliqua. Phasellus faucibus scelerisque eleifend donec pretium.

                         Ultrices dui sapien eget mi proin sed libero enim. Quis auctor elit sed vulputate mi sit amet.

                         @Image(source: arkit.png)
                      }

                      @Redirected(from: "old/path/to/this/landmark")
                      
                      @Steps {
                                                 
                         Let's get started building the Augmented Reality app.
                      
                         @Step {
                            Lorem ipsum dolor sit amet, consectetur.
                        
                            @Image(source: Sierra.jpg)
                         }
                      }
                   }
                   @Assessments {
                      @MultipleChoice {
                         Lorem ipsum dolor sit amet?

                         Phasellus faucibus scelerisque eleifend donec pretium.
                                                      
                         @Choice(isCorrect: true) {
                            `anchor.hitTest(view)`
                            
                            @Justification {
                               This is correct because it is.
                            }
                         }
                      }
                   }
                }
                """),
            ]),
        InfoPlist(displayName: "TestBundle", identifier: "com.test.example"),
    ])
    
    func testSummaryOfTutorialPage() throws {
        let workspace = DocumentationWorkspace()
        let context = try! DocumentationContext(dataProvider: workspace)
        
        let bundleURL = try bundleFolderHierarchy.write(inside: createTemporaryDirectory())
        
        let dataProvider = try LocalFileSystemDataProvider(rootURL: bundleURL)
        try workspace.registerProvider(dataProvider)
        
        let bundle = context.bundle(identifier: "com.test.example")!
        let converter = DocumentationNodeConverter(bundle: bundle, context: context)
        
        let node = try context.entity(with: ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/tutorials/TestBundle/Tutorial", sourceLanguage: .swift))
        let renderNode = try converter.convert(node, at: nil)
        
        let summaries = node.externallyLinkableElementSummaries(context: context, renderNode: renderNode)
        let pageSummary = summaries[0]
        XCTAssertEqual(pageSummary.title, "Basic Augmented Reality App")
        XCTAssertEqual(pageSummary.path, "/tutorials/testbundle/tutorial")
        XCTAssertEqual(pageSummary.referenceURL.absoluteString, "doc://com.test.example/tutorials/TestBundle/Tutorial")
        XCTAssertEqual(pageSummary.language, .swift)
        XCTAssertEqual(pageSummary.kind, .tutorial)
        XCTAssertEqual(pageSummary.taskGroups, [
            .init(title: nil,
                  identifiers: ["doc://com.test.example/tutorials/TestBundle/Tutorial#Create-a-New-AR-Project"]
            ),
        ])
        XCTAssertEqual(pageSummary.availableLanguages, [.swift])
        XCTAssertEqual(pageSummary.platforms, renderNode.metadata.platforms)
        XCTAssertEqual(pageSummary.redirects, nil)
        XCTAssertNil(pageSummary.usr, "Only symbols have USRs")
        XCTAssertNil(pageSummary.declarationFragments, "Only symbols have declaration fragments")
        XCTAssertNil(pageSummary.abstract, "There is no text to use as an abstract for the tutorial page")

        let sectionSummary = summaries[1]
        XCTAssertEqual(sectionSummary.title, "Create a New AR Project")
        XCTAssertEqual(sectionSummary.path, "/tutorials/testbundle/tutorial#Create-a-New-AR-Project")
        XCTAssertEqual(sectionSummary.referenceURL.absoluteString, "doc://com.test.example/tutorials/TestBundle/Tutorial#Create-a-New-AR-Project")
        XCTAssertEqual(sectionSummary.language, .swift)
        XCTAssertEqual(sectionSummary.kind, .onPageLandmark)
        XCTAssertEqual(sectionSummary.taskGroups, [])
        XCTAssertEqual(sectionSummary.availableLanguages, [.swift])
        XCTAssertEqual(sectionSummary.platforms, nil)
        XCTAssertEqual(sectionSummary.redirects, [
            URL(string: "old/path/to/this/landmark")!,
        ])
        XCTAssertNil(sectionSummary.usr, "Only symbols have USRs")
        XCTAssertNil(sectionSummary.declarationFragments, "Only symbols have declaration fragments")
        XCTAssertEqual(sectionSummary.abstract, [
            .text("Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt"),
            .text(" "),
            .text("ut labore et dolore magna aliqua. Phasellus faucibus scelerisque eleifend donec pretium."),
        ])
        
        // Test that the summaries can be decoded from the encoded data
        let encoded = try JSONEncoder().encode(summaries)
        let decoded = try JSONDecoder().decode([LinkDestinationSummary].self, from: encoded)
        XCTAssertEqual(summaries, decoded)
    }

    func testSymbolSummaries() throws {
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        let converter = DocumentationNodeConverter(bundle: bundle, context: context)
        do {
            let symbolReference = ResolvedTopicReference(bundleIdentifier: "org.swift.docc.example", path: "/documentation/MyKit/MyClass", sourceLanguage: .swift)
            let node = try context.entity(with: symbolReference)
            let renderNode = try converter.convert(node, at: nil)
            let summary = node.externallyLinkableElementSummaries(context: context, renderNode: renderNode)[0]
            
            XCTAssertEqual(summary.title, "MyClass")
            XCTAssertEqual(summary.path, "/documentation/mykit/myclass")
            XCTAssertEqual(summary.referenceURL.absoluteString, "doc://org.swift.docc.example/documentation/MyKit/MyClass")
            XCTAssertEqual(summary.language, .swift)
            XCTAssertEqual(summary.kind, .class)
            XCTAssertEqual(summary.abstract, [.text("MyClass abstract.")])
            XCTAssertEqual(summary.taskGroups?.map { $0.title }, [
                "MyClass members (relative)",
                "MyClass members (module level)",
                "MyClass members (absolute)",
                "MyClass members (topic relative)",
                "MyClass members (topic module level)",
                "MyClass members (topic absolute)",
            ])
            for group in summary.taskGroups ?? [] {
                // All 6 topic sections curate the same 3 symbols using different syntax and different specificity
                XCTAssertEqual(group.identifiers, [
                    summary.referenceURL.appendingPathComponent("init()-33vaw").absoluteString,
                    summary.referenceURL.appendingPathComponent("init()-3743d").absoluteString,
                    summary.referenceURL.appendingPathComponent("myFunction()").absoluteString,
                ])
            }
            XCTAssertEqual(summary.availableLanguages, [.swift])
            XCTAssertEqual(summary.platforms, renderNode.metadata.platforms)
            XCTAssertEqual(summary.usr, "s:5MyKit0A5ClassC")
            XCTAssertEqual(summary.declarationFragments, [
                .init(text: "class", kind: .keyword, identifier: nil),
                .init(text: " ", kind: .text, identifier: nil),
                .init(text: "MyClass", kind: .identifier, identifier: nil),
            ])
        }
        
        do {
            let symbolReference = ResolvedTopicReference(bundleIdentifier: "org.swift.docc.example", path: "/documentation/MyKit/MyProtocol", sourceLanguage: .swift)
            let node = try context.entity(with: symbolReference)
            let renderNode = try converter.convert(node, at: nil)
            let summary = node.externallyLinkableElementSummaries(context: context, renderNode: renderNode)[0]
            
            XCTAssertEqual(summary.title, "MyProtocol")
            XCTAssertEqual(summary.path, "/documentation/mykit/myprotocol")
            XCTAssertEqual(summary.referenceURL.absoluteString, "doc://org.swift.docc.example/documentation/MyKit/MyProtocol")
            XCTAssertEqual(summary.language, .swift)
            XCTAssertEqual(summary.kind, .protocol)
            XCTAssertEqual(summary.abstract, [.text("An abstract of a protocol using a "), .codeVoice(code: "String"), .text(" id value.")])
            XCTAssertEqual(summary.taskGroups, [
                .init(
                    title: "Task Group Excercising Symbol Links",
                    identifiers: [
                        // MyClass is curated 3 times using different syntax.
                        summary.referenceURL.deletingLastPathComponent().appendingPathComponent("MyClass").absoluteString,
                        summary.referenceURL.deletingLastPathComponent().appendingPathComponent("MyClass").absoluteString,
                        summary.referenceURL.deletingLastPathComponent().appendingPathComponent("MyClass").absoluteString,
                    ]
                ),
            ])
            XCTAssertEqual(summary.availableLanguages, [.swift])
            XCTAssertEqual(summary.platforms, renderNode.metadata.platforms)
            XCTAssertEqual(summary.usr, "s:5MyKit0A5ProtocolP")
            XCTAssertEqual(summary.declarationFragments, [
                .init(text: "protocol", kind: .keyword, identifier: nil),
                .init(text: " ", kind: .text, identifier: nil),
                .init(text: "MyProtocol", kind: .identifier, identifier: nil),
                .init(text: " : ", kind: .text, identifier: nil),
                .init(text: "Hashable", kind: .typeIdentifier, identifier: nil, preciseIdentifier: "p:hPP"),
            ])
        }
        
        do {
            let symbolReference = ResolvedTopicReference(bundleIdentifier: "org.swift.docc.example", path: "/documentation/MyKit/MyClass/myFunction()", sourceLanguage: .swift)
            let node = try context.entity(with: symbolReference)
            let renderNode = try converter.convert(node, at: nil)
            let summary = node.externallyLinkableElementSummaries(context: context, renderNode: renderNode)[0]
            
            XCTAssertEqual(summary.title, "myFunction()")
            XCTAssertEqual(summary.path, "/documentation/mykit/myclass/myfunction()")
            XCTAssertEqual(summary.referenceURL.absoluteString, "doc://org.swift.docc.example/documentation/MyKit/MyClass/myFunction()")
            XCTAssertEqual(summary.language, .swift)
            XCTAssertEqual(summary.kind, .instanceMethod)
            XCTAssertEqual(summary.abstract, [.text("A cool API to call.")])
            XCTAssertEqual(summary.taskGroups, [])
            XCTAssertEqual(summary.availableLanguages, [.swift])
            XCTAssertEqual(summary.platforms, renderNode.metadata.platforms)
            XCTAssertEqual(summary.usr, "s:5MyKit0A5ClassC10myFunctionyyF")
            XCTAssertEqual(summary.declarationFragments, nil) // This symbol doesn't have a `subHeading` in the symbol graph
        }
        
        do {
            let symbolReference = ResolvedTopicReference(bundleIdentifier: "org.swift.docc.example", path: "/documentation/MyKit/globalFunction(_:considering:)", sourceLanguage: .swift)
            let node = try context.entity(with: symbolReference)
            let renderNode = try converter.convert(node, at: nil)
            let summary = node.externallyLinkableElementSummaries(context: context, renderNode: renderNode)[0]
            
            XCTAssertEqual(summary.title, "globalFunction(_:considering:)")
            XCTAssertEqual(summary.path, "/documentation/mykit/globalfunction(_:considering:)")
            XCTAssertEqual(summary.referenceURL.absoluteString, "doc://org.swift.docc.example/documentation/MyKit/globalFunction(_:considering:)")
            XCTAssertEqual(summary.language, .swift)
            XCTAssertEqual(summary.kind, .function)
            XCTAssertEqual(summary.abstract, nil)
            XCTAssertEqual(summary.taskGroups, [])
            XCTAssertEqual(summary.availableLanguages, [.swift])
            XCTAssertEqual(summary.platforms, renderNode.metadata.platforms)
            XCTAssertEqual(summary.usr, "s:5MyKit14globalFunction_11consideringy10Foundation4DataV_SitF")
            XCTAssertEqual(summary.declarationFragments, [
                .init(text: "func", kind: .keyword, identifier: nil, preciseIdentifier: nil),
                .init(text: " ", kind: .text, identifier: nil, preciseIdentifier: nil),
                .init(text: "globalFunction", kind: .identifier, identifier: nil, preciseIdentifier: nil),
                .init(text: "(", kind: .text, identifier: nil, preciseIdentifier: nil),
                .init(text: "Data", kind: .typeIdentifier, identifier: nil, preciseIdentifier: "s:10Foundation4DataV"),
                .init(text: ", ", kind: .text, identifier: nil, preciseIdentifier: nil),
                .init(text: "considering", kind: .identifier, identifier: nil, preciseIdentifier: nil),
                .init(text: ": ", kind: .text, identifier: nil, preciseIdentifier: nil),
                .init(text: "Int", kind: .typeIdentifier, identifier: nil, preciseIdentifier: "s:Si"),
                .init(text: ")", kind: .text, identifier: nil, preciseIdentifier: nil),
                .init(text: "\n", kind: .text, identifier: nil, preciseIdentifier: nil),
            ])
        }
    }
    func testDecodingLegacyData() throws {
        let legacyData = """
        {
          "title": "ClassName",
          "referenceURL": "doc://org.swift.docc.example/documentation/MyKit/ClassName",
          "language": "swift",
          "path": "documentation/MyKit/ClassName",
          "availableLanguages": [
            "swift"
          ],
          "kind": "org.swift.docc.kind.class",
          "abstract": [
            {
              "type": "text",
              "text": "A brief explanation of my class."
            }
          ],
          "platforms": [
            {
              "name": "PlatformName",
              "introducedAt": "1.0"
            },
          ],
          "fragments": [
            {
              "kind": "keyword",
              "text": "class"
            },
            {
              "kind": "text",
              "text": " "
            },
            {
              "kind": "identifier",
              "text": "ClassName"
            }
          ]
        }
        """.data(using: .utf8)!
        
        let decoded = try JSONDecoder().decode(LinkDestinationSummary.self, from: legacyData)
        
        XCTAssertEqual(decoded.referenceURL, ResolvedTopicReference(bundleIdentifier: "org.swift.docc.example", path: "/documentation/MyKit/ClassName", sourceLanguage: .swift).url)
        XCTAssertEqual(decoded.platforms?.count, 1)
        XCTAssertEqual(decoded.platforms?.first?.name, "PlatformName")
        XCTAssertEqual(decoded.platforms?.first?.introduced, "1.0")
        XCTAssertEqual(decoded.kind, .class)
        XCTAssertEqual(decoded.title, "ClassName")
        XCTAssertEqual(decoded.abstract?.plainText, "A brief explanation of my class.")
        XCTAssertEqual(decoded.path, "documentation/MyKit/ClassName")
        XCTAssertEqual(decoded.declarationFragments, [
            .init(text: "class", kind: .keyword, identifier: nil),
            .init(text: " ", kind: .text, identifier: nil),
            .init(text: "ClassName", kind: .identifier, identifier: nil),
        ])
        
        XCTAssert(decoded.variants.isEmpty)
    }
}
