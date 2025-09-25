/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
import Foundation
import SymbolKit
@_spi(ExternalLinks) @testable import SwiftDocC
import SwiftDocCTestUtilities

#if os(macOS)
class OutOfProcessReferenceResolverV2Tests: XCTestCase {
    
    func testInitializationProcess() throws {
        let temporaryFolder = try createTemporaryDirectory()
        
        let executableLocation = temporaryFolder.appendingPathComponent("link-resolver-executable")
        // When the executable file doesn't exist
        XCTAssertFalse(FileManager.default.fileExists(atPath: executableLocation.path))
        XCTAssertThrowsError(try OutOfProcessReferenceResolver(processLocation: executableLocation, errorOutputHandler: { _ in }),
                        "There should be a validation error if the executable file doesn't exist")
        
        // When the file isn't executable
        try "".write(to: executableLocation, atomically: true, encoding: .utf8)
        XCTAssertFalse(FileManager.default.isExecutableFile(atPath: executableLocation.path))
        XCTAssertThrowsError(try OutOfProcessReferenceResolver(processLocation: executableLocation, errorOutputHandler: { _ in }),
                        "There should be a validation error if the file isn't executable")
        
        // When the file isn't executable
        try """
        #!/bin/bash
        echo '{"identifier":"com.test.bundle","capabilities": 0}'  # Write this resolver's identifier & capabilities
        read                                                       # Wait for docc to send a request
        """.write(to: executableLocation, atomically: true, encoding: .utf8)
        
        // `0o0700` is `-rwx------` (read, write, & execute only for owner)
        try FileManager.default.setAttributes([.posixPermissions: 0o0700], ofItemAtPath: executableLocation.path)
        XCTAssert(FileManager.default.isExecutableFile(atPath: executableLocation.path))
         
        let resolver = try OutOfProcessReferenceResolver(processLocation: executableLocation, errorOutputHandler: { errorMessage in
            XCTFail("No error output is expected for this test executable. Got:\n\(errorMessage)")
        })
        XCTAssertEqual(resolver.bundleID, "com.test.bundle")
    }
    
    private func makeTestSummary() -> (summary: LinkDestinationSummary, imageReference: RenderReferenceIdentifier, imageURLs: (light: URL, dark: URL)) {
        let linkedReference = RenderReferenceIdentifier("doc://com.test.bundle/something-else")
        let linkedImage     = RenderReferenceIdentifier("some-image-identifier")
        let linkedVariantReference = RenderReferenceIdentifier("doc://com.test.bundle/something-else-2")
        
        func cardImages(name: String) -> (light: URL, dark: URL) {
            ( URL(string: "https://example.com/path/to/\(name)@2x.png")!,
              URL(string: "https://example.com/path/to/\(name)~dark@2x.png")! )
        }
        
        let imageURLs = cardImages(name: "some-image")
        
        let summary = LinkDestinationSummary(
            kind: .structure,
            language: .swift, // This is Swift to account for what is considered a symbol's "first" variant value (rdar://86580516),
            relativePresentationURL: URL(string: "/path/so/something")!,
            referenceURL: URL(string: "doc://com.test.bundle/something")!,
            title: "Resolved Title",
            abstract: [
                .text("Resolved abstract with "),
                .emphasis(inlineContent: [.text("formatted")]),
                .text(" "),
                .strong(inlineContent: [.text("formatted")]),
                .text(" and a link: "),
                .reference(identifier: linkedReference, isActive: true, overridingTitle: nil, overridingTitleInlineContent: nil)
            ],
            availableLanguages: [
                .swift,
                .init(name: "Language Name 2", id: "com.test.another-language.id"),
                .objectiveC,
            ],
            platforms: [
                .init(name: "firstOS",  introduced: "1.2.3", isBeta: false),
                .init(name: "secondOS", introduced: "4.5.6", isBeta: false),
            ],
            usr: "some-unique-symbol-id",
            declarationFragments: .init([
                .init(text: "struct", kind: .keyword, preciseIdentifier: nil),
                .init(text: " ", kind: .text, preciseIdentifier: nil),
                .init(text: "declaration fragment", kind: .identifier, preciseIdentifier: nil),
            ]),
            topicImages: [
                .init(pageImagePurpose: .card, identifier: linkedImage)
            ],
            references: [
                TopicRenderReference(identifier: linkedReference, title: "Something Else", abstract: [.text("Some other page")], url: "/path/to/something-else", kind: .symbol),
                TopicRenderReference(identifier: linkedVariantReference, title: "Another Page", abstract: [.text("Yet another page")], url: "/path/to/something-else-2", kind: .article),
                
                ImageReference(
                    identifier: linkedImage,
                    altText: "External card alt text",
                    imageAsset: DataAsset(
                        variants: [
                            DataTraitCollection(userInterfaceStyle: .light, displayScale: .double): imageURLs.light,
                            DataTraitCollection(userInterfaceStyle: .dark, displayScale: .double): imageURLs.dark,
                        ],
                        metadata: [
                            imageURLs.light : DataAsset.Metadata(svgID: nil),
                            imageURLs.dark : DataAsset.Metadata(svgID: nil),
                        ],
                        context: .display
                    )
                ),
            ],
            variants: [
                .init(
                    traits: [.interfaceLanguage("com.test.another-language.id")],
                    kind: .init(name: "Variant Kind Name", id: "com.test.kind2.id", isSymbol: true),
                    language: .init(name: "Language Name 2", id: "com.test.another-language.id"),
                    title: "Resolved Variant Title",
                    abstract: [
                        .text("Resolved variant abstract with "),
                        .emphasis(inlineContent: [.text("formatted")]),
                        .text(" "),
                        .strong(inlineContent: [.text("formatted")]),
                        .text(" and a link: "),
                        .reference(identifier: linkedVariantReference, isActive: true, overridingTitle: nil, overridingTitleInlineContent: nil)
                    ],
                    declarationFragments: .init([
                        .init(text: "variant declaration fragment", kind: .text, preciseIdentifier: nil)
                    ])
                )
            ]
        )
        
        return (summary, linkedImage, imageURLs)
    }
    
    func testResolvingLinkAndSymbol() throws {
        enum RequestKind {
            case link, symbol
            
            func perform(resolver: OutOfProcessReferenceResolver, file: StaticString = #filePath, line: UInt = #line) throws -> LinkResolver.ExternalEntity? {
                switch self {
                    case .link:
                        let unresolved = TopicReference.unresolved(UnresolvedTopicReference(topicURL: ValidatedURL(parsingExact: "doc://com.test.bundle/something")!))
                        let reference: ResolvedTopicReference
                        switch resolver.resolve(unresolved) {
                            case .success(let resolved):
                                reference = resolved
                            case .failure(_, let errorInfo):
                                XCTFail("Unexpectedly failed to resolve reference with error: \(errorInfo.message)", file: file, line: line)
                                return nil
                        }
                        
                        // Resolve the symbol
                        return resolver.entity(with: reference)
                        
                    case .symbol:
                        return try XCTUnwrap(resolver.symbolReferenceAndEntity(withPreciseIdentifier: "")?.1, file: file, line: line)
                }
            }
        }
        
        for requestKind in [RequestKind.link, .symbol] {
            let (testSummary, linkedImage, imageURLs) = makeTestSummary()
            
            let resolver: OutOfProcessReferenceResolver
            do {
                let temporaryFolder = try createTemporaryDirectory()
                let executableLocation = temporaryFolder.appendingPathComponent("link-resolver-executable")
                
                let encodedLinkSummary = try String(data: JSONEncoder().encode(testSummary), encoding: .utf8)!
                
                try """
                #!/bin/bash
                echo '{"identifier":"com.test.bundle","capabilities": 0}'  # Write this resolver's identifier & capabilities
                read                                                       # Wait for docc to send a request
                echo '{"resolved":\(encodedLinkSummary)}'                  # Respond with the test link summary (above)
                """.write(to: executableLocation, atomically: true, encoding: .utf8)
                
                // `0o0700` is `-rwx------` (read, write, & execute only for owner)
                try FileManager.default.setAttributes([.posixPermissions: 0o0700], ofItemAtPath: executableLocation.path)
                XCTAssert(FileManager.default.isExecutableFile(atPath: executableLocation.path))
                
                resolver = try OutOfProcessReferenceResolver(processLocation: executableLocation, errorOutputHandler: { _ in })
                XCTAssertEqual(resolver.bundleID, "com.test.bundle")
            }
            
            let entity = try XCTUnwrap(requestKind.perform(resolver: resolver))
            let topicRenderReference = entity.makeTopicRenderReference()
            
            XCTAssertEqual(topicRenderReference.url, testSummary.relativePresentationURL.absoluteString)
            
            XCTAssertEqual(topicRenderReference.kind.rawValue, "symbol")
            XCTAssertEqual(topicRenderReference.role, "symbol")
            
            XCTAssertEqual(topicRenderReference.title, "Resolved Title")
            XCTAssertEqual(topicRenderReference.abstract, [
                .text("Resolved abstract with "),
                .emphasis(inlineContent: [.text("formatted")]),
                .text(" "),
                .strong(inlineContent: [.text("formatted")]),
                .text(" and a link: "),
                .reference(identifier: .init("doc://com.test.bundle/something-else"), isActive: true, overridingTitle: nil, overridingTitleInlineContent: nil)
            ])
            
            XCTAssertFalse(topicRenderReference.isBeta)
            
            XCTAssertEqual(entity.availableLanguages.count, 3)
            
            let availableSourceLanguages = entity.availableLanguages.sorted()
            let expectedLanguages = testSummary.availableLanguages.sorted()
            
            XCTAssertEqual(availableSourceLanguages[0], expectedLanguages[0])
            XCTAssertEqual(availableSourceLanguages[1], expectedLanguages[1])
            XCTAssertEqual(availableSourceLanguages[2], expectedLanguages[2])
            
            XCTAssertEqual(topicRenderReference.fragments, [
                .init(text: "struct", kind: .keyword, preciseIdentifier: nil),
                .init(text: " ", kind: .text, preciseIdentifier: nil),
                .init(text: "declaration fragment", kind: .identifier, preciseIdentifier: nil),
            ])
            
            let variantTraits = [RenderNode.Variant.Trait.interfaceLanguage("com.test.another-language.id")]
            XCTAssertEqual(topicRenderReference.titleVariants.value(for: variantTraits), "Resolved Variant Title")
            XCTAssertEqual(topicRenderReference.abstractVariants.value(for: variantTraits), [
                .text("Resolved variant abstract with "),
                .emphasis(inlineContent: [.text("formatted")]),
                .text(" "),
                .strong(inlineContent: [.text("formatted")]),
                .text(" and a link: "),
                .reference(identifier: .init("doc://com.test.bundle/something-else-2"), isActive: true, overridingTitle: nil, overridingTitleInlineContent: nil)
            ])
            
            let fragmentVariant = try XCTUnwrap(topicRenderReference.fragmentsVariants.variants.first(where: { $0.traits == variantTraits }))
            XCTAssertEqual(fragmentVariant.patch.map(\.operation), [.replace])
            if case .replace(let variantFragment) = fragmentVariant.patch.first {
                XCTAssertEqual(variantFragment, [.init(text: "variant declaration fragment", kind: .text, preciseIdentifier: nil)])
            } else {
                XCTFail("Unexpected fragments variant patch")
            }
            
            XCTAssertNil(topicRenderReference.conformance)
            XCTAssertNil(topicRenderReference.estimatedTime)
            XCTAssertNil(topicRenderReference.defaultImplementationCount)
            XCTAssertFalse(topicRenderReference.isBeta)
            XCTAssertFalse(topicRenderReference.isDeprecated)
            XCTAssertNil(topicRenderReference.propertyListKeyNames)
            XCTAssertNil(topicRenderReference.tags)
            
            XCTAssertEqual(topicRenderReference.images.count, 1)
            let topicImage = try XCTUnwrap(topicRenderReference.images.first)
            XCTAssertEqual(topicImage.type, .card)
            
            let image = try XCTUnwrap(entity.makeRenderDependencies().imageReferences.first(where: { $0.identifier == topicImage.identifier }))
            
            XCTAssertEqual(image.identifier, linkedImage)
            XCTAssertEqual(image.altText, "External card alt text")
            
            XCTAssertEqual(image.asset, DataAsset(
                variants: [
                    DataTraitCollection(userInterfaceStyle: .light, displayScale: .double): imageURLs.light,
                    DataTraitCollection(userInterfaceStyle: .dark,  displayScale: .double): imageURLs.dark,
                ],
                metadata: [
                    imageURLs.light: DataAsset.Metadata(svgID: nil),
                    imageURLs.dark:  DataAsset.Metadata(svgID: nil),
                ],
                context: .display
            ))
        }
    }
    
    func testForwardsErrorOutputProcess() throws {
        let temporaryFolder = try createTemporaryDirectory()
        
        let executableLocation = temporaryFolder.appendingPathComponent("link-resolver-executable")
        try """
        #!/bin/bash
        echo '{"identifier":"com.test.bundle","capabilities": 0}'  # Write this resolver's identifier & capabilities
        echo "Some error output" 1>&2                              # Write to stderr
        read                                                       # Wait for docc to send a request
        """.write(to: executableLocation, atomically: true, encoding: .utf8)
        
        // `0o0700` is `-rwx------` (read, write, & execute only for owner)
        try FileManager.default.setAttributes([.posixPermissions: 0o0700], ofItemAtPath: executableLocation.path)
        XCTAssert(FileManager.default.isExecutableFile(atPath: executableLocation.path))
         
        let didReadErrorOutputExpectation = expectation(description: "Did read forwarded error output.")
        
        let resolver = try? OutOfProcessReferenceResolver(processLocation: executableLocation, errorOutputHandler: {
            errorMessage in
            XCTAssertEqual(errorMessage, "Some error output\n")
            didReadErrorOutputExpectation.fulfill()
        })
        XCTAssertEqual(resolver?.bundleID, "com.test.bundle")
        
        wait(for: [didReadErrorOutputExpectation], timeout: 20.0)
    }
    
    func testLinksAndImagesInExternalAbstractAreIncludedInTheRenderedPageReferenecs() async throws {
        let externalBundleID: DocumentationBundle.Identifier = "com.example.test"
        
        let imageRef = RenderReferenceIdentifier("some-external-card-image-identifier")
        let linkRef = RenderReferenceIdentifier("doc://\(externalBundleID)/path/to/other-page")
        
        let imageURL = URL(string: "https://example.com/path/to/some-image.png")!
              
        let originalLinkedImage = ImageReference(
            identifier: imageRef,
            imageAsset: DataAsset(
                variants: [.init(displayScale: .standard): imageURL],
                metadata: [imageURL: .init()],
                context: .display
            )
        )
        
        let originalLinkedTopic = TopicRenderReference(
            identifier: linkRef,
            title: "Resolved title of link inside abstract",
            abstract: [
                .text("This transient content is not displayed anywhere"),
            ],
            url: "/path/to/other-page",
            kind: .article
        )
        
        let externalSummary = LinkDestinationSummary(
            kind: .article,
            language: .swift,
            relativePresentationURL: URL(string: "/path/to/something")!,
            referenceURL: URL(string: "doc://\(externalBundleID)/path/to/something")!,
            title: "Resolved title",
            abstract: [
                .text("External abstract with an image "),
                .image(identifier: imageRef, metadata: nil),
                .text(" and link "),
                .reference(identifier: linkRef, isActive: true, overridingTitle: nil, overridingTitleInlineContent: nil),
                .text("."),
            ],
            availableLanguages: [.swift],
            platforms: nil,
            taskGroups: nil,
            usr: nil,
            declarationFragments: nil,
            redirects: nil,
            topicImages: nil,
            references: [originalLinkedImage, originalLinkedTopic],
            variants: []
        )
        
        let resolver: OutOfProcessReferenceResolver
        do {
            let temporaryFolder = try createTemporaryDirectory()
            let encodedResponse = try String(decoding: JSONEncoder().encode(OutOfProcessReferenceResolver.ResponseV2.resolved(externalSummary)), as: UTF8.self)
            
            let executableLocation = temporaryFolder.appendingPathComponent("link-resolver-executable")
            try """
            #!/bin/bash
            echo '{"identifier":"\(externalBundleID)","capabilities": 0}'  # Write this resolver's identifier & capabilities
            read                                                           # Wait for docc to send a request
            echo '\(encodedResponse)'                                      # Respond with the resolved link summary
            read                                                           # Wait for docc to send another request
            """.write(to: executableLocation, atomically: true, encoding: .utf8)
            
            // `0o0700` is `-rwx------` (read, write, & execute only for owner)
            try FileManager.default.setAttributes([.posixPermissions: 0o0700], ofItemAtPath: executableLocation.path)
            XCTAssert(FileManager.default.isExecutableFile(atPath: executableLocation.path))
            
            resolver = try OutOfProcessReferenceResolver(processLocation: executableLocation, errorOutputHandler: { _ in })
        }
        
        let catalog = Folder(name: "unit-test.docc", content: [
            TextFile(name: "Something.md", utf8Content: """
            # My root page
            
            This page curates an an external page (so that its abstract and transient references are displayed on the page)
            
            ## Topics
            
            ### An external link
            
            -  <doc://\(externalBundleID)/some-link>
            """)
        ])
        let inputDirectory = Folder(name: "path", content: [Folder(name: "to", content: [catalog])])
        
        var configuration = DocumentationContext.Configuration()
        configuration.externalDocumentationConfiguration.sources = [
            externalBundleID: resolver
        ]
        let (_, context) = try await loadBundle(catalog: inputDirectory, configuration: configuration)
        XCTAssertEqual(context.problems.map(\.diagnostic.summary), [], "Encountered unexpected problems")
        
        let reference = try XCTUnwrap(context.soleRootModuleReference, "This example catalog only has a root page")
        
        let converter = DocumentationContextConverter(
            bundle: context.bundle,
            context: context,
            renderContext: RenderContext(
                documentationContext: context,
                bundle: context.bundle
            )
        )
        let renderNode = try XCTUnwrap(converter.renderNode(for: context.entity(with: reference)))
        
        // Verify that the topic section exist and has the external link
        XCTAssertEqual(renderNode.topicSections.flatMap { [$0.title ?? "<no-title>"] + $0.identifiers }, [
            "An external link",
            "doc://\(externalBundleID)/path/to/something", // Resolved links use their canonical references
        ])
        
        // Verify that the externally resolved page's references are included on the page
        XCTAssertEqual(Set(renderNode.references.keys), [
            "doc://com.example.test/path/to/something", // The external page that the root links to
            
            "some-external-card-image-identifier", // The image in that page's abstract
            "doc://com.example.test/path/to/other-page", // The link in that page's abstract
        ], "The external page and its two references should be included on this page")
        
        XCTAssertEqual(renderNode.references[imageRef.identifier] as? ImageReference, originalLinkedImage)
        XCTAssertEqual(renderNode.references[linkRef.identifier] as? TopicRenderReference, originalLinkedTopic)
    }
    
    func testExternalLinkFailureResultInDiagnosticWithSolutions() async throws {
        let externalBundleID: DocumentationBundle.Identifier = "com.example.test"
        
        let resolver: OutOfProcessReferenceResolver
        do {
            let temporaryFolder = try createTemporaryDirectory()
            
            let diagnosticInfo = OutOfProcessReferenceResolver.ResponseV2.DiagnosticInformation(
                summary: "Some external link issue summary",
                solutions: [
                    .init(summary: "Some external solution", replacement: "some-replacement")
                ]
            )
            let encodedDiagnostic = try String(decoding: JSONEncoder().encode(diagnosticInfo), as: UTF8.self)
            
            let executableLocation = temporaryFolder.appendingPathComponent("link-resolver-executable")
            try """
            #!/bin/bash
            echo '{"identifier":"\(externalBundleID)","capabilities": 0}'  # Write this resolver's identifier & capabilities
            read                                                           # Wait for docc to send a request
            echo '{"failure":\(encodedDiagnostic)}'                        # Respond with an error message
            """.write(to: executableLocation, atomically: true, encoding: .utf8)
            
            // `0o0700` is `-rwx------` (read, write, & execute only for owner)
            try FileManager.default.setAttributes([.posixPermissions: 0o0700], ofItemAtPath: executableLocation.path)
            XCTAssert(FileManager.default.isExecutableFile(atPath: executableLocation.path))
             
            resolver = try OutOfProcessReferenceResolver(processLocation: executableLocation, errorOutputHandler: { _ in })
        }
        
        let catalog = Folder(name: "unit-test.docc", content: [
            TextFile(name: "Something.md", utf8Content: """
            # My root page
            
            This page contains an external link that will fail to resolve: <doc://\(externalBundleID.rawValue)/some-link>
            """)
        ])
        let inputDirectory = Folder(name: "path", content: [Folder(name: "to", content: [catalog])])
        
        var configuration = DocumentationContext.Configuration()
        configuration.externalDocumentationConfiguration.sources = [
            externalBundleID: resolver
        ]
        let (_, context) = try await loadBundle(catalog: inputDirectory, configuration: configuration)
        
        XCTAssertEqual(context.problems.map(\.diagnostic.summary), [
            "Some external link issue summary",
        ])
        
        let problem = try XCTUnwrap(context.problems.sorted(by: \.diagnostic.identifier).first)
        
        XCTAssertEqual(problem.diagnostic.summary, "Some external link issue summary")
        XCTAssertEqual(problem.diagnostic.range?.lowerBound, .init(line: 3, column: 69, source: URL(fileURLWithPath: "/path/to/unit-test.docc/Something.md")))
        XCTAssertEqual(problem.diagnostic.range?.upperBound, .init(line: 3, column: 97, source: URL(fileURLWithPath: "/path/to/unit-test.docc/Something.md")))
        
        XCTAssertEqual(problem.possibleSolutions.count, 1)
        let solution = try XCTUnwrap(problem.possibleSolutions.first)
        XCTAssertEqual(solution.summary, "Some external solution")
        XCTAssertEqual(solution.replacements.count, 1)
        XCTAssertEqual(solution.replacements.first?.range.lowerBound, .init(line: 3, column: 65, source: nil))
        XCTAssertEqual(solution.replacements.first?.range.upperBound, .init(line: 3, column: 97, source: nil))
        
        // Verify the warning presentation
        let diagnosticOutput = LogHandle.LogStorage()
        let fileSystem = try TestFileSystem(folders: [inputDirectory])
        let diagnosticFormatter = DiagnosticConsoleWriter(LogHandle.memory(diagnosticOutput), formattingOptions: [], highlight: true, dataProvider: fileSystem)
        diagnosticFormatter.receive(context.diagnosticEngine.problems)
        try diagnosticFormatter.flush()
        
        let warning    = "\u{001B}[1;33m"
        let highlight  = "\u{001B}[1;32m"
        let suggestion = "\u{001B}[1;39m"
        let clear      = "\u{001B}[0;0m"
        XCTAssertEqual(diagnosticOutput.text, """
        \(warning)warning: Some external link issue summary\(clear)
         --> /path/to/unit-test.docc/Something.md:3:69-3:97
        1 | # My root page
        2 |
        3 + This page contains an external link that will fail to resolve: <doc:\(highlight)//com.example.test/some-link\(clear)>
          |                                                                 ╰─\(suggestion)suggestion: Some external solution\(clear)
        
        """)
        
        // Verify the suggestion replacement
        let source = try XCTUnwrap(problem.diagnostic.source)
        let original = String(decoding: try fileSystem.contents(of: source), as: UTF8.self)
        
        XCTAssertEqual(try solution.applyTo(original), """
        # My root page

        This page contains an external link that will fail to resolve: <some-replacement>
        """)
    }
    
    func testEncodingAndDecodingRequests() throws {
        do {
            let request = OutOfProcessReferenceResolver.RequestV2.link("doc://com.example/path/to/something")
            
            let data = try JSONEncoder().encode(request)
            if case .link(let link) = try JSONDecoder().decode(OutOfProcessReferenceResolver.RequestV2.self, from: data) {
                XCTAssertEqual(link, "doc://com.example/path/to/something")
            } else {
                XCTFail("Decoded the wrong type of request")
            }
        }
        
        do {
            let request = OutOfProcessReferenceResolver.RequestV2.symbol("some-unique-symbol-id")
            
            let data = try JSONEncoder().encode(request)
            if case .symbol(let usr) = try JSONDecoder().decode(OutOfProcessReferenceResolver.RequestV2.self, from: data) {
                XCTAssertEqual(usr, "some-unique-symbol-id")
            } else {
                XCTFail("Decoded the wrong type of request")
            }
        }
    }
    
    func testEncodingAndDecodingResponses() throws {
        // Identifier and capabilities
        do {
            let request = OutOfProcessReferenceResolver.ResponseV2.identifierAndCapabilities("com.example.test", [])
            
            let data = try JSONEncoder().encode(request)
            if case .identifierAndCapabilities(let identifier, let capabilities) = try JSONDecoder().decode(OutOfProcessReferenceResolver.ResponseV2.self, from: data) {
                XCTAssertEqual(identifier.rawValue, "com.example.test")
                XCTAssertEqual(capabilities.rawValue, 0)
            } else {
                XCTFail("Decoded the wrong type of message")
            }
        }
        
        // Failures
        do {
            let originalInfo = OutOfProcessReferenceResolver.ResponseV2.DiagnosticInformation(
                summary: "Some summary",
                solutions: [
                    .init(summary: "Some solution", replacement: "some-replacement")
                ]
            )
               
            let request = OutOfProcessReferenceResolver.ResponseV2.failure(originalInfo)
            let data = try JSONEncoder().encode(request)
            if case .failure(let info) = try JSONDecoder().decode(OutOfProcessReferenceResolver.ResponseV2.self, from: data) {
                XCTAssertEqual(info.summary, originalInfo.summary)
                XCTAssertEqual(info.solutions?.count, originalInfo.solutions?.count)
                for (solution, originalSolution) in zip(info.solutions ?? [], originalInfo.solutions ?? []) {
                    XCTAssertEqual(solution.summary, originalSolution.summary)
                    XCTAssertEqual(solution.replacement, originalSolution.replacement)
                }
            } else {
                XCTFail("Decoded the wrong type of message")
            }
        }
        
        // Resolved link information
        do {
            let originalSummary = makeTestSummary().summary
            let message = OutOfProcessReferenceResolver.ResponseV2.resolved(originalSummary)
            
            let data = try JSONEncoder().encode(message)
            if case .resolved(let summary) = try JSONDecoder().decode(OutOfProcessReferenceResolver.ResponseV2.self, from: data) {
                XCTAssertEqual(summary, originalSummary)
            } else {
                XCTFail("Decoded the wrong type of message")
                return
            }
        }
    }
    
    func testErrorWhenReceivingBundleIdentifierTwice() throws {
        let temporaryFolder = try createTemporaryDirectory()
        
        let executableLocation = temporaryFolder.appendingPathComponent("link-resolver-executable")
        try """
            #!/bin/bash
            echo '{"identifier":"com.test.bundle","capabilities": 0}'  # Write this resolver's identifier & capabilities
            read                                                       # Wait for docc to send a request
            echo '{"identifier":"com.test.bundle","capabilities": 0}'  # Write this identifier & capabilities again
            """.write(to: executableLocation, atomically: true, encoding: .utf8)
        
        // `0o0700` is `-rwx------` (read, write, & execute only for owner)
        try FileManager.default.setAttributes([.posixPermissions: 0o0700], ofItemAtPath: executableLocation.path)
        XCTAssert(FileManager.default.isExecutableFile(atPath: executableLocation.path))
        
        let resolver = try OutOfProcessReferenceResolver(processLocation: executableLocation, errorOutputHandler: { _ in })
        XCTAssertEqual(resolver.bundleID, "com.test.bundle")
        
        if case .failure(_, let errorInfo) = resolver.resolve(.unresolved(UnresolvedTopicReference(topicURL: ValidatedURL(parsingAuthoredLink: "doc://com.test.bundle/something")!))) {
            XCTAssertEqual(errorInfo.message, "Executable sent bundle identifier message again, after it was already received.")
        } else {
            XCTFail("Unexpectedly resolved the link from an identifier and capabilities response")
        }
    }
    
    func testResolvingSymbolBetaStatusProcess() throws {
        func betaStatus(forSymbolWithPlatforms platforms: [LinkDestinationSummary.PlatformAvailability], file: StaticString = #filePath, line: UInt = #line) throws -> Bool {
            let summary = LinkDestinationSummary(
                kind: .class,
                language: .swift,
                relativePresentationURL: URL(string: "/documentation/ModuleName/Something")!,
                referenceURL: URL(string: "/documentation/ModuleName/Something")!,
                title: "Something",
                availableLanguages: [.swift, .objectiveC],
                platforms: platforms,
                variants: []
            )
            
            let resolver: OutOfProcessReferenceResolver
            do {
                let temporaryFolder = try createTemporaryDirectory()
                let executableLocation = temporaryFolder.appendingPathComponent("link-resolver-executable")
                
                let encodedLinkSummary = try String(data: JSONEncoder().encode(summary), encoding: .utf8)!
                
                try """
                #!/bin/bash
                #!/bin/bash
                echo '{"identifier":"com.test.bundle","capabilities": 0}'  # Write this resolver's identifier & capabilities
                read                                                       # Wait for docc to send a request
                echo '{"resolved":\(encodedLinkSummary)}'                  # Respond with the test link summary (above)
                """.write(to: executableLocation, atomically: true, encoding: .utf8)
                
                // `0o0700` is `-rwx------` (read, write, & execute only for owner)
                try FileManager.default.setAttributes([.posixPermissions: 0o0700], ofItemAtPath: executableLocation.path)
                XCTAssert(FileManager.default.isExecutableFile(atPath: executableLocation.path))
                
                resolver = try OutOfProcessReferenceResolver(processLocation: executableLocation, errorOutputHandler: { _ in })
                XCTAssertEqual(resolver.bundleID, "com.test.bundle", file: file, line: line)
            }

            let (_, symbolEntity) = try XCTUnwrap(resolver.symbolReferenceAndEntity(withPreciseIdentifier: "abc123"), "Unexpectedly failed to resolve symbol")
            return symbolEntity.makeTopicRenderReference().isBeta
        }
        
        // All platforms are in beta
        XCTAssertEqual(true, try betaStatus(forSymbolWithPlatforms: [
            .init(name: "fooOS", introduced: "1.2.3", isBeta: true),
            .init(name: "barOS", introduced: "1.2.3", isBeta: true),
            .init(name: "bazOS", introduced: "1.2.3", isBeta: true),
        ]))
        
        // One platform is stable, the other two are in beta
        XCTAssertEqual(false, try betaStatus(forSymbolWithPlatforms: [
            .init(name: "fooOS", introduced: "1.2.3", isBeta: false),
            .init(name: "barOS", introduced: "1.2.3", isBeta: true),
            .init(name: "bazOS", introduced: "1.2.3", isBeta: true),
        ]))
        
        // No platforms explicitly supported
        XCTAssertEqual(false, try betaStatus(forSymbolWithPlatforms: []))
    }
}
#endif
