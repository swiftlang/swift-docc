/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocC

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
        let pageSummary = node.externallyLinkableElementSummaries(context: context, renderNode: renderNode)[0]
        
        // Check the page
        XCTAssertEqual(pageSummary.referenceURL.absoluteString, "doc://com.test.example/tutorials/TestBundle/Tutorial")
        XCTAssertEqual(pageSummary.availableLanguages, [.swift])
        XCTAssertEqual(pageSummary.platforms, renderNode.metadata.platforms)
        XCTAssertEqual(pageSummary.redirects, nil)
        XCTAssertNil(pageSummary.usr, "Only symbols have USRs")

        XCTAssertEqual(pageSummary.contentVariants.count, 1)
        let pageContentVariant = try XCTUnwrap(pageSummary.contentVariants.first)
        XCTAssertEqual(pageContentVariant.traits, [.interfaceLanguage("swift")])
        
        XCTAssertEqual(pageContentVariant.title, "Basic Augmented Reality App")
        XCTAssertEqual(pageContentVariant.path, "/tutorials/testbundle/tutorial")
        XCTAssertEqual(pageContentVariant.kind, .tutorial)
        XCTAssertEqual(pageContentVariant.taskGroups, [
            .init(title: nil,
                  identifiers: ["doc://com.test.example/tutorials/TestBundle/Tutorial#Create-a-New-AR-Project"]
            ),
        ])
        XCTAssertNil(pageContentVariant.declarationFragments, "Only symbols have declaration fragments")
        XCTAssertNil(pageContentVariant.abstract, "There is no text to use as an abstract for the tutorial page")

        // Check the section
        let sectionSummary = node.externallyLinkableElementSummaries(context: context, renderNode: renderNode)[1]
        
        XCTAssertEqual(sectionSummary.referenceURL.absoluteString, "doc://com.test.example/tutorials/TestBundle/Tutorial#Create-a-New-AR-Project")
        XCTAssertEqual(sectionSummary.availableLanguages, [.swift])
        XCTAssertEqual(sectionSummary.platforms, nil)
        XCTAssertEqual(sectionSummary.redirects, [
            URL(string: "old/path/to/this/landmark")!,
        ])
        XCTAssertNil(sectionSummary.usr, "Only symbols have USRs")
        
        XCTAssertEqual(sectionSummary.contentVariants.count, 1)
        let sectionContentVariant = try XCTUnwrap(sectionSummary.contentVariants.first)
        XCTAssertEqual(sectionContentVariant.traits, [.interfaceLanguage("swift")])

        XCTAssertEqual(sectionContentVariant.kind, .onPageLandmark)
        XCTAssertEqual(sectionContentVariant.title, "Create a New AR Project")
        XCTAssertEqual(sectionContentVariant.path, "/tutorials/testbundle/tutorial#Create-a-New-AR-Project")
        XCTAssertEqual(sectionContentVariant.taskGroups, [])
       
        XCTAssertNil(sectionContentVariant.declarationFragments, "Only symbols have declaration fragments")
        XCTAssertEqual(sectionContentVariant.abstract, [
            .text("Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt"),
            .text(" "),
            .text("ut labore et dolore magna aliqua. Phasellus faucibus scelerisque eleifend donec pretium."),
        ])
    }

    func testSymbolSummaries() throws {
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        let converter = DocumentationNodeConverter(bundle: bundle, context: context)
        do {
            let symbolReference = ResolvedTopicReference(bundleIdentifier: "org.swift.docc.example", path: "/documentation/MyKit/MyClass", sourceLanguage: .swift)
            let node = try context.entity(with: symbolReference)
            let renderNode = try converter.convert(node, at: nil)
            let summary = node.externallyLinkableElementSummaries(context: context, renderNode: renderNode)[0]
            
            XCTAssertEqual(summary.referenceURL.absoluteString, "doc://org.swift.docc.example/documentation/MyKit/MyClass")
            XCTAssertEqual(summary.availableLanguages, [.swift])
            XCTAssertEqual(summary.platforms, renderNode.metadata.platforms)
            XCTAssertEqual(summary.usr, "s:5MyKit0A5ClassC")
            
            XCTAssertEqual(summary.contentVariants.count, 1)
            let contentVariant = try XCTUnwrap(summary.contentVariants.first)
            XCTAssertEqual(contentVariant.traits, [.interfaceLanguage("swift")])
            
            XCTAssertEqual(contentVariant.kind, .class)
            XCTAssertEqual(contentVariant.title, "MyClass")
            XCTAssertEqual(contentVariant.path, "/documentation/mykit/myclass")
            XCTAssertEqual(contentVariant.abstract, [.text("MyClass abstract.")])
            XCTAssertEqual(contentVariant.taskGroups?.map { $0.title }, [
                "MyClass members (relative)",
                "MyClass members (module level)",
                "MyClass members (absolute)",
                "MyClass members (topic relative)",
                "MyClass members (topic module level)",
                "MyClass members (topic absolute)",
            ])
            for group in contentVariant.taskGroups ?? [] {
                // All 6 topic sections curate the same 3 symbols using different syntax and different specificity
                XCTAssertEqual(group.identifiers, [
                    summary.referenceURL.appendingPathComponent("init()-33vaw").absoluteString,
                    summary.referenceURL.appendingPathComponent("init()-3743d").absoluteString,
                    summary.referenceURL.appendingPathComponent("myFunction()").absoluteString,
                ])
            }
            XCTAssertEqual(contentVariant.declarationFragments, [
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
            
            XCTAssertEqual(summary.referenceURL.absoluteString, "doc://org.swift.docc.example/documentation/MyKit/MyProtocol")
            XCTAssertEqual(summary.availableLanguages, [.swift])
            XCTAssertEqual(summary.platforms, renderNode.metadata.platforms)
            XCTAssertEqual(summary.usr, "s:5MyKit0A5ProtocolP")
            
            XCTAssertEqual(summary.contentVariants.count, 1)
            let contentVariant = try XCTUnwrap(summary.contentVariants.first)
            XCTAssertEqual(contentVariant.traits, [.interfaceLanguage("swift")])
            
            XCTAssertEqual(contentVariant.kind, .protocol)
            XCTAssertEqual(contentVariant.title, "MyProtocol")
            XCTAssertEqual(contentVariant.path, "/documentation/mykit/myprotocol")
            XCTAssertEqual(contentVariant.abstract, [.text("An abstract of a protocol using a "), .codeVoice(code: "String"), .text(" id value.")])
            XCTAssertEqual(contentVariant.taskGroups, [
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
            
            XCTAssertEqual(contentVariant.declarationFragments, [
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
            
            XCTAssertEqual(summary.referenceURL.absoluteString, "doc://org.swift.docc.example/documentation/MyKit/MyClass/myFunction()")
            XCTAssertEqual(summary.availableLanguages, [.swift])
            XCTAssertEqual(summary.platforms, renderNode.metadata.platforms)
            XCTAssertEqual(summary.usr, "s:5MyKit0A5ClassC10myFunctionyyF")
            
            XCTAssertEqual(summary.contentVariants.count, 1)
            let contentVariant = try XCTUnwrap(summary.contentVariants.first)
            XCTAssertEqual(contentVariant.traits, [.interfaceLanguage("swift")])
            
            XCTAssertEqual(contentVariant.kind, .instanceMethod)
            XCTAssertEqual(contentVariant.title, "myFunction()")
            XCTAssertEqual(contentVariant.path, "/documentation/mykit/myclass/myfunction()")
            XCTAssertEqual(contentVariant.abstract, [.text("A cool API to call.")])
            XCTAssertEqual(contentVariant.taskGroups, [])
            XCTAssertEqual(contentVariant.declarationFragments, nil) // This symbol doesn't have a `subHeading` in the symbol graph
        }
        
        do {
            let symbolReference = ResolvedTopicReference(bundleIdentifier: "org.swift.docc.example", path: "/documentation/MyKit/globalFunction(_:considering:)", sourceLanguage: .swift)
            let node = try context.entity(with: symbolReference)
            let renderNode = try converter.convert(node, at: nil)
            let summary = node.externallyLinkableElementSummaries(context: context, renderNode: renderNode)[0]
            
            XCTAssertEqual(summary.referenceURL.absoluteString, "doc://org.swift.docc.example/documentation/MyKit/globalFunction(_:considering:)")
            XCTAssertEqual(summary.availableLanguages, [.swift])
            XCTAssertEqual(summary.platforms, renderNode.metadata.platforms)
            XCTAssertEqual(summary.usr, "s:5MyKit14globalFunction_11consideringy10Foundation4DataV_SitF")
            
            XCTAssertEqual(summary.contentVariants.count, 1)
            let contentVariant = try XCTUnwrap(summary.contentVariants.first)
            XCTAssertEqual(contentVariant.traits, [.interfaceLanguage("swift")])
            
            XCTAssertEqual(contentVariant.kind, .function)
            XCTAssertEqual(contentVariant.title, "globalFunction(_:considering:)")
            XCTAssertEqual(contentVariant.path, "/documentation/mykit/globalfunction(_:considering:)")
            XCTAssertEqual(contentVariant.abstract, nil)
            XCTAssertEqual(contentVariant.taskGroups, [])
            XCTAssertEqual(contentVariant.declarationFragments, [
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
        // Check the general information
        XCTAssertEqual(decoded.referenceURL, ResolvedTopicReference(bundleIdentifier: "org.swift.docc.example", path: "/documentation/MyKit/ClassName", sourceLanguage: .swift).url)
        XCTAssertEqual(decoded.platforms?.count, 1)
        XCTAssertEqual(decoded.platforms?.first?.name, "PlatformName")
        XCTAssertEqual(decoded.platforms?.first?.introduced, "1.0")
        
        // Check the language specific information
        XCTAssertEqual(decoded.contentVariants.count, 1)
        let contentVariant = try XCTUnwrap(decoded.contentVariants.first)
        XCTAssertEqual(contentVariant.traits, [.interfaceLanguage("swift")])
        
        XCTAssertEqual(contentVariant.kind, .class)
        XCTAssertEqual(contentVariant.title, "ClassName")
        XCTAssertEqual(contentVariant.abstract?.plainText, "A brief explanation of my class.")
        XCTAssertEqual(contentVariant.path, "documentation/MyKit/ClassName")
        XCTAssertEqual(contentVariant.declarationFragments, [
            .init(text: "class", kind: .keyword, identifier: nil),
            .init(text: " ", kind: .text, identifier: nil),
            .init(text: "ClassName", kind: .identifier, identifier: nil),
        ])
    }
    
    // Workaround that addTeardownBlock doesn't exist in swift-corelibs-xctest
    
    private var tempFilesToRemove: [URL] = []
    
    override func tearDown() {
        for url in tempFilesToRemove {
            try? FileManager.default.removeItem(at: url)
        }
        tempFilesToRemove.removeAll()
        super.tearDown()
    }
    
    func createTemporaryDirectory() throws -> URL {
        let url = Foundation.URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(ProcessInfo.processInfo.globallyUniqueString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        tempFilesToRemove.append(url)
        return url
    }
}
