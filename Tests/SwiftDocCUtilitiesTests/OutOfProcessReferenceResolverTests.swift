/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
import Foundation
import SymbolKit
@_spi(ExternalLinks) @testable import SwiftDocC
@testable import SwiftDocCUtilities
import SwiftDocCTestUtilities

class OutOfProcessReferenceResolverTests: XCTestCase {
    
    func testInitializationProcess() throws {
        #if os(macOS)
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
        echo '{"bundleIdentifier":"com.test.bundle"}'   # Write this resolver's bundle identifier
        read                                            # Wait for docc to send a topic URL
        """.write(to: executableLocation, atomically: true, encoding: .utf8)
        
        // `0o0700` is `-rwx------` (read, write, & execute only for owner)
        try FileManager.default.setAttributes([.posixPermissions: 0o0700], ofItemAtPath: executableLocation.path)
        XCTAssert(FileManager.default.isExecutableFile(atPath: executableLocation.path))
         
        let resolver = try OutOfProcessReferenceResolver(processLocation: executableLocation, errorOutputHandler: { errorMessage in
            XCTFail("No error output is expected for this test executable. Got:\n\(errorMessage)")
        })
        XCTAssertEqual(resolver.bundleID, "com.test.bundle")
        #endif
    }
    
    func assertResolvesTopicLink(makeResolver: (OutOfProcessReferenceResolver.ResolvedInformation) throws -> OutOfProcessReferenceResolver) throws {
        let testMetadata = OutOfProcessReferenceResolver.ResolvedInformation(
            kind: .init(name: "Kind Name", id: "com.test.kind.id", isSymbol: true),
            url: URL(string: "doc://com.test.bundle/something")!,
            title: "Resolved Title",
            abstract: "Resolved abstract for this topic.",
            language: .swift, // This is Swift to account for what is considered a symbol's "first" variant value (rdar://86580516)
            availableLanguages: [
                .swift,
                .init(name: "Language Name 2", id: "com.test.another-language.id"),
                .objectiveC,
            ],
            platforms: [
                .init(name: "fooOS", introduced: "1.2.3", isBeta: false),
                .init(name: "barOS", introduced: "1.2.3", isBeta: false),
            ],
            declarationFragments: .init(declarationFragments: [
                .init(kind: .text, spelling: "declaration fragment", preciseIdentifier: nil)
            ]),
            topicImages: nil,
            references: nil,
            variants: [
                .init(
                    traits: [.interfaceLanguage("com.test.another-language.id")],
                    kind: .init(name: "Variant Kind Name", id: "com.test.kind2.id", isSymbol: true),
                    url: nil,
                    title: "Resolved Variant Title",
                    abstract: "Resolved variant abstract for this topic.",
                    language: .init(name: "Language Name 2", id: "com.test.another-language.id"),
                    declarationFragments: .init(declarationFragments: [
                        .init(kind: .text, spelling: "variant declaration fragment", preciseIdentifier: nil)
                    ])
                )
            ]
        )
        
        let resolver = try makeResolver(testMetadata)
        XCTAssertEqual(resolver.bundleID, "com.test.bundle")
        
        // Resolve the reference
        let unresolved = TopicReference.unresolved(
            UnresolvedTopicReference(topicURL: ValidatedURL(parsingExact: "doc://com.test.bundle/something")!))
        guard case .success(let resolvedReference) = resolver.resolve(unresolved) else {
            XCTFail("Unexpectedly failed to resolve reference")
            return
        }
        
        // Resolve the symbol
        let entity = resolver.entity(with: resolvedReference)
        
        XCTAssertEqual(entity.topicRenderReference.url, testMetadata.url.withoutHostAndPortAndScheme().absoluteString)
        
        XCTAssertEqual(entity.topicRenderReference.kind.rawValue, "symbol")
        XCTAssertEqual(entity.topicRenderReference.role, "symbol")
        
        XCTAssertEqual(entity.topicRenderReference.title, "Resolved Title")
        XCTAssertEqual(entity.topicRenderReference.abstract, [.text("Resolved abstract for this topic.")])

        XCTAssertFalse(entity.topicRenderReference.isBeta)
        
        XCTAssertEqual(entity.sourceLanguages.count, 3)

        let availableSourceLanguages = entity.sourceLanguages.sorted()
        let expectedLanguages = testMetadata.availableLanguages.sorted()
        
        XCTAssertEqual(availableSourceLanguages[0], expectedLanguages[0])
        XCTAssertEqual(availableSourceLanguages[1], expectedLanguages[1])
        XCTAssertEqual(availableSourceLanguages[2], expectedLanguages[2])
        
        XCTAssertEqual(entity.topicRenderReference.fragments, [.init(text: "declaration fragment", kind: .text, preciseIdentifier: nil)])

        let variantTraits = [RenderNode.Variant.Trait.interfaceLanguage("com.test.another-language.id")]
        XCTAssertEqual(entity.topicRenderReference.titleVariants.value(for: variantTraits), "Resolved Variant Title")
        XCTAssertEqual(entity.topicRenderReference.abstractVariants.value(for: variantTraits), [.text("Resolved variant abstract for this topic.")])
        
        let fragmentVariant = try XCTUnwrap(entity.topicRenderReference.fragmentsVariants.variants.first(where: { $0.traits == variantTraits }))
        XCTAssertEqual(fragmentVariant.patch.map(\.operation), [.replace])
        if case .replace(let variantFragment) = fragmentVariant.patch.first {
            XCTAssertEqual(variantFragment, [.init(text: "variant declaration fragment", kind: .text, preciseIdentifier: nil)])
        } else {
            XCTFail("Unexpected fragments variant patch")
        }
    }
    
    func testResolvingTopicLinkProcess() throws {
        #if os(macOS)
        try assertResolvesTopicLink(makeResolver: { testMetadata in
            let temporaryFolder = try createTemporaryDirectory()
            let executableLocation = temporaryFolder.appendingPathComponent("link-resolver-executable")
            
            let encodedMetadata = try String(data: JSONEncoder().encode(testMetadata), encoding: .utf8)!
            
            try """
            #!/bin/bash
            echo '{"bundleIdentifier":"com.test.bundle"}'       # Write this resolver's bundle identifier
            read                                                # Wait for docc to send a topic URL
            echo '{"resolvedInformation":\(encodedMetadata)}'   # Respond with the test metadata (above)
            """.write(to: executableLocation, atomically: true, encoding: .utf8)
            
            // `0o0700` is `-rwx------` (read, write, & execute only for owner)
            try FileManager.default.setAttributes([.posixPermissions: 0o0700], ofItemAtPath: executableLocation.path)
            XCTAssert(FileManager.default.isExecutableFile(atPath: executableLocation.path))
             
            return try OutOfProcessReferenceResolver(processLocation: executableLocation, errorOutputHandler: { _ in })
        })
        
        #endif
    }
    
    func testResolvingTopicLinkService() throws {
        try assertResolvesTopicLink(makeResolver: { testMetadata in
            let server = DocumentationServer()
            server.register(service: MockService { message in
                XCTAssertEqual(message.type, "resolve-reference")
                XCTAssert(message.identifier.hasPrefix("SwiftDocC"))
                do {
                    let payload = try XCTUnwrap(message.payload)
                    let request = try JSONDecoder()
                        .decode(
                            ConvertRequestContextWrapper<OutOfProcessReferenceResolver.Request>.self,
                            from: payload
                        )
                    
                    XCTAssertEqual(request.convertRequestIdentifier, "convert-id")
                    
                    guard case .topic(let url) = request.payload else {
                        XCTFail("Unexpected request")
                        return nil
                    }
                    
                    XCTAssertEqual(url, URL(string: "doc://com.test.bundle/something")!)
                    
                    let response = DocumentationServer.Message(
                        type: "resolve-reference-response",
                        payload: try JSONEncoder().encode(
                            OutOfProcessReferenceResolver.Response.resolvedInformation(testMetadata))
                    )
                    
                    return response
                } catch {
                    XCTFail(error.localizedDescription)
                    return nil
                }
            })

            return try OutOfProcessReferenceResolver(
                id: "com.test.bundle",
                server: server,
                convertRequestIdentifier: "convert-id"
            )
        })
    }
    
    func assertResolvesSymbol(makeResolver: (OutOfProcessReferenceResolver.ResolvedInformation) throws -> OutOfProcessReferenceResolver) throws {
        let lightCardImageURL = try XCTUnwrap(URL(string: "https://com.test.example/some-image-name.jpg"))
        let darkCardImageURL = try XCTUnwrap(URL(string: "https://com.test.example/some-image-name-dark.jpg"))
        
        let testMetadata = OutOfProcessReferenceResolver.ResolvedInformation(
            kind: .init(name: "Kind Name", id: "com.test.kind.id", isSymbol: true),
            url: URL(string: "/relative/path/to/symbol")!,
            title: "Resolved Title",
            abstract: "Resolved abstract for this topic.",
            language: .swift, // This is Swift to account for what is considered a symbol's "first" variant value (rdar://86580516)
            availableLanguages: [
                .swift,
                .init(name: "Language Name 2", id: "com.test.another-language.id"),
                .objectiveC,
            ],
            platforms: [
                .init(name: "fooOS", introduced: "1.2.3", isBeta: false),
                .init(name: "barOS", introduced: "1.2.3", isBeta: false),
            ],
            declarationFragments: .init(declarationFragments: [
                .init(kind: .text, spelling: "declaration fragment", preciseIdentifier: nil)
            ]),
            topicImages: [
                TopicImage(
                    type: .card,
                    identifier: RenderReferenceIdentifier("external-card")
                ),
            ],
            references: [
                ImageReference(
                    identifier: RenderReferenceIdentifier("external-card"),
                    altText: "External card alt text",
                    imageAsset:
                        DataAsset(
                            variants: [
                                DataTraitCollection(userInterfaceStyle: .light, displayScale: .double): lightCardImageURL,
                                DataTraitCollection(userInterfaceStyle: .dark, displayScale: .double): darkCardImageURL,
                            ],
                            metadata: [
                                lightCardImageURL : DataAsset.Metadata(svgID: nil),
                                darkCardImageURL : DataAsset.Metadata(svgID: nil),
                            ],
                            context: .display
                        )
                    ),
            ],
            variants: [
                .init(
                    traits: [.interfaceLanguage("com.test.another-language.id")],
                    kind: .init(name: "Variant Kind Name", id: "com.test.kind2.id", isSymbol: true),
                    url: nil,
                    title: "Resolved Variant Title",
                    abstract: "Resolved variant abstract for this topic.",
                    language: .init(name: "Language Name 2", id: "com.test.another-language.id"),
                    declarationFragments: .init(declarationFragments: [
                        .init(kind: .text, spelling: "variant declaration fragment", preciseIdentifier: nil)
                    ])
                )
            ]
        )
        
        let resolver = try makeResolver(testMetadata)
        
        XCTAssertEqual(resolver.bundleID, "com.test.bundle")
        
        // Resolve the symbol
        let (_, entity) = try XCTUnwrap(resolver.symbolReferenceAndEntity(withPreciseIdentifier: "abc123"), "Unexpectedly failed to resolve symbol")
        
        XCTAssertEqual(entity.topicRenderReference.url, testMetadata.url.absoluteString)
        
        XCTAssertEqual(entity.topicRenderReference.kind.rawValue, "symbol")
        XCTAssertEqual(entity.topicRenderReference.role, "symbol")
        
        XCTAssertEqual(entity.topicRenderReference.title, "Resolved Title")

        XCTAssertEqual(entity.sourceLanguages.count, 3)

        let availableSourceLanguages = entity.sourceLanguages.sorted()
        let expectedLanguages = testMetadata.availableLanguages.sorted()
        
        XCTAssertEqual(availableSourceLanguages[0], expectedLanguages[0])
        XCTAssertEqual(availableSourceLanguages[1], expectedLanguages[1])
        XCTAssertEqual(availableSourceLanguages[2], expectedLanguages[2])
        
        XCTAssertEqual(entity.topicRenderReference.fragments, [.init(text: "declaration fragment", kind: .text, preciseIdentifier: nil)])
        
        let variantTraits = [RenderNode.Variant.Trait.interfaceLanguage("com.test.another-language.id")]
        XCTAssertEqual(entity.topicRenderReference.titleVariants.value(for: variantTraits), "Resolved Variant Title")
        XCTAssertEqual(entity.topicRenderReference.abstractVariants.value(for: variantTraits), [.text("Resolved variant abstract for this topic.")])
        
        let fragmentVariant = try XCTUnwrap(entity.topicRenderReference.fragmentsVariants.variants.first(where: { $0.traits == variantTraits }))
        XCTAssertEqual(fragmentVariant.patch.map(\.operation), [.replace])
        if case .replace(let variantFragment) = fragmentVariant.patch.first {
            XCTAssertEqual(variantFragment, [.init(text: "variant declaration fragment", kind: .text, preciseIdentifier: nil)])
        } else {
           XCTFail("Unexpected fragments variant patch")
        }

        XCTAssertNil(entity.topicRenderReference.conformance)
        XCTAssertNil(entity.topicRenderReference.estimatedTime)
        XCTAssertNil(entity.topicRenderReference.defaultImplementationCount)
        XCTAssertFalse(entity.topicRenderReference.isBeta)
        XCTAssertFalse(entity.topicRenderReference.isDeprecated)
        XCTAssertNil(entity.topicRenderReference.propertyListKeyNames)
        XCTAssertNil(entity.topicRenderReference.tags)
        
        XCTAssertEqual(entity.topicRenderReference.images.count, 1)
        let topicImage = try XCTUnwrap(entity.topicRenderReference.images.first)
        XCTAssertEqual(topicImage.type, .card)
        
        let image = try XCTUnwrap(entity.renderReferenceDependencies.imageReferences.first(where: { $0.identifier == topicImage.identifier }))
        
        XCTAssertEqual(image.identifier, RenderReferenceIdentifier("external-card"))
        XCTAssertEqual(image.altText, "External card alt text")

        XCTAssertEqual(image.asset, DataAsset(
            variants: [
                DataTraitCollection(userInterfaceStyle: .light, displayScale: .double): lightCardImageURL,
                DataTraitCollection(userInterfaceStyle: .dark, displayScale: .double): darkCardImageURL,
            ],
            metadata: [
                lightCardImageURL : DataAsset.Metadata(svgID: nil),
                darkCardImageURL : DataAsset.Metadata(svgID: nil),
            ],
            context: .display
        ))
    }
    
    func testResolvingSymbolProcess() throws {
        #if os(macOS)
        try assertResolvesSymbol(makeResolver: { testMetadata in
            let temporaryFolder = try createTemporaryDirectory()
            let executableLocation = temporaryFolder.appendingPathComponent("link-resolver-executable")
            
            let encodedMetadata = try String(data: JSONEncoder().encode(testMetadata), encoding: .utf8)!
            
            try """
        #!/bin/bash
        echo '{"bundleIdentifier":"com.test.bundle"}'         # Write this resolver's bundle identifier
        read                                                  # Wait for docc to send a symbol USR
        echo '{"resolvedInformation":\(encodedMetadata)}'     # Respond with the test metadata (above)
        """.write(to: executableLocation, atomically: true, encoding: .utf8)
            
            // `0o0700` is `-rwx------` (read, write, & execute only for owner)
            try FileManager.default.setAttributes([.posixPermissions: 0o0700], ofItemAtPath: executableLocation.path)
            XCTAssert(FileManager.default.isExecutableFile(atPath: executableLocation.path))
            
            return try OutOfProcessReferenceResolver(processLocation: executableLocation, errorOutputHandler: { _ in })
        })
        #endif
    }
    
    func testResolvingSymbolService() throws {
        try assertResolvesSymbol(makeResolver: { testMetadata in
            let server = DocumentationServer()
            server.register(service: MockService { message in
                XCTAssertEqual(message.type, "resolve-reference")
                XCTAssert(message.identifier.hasPrefix("SwiftDocC"))
                do {
                    let payload = try XCTUnwrap(message.payload)
                    let request = try JSONDecoder()
                        .decode(
                            ConvertRequestContextWrapper<OutOfProcessReferenceResolver.Request>.self,
                            from: payload
                        )
                    
                    XCTAssertEqual(request.convertRequestIdentifier, "convert-id")
                    
                    guard case .symbol(let preciseIdentifier) = request.payload else {
                        XCTFail("Unexpected request")
                        return nil
                    }
                    
                    XCTAssertEqual(preciseIdentifier, "abc123")
                    
                    let response = DocumentationServer.Message(
                        type: "resolve-reference-response",
                        payload: try JSONEncoder().encode(
                            OutOfProcessReferenceResolver.Response.resolvedInformation(testMetadata))
                    )
                    
                    return response
                } catch {
                    XCTFail(error.localizedDescription)
                    return nil
                }
            })

            return try OutOfProcessReferenceResolver(
                id: "com.test.bundle",
                server: server,
                convertRequestIdentifier: "convert-id"
            )
        })
    }
    
    func testForwardsErrorOutputProcess() throws {
        #if os(macOS)
        let temporaryFolder = try createTemporaryDirectory()
        
        let executableLocation = temporaryFolder.appendingPathComponent("link-resolver-executable")
        try """
        #!/bin/bash
        echo '{"bundleIdentifier":"com.test.bundle"}'   # Write this resolver's bundle identifier
        echo "Some error output" 1>&2                   # Write to stderr
        read                                            # Wait for docc to send a topic URL
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
        #endif
    }
    
    func assertForwardsResolverErrors(resolver: OutOfProcessReferenceResolver, file: StaticString = #file, line: UInt = #line) throws {
        XCTAssertEqual(resolver.bundleID, "com.test.bundle", file: file, line: line)
        let resolverResult = resolver.resolve(.unresolved(UnresolvedTopicReference(topicURL: ValidatedURL(parsingExact: "doc://com.test.bundle/something")!)))
        guard case .failure(_, let error) = resolverResult else {
            XCTFail("Encountered an unexpected type of error.", file: file, line: line)
            return
        }
        XCTAssertEqual(error.message, "Some error message.", file: file, line: line)
    }
    
    func testForwardsResolverErrorsProcess() throws {
        #if os(macOS)
        let temporaryFolder = try createTemporaryDirectory()
        
        let executableLocation = temporaryFolder.appendingPathComponent("link-resolver-executable")
        try """
        #!/bin/bash
        echo '{"bundleIdentifier":"com.test.bundle"}'   # Write this resolver's bundle identifier
        read                                            # Wait for docc to send a topic URL
        echo '{"errorMessage":"Some error message."}'   # Respond with an error message
        """.write(to: executableLocation, atomically: true, encoding: .utf8)
        
        // `0o0700` is `-rwx------` (read, write, & execute only for owner)
        try FileManager.default.setAttributes([.posixPermissions: 0o0700], ofItemAtPath: executableLocation.path)
        XCTAssert(FileManager.default.isExecutableFile(atPath: executableLocation.path))
         
        let resolver = try OutOfProcessReferenceResolver(processLocation: executableLocation, errorOutputHandler: { _ in })
        try assertForwardsResolverErrors(resolver: resolver)
        #endif
    }
    
    func testForwardsResolverErrorsService() throws {
        let server = DocumentationServer()
        server.register(service: MockService { message in
            XCTAssertEqual(message.type, "resolve-reference")
            XCTAssert(message.identifier.hasPrefix("SwiftDocC"))
            do {
                let payload = try XCTUnwrap(message.payload)
                let request = try JSONDecoder()
                    .decode(
                        ConvertRequestContextWrapper<OutOfProcessReferenceResolver.Request>.self,
                        from: payload
                    )
                
                XCTAssertEqual(request.convertRequestIdentifier, "convert-id")
                
                guard case .topic = request.payload else {
                    XCTFail("Unexpected request")
                    return nil
                }
                                
                let response = DocumentationServer.Message(
                    type: "resolve-reference-response",
                    payload: try JSONEncoder().encode(
                        OutOfProcessReferenceResolver.Response.errorMessage("Some error message.")
                    )
                )
                
                return response
            } catch {
                XCTFail(error.localizedDescription)
                return nil
            }
        })
        
        let resolver = try OutOfProcessReferenceResolver(
            id: "com.test.bundle", server: server, convertRequestIdentifier: "convert-id")
        
        try assertForwardsResolverErrors(resolver: resolver)
    }
    
    func testMessageEncodingAndDecoding() throws {
        #if os(macOS)
        // Bundle identifier
        do {
            let message = OutOfProcessReferenceResolver.Response.bundleIdentifier("com.example.test")
            
            let data = try JSONEncoder().encode(message)
            let decodedMessage = try JSONDecoder().decode(OutOfProcessReferenceResolver.Response.self, from: data)
            
            switch decodedMessage {
            case .bundleIdentifier(let decodedIdentifier):
                XCTAssertEqual(decodedIdentifier, "com.example.test")
                
            default:
                XCTFail("Decoded the wrong type of message")
            }
        }
        
        // Error message
        do {
            let message = OutOfProcessReferenceResolver.Response.errorMessage("Some error output.")
            
            let data = try JSONEncoder().encode(message)
            let decodedMessage = try JSONDecoder().decode(OutOfProcessReferenceResolver.Response.self, from: data)
            
            switch decodedMessage {
            case .errorMessage(let decodedErrorMessage):
                XCTAssertEqual(decodedErrorMessage, "Some error output.")
                
            default:
                XCTFail("Decoded the wrong type of message")
            }
        }
        
        // Resolved metadata
        do {
            let testMetadata = OutOfProcessReferenceResolver.ResolvedInformation(
                kind: .init(name: "Kind Name", id: "com.test.kind.id", isSymbol: true),
                url: URL(string: "scheme://host.name/path/")!,
                title: "Resolved Title",
                abstract: "Resolved abstract for this topic.",
                language: .init(name: "Language Name", id: "com.test.language.id"),
                availableLanguages: [],
                platforms: nil,
                declarationFragments: nil,
                topicImages: nil,
                references: nil
            )
            let message = OutOfProcessReferenceResolver.Response.resolvedInformation(testMetadata)
            
            let data = try JSONEncoder().encode(message)
            let decodedMessage = try JSONDecoder().decode(OutOfProcessReferenceResolver.Response.self, from: data)
            
            switch decodedMessage {
            case .resolvedInformation(let decodedInformation):
                XCTAssertEqual(decodedInformation.kind.name, testMetadata.kind.name)
                XCTAssertEqual(decodedInformation.kind.id, testMetadata.kind.id)
                XCTAssertEqual(decodedInformation.kind.isSymbol, testMetadata.kind.isSymbol)
                
                XCTAssertEqual(decodedInformation.title, testMetadata.title)
                
                XCTAssertEqual(decodedInformation.language.name, testMetadata.language.name)
                XCTAssertEqual(decodedInformation.language.id, testMetadata.language.id)
                
            default:
                XCTFail("Decoded the wrong type of message")
            }
        }
        #endif
    }
    
    func testMetadataMessageWithVariants() throws {
        #if os(macOS)
        do {
            let testMetadata = OutOfProcessReferenceResolver.ResolvedInformation(
                kind: .init(name: "Kind Name", id: "com.test.kind.id", isSymbol: true),
                url: URL(string: "scheme://host.name/path/")!,
                title: "Resolved Title",
                abstract: "Resolved abstract for this topic.",
                language: .swift, // This is Swift to account for what is considered a symbol's "first" variant value (rdar://86580516)
                availableLanguages: [
                    .swift,
                    .init(name: "Variant Language Name", id: "com.test.other-language.id")
                ],
                platforms: [.init(name: "Platform Name", introduced: "1.0.0", isBeta: false)],
                declarationFragments: .init(declarationFragments: [
                    .init(kind: .text, spelling: "declaration fragment", preciseIdentifier: nil)
                ]),
                topicImages: nil,
                references: nil,
                variants: [
                    .init(
                        traits: [.interfaceLanguage("com.test.other-language.id")],
                        kind: .init(name: "Variant Kind Name", id: "com.test.other-kind.id", isSymbol: true),
                        url: nil,
                        title: "Resolved Variant Title",
                        abstract: "Resolved variant abstract for this topic.",
                        language: .init(name: "Variant Language Name", id: "com.test.other-language.id"),
                        declarationFragments: .init(declarationFragments: [
                            .init(kind: .text, spelling: "variant declaration fragment", preciseIdentifier: nil)
                        ])
                    )
                ]
            )
            let message = OutOfProcessReferenceResolver.Response.resolvedInformation(testMetadata)
            
            let data = try JSONEncoder().encode(message)
            let decodedMessage = try JSONDecoder().decode(OutOfProcessReferenceResolver.Response.self, from: data)
            
            switch decodedMessage {
            case .resolvedInformation(let decodedInformation):
                XCTAssertEqual(decodedInformation.kind.name, testMetadata.kind.name)
                XCTAssertEqual(decodedInformation.kind.id, testMetadata.kind.id)
                XCTAssertEqual(decodedInformation.kind.isSymbol, testMetadata.kind.isSymbol)
                
                XCTAssertEqual(decodedInformation.title, testMetadata.title)
                
                XCTAssertEqual(decodedInformation.abstract, testMetadata.abstract)
                
                XCTAssertEqual(decodedInformation.language.name, testMetadata.language.name)
                XCTAssertEqual(decodedInformation.language.id, testMetadata.language.id)
                
                XCTAssertEqual(decodedInformation.availableLanguages, testMetadata.availableLanguages)
                XCTAssertEqual(decodedInformation.platforms, testMetadata.platforms)
                
                XCTAssertEqual(decodedInformation.declarationFragments?.declarationFragments.count, testMetadata.declarationFragments?.declarationFragments.count)
                for (decodedFragment, testFragment) in zip(decodedInformation.declarationFragments?.declarationFragments ?? [], testMetadata.declarationFragments?.declarationFragments ?? []) {
                    XCTAssertEqual(decodedFragment, testFragment)
                }
                
                XCTAssertEqual(decodedInformation.variants?.count, testMetadata.variants?.count)
                let decodedVariant = try XCTUnwrap(decodedInformation.variants?.first)
                let testVariant = try XCTUnwrap(testMetadata.variants?.first)
                
                XCTAssertEqual(decodedVariant.kind?.name, testVariant.kind?.name)
                XCTAssertEqual(decodedVariant.kind?.id, testVariant.kind?.id)
                XCTAssertEqual(decodedVariant.kind?.isSymbol, testVariant.kind?.isSymbol)
                
                XCTAssertEqual(decodedVariant.title, testVariant.title)
                
                XCTAssertEqual(decodedVariant.abstract, testVariant.abstract)
                
                XCTAssertEqual(decodedVariant.language?.name, testVariant.language?.name)
                XCTAssertEqual(decodedVariant.language?.id, testVariant.language?.id)
                
                XCTAssertEqual(decodedVariant.declarationFragments??.declarationFragments.count, testVariant.declarationFragments??.declarationFragments.count)
                for (decodedFragment, testFragment) in zip(decodedVariant.declarationFragments??.declarationFragments ?? [], testVariant.declarationFragments??.declarationFragments ?? []) {
                    XCTAssertEqual(decodedFragment, testFragment)
                }
                
            default:
                XCTFail("Decoded the wrong type of message")
            }
        }
        #endif
    }
    
    func testErrorWhenReceivingBundleIdentifierTwiceProcess() throws {
        #if os(macOS)
        let temporaryFolder = try createTemporaryDirectory()
        
        let executableLocation = temporaryFolder.appendingPathComponent("link-resolver-executable")
        try """
            #!/bin/bash
            echo '{"bundleIdentifier":"com.test.bundle"}'   # Write this resolver's bundle identifier
            read                                            # Wait for docc to send a topic URL
            echo '{"bundleIdentifier":"com.test.bundle"}'   # Write the bundle identifier again
            """.write(to: executableLocation, atomically: true, encoding: .utf8)
        
        // `0o0700` is `-rwx------` (read, write, & execute only for owner)
        try FileManager.default.setAttributes([.posixPermissions: 0o0700], ofItemAtPath: executableLocation.path)
        XCTAssert(FileManager.default.isExecutableFile(atPath: executableLocation.path))
        
        let resolver = try OutOfProcessReferenceResolver(processLocation: executableLocation, errorOutputHandler: { _ in })
        XCTAssertEqual(resolver.bundleID, "com.test.bundle")
        
        XCTAssertThrowsError(try resolver.resolveInformationForTopicURL(URL(string: "doc://com.test.bundle/something")!)) {
            guard case OutOfProcessReferenceResolver.Error.executableSentBundleIdentifierAgain = $0 else {
                XCTFail("Encountered an unexpected type of error.")
                return
            }
        }
        #endif
    }
    
    struct MockService: DocumentationService {
        static var handlingTypes: [DocumentationServer.MessageType] = ["resolve-reference"]
        
        var processHandler: (DocumentationServer.Message) -> DocumentationServer.Message?
        
        func process(
            _ message: DocumentationServer.Message,
            completion: @escaping (DocumentationServer.Message) -> ()
        ) {
            if let response = processHandler(message) {
                completion(response)
            }
        }
    }
    
    func assertSymbolBetaStatus(
        platforms: [OutOfProcessReferenceResolver.ResolvedInformation.PlatformAvailability], expectedStatus isBeta: Bool,
        file: StaticString = #file, line: UInt = #line,
        makeResolver: (OutOfProcessReferenceResolver.ResolvedInformation) throws -> OutOfProcessReferenceResolver
    ) throws {
        let testMetadata = OutOfProcessReferenceResolver.ResolvedInformation(
            kind: .init(name: "Kind Name", id: "com.test.kind.id", isSymbol: true),
            url: URL(string: "doc://com.test.bundle/something")!,
            title: "Resolved Title",
            abstract: "Resolved abstract for this topic.",
            language: .swift, // This is Swift to account for what is considered a symbol's "first" variant value (rdar://86580516)
            availableLanguages: [],
            platforms: platforms,
            declarationFragments: nil,
            topicImages: nil,
            references: nil,
            variants: []
        )
                
        let resolver = try makeResolver(testMetadata)
        XCTAssertEqual(resolver.bundleID, "com.test.bundle", file: file, line: line)

        // Resolve the reference
        let unresolved = TopicReference.unresolved(
            UnresolvedTopicReference(topicURL: ValidatedURL(parsingExact: "doc://com.test.bundle/something")!))
        guard case .success(let resolvedReference) = resolver.resolve(unresolved) else {
            XCTFail("Unexpectedly failed to resolve reference")
            return
        }
        
        // Resolve the symbol
        let topicLinkEntity = resolver.entity(with: resolvedReference)

        XCTAssertEqual(topicLinkEntity.topicRenderReference.isBeta, isBeta, file: file, line: line)
        
        // Resolve the symbol
        let (_, symbolEntity) = try XCTUnwrap(resolver.symbolReferenceAndEntity(withPreciseIdentifier: "abc123"), "Unexpectedly failed to resolve symbol")
        
        XCTAssertEqual(symbolEntity.topicRenderReference.isBeta, isBeta, file: file, line: line)

    }
    
    func testResolvingSymbolBetaStatusProcess() throws {
        #if os(macOS)
        func makeResolver(testMetadata: OutOfProcessReferenceResolver.ResolvedInformation) throws -> OutOfProcessReferenceResolver {
            let temporaryFolder = try createTemporaryDirectory()
            let executableLocation = temporaryFolder.appendingPathComponent("link-resolver-executable")
            
            let encodedMetadata = try String(data: JSONEncoder().encode(testMetadata), encoding: .utf8)!
            
            try """
        #!/bin/bash
        echo '{"bundleIdentifier":"com.test.bundle"}'           # Write this resolver's bundle identifier
        read                                                    # Wait for docc to send a symbol USR
        echo '{"resolvedInformation":\(encodedMetadata)}'       # Respond with the test metadata (above)
        read                                                    # Wait for docc to send a symbol USR
        echo '{"resolvedInformation":\(encodedMetadata)}'       # Respond with the test metadata (above)
        """.write(to: executableLocation, atomically: true, encoding: .utf8)
            
            // `0o0700` is `-rwx------` (read, write, & execute only for owner)
            try FileManager.default.setAttributes([.posixPermissions: 0o0700], ofItemAtPath: executableLocation.path)
            XCTAssert(FileManager.default.isExecutableFile(atPath: executableLocation.path))
            
            return try OutOfProcessReferenceResolver(processLocation: executableLocation, errorOutputHandler: { _ in })
        }
        
        // All platforms are in beta
        try assertSymbolBetaStatus(platforms: [
            .init(name: "fooOS", introduced: "1.2.3", isBeta: true),
            .init(name: "barOS", introduced: "1.2.3", isBeta: true),
            .init(name: "bazOS", introduced: "1.2.3", isBeta: true),
        ], expectedStatus: true, makeResolver: makeResolver)
        
        // One platform is stable, the other two are in beta
        try assertSymbolBetaStatus(platforms: [
            .init(name: "fooOS", introduced: "1.2.3", isBeta: false),
            .init(name: "barOS", introduced: "1.2.3", isBeta: true),
            .init(name: "bazOS", introduced: "1.2.3", isBeta: true),
        ], expectedStatus: false, makeResolver: makeResolver)
        
        // No platforms explicitly supported
        try assertSymbolBetaStatus(platforms: [
        ], expectedStatus: false, makeResolver: makeResolver)

        #endif
    }
    
    func testResolvingSymbolBetaStatusService() throws {
        func makeResolver(testMetadata: OutOfProcessReferenceResolver.ResolvedInformation) throws -> OutOfProcessReferenceResolver {
            let server = DocumentationServer()
            server.register(service: MockService { message in
                XCTAssertEqual(message.type, "resolve-reference")
                XCTAssert(message.identifier.hasPrefix("SwiftDocC"))
                do {
                    let payload = try XCTUnwrap(message.payload)
                    let request = try JSONDecoder()
                        .decode(
                            ConvertRequestContextWrapper<OutOfProcessReferenceResolver.Request>.self,
                            from: payload
                        )
                    
                    XCTAssertEqual(request.convertRequestIdentifier, "convert-id")
                    
                    switch request.payload {
                    case .symbol(let preciseIdentifier):
                        XCTAssertEqual(preciseIdentifier, "abc123")
                    case .topic(let url):
                        XCTAssertEqual(url, URL(string: "doc://com.test.bundle/something")!)
                    default:
                        XCTFail("Unexpected request")
                        return nil
                    }

                    let response = DocumentationServer.Message(
                        type: "resolve-reference-response",
                        payload: try JSONEncoder().encode(
                            OutOfProcessReferenceResolver.Response.resolvedInformation(testMetadata))
                    )
                    return response
                } catch {
                    XCTFail(error.localizedDescription)
                    return nil
                }
            })

            return try OutOfProcessReferenceResolver(
                id: "com.test.bundle",
                server: server,
                convertRequestIdentifier: "convert-id"
            )
        }
        
        // All platforms are in beta
        try assertSymbolBetaStatus(platforms: [
            .init(name: "fooOS", introduced: "1.2.3", isBeta: true),
            .init(name: "barOS", introduced: "1.2.3", isBeta: true),
            .init(name: "bazOS", introduced: "1.2.3", isBeta: true),
        ], expectedStatus: true, makeResolver: makeResolver)
        
        // One platform is stable, the other two are in beta
        try assertSymbolBetaStatus(platforms: [
            .init(name: "fooOS", introduced: "1.2.3", isBeta: false),
            .init(name: "barOS", introduced: "1.2.3", isBeta: true),
            .init(name: "bazOS", introduced: "1.2.3", isBeta: true),
        ], expectedStatus: false, makeResolver: makeResolver)
        
        // No platforms explicitly supported
        try assertSymbolBetaStatus(platforms: [
        ], expectedStatus: false, makeResolver: makeResolver)
    }
}
