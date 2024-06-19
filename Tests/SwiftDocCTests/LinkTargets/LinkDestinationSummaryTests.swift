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
                   @Intro(title: "Basic Augmented Reality App 💻", background: image.jpg) {
                      @Video(source: video.mov)
                   }
                   
                   @Section(title: "Create a New AR Project 💻") {
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
        let renderNode = try converter.convert(node)
        
        let summaries = node.externallyLinkableElementSummaries(context: context, renderNode: renderNode)
        let pageSummary = summaries[0]
        XCTAssertEqual(pageSummary.title, "Basic Augmented Reality App 💻")
        XCTAssertEqual(pageSummary.relativePresentationURL.absoluteString, "/tutorials/testbundle/tutorial")
        XCTAssertEqual(pageSummary.referenceURL.absoluteString, "doc://com.test.example/tutorials/TestBundle/Tutorial")
        XCTAssertEqual(pageSummary.language, .swift)
        XCTAssertEqual(pageSummary.kind, .tutorial)
        XCTAssertEqual(pageSummary.taskGroups, [
            .init(title: nil,
                  identifiers: ["doc://com.test.example/tutorials/TestBundle/Tutorial#Create-a-New-AR-Project-%F0%9F%92%BB"]
            ),
        ])
        XCTAssertEqual(pageSummary.availableLanguages, [.swift])
        XCTAssertEqual(pageSummary.platforms, renderNode.metadata.platforms)
        XCTAssertEqual(pageSummary.redirects, nil)
        XCTAssertNil(pageSummary.usr, "Only symbols have USRs")
        XCTAssertNil(pageSummary.declarationFragments, "Only symbols have declaration fragments")
        XCTAssertNil(pageSummary.abstract, "There is no text to use as an abstract for the tutorial page")
        XCTAssertNil(pageSummary.topicImages, "The tutorial page doesn't have any topic images")
        XCTAssertNil(pageSummary.references, "Since the tutorial page doesn't have any topic images it also doesn't have any references")
        
        let sectionSummary = summaries[1]
        XCTAssertEqual(sectionSummary.title, "Create a New AR Project 💻")
        XCTAssertEqual(sectionSummary.relativePresentationURL.absoluteString, "/tutorials/testbundle/tutorial#Create-a-New-AR-Project-%F0%9F%92%BB")
        XCTAssertEqual(sectionSummary.referenceURL.absoluteString, "doc://com.test.example/tutorials/TestBundle/Tutorial#Create-a-New-AR-Project-%F0%9F%92%BB")
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
        XCTAssertNil(sectionSummary.topicImages, "Sections don't have any topic images")
        XCTAssertNil(sectionSummary.references, "Since sections don't have any topic images it also doesn't have any references")
        
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
            let renderNode = try converter.convert(node)
            let summary = node.externallyLinkableElementSummaries(context: context, renderNode: renderNode)[0]
            
            XCTAssertEqual(summary.title, "MyClass")
            XCTAssertEqual(summary.relativePresentationURL.absoluteString, "/documentation/mykit/myclass")
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
            XCTAssertNil(summary.topicImages)
            XCTAssertNil(summary.references)
            
            let encoded = try JSONEncoder().encode(summary)
            let decoded = try JSONDecoder().decode(LinkDestinationSummary.self, from: encoded)
            XCTAssertEqual(decoded, summary)
        }
        
        do {
            let symbolReference = ResolvedTopicReference(bundleIdentifier: "org.swift.docc.example", path: "/documentation/MyKit/MyProtocol", sourceLanguage: .swift)
            let node = try context.entity(with: symbolReference)
            let renderNode = try converter.convert(node)
            let summary = node.externallyLinkableElementSummaries(context: context, renderNode: renderNode)[0]
            
            XCTAssertEqual(summary.title, "MyProtocol")
            XCTAssertEqual(summary.relativePresentationURL.absoluteString, "/documentation/mykit/myprotocol")
            XCTAssertEqual(summary.referenceURL.absoluteString, "doc://org.swift.docc.example/documentation/MyKit/MyProtocol")
            XCTAssertEqual(summary.language, .swift)
            XCTAssertEqual(summary.kind, .protocol)
            XCTAssertEqual(summary.abstract, [.text("An abstract of a protocol using a "), .codeVoice(code: "String"), .text(" id value.")])
            XCTAssertEqual(summary.taskGroups, [
                .init(
                    title: "Task Group Exercising Symbol Links",
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
            XCTAssertNil(summary.topicImages)
            XCTAssertNil(summary.references)
            
            let encoded = try JSONEncoder().encode(summary)
            let decoded = try JSONDecoder().decode(LinkDestinationSummary.self, from: encoded)
            XCTAssertEqual(decoded, summary)
        }
        
        do {
            let symbolReference = ResolvedTopicReference(bundleIdentifier: "org.swift.docc.example", path: "/documentation/MyKit/MyClass/myFunction()", sourceLanguage: .swift)
            let node = try context.entity(with: symbolReference)
            let renderNode = try converter.convert(node)
            let summary = node.externallyLinkableElementSummaries(context: context, renderNode: renderNode)[0]
            
            XCTAssertEqual(summary.title, "myFunction()")
            XCTAssertEqual(summary.relativePresentationURL.absoluteString, "/documentation/mykit/myclass/myfunction()")
            XCTAssertEqual(summary.referenceURL.absoluteString, "doc://org.swift.docc.example/documentation/MyKit/MyClass/myFunction()")
            XCTAssertEqual(summary.language, .swift)
            XCTAssertEqual(summary.kind, .instanceMethod)
            XCTAssertEqual(summary.abstract, [.text("A cool API to call.")])
            XCTAssertEqual(summary.taskGroups, [])
            XCTAssertEqual(summary.availableLanguages, [.swift])
            XCTAssertEqual(summary.platforms, renderNode.metadata.platforms)
            XCTAssertEqual(summary.usr, "s:5MyKit0A5ClassC10myFunctionyyF")
            XCTAssertEqual(summary.declarationFragments, [
                .init(text: "func", kind: .keyword, identifier: nil),
                .init(text: " ", kind: .text, identifier: nil),
                .init(text: "myFunction", kind: .identifier, identifier: nil),
                .init(text: "(", kind: .text, identifier: nil),
                .init(text: "for", kind: .externalParam, identifier: nil),
                .init(text: " ", kind: .text, identifier: nil),
                .init(text: "name", kind: .internalParam, identifier: nil),
                .init(text: "...", kind: .text, identifier: nil),
                .init(text: ")", kind: .text, identifier: nil)
            ])
            XCTAssertNil(summary.topicImages)
            XCTAssertNil(summary.references)
            
            let encoded = try JSONEncoder().encode(summary)
            let decoded = try JSONDecoder().decode(LinkDestinationSummary.self, from: encoded)
            XCTAssertEqual(decoded, summary)
        }
        
        do {
            let symbolReference = ResolvedTopicReference(bundleIdentifier: "org.swift.docc.example", path: "/documentation/MyKit/globalFunction(_:considering:)", sourceLanguage: .swift)
            let node = try context.entity(with: symbolReference)
            let renderNode = try converter.convert(node)
            let summary = node.externallyLinkableElementSummaries(context: context, renderNode: renderNode)[0]
            
            XCTAssertEqual(summary.title, "globalFunction(_:considering:)")
            XCTAssertEqual(summary.relativePresentationURL.absoluteString, "/documentation/mykit/globalfunction(_:considering:)")
            XCTAssertEqual(summary.referenceURL.absoluteString, "doc://org.swift.docc.example/documentation/MyKit/globalFunction(_:considering:)")
            XCTAssertEqual(summary.language, .swift)
            XCTAssertEqual(summary.kind, .function)
            XCTAssertEqual(summary.abstract, nil)
            XCTAssertEqual(summary.taskGroups, [])
            XCTAssertEqual(summary.availableLanguages, [.swift])
            XCTAssertEqual(summary.platforms, renderNode.metadata.platforms)
            XCTAssertEqual(summary.usr, "s:5MyKit14globalFunction_11consideringy10Foundation4DataV_SitF")
            XCTAssertEqual(summary.declarationFragments, [
                .init(text: "func", kind: .keyword, identifier: nil),
                .init(text: " ", kind: .text, identifier: nil),
                .init(text: "globalFunction", kind: .identifier, identifier: nil),
                .init(text: "(", kind: .text, identifier: nil),
                .init(text: "_", kind: .identifier, identifier: nil),
                .init(text: ": ", kind: .text, identifier: nil),
                .init(text: "Data", kind: .typeIdentifier, identifier: nil, preciseIdentifier: "s:10Foundation4DataV"),
                .init(text: ", ", kind: .text, identifier: nil),
                .init(text: "considering", kind: .identifier, identifier: nil),
                .init(text: ": ", kind: .text, identifier: nil),
                .init(text: "Int", kind: .typeIdentifier, identifier: nil, preciseIdentifier: "s:Si"),
                .init(text: ")", kind: .text, identifier: nil)
            ])
            XCTAssertNil(summary.topicImages)
            XCTAssertNil(summary.references)
            
            let encoded = try JSONEncoder().encode(summary)
            let decoded = try JSONDecoder().decode(LinkDestinationSummary.self, from: encoded)
            XCTAssertEqual(decoded, summary)
        }
    }
    
    func testTopicImageReferences() throws {
        let (url, bundle, context) = try testBundleAndContext(copying: "TestBundle") { url in
            let extensionFile = """
            # ``MyKit/MyClass/myFunction()``

            myFunction abstract
            
            @Metadata {
              @PageImage(purpose: card, source: figure1.png, alt: "Card image alt text")
            
              @PageImage(purpose: icon, source: something, alt: "Icon image alt text")
            }
            """
            let fileURL = url.appendingPathComponent("documentation").appendingPathComponent("myFunction.md")
            try extensionFile.write(to: fileURL, atomically: true, encoding: .utf8)
        }
        let converter = DocumentationNodeConverter(bundle: bundle, context: context)
        
        do {
            let symbolReference = ResolvedTopicReference(bundleIdentifier: "org.swift.docc.example", path: "/documentation/MyKit/MyClass/myFunction()", sourceLanguage: .swift)
            let node = try context.entity(with: symbolReference)
            let renderNode = try converter.convert(node)
            var summary = node.externallyLinkableElementSummaries(context: context, renderNode: renderNode)[0]
            
            XCTAssertEqual(summary.title, "myFunction()")
            XCTAssertEqual(summary.relativePresentationURL.absoluteString, "/documentation/mykit/myclass/myfunction()")
            XCTAssertEqual(summary.referenceURL.absoluteString, "doc://org.swift.docc.example/documentation/MyKit/MyClass/myFunction()")
            XCTAssertEqual(summary.language, .swift)
            XCTAssertEqual(summary.kind, .instanceMethod)
            XCTAssertEqual(summary.abstract, [.text("A cool API to call.")])
            XCTAssertEqual(summary.taskGroups, [])
            XCTAssertEqual(summary.availableLanguages, [.swift])
            XCTAssertEqual(summary.platforms, renderNode.metadata.platforms)
            XCTAssertEqual(summary.usr, "s:5MyKit0A5ClassC10myFunctionyyF")
            XCTAssertEqual(summary.declarationFragments, [
                .init(text: "func", kind: .keyword, identifier: nil),
                .init(text: " ", kind: .text, identifier: nil),
                .init(text: "myFunction", kind: .identifier, identifier: nil),
                .init(text: "(", kind: .text, identifier: nil),
                .init(text: "for", kind: .externalParam, identifier: nil),
                .init(text: " ", kind: .text, identifier: nil),
                .init(text: "name", kind: .internalParam, identifier: nil),
                .init(text: "...", kind: .text, identifier: nil),
                .init(text: ")", kind: .text, identifier: nil)
            ])
            
            XCTAssertEqual(summary.topicImages, [
                TopicImage(
                    type: .card,
                    identifier: RenderReferenceIdentifier("figure1.png")
                ),
                TopicImage(
                    type: .icon,
                    identifier: RenderReferenceIdentifier("something.png")
                ),
            ])
            
            XCTAssertEqual(summary.references?.count, 2)
            
            // The order of the references is expected to be stable.
            do {
                let imageReference = try XCTUnwrap(summary.references?.first as? ImageReference)
                XCTAssertEqual(imageReference.identifier.identifier, "figure1.png")
                XCTAssertEqual(imageReference.altText, "Card image alt text")
                XCTAssertEqual(imageReference.asset.context, .display)
                
                XCTAssertEqual(Set(imageReference.asset.variants.keys), [
                    DataTraitCollection(userInterfaceStyle: .light, displayScale: .standard),
                    DataTraitCollection(userInterfaceStyle: .dark, displayScale: .standard),
                ])
                let lightImageURL = try XCTUnwrap(imageReference.asset.variants[DataTraitCollection(userInterfaceStyle: .light, displayScale: .standard)])
                XCTAssertEqual(lightImageURL, url.appendingPathComponent("figure1.png"))
                let darkImageURL = try XCTUnwrap(imageReference.asset.variants[DataTraitCollection(userInterfaceStyle: .dark, displayScale: .standard)])
                XCTAssertEqual(darkImageURL, url.appendingPathComponent("figure1~dark.png"))
                
                XCTAssertEqual(Set(imageReference.asset.metadata.keys), [lightImageURL, darkImageURL])
                let lightImageMetadata = try XCTUnwrap(imageReference.asset.metadata[lightImageURL])
                XCTAssertEqual(lightImageMetadata.svgID, nil)
                let darkImageMetadata = try XCTUnwrap(imageReference.asset.metadata[darkImageURL])
                XCTAssertEqual(darkImageMetadata.svgID, nil)
            }
            
            do {
                let imageReference = try XCTUnwrap(summary.references?.last as? ImageReference)
                XCTAssertEqual(imageReference.identifier.identifier, "something.png")
                XCTAssertEqual(imageReference.altText, "Icon image alt text")
                XCTAssertEqual(imageReference.asset.context, .display)
                
                XCTAssertEqual(Set(imageReference.asset.variants.keys), [
                    DataTraitCollection(userInterfaceStyle: .light, displayScale: .double),
                ])
                let lightImageURL = try XCTUnwrap(imageReference.asset.variants[DataTraitCollection(userInterfaceStyle: .light, displayScale: .double)])
                XCTAssertEqual(lightImageURL, url.appendingPathComponent("something@2x.png"))
                
                XCTAssertEqual(Set(imageReference.asset.metadata.keys), [lightImageURL])
                let lightImageMetadata = try XCTUnwrap(imageReference.asset.metadata[lightImageURL])
                XCTAssertEqual(lightImageMetadata.svgID, nil)
            }
            
            // TODO: DataAsset doesn't round-trip encode/decode
            summary.references = summary.references?.compactMap { (original: RenderReference) -> RenderReference? in
                guard var imageRef = original as? ImageReference else { return nil }
                imageRef.asset.variants = imageRef.asset.variants.mapValues { variant in
                    return imageRef.destinationURL(for: variant.lastPathComponent, prefixComponent: bundle.identifier)
                }
                imageRef.asset.metadata = .init(uniqueKeysWithValues: imageRef.asset.metadata.map { key, value in
                    return (imageRef.destinationURL(for: key.lastPathComponent, prefixComponent: bundle.identifier), value)
                })
                return imageRef as RenderReference
            }
            
            
            let encoded = try RenderJSONEncoder.makeEncoder(assetPrefixComponent: bundle.identifier).encode(summary)
            let decoded = try JSONDecoder().decode(LinkDestinationSummary.self, from: encoded)
            XCTAssertEqual(decoded, summary)
        }
    }
    
    func testVariantSummaries() throws {
        let (bundle, context) = try testBundleAndContext(named: "MixedLanguageFramework")
        let converter = DocumentationNodeConverter(bundle: bundle, context: context)
        
        // Check a symbol that's represented as a class in both Swift and Objective-C
        do {
            let symbolReference = ResolvedTopicReference(bundleIdentifier: "org.swift.MixedLanguageFramework", path: "/documentation/MixedLanguageFramework/Bar", sourceLanguage: .swift)
            let node = try context.entity(with: symbolReference)
            let renderNode = try converter.convert(node)
            let summary = node.externallyLinkableElementSummaries(context: context, renderNode: renderNode)[0]
            
            XCTAssertEqual(summary.title, "Bar")
            XCTAssertEqual(summary.relativePresentationURL.absoluteString, "/documentation/mixedlanguageframework/bar")
            XCTAssertEqual(summary.referenceURL.absoluteString, "doc://org.swift.MixedLanguageFramework/documentation/MixedLanguageFramework/Bar")
            XCTAssertEqual(summary.language, .swift)
            XCTAssertEqual(summary.kind, .class)
            XCTAssertEqual(summary.abstract, [.text("A bar.")])
            XCTAssertEqual(summary.taskGroups, [
                .init(
                    title: "Type Methods",
                    identifiers: [
                        summary.referenceURL.appendingPathComponent("myStringFunction(_:)").absoluteString,
                    ]
                ),
            ])
            XCTAssertEqual(summary.availableLanguages.sorted(), [.swift, .objectiveC])
            XCTAssertEqual(summary.platforms, renderNode.metadata.platforms)
            XCTAssertEqual(summary.usr, "c:objc(cs)Bar")
            
            XCTAssertEqual(summary.declarationFragments, [
                .init(text: "class", kind: .keyword, identifier: nil),
                .init(text: " ", kind: .text, identifier: nil),
                .init(text: "Bar", kind: .identifier, identifier: nil)
            ])
            XCTAssertNil(summary.topicImages)
            XCTAssertNil(summary.references)
            
            XCTAssertEqual(summary.variants.count, 1)
            let variant = try XCTUnwrap(summary.variants.first)
            
            // Check variant content that is different
            XCTAssertEqual(variant.language, .objectiveC)
            XCTAssertEqual(variant.declarationFragments, [
                .init(text: "@interface", kind: .keyword, identifier: nil),
                .init(text: " ", kind: .text, identifier: nil),
                .init(text: "Bar", kind: .identifier, identifier: nil),
                .init(text: " : ", kind: .text, identifier: nil),
                .init(text: "NSObject", kind: .typeIdentifier, identifier: nil, preciseIdentifier: "c:objc(cs)NSObject"),
            ])
            
            // Check variant content that is the same as the summarized element
            XCTAssertEqual(variant.title, nil)
            XCTAssertEqual(variant.abstract, nil)
            XCTAssertEqual(variant.usr, nil)
            XCTAssertEqual(variant.kind, nil)
            XCTAssertEqual(variant.taskGroups, nil)
            XCTAssertEqual(variant.topicImages, nil)
            
            let encoded = try JSONEncoder().encode(summary)
            let decoded = try JSONDecoder().decode(LinkDestinationSummary.self, from: encoded)
            XCTAssertEqual(decoded, summary)
        }
        
        // Check the Swift version of a symbol that's represented differently in different languages
        do {
            let symbolReference = ResolvedTopicReference(bundleIdentifier: "org.swift.MixedLanguageFramework", path: "/documentation/MixedLanguageFramework/Bar/myStringFunction(_:)", sourceLanguage: .swift)
            let node = try context.entity(with: symbolReference)
            let renderNode = try converter.convert(node)
            let summary = node.externallyLinkableElementSummaries(context: context, renderNode: renderNode)[0]
            
            XCTAssertEqual(summary.title, "myStringFunction(_:)")
            XCTAssertEqual(summary.relativePresentationURL.absoluteString, "/documentation/mixedlanguageframework/bar/mystringfunction(_:)")
            XCTAssertEqual(summary.referenceURL.absoluteString, "doc://org.swift.MixedLanguageFramework/documentation/MixedLanguageFramework/Bar/myStringFunction(_:)")
            XCTAssertEqual(summary.language, .swift)
            XCTAssertEqual(summary.kind, .typeMethod)
            
            XCTAssertEqual(summary.abstract, [.text("Does a string function.")])
            XCTAssertEqual(
                summary.taskGroups,
                [],
                """
                Expected no task groups for the Swift documentation because the symbol \
                it curates (``Foo-c.typealias``) is available in Objective-C only.
                """
            )
            
            XCTAssertEqual(summary.availableLanguages.sorted(), [.swift, .objectiveC])
            XCTAssertEqual(summary.platforms, renderNode.metadata.platforms)
            XCTAssertEqual(summary.usr, "c:objc(cs)Bar(cm)myStringFunction:error:")
            XCTAssertEqual(summary.declarationFragments, [
                .init(text: "class", kind: .keyword, identifier: nil),
                .init(text: " ", kind: .text, identifier: nil),
                .init(text: "func", kind: .keyword, identifier: nil),
                .init(text: " ", kind: .text, identifier: nil),
                .init(text: "myStringFunction", kind: .identifier, identifier: nil),
                .init(text: "(", kind: .text, identifier: nil),
                .init(text: "_", kind: .externalParam, identifier: nil),
                .init(text: " ", kind: .text, identifier: nil),
                .init(text: "string", kind: .internalParam, identifier: nil),
                .init(text: ": ", kind: .text, identifier: nil),
                .init(text: "String", kind: .typeIdentifier, identifier: nil, preciseIdentifier: "s:SS"),
                .init(text: ") ", kind: .text, identifier: nil),
                .init(text: "throws", kind: .keyword, identifier: nil),
                .init(text: " -> ", kind: .text, identifier: nil),
                .init(text: "String", kind: .typeIdentifier, identifier: nil, preciseIdentifier: "s:SS")
            ])
            XCTAssertNil(summary.topicImages)
            XCTAssertNil(summary.references)
            
            XCTAssertEqual(summary.variants.count, 1)
            let variant = try XCTUnwrap(summary.variants.first)
            
            // Check variant content that is different
            XCTAssertEqual(variant.language, .objectiveC)
            XCTAssertEqual(variant.title, "myStringFunction:error:")
            XCTAssertEqual(variant.declarationFragments, [
                .init(text: "+ (", kind: .text, identifier: nil),
                .init(text: "NSString", kind: .typeIdentifier, identifier: nil, preciseIdentifier: "c:objc(cs)NSString"),
                .init(text: " *) ", kind: .text, identifier: nil),
                .init(text: "myStringFunction", kind: .identifier, identifier: nil),
                .init(text: ": (", kind: .text, identifier: nil),
                .init(text: "NSString", kind: .typeIdentifier, identifier: nil, preciseIdentifier: "c:objc(cs)NSString"),
                .init(text: " *)string", kind: .text, identifier: nil),
                .init(text: "error", kind: .identifier, identifier: nil),
                .init(text: ": (", kind: .text, identifier: nil),
                .init(text: "NSError", kind: .typeIdentifier, identifier: nil, preciseIdentifier: "c:objc(cs)NSError"),
                .init(text: " **)error;", kind: .text, identifier: nil)
            ])
            
            // Check variant content that is the same as the summarized element
            XCTAssertEqual(variant.abstract, nil)
            XCTAssertEqual(variant.usr, nil)
            XCTAssertEqual(variant.kind, nil)
            XCTAssertEqual(
                variant.taskGroups,
                [
                    .init(
                        title: "Custom",
                        identifiers: [
                            summary.referenceURL
                                .deletingLastPathComponent() // myStringFunction:error:
                                .deletingLastPathComponent() // Bar
                                .appendingPathComponent("Foo-c.typealias").absoluteString,
                        ]
                    )
                ]
            )
            XCTAssertEqual(variant.topicImages, nil)
            
            let encoded = try JSONEncoder().encode(summary)
            let decoded = try JSONDecoder().decode(LinkDestinationSummary.self, from: encoded)
            XCTAssertEqual(decoded, summary)
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
        XCTAssertEqual(decoded.relativePresentationURL.absoluteString, "documentation/MyKit/ClassName")
        XCTAssertEqual(decoded.declarationFragments, [
            .init(text: "class", kind: .keyword, identifier: nil),
            .init(text: " ", kind: .text, identifier: nil),
            .init(text: "ClassName", kind: .identifier, identifier: nil),
        ])
        XCTAssertNil(decoded.topicImages)
        XCTAssertNil(decoded.references)
        
        XCTAssert(decoded.variants.isEmpty)
    }

    /// Ensure that the task group link summary for overload group pages doesn't overwrite any manual curation.
    func testOverloadSymbolsWithManualCuration() throws {
        enableFeatureFlag(\.isExperimentalOverloadedSymbolPresentationEnabled)

        let symbolGraph = SymbolGraph.init(
            metadata: .init(formatVersion: .init(string: "1.0.0")!, generator: "unit-test"),
            module: .init(name: "MyModule", platform: .init()),
            symbols: [
                .init(
                    identifier: .init(precise: "s:MyClass", interfaceLanguage: "swift"),
                    names: .init(title: "MyClass", navigator: nil, subHeading: nil, prose: nil),
                    pathComponents: ["MyClass"],
                    docComment: nil,
                    accessLevel: .public,
                    kind: .init(parsedIdentifier: .class, displayName: "Class"),
                    mixins: [:]
                ),
                .init(
                    identifier: .init(precise: "s:MyClass:myFunc-1", interfaceLanguage: "swift"),
                    names: .init(title: "myFunc()", navigator: nil, subHeading: nil, prose: nil),
                    pathComponents: ["MyClass", "myFunc()"],
                    docComment: .init([
                        .init(
                            text: """
                            A wonderful overloaded function.

                            ## Topics

                            ### Other Cool Symbols

                            - ``MyStruct``
                            """,
                            range: nil)
                    ]),
                    accessLevel: .public,
                    kind: .init(parsedIdentifier: .method, displayName: "Instance Method"),
                    mixins: [:]
                ),
                .init(
                    identifier: .init(precise: "s:MyClass:myFunc-2", interfaceLanguage: "swift"),
                    names: .init(title: "myFunc()", navigator: nil, subHeading: nil, prose: nil),
                    pathComponents: ["MyClass", "myFunc()"],
                    docComment: nil,
                    accessLevel: .public,
                    kind: .init(parsedIdentifier: .method, displayName: "Instance Method"),
                    mixins: [:]
                ),
                .init(
                    identifier: .init(precise: "s:MyStruct", interfaceLanguage: "swift"),
                    names: .init(title: "MyStruct", navigator: nil, subHeading: nil, prose: nil),
                    pathComponents: ["MyStruct"],
                    docComment: nil,
                    accessLevel: .public,
                    kind: .init(parsedIdentifier: .struct, displayName: "Structure"),
                    mixins: [:]
                ),
            ],
            relationships: [
                .init(
                    source: "s:MyClass:myFunc-1",
                    target: "s:MyClass",
                    kind: .memberOf,
                    targetFallback: nil
                ),
                .init(
                    source: "s:MyClass:myFunc-2",
                    target: "s:MyClass",
                    kind: .memberOf,
                    targetFallback: nil
                ),
            ]
        )

        let bundleFolderHierarchy = Folder(name: "unit-test.docc", content: [
            JSONFile(name: "MyModule.symbols.json", content: symbolGraph),
            InfoPlist(displayName: "MyModule", identifier: "com.example.mymodule")
        ])
        let workspace = DocumentationWorkspace()
        let context = try! DocumentationContext(dataProvider: workspace)

        let bundleURL = try bundleFolderHierarchy.write(inside: createTemporaryDirectory())

        let dataProvider = try LocalFileSystemDataProvider(rootURL: bundleURL)
        try workspace.registerProvider(dataProvider)

        let bundle = context.bundle(identifier: "com.example.mymodule")!
        let converter = DocumentationNodeConverter(bundle: bundle, context: context)

        let node = try context.entity(with: ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/MyModule/MyClass/myFunc()-9sdsh", sourceLanguage: .swift))
        let renderNode = try converter.convert(node)

        let summaries = node.externallyLinkableElementSummaries(context: context, renderNode: renderNode)
        let pageSummary = summaries[0]

        let taskGroups = try XCTUnwrap(pageSummary.taskGroups)

        guard taskGroups.count == 2 else {
            XCTFail("Expected 2 task groups, found \(taskGroups.count): \(taskGroups.map(\.title))")
            return
        }

        XCTAssertEqual(taskGroups[0].title, "Other Cool Symbols")
        XCTAssertEqual(taskGroups[0].identifiers, [
            "doc://com.example.mymodule/documentation/MyModule/MyStruct"
        ])

        XCTAssertEqual(taskGroups[1].title, "Overloads")
        XCTAssertEqual(Set(taskGroups[1].identifiers), [
            "doc://com.example.mymodule/documentation/MyModule/MyClass/myFunc()-9a7pr",
            "doc://com.example.mymodule/documentation/MyModule/MyClass/myFunc()-9a7po",
        ])
    }
}
