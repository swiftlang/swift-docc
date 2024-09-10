/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
import Foundation
@testable import SwiftDocC
import SymbolKit
import SwiftDocCTestUtilities

class ConvertServiceTests: XCTestCase {
    private let testBundleInfo = DocumentationBundle.Info(
        displayName: "TestBundle",
        identifier: "identifier",
        version: "1.0.0"
    )
    
    func testConvertSinglePage() throws {
        let symbolGraphFile = Bundle.module.url(
            forResource: "mykit-one-symbol",
            withExtension: "symbols.json",
            subdirectory: "Test Resources"
        )!
        
        let symbolGraph = try Data(contentsOf: symbolGraphFile)
        
        let request = ConvertRequest(
            bundleInfo: testBundleInfo,
            externalIDsToConvert: ["s:5MyKit0A5ClassC10myFunctionyyF"],
            documentPathsToConvert: [],
            symbolGraphs: [symbolGraph],
            markupFiles: [],
            miscResourceURLs: []
        )
        
        try processAndAssert(request: request) { message in
            XCTAssertEqual(message.type, "convert-response")
            XCTAssertEqual(message.identifier, "test-identifier-response")
            
            let renderNodes = try JSONDecoder().decode(
                ConvertResponse.self, from: XCTUnwrap(message.payload)).renderNodes
            
            XCTAssertEqual(renderNodes.count, 1)
            let data = try XCTUnwrap(renderNodes.first)
            let renderNode = try JSONDecoder().decode(RenderNode.self, from: data)

            XCTAssertEqual(
                renderNode.metadata.externalID,
                "s:5MyKit0A5ClassC10myFunctionyyF"
            )
            
            XCTAssertEqual(
               renderNode.metadata.sourceFileURI,
               "file:///private/tmp/test.swift"
            )
            
            XCTAssertEqual(
               renderNode.metadata.symbolAccessLevel,
               "public"
            )
            
            XCTAssertEqual(
               renderNode.metadata.extendedModule,
               "OtherModule"
            )
            
            XCTAssertEqual(
                renderNode.identifier.path,
                "/documentation/MyKit/MyClass/myFunction()"
            )
            
            guard renderNode.abstract?.count == 14 else {
                XCTFail()
                return
            }
            
            XCTAssertEqual(
                renderNode.abstract?[0],
                .reference(
                    identifier: .init("doc://identifier/documentation/MyKit/MyClass/myFunction()"),
                    isActive: true,
                    overridingTitle: nil,
                    overridingTitleInlineContent: nil
                )
            )
            
            XCTAssertEqual(
                renderNode.abstract?[1],
                .text(" is the public API to using the most of ")
            )
        }
    }
    
    func testConvertSinglePageWithDocumentationExtension() throws {
        let symbolGraphFile = Bundle.module.url(
            forResource: "mykit-one-symbol",
            withExtension: "symbols.json",
            subdirectory: "Test Resources"
        )!
        
        let myFunctionExtension = Bundle.module.url(
            forResource: "myFunction()",
            withExtension: "md",
            subdirectory: "Test Resources"
        )!
        
        let symbolGraph = try Data(contentsOf: symbolGraphFile)
        let myFunctionExtensionData = try Data(contentsOf: myFunctionExtension)
        
        let request = ConvertRequest(
            bundleInfo: testBundleInfo,
            externalIDsToConvert: ["s:5MyKit0A5ClassC10myFunctionyyF"],
            documentPathsToConvert: [],
            symbolGraphs: [symbolGraph],
            markupFiles: [myFunctionExtensionData],
            miscResourceURLs: []
        )
        
        try processAndAssert(request: request) { message in
            XCTAssertEqual(message.type, "convert-response")
            XCTAssertEqual(message.identifier, "test-identifier-response")
            
            let renderNodes = try JSONDecoder().decode(
                ConvertResponse.self, from: XCTUnwrap(message.payload)
            ).renderNodes
            
            XCTAssertEqual(renderNodes.count, 1)
            let data = try XCTUnwrap(renderNodes.first)
            let renderNode = try JSONDecoder().decode(RenderNode.self, from: data)

            XCTAssertEqual(
                renderNode.metadata.externalID,
                "s:5MyKit0A5ClassC10myFunctionyyF"
            )
            
            XCTAssertEqual(
                renderNode.identifier.path,
                "/documentation/MyKit/MyClass/myFunction()"
            )
            
            XCTAssertEqual(renderNode.abstract?.count, 1)
            
            XCTAssertEqual(
                renderNode.abstract?.first,
                .text("This abstract is written in a documentation extension file.")
            )
        }
    }
    
    func testIncludesRemoteSourceInformationForSymbol() throws {
        let symbolGraphFile = Bundle.module.url(
            forResource: "mykit-one-symbol",
            withExtension: "symbols.json",
            subdirectory: "Test Resources"
        )!
        
        let symbolGraph = try Data(contentsOf: symbolGraphFile)
        
        let request = ConvertRequest(
            bundleInfo: testBundleInfo,
            externalIDsToConvert: ["s:5MyKit0A5ClassC10myFunctionyyF"],
            documentPathsToConvert: [],
            symbolGraphs: [symbolGraph],
            markupFiles: [],
            miscResourceURLs: []
        )
        
        try processAndAssert(request: request) { message in
            XCTAssertEqual(message.type, "convert-response")
            XCTAssertEqual(message.identifier, "test-identifier-response")
            
            let renderNodes = try JSONDecoder().decode(
                ConvertResponse.self, from: XCTUnwrap(message.payload)).renderNodes
            
            XCTAssertEqual(renderNodes.count, 1)
            let data = try XCTUnwrap(renderNodes.first)
            let renderNode = try JSONDecoder().decode(RenderNode.self, from: data)
            
            XCTAssertEqual(
                renderNode.metadata.remoteSource?.fileName,
                "test.swift"
            )
            
            XCTAssertEqual(
                renderNode.metadata.remoteSource?.url.absoluteString,
                "doc-source-file:///private/tmp/test.swift#L2"
            )
        }
    }
    
    func testRemoteSourceInformationOptOut() throws {
        let symbolGraphFile = Bundle.module.url(
            forResource: "mykit-one-symbol",
            withExtension: "symbols.json",
            subdirectory: "Test Resources"
        )!
        
        let symbolGraph = try Data(contentsOf: symbolGraphFile)
        
        let request = ConvertRequest(
            bundleInfo: testBundleInfo,
            externalIDsToConvert: ["s:5MyKit0A5ClassC10myFunctionyyF"],
            documentPathsToConvert: [],
            symbolGraphs: [symbolGraph],
            emitSymbolSourceFileURIs: false,
            markupFiles: [],
            miscResourceURLs: []
        )
        
        try processAndAssert(request: request) { message in
            XCTAssertEqual(message.type, "convert-response")
            XCTAssertEqual(message.identifier, "test-identifier-response")
            
            let renderNodes = try JSONDecoder().decode(
                ConvertResponse.self, from: XCTUnwrap(message.payload)).renderNodes
            
            XCTAssertEqual(renderNodes.count, 1)
            let data = try XCTUnwrap(renderNodes.first)
            let renderNode = try JSONDecoder().decode(RenderNode.self, from: data)
            
            XCTAssertNil(renderNode.metadata.remoteSource, "No remote source when 'emitSymbolSourceFileURIs' is 'false'")
        }
    }
    
    func testOverridesDocumentationComments() throws {
        let symbolGraphFile = Bundle.module.url(
            forResource: "mykit-one-symbol",
            withExtension: "symbols.json",
            subdirectory: "Test Resources"
        )!
        
        let symbolGraph = try Data(contentsOf: symbolGraphFile)
        
        let request = ConvertRequest(
            bundleInfo: testBundleInfo,
            externalIDsToConvert: ["s:5MyKit0A5ClassC10myFunctionyyF"],
            documentPathsToConvert: [],
            symbolGraphs: [symbolGraph],
            overridingDocumentationComments: [
                "s:5MyKit0A5ClassC10myFunctionyyF": [
                    ConvertRequest.Line(
                        text: "line 1",
                        sourceRange: ConvertRequest.SourceRange(
                            start: ConvertRequest.Position(
                                line: 12,
                                character: 0
                            ),
                            end: ConvertRequest.Position(
                                line: 12,
                                character: 7
                            )
                        )
                    ),
                    ConvertRequest.Line(text: "line 2")
                ]
            ],
            markupFiles: [],
            miscResourceURLs: []
        )
        
        try processAndAssert(request: request) { message in
            let renderNodes = try JSONDecoder().decode(
                ConvertResponse.self, from: XCTUnwrap(message.payload)).renderNodes
            
            XCTAssertEqual(renderNodes.count, 1)
            let data = try XCTUnwrap(renderNodes.first)
            let renderNode = try JSONDecoder().decode(RenderNode.self, from: data)
            
            XCTAssertEqual(
                renderNode.abstract?.plainText,
                "line 1 line 2"
            )
        }
    }
    
    func testConvertSinglePageWithUnrelatedDocumentationExtension() throws {
        let symbolGraphFile = Bundle.module.url(
            forResource: "mykit-one-symbol",
            withExtension: "symbols.json",
            subdirectory: "Test Resources"
        )!
        
        let myFunctionExtension = Bundle.module.url(
            forResource: "myFunction()",
            withExtension: "md",
            subdirectory: "Test Resources"
        )!
        
        let symbolGraph = try Data(contentsOf: symbolGraphFile)
        
        let unrelatedFunctionExtensionData = try XCTUnwrap(
            try String(
                contentsOf: myFunctionExtension, encoding: .utf8
            ).replacingOccurrences(
                of: "``MyKit/MyClass/myFunction()``",
                with: "``MyKit/UnrelatedClass/unrelatedFunction()``"
            ).data(using: .utf8)
        )
        
        let request = ConvertRequest(
            bundleInfo: testBundleInfo,
            externalIDsToConvert: ["s:5MyKit0A5ClassC10myFunctionyyF"],
            documentPathsToConvert: [],
            symbolGraphs: [symbolGraph],
            markupFiles: [unrelatedFunctionExtensionData],
            miscResourceURLs: []
        )
        
        try processAndAssert(request: request) { message in
            XCTAssertEqual(message.type, "convert-response")
            XCTAssertEqual(message.identifier, "test-identifier-response")
            
            let renderNodes = try JSONDecoder().decode(
                ConvertResponse.self, from: XCTUnwrap(message.payload)
            ).renderNodes
            
            XCTAssertEqual(renderNodes.count, 1)
            let data = try XCTUnwrap(renderNodes.first)
            let renderNode = try JSONDecoder().decode(RenderNode.self, from: data)

            XCTAssertEqual(
                renderNode.metadata.externalID,
                "s:5MyKit0A5ClassC10myFunctionyyF"
            )
            
            XCTAssertEqual(
                renderNode.identifier.path,
                "/documentation/MyKit/MyClass/myFunction()"
            )
            
            XCTAssertEqual(renderNode.abstract?.count, 14)
            
            XCTAssertEqual(
                renderNode.abstract?.first,
                .reference(
                    identifier: .init("doc://identifier/documentation/MyKit/MyClass/myFunction()"),
                    isActive: true,
                    overridingTitle: nil,
                    overridingTitleInlineContent: nil
                )
            )
            
            XCTAssertEqual(
                renderNode.abstract?.dropFirst().first,
                .text(" is the public API to using the most of ")
            )
        }
    }
    
    func testConvertSinglePageWithDocumentationExtensionAndKnownDisambiguatedPathComponents() throws {
        let symbolGraphFile = Bundle.module.url(
            forResource: "mykit-one-symbol",
            withExtension: "symbols.json",
            subdirectory: "Test Resources"
        )!
        
        let myFunctionExtension = Bundle.module.url(
            forResource: "myFunction()",
            withExtension: "md",
            subdirectory: "Test Resources"
        )!
        
        let symbolGraph = try Data(contentsOf: symbolGraphFile)
        let myFunctionExtensionData = try XCTUnwrap(
            try String(
                contentsOf: myFunctionExtension, encoding: .utf8
            ).replacingOccurrences(
                of: "``MyKit/MyClass/myFunction()``",
                with: "``MyKit/MyClass-swift.class/myFunction()``"
            ).data(using: .utf8)
        )
        
        let request = ConvertRequest(
            bundleInfo: testBundleInfo,
            externalIDsToConvert: ["s:5MyKit0A5ClassC10myFunctionyyF"],
            documentPathsToConvert: [],
            symbolGraphs: [symbolGraph],
            knownDisambiguatedSymbolPathComponents: [
                "s:5MyKit0A5ClassC10myFunctionyyF": ["MyClass-swift.class", "myFunction()"],
            ],
            markupFiles: [myFunctionExtensionData],
            miscResourceURLs: []
        )
        
        try processAndAssert(request: request) { message in
            XCTAssertEqual(message.type, "convert-response")
            XCTAssertEqual(message.identifier, "test-identifier-response")
            
            let renderNodes = try JSONDecoder().decode(
                ConvertResponse.self, from: XCTUnwrap(message.payload)
            ).renderNodes
            
            XCTAssertEqual(renderNodes.count, 1)
            let data = try XCTUnwrap(renderNodes.first)
            let renderNode = try JSONDecoder().decode(RenderNode.self, from: data)

            XCTAssertEqual(
                renderNode.metadata.externalID,
                "s:5MyKit0A5ClassC10myFunctionyyF"
            )
            
            XCTAssertEqual(
                renderNode.identifier.path,
                "/documentation/MyKit/MyClass-swift.class/myFunction()"
            )
            
            XCTAssertEqual(renderNode.abstract?.count, 1)
            
            XCTAssertEqual(
                renderNode.abstract?.first,
                .text("This abstract is written in a documentation extension file.")
            )
        }
    }
    
    func testConvertSinglePageWithKnownDisambiguatedPathComponents() throws {
        let symbolGraphFile = Bundle.module.url(
            forResource: "mykit-one-symbol",
            withExtension: "symbols.json",
            subdirectory: "Test Resources"
        )!
        
        let symbolGraph = try Data(contentsOf: symbolGraphFile)
        
        var request = ConvertRequest(
            bundleInfo: testBundleInfo,
            externalIDsToConvert: ["s:5MyKit0A5ClassC10myFunctionyyF"],
            documentPathsToConvert: [],
            symbolGraphs: [symbolGraph],
            knownDisambiguatedSymbolPathComponents: [
                "s:5MyKit0A5ClassC10myFunctionyyF": ["MyClass-swift.class", "myFunction()"],
            ],
            markupFiles: [],
            miscResourceURLs: []
        )
        
        try processAndAssert(request: request) { message in
            let renderNodes = try JSONDecoder().decode(
                ConvertResponse.self, from: XCTUnwrap(message.payload)).renderNodes
            
            let data = try XCTUnwrap(renderNodes.first)
            let renderNode = try JSONDecoder().decode(RenderNode.self, from: data)
            
            XCTAssertEqual(
                renderNode.identifier.path,
                "/documentation/MyKit/MyClass-swift.class/myFunction()"
            )
            
            XCTAssertEqual(
                renderNode.abstract?.first,
                .reference(
                    identifier: .init("""
                        doc://identifier/documentation/MyKit/MyClass-swift.class/myFunction()
                        """
                    ),
                    isActive: true,
                    overridingTitle: nil,
                    overridingTitleInlineContent: nil
                )
            )
        }
        
        request.knownDisambiguatedSymbolPathComponents = [
            "s:5MyKit0A5ClassC10myFunctionyyF": ["MyClass-swift.class", "myFunction()-swift.method"],
        ]
        
        try processAndAssert(request: request) { message in
            let renderNodes = try JSONDecoder().decode(
                ConvertResponse.self, from: XCTUnwrap(message.payload)).renderNodes
            
            let data = try XCTUnwrap(renderNodes.first)
            let renderNode = try JSONDecoder().decode(RenderNode.self, from: data)
            
            XCTAssertEqual(
                renderNode.identifier.path,
                "/documentation/MyKit/MyClass-swift.class/myFunction()-swift.method"
            )
            
            XCTAssertEqual(
                renderNode.abstract?.first,
                .reference(
                    identifier: .init("""
                    doc://identifier/documentation/MyKit/MyClass-swift.class/myFunction()-swift.method
                    """
                                     ),
                    isActive: true,
                    overridingTitle: nil,
                    overridingTitleInlineContent: nil
                )
            )
        }
        
        let symbolGraphWithAdjustedLink = Data(
            try XCTUnwrap(
                String(data: symbolGraph, encoding: .utf8)
            )
            .replacingOccurrences(of: "``myFunction()``", with: "``myFunction()-swift.method``")
            .utf8
        )
        
        request.symbolGraphs = [symbolGraphWithAdjustedLink]
        
        try processAndAssert(request: request) { message in
            let renderNodes = try JSONDecoder().decode(
                ConvertResponse.self, from: XCTUnwrap(message.payload)).renderNodes
            
            let data = try XCTUnwrap(renderNodes.first)
            let renderNode = try JSONDecoder().decode(RenderNode.self, from: data)
            
            XCTAssertEqual(
                renderNode.identifier.path,
                "/documentation/MyKit/MyClass-swift.class/myFunction()-swift.method"
            )
            
            XCTAssertEqual(
                renderNode.abstract?.first,
                .reference(
                    identifier: .init("""
                        doc://identifier/documentation/MyKit/MyClass-swift.class/myFunction()-swift.method
                        """
                    ),
                    isActive: true,
                    overridingTitle: nil,
                    overridingTitleInlineContent: nil
                )
            )
        }
    }
    
    func testConvertPageWithLinkResolvingAndKnownPathComponents() throws {
        let symbolGraphFile = Bundle.module.url(
            forResource: "mykit-one-symbol",
            withExtension: "symbols.json",
            subdirectory: "Test Resources"
        )!
        
        let symbolGraph = try Data(contentsOf: symbolGraphFile)
        
        let request = ConvertRequest(
            bundleInfo: testBundleInfo,
            externalIDsToConvert: ["s:5MyKit0A5ClassC10myFunctionyyF"],
            documentPathsToConvert: [],
            symbolGraphs: [symbolGraph],
            knownDisambiguatedSymbolPathComponents: [
                "s:5MyKit0A5ClassC10myFunctionyyF": ["MyClass-swift.class", "myFunction()"],
            ],
            markupFiles: [],
            miscResourceURLs: []
        )
        
        let server = DocumentationServer()
        var requestedChildOfDisambiguatedPathComponent = false
        
        let mockLinkResolvingService = LinkResolvingService { message in
            do {
                let payload = try XCTUnwrap(message.payload)
                let request = try JSONDecoder()
                    .decode(
                        ConvertRequestContextWrapper<OutOfProcessReferenceResolver.Request>.self,
                        from: payload
                    )
                
                
                if case let .topic(topicURL) = request.payload {
                    XCTAssertNotEqual(topicURL.path, "/documentation/MyKit/MyClass/ChildOfMyClass")
                    if topicURL.path == "/documentation/MyKit/MyClass-swift.class/ChildOfMyClass" {
                        requestedChildOfDisambiguatedPathComponent = true
                    }
                }
                
                let payloadData = OutOfProcessReferenceResolver.Response
                        .errorMessage("Unable to resolve reference.")
                
                return DocumentationServer.Message(
                    type: "resolve-reference-response",
                    payload: try JSONEncoder().encode(payloadData)
                )
            } catch {
                XCTFail(error.localizedDescription)
                return nil
            }
        }
        
        server.register(service: mockLinkResolvingService)
        
        try processAndAssert(request: request, linkResolvingServer: server) { message in
            XCTAssertTrue(requestedChildOfDisambiguatedPathComponent)
        }
    }
    
    func testConvertSinglePageWithIncompatibleKnownDisambiguatedPathComponents() throws {
        let symbolGraphFile = Bundle.module.url(
            forResource: "mykit-one-symbol",
            withExtension: "symbols.json",
            subdirectory: "Test Resources"
        )!
        
        let symbolGraph = try Data(contentsOf: symbolGraphFile)
        
        let request = ConvertRequest(
            bundleInfo: testBundleInfo,
            externalIDsToConvert: ["s:5MyKit0A5ClassC10myFunctionyyF"],
            documentPathsToConvert: [],
            symbolGraphs: [symbolGraph],
            knownDisambiguatedSymbolPathComponents: [
                // Only provide a single path component when this USR should
                // produce two
                "s:5MyKit0A5ClassC10myFunctionyyF": ["MyClass-swift.class"],
            ],
            markupFiles: [],
            miscResourceURLs: []
        )
        
        try processAndAssert(request: request) { message in
            let renderNodes = try JSONDecoder().decode(
                ConvertResponse.self, from: XCTUnwrap(message.payload)).renderNodes
            
            let data = try XCTUnwrap(renderNodes.first)
            let renderNode = try JSONDecoder().decode(RenderNode.self, from: data)
            
            XCTAssertEqual(
                renderNode.identifier.path,
                "/documentation/MyKit/MyClass/myFunction()"
            )
            
            XCTAssertEqual(
                renderNode.abstract?.first,
                .reference(
                    identifier: .init("""
                        doc://identifier/documentation/MyKit/MyClass/myFunction()
                        """
                    ),
                    isActive: true,
                    overridingTitle: nil,
                    overridingTitleInlineContent: nil
                )
            )
        }
    }
    
    func testConvertsSymbolPageThatHasExpandedDocumentation() throws {
        let symbolGraphFile = Bundle.module.url(
            forResource: "mykit-one-symbol",
            withExtension: "symbols.json",
            subdirectory: "Test Resources"
        )!
        
        let symbolGraph = try Data(contentsOf: symbolGraphFile)
        
        let request = ConvertRequest(
            bundleInfo: testBundleInfo,
            externalIDsToConvert: ["s:5MyKit0A5ClassC10myFunctionyyF"],
            documentPathsToConvert: [],
            symbolGraphs: [symbolGraph],
            markupFiles: [],
            miscResourceURLs: [],
            symbolIdentifiersWithExpandedDocumentation: [
                "s:5MyKit0A5ClassC10myFunctionyyF":
                    ConvertRequest.ExpandedDocumentationRequirements(accessControlLevels: ["public", "open"])
            ]
        )
        
        try processAndAssert(request: request) { message in
            XCTAssertEqual(message.type, "convert-response")
            XCTAssertEqual(message.identifier, "test-identifier-response")
            
            let renderNodes = try JSONDecoder().decode(
                ConvertResponse.self, from: XCTUnwrap(message.payload)).renderNodes
            
            let data = try XCTUnwrap(renderNodes.first)
            let renderNode = try JSONDecoder().decode(RenderNode.self, from: data)

            XCTAssertFalse(renderNode.metadata.hasNoExpandedDocumentation)
        }
    }
    
    func testConvertsSymbolPageThatDoesNotMeetAccessLevelRequirementForExpandedDocumentation() throws {
        let symbolGraphFile = Bundle.module.url(
            forResource: "mykit-one-symbol",
            withExtension: "symbols.json",
            subdirectory: "Test Resources"
        )!
        
        let symbolGraph = try Data(contentsOf: symbolGraphFile)
        
        let request = ConvertRequest(
            bundleInfo: testBundleInfo,
            externalIDsToConvert: ["s:5MyKit0A5ClassC10myFunctionyyF"],
            documentPathsToConvert: [],
            symbolGraphs: [symbolGraph],
            markupFiles: [],
            miscResourceURLs: [],
            symbolIdentifiersWithExpandedDocumentation: [
                "s:5MyKit0A5ClassC10myFunctionyyF":
                    ConvertRequest.ExpandedDocumentationRequirements(accessControlLevels: ["open"])
            ] // This symbol is public
        )
        
        try processAndAssert(request: request) { message in
            XCTAssertEqual(message.type, "convert-response")
            XCTAssertEqual(message.identifier, "test-identifier-response")
            
            let renderNodes = try JSONDecoder().decode(
                ConvertResponse.self, from: XCTUnwrap(message.payload)).renderNodes
            
            let data = try XCTUnwrap(renderNodes.first)
            let renderNode = try JSONDecoder().decode(RenderNode.self, from: data)

            XCTAssertTrue(renderNode.metadata.hasNoExpandedDocumentation)
        }
    }
    
    func testConvertsSymbolPageThatHasDoesNotHaveExpandedDocumentation() throws {
        let symbolGraphFile = Bundle.module.url(
            forResource: "mykit-one-symbol",
            withExtension: "symbols.json",
            subdirectory: "Test Resources"
        )!
        
        let symbolGraph = try Data(contentsOf: symbolGraphFile)
        
        let request = ConvertRequest(
            bundleInfo: testBundleInfo,
            externalIDsToConvert: ["s:5MyKit0A5ClassC10myFunctionyyF"],
            documentPathsToConvert: [],
            symbolGraphs: [symbolGraph],
            markupFiles: [],
            miscResourceURLs: [],
            symbolIdentifiersWithExpandedDocumentation: [:]
        )
        
        try processAndAssert(request: request) { message in
            XCTAssertEqual(message.type, "convert-response")
            XCTAssertEqual(message.identifier, "test-identifier-response")
            
            let renderNodes = try JSONDecoder().decode(
                ConvertResponse.self, from: XCTUnwrap(message.payload)).renderNodes
            
            let data = try XCTUnwrap(renderNodes.first)
            let renderNode = try JSONDecoder().decode(RenderNode.self, from: data)

            XCTAssert(renderNode.metadata.hasNoExpandedDocumentation)
        }
    }
    
    func testConvertsSymbolPageForRequestThatDoesNotSpecifyExpandedDocumentation() throws {
        let symbolGraphFile = Bundle.module.url(
            forResource: "mykit-one-symbol",
            withExtension: "symbols.json",
            subdirectory: "Test Resources"
        )!
        
        let symbolGraph = try Data(contentsOf: symbolGraphFile)
        
        let request = ConvertRequest(
            bundleInfo: testBundleInfo,
            externalIDsToConvert: ["s:5MyKit0A5ClassC10myFunctionyyF"],
            documentPathsToConvert: [],
            symbolGraphs: [symbolGraph],
            markupFiles: [],
            miscResourceURLs: [],
            symbolIdentifiersWithExpandedDocumentation: nil
        )
        
        try processAndAssert(request: request) { message in
            XCTAssertEqual(message.type, "convert-response")
            XCTAssertEqual(message.identifier, "test-identifier-response")
            
            let renderNodes = try JSONDecoder().decode(
                ConvertResponse.self, from: XCTUnwrap(message.payload)).renderNodes
            
            let data = try XCTUnwrap(renderNodes.first)
            let renderNode = try JSONDecoder().decode(RenderNode.self, from: data)

            XCTAssertFalse(renderNode.metadata.hasNoExpandedDocumentation)
        }
    }
    
    func testConvertSingleArticlePage() throws {
        let articleFile = Bundle.module.url(
            forResource: "StandaloneArticle",
            withExtension: "md",
            subdirectory: "Test Resources"
        )!
        
        let article = try Data(contentsOf: articleFile)
        
        let request = ConvertRequest(
            bundleInfo: testBundleInfo,
            externalIDsToConvert: nil,
            documentPathsToConvert: nil,
            symbolGraphs: [],
            knownDisambiguatedSymbolPathComponents: nil,
            markupFiles: [article],
            miscResourceURLs: []
        )
        
        try processAndAssert(request: request) { message in
            XCTAssertEqual(message.type, "convert-response")
            XCTAssertEqual(message.identifier, "test-identifier-response")
            
            let response = try JSONDecoder().decode(
                ConvertResponse.self, from: XCTUnwrap(message.payload)
            )
            
            XCTAssertEqual(response.renderNodes.count, 1)
            let data = try XCTUnwrap(response.renderNodes.first)
            let renderNode = try JSONDecoder().decode(RenderNode.self, from: data)
            
            XCTAssertEqual(
                renderNode.metadata.externalID,
                nil
            )
            
            XCTAssertEqual(renderNode.kind, .article)
            
            XCTAssertEqual(renderNode.abstract?.count, 1)
            
            XCTAssertEqual(
                renderNode.abstract?.first,
                .text("An article abstract.")
            )
        }
    }

    func testConvertTutorialWithCode() throws {
        let tutorialContent = """
        @Tutorial(time: 99) {
            @Intro(title: "Tutorial Title") {
                Tutorial intro.
            }
            @Section(title: "Section title") {
                This section has one step with a code file reference.
                
                @Steps {
                    @Step {
                        Start with this
                        
                        @Code(name: "Something.swift", file: before.swift)
                    }
        
                    @Step {
                        Add this
                        
                        @Code(name: "Something.swift", file: after.swift)
                    }
                }
            }
        }
        """
        
        let tempURL = try createTempFolder(content: [
            Folder(name: "TutorialWithCodeTest.docc", content: [
                TextFile(name: "Something.tutorial", utf8Content: tutorialContent),
                
                TextFile(name: "before.swift", utf8Content: """
                    // This is an example swift file
                    """),
                TextFile(name: "after.swift", utf8Content: """
                    // This is an example swift file
                    let something = 0
                    """),
            ])
        ])
        let catalog = tempURL.appendingPathComponent("TutorialWithCodeTest.docc")
        
        let request = ConvertRequest(
            bundleInfo: testBundleInfo,
            externalIDsToConvert: nil,
            documentPathsToConvert: nil,
            bundleLocation: nil,
            symbolGraphs: [],
            knownDisambiguatedSymbolPathComponents: nil,
            markupFiles: [],
            tutorialFiles: [tutorialContent.data(using: .utf8)!],
            miscResourceURLs: []
        )
        
        let server = DocumentationServer()
        
        let mockLinkResolvingService = LinkResolvingService { message in
            XCTAssertEqual(message.type, "resolve-reference")
            XCTAssert(message.identifier.hasPrefix("SwiftDocC"))
            do {
                let payload = try XCTUnwrap(message.payload)
                let request = try JSONDecoder()
                    .decode(
                        ConvertRequestContextWrapper<OutOfProcessReferenceResolver.Request>.self,
                        from: payload
                    )
                
                XCTAssertEqual(request.convertRequestIdentifier, "test-identifier")
                
                switch request.payload {
                case .topic(let url):
                    XCTFail("Unexpected topic request: \(url.absoluteString.singleQuoted)")
                    // Fail to resolve every topic
                    return DocumentationServer.Message(
                        type: "resolve-reference-response",
                        payload: try JSONEncoder().encode(
                            OutOfProcessReferenceResolver.Response.errorMessage("Unexpected topic request")
                        )
                    )
                    
                case .symbol(let preciseIdentifier):
                    XCTFail("Unexpected symbol request: \(preciseIdentifier)")
                    // Fail to resolve every symbol
                    return DocumentationServer.Message(
                        type: "resolve-reference-response",
                        payload: try JSONEncoder().encode(
                            OutOfProcessReferenceResolver.Response.errorMessage("Unexpected symbol request")
                        )
                    )
                    
                case .asset(let assetReference):
                    switch (assetReference.assetName, assetReference.bundleIdentifier) {
                    case (let assetName, "identifier") where ["before.swift", "after.swift"].contains(assetName):
                        var asset = DataAsset()
                        asset.register(
                            catalog.appendingPathComponent(assetName),
                            with: DataTraitCollection()
                        )
                        
                        return DocumentationServer.Message(
                            type: "resolve-reference-response",
                            payload: try JSONEncoder().encode(
                                OutOfProcessReferenceResolver.Response
                                    .asset(asset)
                            )
                        )

                    default:
                        XCTFail("Unexpected asset request: \(assetReference.assetName)")
                        // Fail to resolve all other assets
                        return DocumentationServer.Message(
                            type: "resolve-reference-response",
                            payload: try JSONEncoder().encode(
                                OutOfProcessReferenceResolver.Response.errorMessage("Unexpected topic request")
                            )
                        )
                    }
                }
            } catch {
                XCTFail(error.localizedDescription)
                return nil
            }
        }
        
        server.register(service: mockLinkResolvingService)
        
        try processAndAssert(request: request, linkResolvingServer: server) { message in
            XCTAssertEqual(message.type, "convert-response")
            XCTAssertEqual(message.identifier, "test-identifier-response")
            
            let response = try JSONDecoder().decode(
                ConvertResponse.self, from: XCTUnwrap(message.payload)
            )
            
            XCTAssertEqual(response.renderNodes.count, 1)
            let data = try XCTUnwrap(response.renderNodes.first)
            let renderNode = try JSONDecoder().decode(RenderNode.self, from: data)
            
            let beforeIdentifier = RenderReferenceIdentifier("before.swift")
            let afterIdentifier = RenderReferenceIdentifier("after.swift")
            
            XCTAssertEqual(
                renderNode.references["before.swift"] as? FileReference,
                FileReference(identifier: beforeIdentifier, fileName: "Something.swift", fileType: "swift", syntax: "swift", content: [
                    "// This is an example swift file",
                ], highlights: [])
            )
            XCTAssertEqual(
                renderNode.references["after.swift"] as? FileReference,
                FileReference(identifier: afterIdentifier, fileName: "Something.swift", fileType: "swift", syntax: "swift", content: [
                    "// This is an example swift file",
                    "let something = 0",
                ], highlights: [.init(line: 2)])
            )
            
            let stepsSection = try XCTUnwrap(renderNode.sections.compactMap { $0 as? TutorialSectionsRenderSection }.first?.tasks.first?.stepsSection)
            XCTAssertEqual(stepsSection.count, 2)
            if case .step(let step) = stepsSection.first {
                XCTAssertEqual(step.code, beforeIdentifier)
            } else {
                XCTFail("Unexpected kind of step")
            }
            
            if case .step(let step) = stepsSection.last {
                XCTAssertEqual(step.code, afterIdentifier)
            } else {
                XCTFail("Unexpected kind of step")
            }
        }
    }
    
    func testConvertArticleWithImageReferencesAndDetailedGridLinks() throws {
        let articleData = try XCTUnwrap("""
            # First article
            
            Link to another article which has page images.
            
            @Links(visualStyle: detailedGrid) {
                - <doc:Second-article>
            }
            
            @Metadata {
                @PageImage(purpose: card, source: "first-page-card-image")
                @PageImage(purpose: icon, source: "first-page-icon-image")
            }
            
            ![A markdown image](first-page-markdown-image)
            
            @Image(source: "first-page-directive-image", alt: "A directive image")
            """.data(using: .utf8))
        
        let request = ConvertRequest(
            bundleInfo: testBundleInfo,
            externalIDsToConvert: nil,
            documentPathsToConvert: nil,
            symbolGraphs: [],
            knownDisambiguatedSymbolPathComponents: nil,
            markupFiles: [articleData],
            miscResourceURLs: []
        )
        
        let server = DocumentationServer()
        
        let expectedAssetNames = [
            "second-page-card-image",
            "second-page-icon-image",
            "first-page-card-image",
            "first-page-icon-image",
            "first-page-markdown-image",
            "first-page-directive-image",
        ]
        
        let mockLinkResolvingService = LinkResolvingService { message in
            XCTAssertEqual(message.type, "resolve-reference")
            XCTAssert(message.identifier.hasPrefix("SwiftDocC"))
            do {
                let payload = try XCTUnwrap(message.payload)
                let request = try JSONDecoder()
                    .decode(
                        ConvertRequestContextWrapper<OutOfProcessReferenceResolver.Request>.self,
                        from: payload
                    )
                
                XCTAssertEqual(request.convertRequestIdentifier, "test-identifier")
                
                switch request.payload {
                case .topic(let url):
                    guard url.absoluteString == "doc://identifier/Second-article" else {
                        XCTFail("Unexpected topic request: \(url.absoluteString.singleQuoted)")
                        return nil
                    }
                    
                    let testSymbolInformationResponse = OutOfProcessReferenceResolver
                        .ResolvedInformation(
                            kind: .article,
                            url: url,
                            title: "Second article",
                            abstract: "An article with page image metadata.",
                            language: .swift,
                            availableLanguages: [.swift, .objectiveC],
                            platforms: [],
                            declarationFragments: nil,
                            topicImages: [
                                .init(pageImagePurpose: .card, identifier: RenderReferenceIdentifier("second-page-card-image")),
                                .init(pageImagePurpose: .icon, identifier: RenderReferenceIdentifier("second-page-icon-image")),
                            ],
                            references: nil
                        )
                    
                    let payloadData = OutOfProcessReferenceResolver.Response
                        .resolvedInformation(testSymbolInformationResponse)
                    
                    return DocumentationServer.Message(
                        type: "resolve-reference-response",
                        payload: try JSONEncoder().encode(payloadData)
                    )
                    
                case .symbol(let preciseIdentifier):
                    XCTFail("Unexpected symbol request: \(preciseIdentifier)")
                    return nil
                    
                case .asset(let assetReference):
                    switch (assetReference.assetName, assetReference.bundleIdentifier) {
                    case (let assetName, "identifier") where expectedAssetNames.contains(assetName):
                        var asset = DataAsset()
                        asset.register(
                            URL(string: "docs-media:///path/to/\(assetName).png")!,
                            with: DataTraitCollection(
                                userInterfaceStyle: .light,
                                displayScale: .double
                            )
                        )
                        
                        return DocumentationServer.Message(
                            type: "resolve-reference-response",
                            payload: try JSONEncoder().encode(
                                OutOfProcessReferenceResolver.Response
                                    .asset(asset)
                            )
                        )

                    default:
                        XCTFail("Unexpected asset resolution request for '\(assetReference)'")
                        return nil
                    }
                }
            } catch {
                XCTFail(error.localizedDescription)
                return nil
            }
        }
        
        server.register(service: mockLinkResolvingService)
        
        try processAndAssert(request: request, linkResolvingServer: server) { message in
            XCTAssertEqual(message.type, "convert-response")
            XCTAssertEqual(message.identifier, "test-identifier-response")
            
            let response = try JSONDecoder().decode(
                ConvertResponse.self, from: XCTUnwrap(message.payload)
            )
            
            XCTAssertEqual(response.renderNodes.count, 1)
            let data = try XCTUnwrap(response.renderNodes.first)
            let renderNode = try JSONDecoder().decode(RenderNode.self, from: data)
            
            XCTAssertEqual(
                renderNode.metadata.externalID,
                nil
            )
            
            XCTAssertEqual(renderNode.kind, .article)
            
            XCTAssertEqual(renderNode.abstract?.count, 1)
            
            XCTAssertEqual(
                renderNode.abstract?.first,
                .text("Link to another article which has page images.")
            )
            
            XCTAssertEqual(
                renderNode.metadata.images.map(\.identifier.identifier).sorted(),
                ["first-page-card-image", "first-page-icon-image"]
            )
            
            XCTAssertEqual(
                renderNode.references.keys.sorted(),
                (["doc://identifier/Second-article"] + expectedAssetNames).sorted()
            )
            
            let articleReference = try XCTUnwrap(renderNode.references["doc://identifier/Second-article"] as? TopicRenderReference)
            XCTAssertEqual(articleReference.title, "Second article")
            XCTAssertEqual(articleReference.abstract.plainText, "An article with page image metadata.")
            XCTAssertEqual(articleReference.images.sorted(by: \.identifier.identifier), [
                TopicImage(type: .card, identifier: RenderReferenceIdentifier("second-page-card-image")),
                TopicImage(type: .icon, identifier: RenderReferenceIdentifier("second-page-icon-image")),
            ])
            
            let firstCardImageReference = try XCTUnwrap(renderNode.references["first-page-card-image"] as? ImageReference)
            XCTAssertEqual(firstCardImageReference.asset, DataAsset(
                variants: [
                    DataTraitCollection(userInterfaceStyle: .light, displayScale: .double): URL(string: "docs-media:///path/to/first-page-card-image.png")!,
                ],
                metadata: [
                    URL(string: "docs-media:///path/to/first-page-card-image.png")!: DataAsset.Metadata(svgID: nil),
                ],
                context: .display
            ))
            
            let firstIconImageReference = try XCTUnwrap(renderNode.references["first-page-icon-image"] as? ImageReference)
            XCTAssertEqual(firstIconImageReference.asset, DataAsset(
                variants: [
                    DataTraitCollection(userInterfaceStyle: .light, displayScale: .double): URL(string: "docs-media:///path/to/first-page-icon-image.png")!,
                ],
                metadata: [
                    URL(string: "docs-media:///path/to/first-page-icon-image.png")!: DataAsset.Metadata(svgID: nil),
                ],
                context: .display
            ))
            
            let secondCardImageReference = try XCTUnwrap(renderNode.references["second-page-card-image"] as? ImageReference)
            XCTAssertEqual(secondCardImageReference.asset, DataAsset(
                variants: [
                    DataTraitCollection(userInterfaceStyle: .light, displayScale: .double): URL(string: "docs-media:///path/to/second-page-card-image.png")!,
                ],
                metadata: [
                    URL(string: "docs-media:///path/to/second-page-card-image.png")!: DataAsset.Metadata(svgID: nil),
                ],
                context: .display
            ))
            
            let secondIconImageReference = try XCTUnwrap(renderNode.references["second-page-icon-image"] as? ImageReference)
            XCTAssertEqual(secondIconImageReference.asset, DataAsset(
                variants: [
                    DataTraitCollection(userInterfaceStyle: .light, displayScale: .double): URL(string: "docs-media:///path/to/second-page-icon-image.png")!,
                ],
                metadata: [
                    URL(string: "docs-media:///path/to/second-page-icon-image.png")!: DataAsset.Metadata(svgID: nil),
                ],
                context: .display
            ))
            
            let firstMarkdownImageReference = try XCTUnwrap(renderNode.references["first-page-markdown-image"] as? ImageReference)
            XCTAssertEqual(firstMarkdownImageReference.asset, DataAsset(
                variants: [
                    DataTraitCollection(userInterfaceStyle: .light, displayScale: .double): URL(string: "docs-media:///path/to/first-page-markdown-image.png")!,
                ],
                metadata: [
                    URL(string: "docs-media:///path/to/first-page-markdown-image.png")!: DataAsset.Metadata(svgID: nil),
                ],
                context: .display
            ))
            XCTAssertEqual(firstMarkdownImageReference.altText, "A markdown image")
            
            let firstDirectiveImageReference = try XCTUnwrap(renderNode.references["first-page-directive-image"] as? ImageReference)
            XCTAssertEqual(firstDirectiveImageReference.asset, DataAsset(
                variants: [
                    DataTraitCollection(userInterfaceStyle: .light, displayScale: .double): URL(string: "docs-media:///path/to/first-page-directive-image.png")!,
                ],
                metadata: [
                    URL(string: "docs-media:///path/to/first-page-directive-image.png")!: DataAsset.Metadata(svgID: nil),
                ],
                context: .display
            ))
            XCTAssertEqual(firstDirectiveImageReference.altText, "A directive image")
        }
    }
    
    func testConvertSingleTutorial() throws {
        let tutorialFile = Bundle.module.url(
            forResource: "StandaloneTutorial",
            withExtension: "tutorial",
            subdirectory: "Test Resources"
        )!
        
        let tutorial = try Data(contentsOf: tutorialFile)
        
        let request = ConvertRequest(
            bundleInfo: testBundleInfo,
            externalIDsToConvert: nil,
            documentPathsToConvert: nil,
            symbolGraphs: [],
            knownDisambiguatedSymbolPathComponents: nil,
            markupFiles: [],
            tutorialFiles: [tutorial],
            miscResourceURLs: []
        )
        
        try processAndAssert(request: request) { message in
            XCTAssertEqual(message.type, "convert-response")
            XCTAssertEqual(message.identifier, "test-identifier-response")
            
            let response = try JSONDecoder().decode(
                ConvertResponse.self, from: XCTUnwrap(message.payload)
            )
            
            XCTAssertEqual(response.renderNodes.count, 1)
            let data = try XCTUnwrap(response.renderNodes.first)
            let renderNode = try JSONDecoder().decode(RenderNode.self, from: data)
            
            XCTAssertEqual(
                renderNode.metadata.externalID,
                nil
            )
            
            XCTAssertEqual(renderNode.kind, .tutorial)
            
            XCTAssertEqual(
                renderNode.metadata.title,
                "Standalone Tutorial"
            )
        }
    }
    
    func testConvertSingleTutorialOverview() throws {
        let tutorialOverviewFile = Bundle.module.url(
            forResource: "StandaloneTutorialOverview",
            withExtension: "tutorial",
            subdirectory: "Test Resources"
        )!
        
        let tutorialOverview = try Data(contentsOf: tutorialOverviewFile)
        
        let request = ConvertRequest(
            bundleInfo: testBundleInfo,
            externalIDsToConvert: nil,
            documentPathsToConvert: nil,
            symbolGraphs: [],
            knownDisambiguatedSymbolPathComponents: nil,
            markupFiles: [],
            tutorialFiles: [tutorialOverview],
            miscResourceURLs: []
        )
        
        try processAndAssert(request: request) { message in
            XCTAssertEqual(message.type, "convert-response")
            XCTAssertEqual(message.identifier, "test-identifier-response")
            
            let response = try JSONDecoder().decode(
                ConvertResponse.self, from: XCTUnwrap(message.payload)
            )
            
            XCTAssertEqual(response.renderNodes.count, 1)
            let data = try XCTUnwrap(response.renderNodes.first)
            let renderNode = try JSONDecoder().decode(RenderNode.self, from: data)
            
            XCTAssertEqual(
                renderNode.metadata.externalID,
                nil
            )
            
            XCTAssertEqual(renderNode.kind, .overview)
            
            XCTAssertEqual(
                renderNode.metadata.title,
                "Standalone Tutorial Overview"
            )
        }
    }
    
    func processAndAssertResponseContents(
        expectedRenderNodePaths: [String],
        includesRenderReferenceStore: Bool,
        for convertRequest: ConvertRequest,
        assert: (([RenderNode], RenderReferenceStore?) throws -> ())? = nil
    ) throws {
        try processAndAssert(request: convertRequest) { message in
            let response = try JSONDecoder().decode(
                ConvertResponse.self, from: XCTUnwrap(message.payload))
            
            XCTAssertEqual(response.renderReferenceStore != nil, includesRenderReferenceStore)
            
            let renderNodes = try response.renderNodes.map {
                try JSONDecoder().decode(RenderNode.self, from: $0)
            }
            
            let identifiers = Set(renderNodes.map(\.identifier.path))

            XCTAssertEqual(identifiers, Set(expectedRenderNodePaths))
            
            let renderReferenceStore = try response.renderReferenceStore.map {
                try JSONDecoder().decode(RenderReferenceStore.self, from: $0)
            }
            
            try assert?(renderNodes, renderReferenceStore)
        }
    }
    
    func testConvertAllPagesForInMemoryContent() throws {
        let symbolGraphFile = Bundle.module.url(
            forResource: "mykit-one-symbol",
            withExtension: "symbols.json",
            subdirectory: "Test Resources"
        )!
        
        let symbolGraph = try Data(contentsOf: symbolGraphFile)
        
        let request = ConvertRequest(
            bundleInfo: testBundleInfo,
            externalIDsToConvert: nil,
            documentPathsToConvert: nil,
            symbolGraphs: [symbolGraph],
            markupFiles: [],
            miscResourceURLs: []
        )
        
        try processAndAssertResponseContents(
            expectedRenderNodePaths: [
                "/documentation/MyKit/MyClass/myFunction()", "/documentation/MyKit"],
            includesRenderReferenceStore: false,
            for: request
        )
    }
    
    func testConvertAllPagesForOnDiskContent() throws {
        let testBundleURL = Bundle.module.url(
            forResource: "TestBundle", withExtension: "docc", subdirectory: "Test Bundles")!
                
        let request = ConvertRequest(
            bundleInfo: testBundleInfo,
            externalIDsToConvert: nil,
            documentPathsToConvert: nil,
            bundleLocation: testBundleURL,
            symbolGraphs: [],
            markupFiles: [],
            miscResourceURLs: []
        )
        
        try processAndAssertResponseContents(
            expectedRenderNodePaths: [
                "/documentation/SideKit/UncuratedClass/angle",
                "/documentation/Test-Bundle/article",
                "/tutorials/Test-Bundle/TestTutorial2",
                "/documentation/MyKit/MyClass/init()-33vaw",
                "/tutorials/Test-Bundle/TestTutorial",
                "/documentation/Test-Bundle/Default-Code-Listing-Syntax",
                "/documentation/MyKit/MyClass/init()-3743d",
                "/tutorials/TestOverview",
                "/documentation/MyKit/MyClass",
                "/documentation/MyKit/MyProtocol",
                "/documentation/SideKit/SideClass/init()",
                "/documentation/SideKit/SideClass/Element/inherited()",
                "/documentation/SideKit/UncuratedClass",
                "/documentation/Test-Bundle/article2",
                "/documentation/SideKit/SideClass/Element/Protocol-Implementations",
                "/documentation/FillIntroduced/iOSMacOSOnly()",
                "/documentation/Test-Bundle/article3",
                "/documentation/SideKit/SideClass/Element",
                "/documentation/FillIntroduced",
                "/documentation/FillIntroduced/macOSOnlyIntroduced()",
                "/tutorials/Test-Bundle/TutorialMediaWithSpaces",
                "/documentation/SideKit/SideClass/url",
                "/documentation/SideKit/SideClass/path",
                "/documentation/FillIntroduced/macOSOnlyDeprecated()",
                "/documentation/SideKit/SideProtocol/func()-2dxqn",
                "/documentation/SideKit/SideClass",
                "/documentation/MyKit/globalFunction(_:considering:)",
                "/tutorials/Test-Bundle/TestTutorialArticle",
                "/documentation/FillIntroduced/iOSOnlyIntroduced()",
                "/documentation/FillIntroduced/iOSOnlyDeprecated()",
                "/documentation/MyKit",
                "/documentation/FillIntroduced/macCatalystOnlyIntroduced()",
                "/documentation/SideKit/SideClass/Value(_:)",
                "/documentation/FillIntroduced/macCatalystOnlyDeprecated()",
                "/documentation/MyKit/MyClass/myFunction()",
                "/documentation/SideKit",
                "/documentation/SideKit/SideProtocol/func()-6ijsi",
                "/documentation/SideKit/SideClass/myFunction()",
                "/documentation/SideKit/SideProtocol",
            ],
            includesRenderReferenceStore: false,
            for: request
        )
    }
    
    func testConvertSomeSymbolsAndSomeArticlesForOnDiskContent() throws {
        let testBundleURL = Bundle.module.url(
            forResource: "TestBundle", withExtension: "docc", subdirectory: "Test Bundles")!
                
        let request = ConvertRequest(
            bundleInfo: testBundleInfo,
            externalIDsToConvert: ["s:5MyKit0A5ClassC10myFunctionyyF"],
            documentPathsToConvert: ["/documentation/Test-Bundle/article"],
            bundleLocation: testBundleURL,
            symbolGraphs: [],
            markupFiles: [],
            miscResourceURLs: []
        )
        
        try processAndAssertResponseContents(
            expectedRenderNodePaths: [
                "/documentation/Test-Bundle/article",
                "/documentation/MyKit/MyClass/myFunction()",
            ],
            includesRenderReferenceStore: false,
            for: request
        )
    }
    
    func testConvertNoSymbolsAndNoArticlesForOnDiskContent() throws {
        let testBundleURL = Bundle.module.url(
            forResource: "TestBundle", withExtension: "docc", subdirectory: "Test Bundles")!
                
        let request = ConvertRequest(
            bundleInfo: testBundleInfo,
            externalIDsToConvert: [],
            documentPathsToConvert: [],
            bundleLocation: testBundleURL,
            symbolGraphs: [],
            markupFiles: [],
            miscResourceURLs: []
        )
        
        try processAndAssertResponseContents(
            expectedRenderNodePaths: [],
            includesRenderReferenceStore: false,
            for: request
        )
    }
    
    func testReturnsRenderReferenceStoreWhenRequestedForOnDiskBundleWithUncuratedArticles() throws {
        #if os(Linux)
        throw XCTSkip("""
        Skipped on Linux due to an issue in Foundation.Codable where dictionaries are sometimes getting encoded as \
        arrays. (github.com/apple/swift/issues/57363)
        """)
        #else
        let (testBundleURL, _, _) = try testBundleAndContext(
            copying: "TestBundle",
            excludingPaths: [
                "sidekit.symbols.json",
                "mykit-iOS.symbols.json",
                "MyKit@SideKit.symbols.json",
                "FillIntroduced.symbols.json",
            ]
        )
        
        let request = ConvertRequest(
            bundleInfo: testBundleInfo,
            externalIDsToConvert: [],
            documentPathsToConvert: [],
            includeRenderReferenceStore: true,
            bundleLocation: testBundleURL,
            symbolGraphs: [],
            markupFiles: [],
            miscResourceURLs: []
        )
        
        try processAndAssertResponseContents(
            expectedRenderNodePaths: [],
            includesRenderReferenceStore: true,
            for: request,
            assert: { renderNodes, referenceStore in
                let referenceStore = try XCTUnwrap(referenceStore)
                
                // The ConvertService relies on old implementation detail where documentation extension files were always considered "resolved" even when they didn't match a symbol. (rdar://108563483)
                // https://github.com/swiftlang/swift-docc/issues/567
                
                XCTAssertEqual(
                    Set(referenceStore.topics.keys.map(\.path)),
                    [
                        // Documentation extension files:
                        "/documentation/MyKit",
                        "/documentation/SideKit",
                        "/documentation/MyKit/MyClass",
                        "/documentation/MyKit/MyProtocol",
                        "/documentation/SideKit/SideClass/init()",
                        
                        // Articles and tutorials:
                        "/tutorials/TestOverview",
                        "/tutorials/TestOverview/$volume",
                        "/tutorials/TestOverview/Chapter-1",
                        "/documentation/Test-Bundle/article",
                        "/documentation/Test-Bundle/article2",
                        "/documentation/Test-Bundle/article3",
                        "/tutorials/Test-Bundle/TestTutorial",
                        "/tutorials/Test-Bundle/TestTutorial2",
                        "/tutorials/Test-Bundle/TestTutorialArticle",
                        "/tutorials/Test-Bundle/TutorialMediaWithSpaces",
                        "/documentation/Test-Bundle/Default-Code-Listing-Syntax",
                    ]
                )
                try self.assertReferenceStoreContains(
                    referenceStore: referenceStore,
                    topicPath: "/documentation/MyKit/MyClass",
                    source: testBundleURL.appendingPathComponent("documentation/myclass.md"),
                    title: "doc:MyKit/MyClass",
                    isDocumentationExtensionContent: true
                )
                
                try self.assertReferenceStoreContains(
                    referenceStore: referenceStore,
                    topicPath: "/documentation/Test-Bundle/article",
                    source: testBundleURL.appendingPathComponent("article.md"),
                    title: "My Cool Article",
                    isDocumentationExtensionContent: false
                )
            
                let actualAssets = (try XCTUnwrap(referenceStore).assets.map {
                    (
                        $0.assetName,
                        try XCTUnwrap(
                            $1.variants.map(\.value)
                                .sorted(by: { $0.absoluteString < $1.absoluteString })
                        )
                    )
                }).sorted(by: { $0.0 < $1.0 })
                
                func testImages(_ paths: String...) -> [URL] {
                    paths.map(testBundleURL.resolvingSymlinksInPath().appendingPathComponent)
                }
                
                let expectedAssets = [
                    ("step.png", testImages("step.png")),
                    ("intro.png", testImages("intro.png")),
                    ("Info.plist", testImages("Info.plist")),
                    ("project.zip", testImages("project.zip")),
                    ("titled2up.png", testImages("titled2up.png")),
                    ("figure1.jpg", testImages("images/figure1.jpg")),
                    ("something.png", testImages("something@2x.png")),
                    ("introposter.png", testImages("introposter.png")),
                    ("with spaces.mp4", testImages("with spaces.mp4")),
                    ("helloworld.swift", testImages("helloworld.swift")),
                    ("introposter2.png", testImages("introposter2.png")),
                    ("helloworld1.swift", testImages("helloworld1.swift")),
                    ("helloworld2.swift", testImages("helloworld2.swift")),
                    ("helloworld3.swift", testImages("helloworld3.swift")),
                    ("helloworld4.swift", testImages("helloworld4.swift")),
                    ("titled2upCapital.PNG", testImages("titled2upCapital.PNG")),
                    ("figure1.png", testImages("figure1.png", "figure1~dark.png")),
                    ("introvideo.mp4", testImages("introvideo.mp4", "introvideo~dark.mp4")),
                    ("with spaces.png", testImages("with spaces.png", "with spaces@2x.png")),
                ].sorted(by: { $0.0 < $1.0 })
                
                XCTAssertEqual(actualAssets.count, expectedAssets.count)
                
                for (actual, expected) in zip(actualAssets, expectedAssets) {
                    XCTAssert(
                        actual.0 == expected.0
                            && actual.1.map { $0.resolvingSymlinksInPath() }
                                == expected.1.map { $0.resolvingSymlinksInPath() },
                        "\(actual) is not equal to \(expected)"
                    )
                }
            }
        )
        #endif
    }
    
    func testNoRenderReferencesToNonLinkableNodes() throws {
        #if os(Linux)
        throw XCTSkip("""
        Skipped on Linux due to an issue in Foundation.Codable where dictionaries are sometimes getting encoded as \
        arrays. (github.com/apple/swift/issues/57363)
        """)
        #else
        let (testBundleURL, _, _) = try testBundleAndContext(
            copying: "TestBundle",
            excludingPaths: [
                "mykit-iOS.symbols.json",
                "MyKit@SideKit.symbols.json",
                "FillIntroduced.symbols.json",
            ]
        )
        
        let request = ConvertRequest(
            bundleInfo: testBundleInfo,
            externalIDsToConvert: [],
            documentPathsToConvert: [],
            includeRenderReferenceStore: true,
            bundleLocation: testBundleURL,
            symbolGraphs: [],
            markupFiles: [],
            miscResourceURLs: []
        )
        
        try processAndAssertResponseContents(
            expectedRenderNodePaths: [],
            includesRenderReferenceStore: true,
            for: request,
            assert: { renderNodes, referenceStore in
                let referenceStore = try XCTUnwrap(referenceStore)
                let paths = Set(referenceStore.topics.keys.map(\.path))
                XCTAssertTrue(paths.contains("/documentation/SideKit/SideClass/Element"))
                XCTAssertFalse(paths.contains("/documentation/SideKit/SideClass/Element/Protocol-Implementations"))
            }

        )
        #endif
    }
    
    func testReturnsRenderReferenceStoreWhenRequestedForOnDiskBundleWithCuratedArticles() throws {
        #if os(Linux)
        throw XCTSkip("""
        Skipped on Linux due to an issue in Foundation.Codable where dictionaries are sometimes getting encoded as \
        arrays. (github.com/apple/swift/issues/57363)
        """)
        #else
        let (testBundleURL, _, _) = try testBundleAndContext(
            // Use a bundle that contains only articles, one of which is declared as the TechnologyRoot and curates the
            // other articles.
            copying: "BundleWithTechnologyRoot"
        )
        
        let request = ConvertRequest(
            bundleInfo: testBundleInfo,
            externalIDsToConvert: [],
            documentPathsToConvert: [],
            includeRenderReferenceStore: true,
            bundleLocation: testBundleURL,
            symbolGraphs: [],
            markupFiles: [],
            miscResourceURLs: []
        )
        
        try processAndAssertResponseContents(
            expectedRenderNodePaths: [],
            includesRenderReferenceStore: true,
            for: request,
            assert: { renderNodes, referenceStore in
                let referenceStore = try XCTUnwrap(referenceStore)
                
                XCTAssertEqual(
                    Set(referenceStore.topics.keys.map(\.path)),
                    [
                        // Articles:
                        "/documentation/TechnologyX",
                        "/documentation/TechnologyX/article",
                    ]
                )
            
                try self.assertReferenceStoreContains(
                    referenceStore: referenceStore,
                    topicPath: "/documentation/TechnologyX",
                    source: testBundleURL.appendingPathComponent("TechnologyX.md"),
                    title: "TechnologyX",
                    isDocumentationExtensionContent: false
                )
                
                try self.assertReferenceStoreContains(
                    referenceStore: referenceStore,
                    topicPath: "/documentation/TechnologyX/article",
                    source: testBundleURL.appendingPathComponent("article.md"),
                    title: "My Article",
                    isDocumentationExtensionContent: false
                )
            }
        )
        #endif
    }
    
    func testConvertPageWithLinkResolving() throws {
        let symbolGraphFile = Bundle.module.url(
            forResource: "mykit-one-symbol",
            withExtension: "symbols.json",
            subdirectory: "Test Resources"
        )!
        
        let symbolGraph = try Data(contentsOf: symbolGraphFile)
        
        let request = ConvertRequest(
            bundleInfo: DocumentationBundle.Info(
                displayName: "TestBundle",
                identifier: "com.test.bundle",
                version: "1.0.0"
            ),
            externalIDsToConvert: ["s:5MyKit0A5ClassC10myFunctionyyF"],
            documentPathsToConvert: [],
            symbolGraphs: [symbolGraph],
            markupFiles: [],
            miscResourceURLs: []
        )
        
        let server = DocumentationServer()
        
        let mockLinkResolvingService = LinkResolvingService { message in
            XCTAssertEqual(message.type, "resolve-reference")
            XCTAssert(message.identifier.hasPrefix("SwiftDocC"))
            do {
                let payload = try XCTUnwrap(message.payload)
                let request = try JSONDecoder()
                    .decode(
                        ConvertRequestContextWrapper<OutOfProcessReferenceResolver.Request>.self,
                        from: payload
                    )
                
                XCTAssertEqual(request.convertRequestIdentifier, "test-identifier")
                
                switch request.payload {
                case .topic(let url):
                    let unresolvableURLs = [
                        "doc://com.test.bundle/MyClass",
                        "doc://com.test.bundle/documentation/MyKit/MyClass/myFunction()/MyClass",
                        "doc://com.test.bundle/documentation/MyKit/MyClass/MyClass",
                        "doc://com.test.bundle/documentation/MyKit/MyClass",
                        
                        "doc://com.test.bundle/ChildOfMyClass",
                        "doc://com.test.bundle/MyClass/ChildOfMyClass",
                        "doc://com.test.bundle/tutorials/ChildOfMyClass",
                        "doc://com.test.bundle/documentation/ChildOfMyClass",
                        "doc://com.test.bundle/documentation/MyKit/ChildOfMyClass",
                        "doc://com.test.bundle/tutorials/TestBundle/ChildOfMyClass",
                        "doc://com.test.bundle/documentation/TestBundle/ChildOfMyClass",
                        "doc://com.test.bundle/documentation/MyKit/MyClass/ChildOfMyClass",
                        "doc://com.test.bundle/documentation/MyKit/MyClass/myFunction()/ChildOfMyClass",
                        
                        "doc://com.test.bundle/ViewBuilder",
                        "doc://com.test.bundle/documentation/MyKit/MyClass/myFunction()/ViewBuilder",
                        "doc://com.test.bundle/documentation/MyKit/MyClass/ViewBuilder",
                        "doc://com.test.bundle/documentation/MyKit/ViewBuilder",
                        "doc://com.test.bundle/documentation/ViewBuilder",
                    ].map { URL(string: $0)! }
                    
                    let resolvableMyClassURL = URL(
                        string: "doc://com.test.bundle/documentation/MyKit/MyClass")!
                    
                    let resolvableOtherFunctionURL = URL(
                        string: "doc://com.test.bundle/MyKit/MyClass/myOtherFunction()")!
                    
                    if url == resolvableMyClassURL {
                        let testSymbolInformationResponse = OutOfProcessReferenceResolver
                            .ResolvedInformation(
                                kind: .init(
                                    name: "Class",
                                    id: "org.swift.docc.kind.class",
                                    isSymbol: true
                                ),
                                url: resolvableMyClassURL,
                                title: "MyClass Title",
                                abstract: "",
                                language: .init(name: "Swift", id: "swift"),
                                availableLanguages: [],
                                platforms: [],
                                declarationFragments: nil,
                                topicImages: nil,
                                references: nil
                            )
                        
                        let payloadData = OutOfProcessReferenceResolver.Response
                            .resolvedInformation(testSymbolInformationResponse)
                        
                        return DocumentationServer.Message(
                            type: "resolve-reference-response",
                            payload: try JSONEncoder().encode(payloadData)
                        )
                    } else if url == resolvableOtherFunctionURL {
                        let testSymbolInformationResponse = OutOfProcessReferenceResolver
                            .ResolvedInformation(
                                kind: .init(
                                    name: "Function",
                                    id: "org.swift.docc.kind.function",
                                    isSymbol: true
                                ),
                                url: resolvableOtherFunctionURL,
                                title: "myOtherFunction Title",
                                abstract: "",
                                language: .init(name: "Swift", id: "swift"),
                                availableLanguages: [],
                                platforms: [],
                                declarationFragments: nil,
                                topicImages: nil,
                                references: nil
                            )
                        
                        let payloadData = OutOfProcessReferenceResolver.Response
                            .resolvedInformation(testSymbolInformationResponse)
                        
                        return DocumentationServer.Message(
                            type: "resolve-reference-response",
                            payload: try JSONEncoder().encode(payloadData)
                        )
                    } else if unresolvableURLs.contains(url) {
                        let payloadData = OutOfProcessReferenceResolver.Response
                                .errorMessage("Unable to resolve reference.")
                        
                        return DocumentationServer.Message(
                            type: "resolve-reference-response",
                            payload: try JSONEncoder().encode(payloadData)
                        )
                    } else {
                        XCTFail("Received unexpected request: \(request)")
                        return nil
                    }
                case .symbol(let preciseIdentifier):
                    if ["TestSymbolPreciseIdentifier"].contains(preciseIdentifier) {
                        let symbolInformationResponse = OutOfProcessReferenceResolver
                            .ResolvedInformation(
                                kind: .init(
                                    name: "Class",
                                    id: "org.swift.docc.kind.class",
                                    isSymbol: true
                                ),
                                url: URL(string: "doc://com.test.bundle/MyKit/TestSymbol")!,
                                title: "MyClass Title From Precise Identifier",
                                abstract: "",
                                language: .init(name: "Swift", id: "swift"),
                                availableLanguages: [],
                                platforms: [],
                                declarationFragments: nil,
                                topicImages: nil,
                                references: nil
                            )
                        
                        return DocumentationServer.Message(
                            type: "resolve-reference-response",
                            payload: try JSONEncoder().encode(
                                OutOfProcessReferenceResolver.Response
                                    .resolvedInformation(symbolInformationResponse))
                        )
                    } else {
                        XCTFail("Received unexpected request: \(request)")
                        return nil
                    }
                    
                case .asset(let assetReference):
                    switch (assetReference.assetName, assetReference.bundleIdentifier) {
                    case ("image.png", "com.test.bundle"):
                        var asset = DataAsset()
                        asset.register(
                            URL(string: "docs-media:///path/to/image.png")!,
                            with: DataTraitCollection(
                                userInterfaceStyle: .light,
                                displayScale: .double
                            )
                        )
                        
                        return DocumentationServer.Message(
                            type: "resolve-reference-response",
                            payload: try JSONEncoder().encode(
                                OutOfProcessReferenceResolver.Response
                                    .asset(asset)
                            )
                        )
                    case ("another-image.png", "com.test.bundle"):
                        let payloadData = OutOfProcessReferenceResolver.Response
                                .errorMessage("Unable to resolve asset.")
                        
                        return DocumentationServer.Message(
                            type: "resolve-reference-response",
                            payload: try JSONEncoder().encode(payloadData)
                        )
                    default:
                        XCTFail("Unexpected asset resolution request for '\(assetReference)'")
                        return nil
                    }
                }
            } catch {
                XCTFail(error.localizedDescription)
                return nil
            }
        }
        
        server.register(service: mockLinkResolvingService)
        
        try processAndAssert(request: request, linkResolvingServer: server) { message in
            XCTAssertEqual(message.type, "convert-response")
            XCTAssertEqual(message.identifier, "test-identifier-response")
            
            let renderNodes = try JSONDecoder().decode(
                ConvertResponse.self, from: XCTUnwrap(message.payload)).renderNodes
            
            XCTAssertEqual(renderNodes.count, 1)
            let data = try XCTUnwrap(renderNodes.first)
            let renderNode = try JSONDecoder().decode(RenderNode.self, from: data)

            XCTAssertEqual(
                renderNode.metadata.externalID,
                "s:5MyKit0A5ClassC10myFunctionyyF"
            )
            
            XCTAssertEqual(
                renderNode.abstract?[...10],
                [
                    .reference(
                        identifier: .init("doc://com.test.bundle/documentation/MyKit/MyClass/myFunction()"),
                        isActive: true,
                        overridingTitle: nil,
                        overridingTitleInlineContent: nil
                    ),
                    .text(" is the public API to using the most of "),
                    .codeVoice(code: "ChildOfMyClass"),
                    .text("’s features."),
                    .text(" "),
                    .text("The "),
                    .codeVoice(code: "ViewBuilder"),
                    .text(", "),
                    .reference(
                        identifier: .init("doc://com.test.bundle/documentation/MyKit/MyClass"),
                        isActive: true,
                        overridingTitle: nil,
                        overridingTitleInlineContent: nil
                    ),
                    .text(", and "),
                    .reference(
                        identifier: .init("doc://com.test.bundle/MyKit/MyClass/myOtherFunction()"),
                        isActive: true,
                        overridingTitle: nil,
                        overridingTitleInlineContent: nil
                    ),
                ]
            )
            
            func reference<Reference: RenderReference>(
                withIdentifier identifier: String,
                ofType type: Reference.Type
            ) throws -> Reference {
                try XCTUnwrap(renderNode.references[identifier] as? Reference)
            }
            
            let myClassReference = try reference(
                withIdentifier: "doc://com.test.bundle/documentation/MyKit/MyClass",
                ofType: TopicRenderReference.self
            )
            XCTAssertEqual(myClassReference.title, "MyClass Title")
            
            let myOtherFunctionReference = try reference(
                withIdentifier: "doc://com.test.bundle/MyKit/MyClass/myOtherFunction()",
                ofType: TopicRenderReference.self
            )
            XCTAssertEqual(myOtherFunctionReference.title, "myOtherFunction Title")
            
            let testSymbolReference = try reference(
                withIdentifier: "doc://com.externally.resolved.symbol/TestSymbolPreciseIdentifier",
                ofType: TopicRenderReference.self
            )
            XCTAssertEqual(testSymbolReference.title, "MyClass Title From Precise Identifier")
            
            let imageReference = try reference(
                withIdentifier: "image.png",
                ofType: ImageReference.self
            )
            XCTAssertEqual(imageReference.asset.variants, [
                DataTraitCollection(
                    userInterfaceStyle: .light,
                    displayScale: .double
                ): URL(string: "docs-media:///path/to/image.png")!])
            
            XCTAssertNil(renderNode.references["another-image.png"])
        }
    }
    
    func testConvertTopLevelSymbolWithLinkResolving() throws {
        let symbolGraphFile = Bundle.module.url(
            forResource: "one-symbol-top-level",
            withExtension: "symbols.json",
            subdirectory: "Test Resources"
        )!
        
        let symbolGraph = try Data(contentsOf: symbolGraphFile)
        
        let request = ConvertRequest(
            bundleInfo: DocumentationBundle.Info(
                displayName: "TestBundle",
                identifier: "org.swift.example",
                version: "1.0.0"
            ),
            externalIDsToConvert: ["s:32MyKit3FooV"],
            documentPathsToConvert: [],
            symbolGraphs: [symbolGraph],
            markupFiles: [],
            miscResourceURLs: []
        )
        
        let server = DocumentationServer()
        
        let mockLinkResolvingService = LinkResolvingService { message in
            do {
                let payload = try XCTUnwrap(message.payload)
                let request = try JSONDecoder()
                    .decode(
                        ConvertRequestContextWrapper<OutOfProcessReferenceResolver.Request>.self,
                        from: payload
                    )
                
                let errorResponse = DocumentationServer.Message(
                    type: "resolve-reference-response",
                    payload: try JSONEncoder().encode(
                        OutOfProcessReferenceResolver.Response
                            .errorMessage("Unable to resolve reference.")
                    )
                )
                
                switch request.payload {
                case .topic(let url):
                    let resolvableBarURL = URL(
                        string: "doc://org.swift.example/documentation/MyKit/Foo/bar()"
                    )!
                    
                    if url == resolvableBarURL {
                        let testSymbolInformationResponse = OutOfProcessReferenceResolver
                            .ResolvedInformation(
                                kind: .init(
                                    name: "bar()",
                                    id: "org.swift.docc.kind.method",
                                    isSymbol: true
                                ),
                                url: resolvableBarURL,
                                title: "bar()",
                                abstract: "",
                                language: .init(name: "Swift", id: "swift"),
                                availableLanguages: [],
                                platforms: [],
                                declarationFragments: nil,
                                topicImages: nil,
                                references: nil
                            )
                        
                        let payloadData = OutOfProcessReferenceResolver.Response
                            .resolvedInformation(testSymbolInformationResponse)
                        
                        return DocumentationServer.Message(
                            type: "resolve-reference-response",
                            payload: try JSONEncoder().encode(payloadData)
                        )
                    } else {
                        return errorResponse
                    }
                default:
                    return errorResponse
                }
            } catch {
                XCTFail(error.localizedDescription)
                return nil
            }
        }
        
        server.register(service: mockLinkResolvingService)
        
        try processAndAssert(request: request, linkResolvingServer: server) { message in
            let renderNodes = try JSONDecoder().decode(
                ConvertResponse.self,
                from: XCTUnwrap(message.payload)
            ).renderNodes
            
            XCTAssertEqual(renderNodes.count, 1)
            let data = try XCTUnwrap(renderNodes.first)
            let renderNode = try JSONDecoder().decode(RenderNode.self, from: data)
            
            XCTAssertEqual(
                Set(renderNode.references.keys),
                [
                    "doc://org.swift.example/documentation/MyKit",
                    "doc://org.swift.example/documentation/MyKit/Foo",
                    "doc://org.swift.example/documentation/MyKit/Foo/bar()",
                ]
            )
        }
    }
    
    func testOrderOfLinkResolutionRequestsForDocLink() throws {
        let symbolGraphFile = try XCTUnwrap(
            Bundle.module.url(
                forResource: "SingleSymbolWithUnresolvableDocLink",
                withExtension: "symbols.json",
                subdirectory: "Test Resources"
            )
        )
        
        let symbolGraph = try Data(contentsOf: symbolGraphFile)
        
        let request = ConvertRequest(
            bundleInfo: DocumentationBundle.Info(
                displayName: "TestBundleDisplayName",
                identifier: "com.test.bundle",
                version: "1.0.0"
            ),
            externalIDsToConvert: ["s:21SmallTestingFramework40EnumerationWithSingleUnresolvableDocLinkO"],
            documentPathsToConvert: [],
            symbolGraphs: [symbolGraph],
            markupFiles: [],
            miscResourceURLs: []
        )
        
        let receivedLinkResolutionRequests = try linkResolutionRequestsForConvertRequest(request)
        
        let expectedLinkResolutionRequests = [
            "doc://com.test.bundle/LinkToNowhere",
            "doc://com.test.bundle/documentation/TestBundleDisplayName/LinkToNowhere",
            "doc://com.test.bundle/tutorials/TestBundleDisplayName/LinkToNowhere",
            "doc://com.test.bundle/tutorials/LinkToNowhere",
            "doc://com.test.bundle/documentation/SmallTestingFramework/EnumerationWithSingleUnresolvableDocLink/LinkToNowhere",
            "doc://com.test.bundle/documentation/SmallTestingFramework/LinkToNowhere",
            "doc://com.test.bundle/documentation/LinkToNowhere",
        ]
        
        XCTAssertEqual(expectedLinkResolutionRequests, receivedLinkResolutionRequests)
    }
    
    func testOrderOfLinkResolutionRequestsForDeeplyNestedSymbol() throws {
        let symbolGraphFile = try XCTUnwrap(
            Bundle.module.url(
                forResource: "DeeplyNestedSymbolWithUnresolvableDocLink",
                withExtension: "symbols.json",
                subdirectory: "Test Resources"
            )
        )
        
        let symbolGraph = try Data(contentsOf: symbolGraphFile)
        
        let request = ConvertRequest(
            bundleInfo: DocumentationBundle.Info(
                displayName: "TestBundleDisplayName",
                identifier: "com.test.bundle",
                version: "1.0.0"
            ),
            externalIDsToConvert: ["s:21SmallTestingFramework15TestEnumerationO06NesteddE0O0D6StructV06deeplyfD31FunctionWithUnresolvableDocLinkyyF"],
            documentPathsToConvert: [],
            symbolGraphs: [symbolGraph],
            markupFiles: [],
            miscResourceURLs: []
        )
        
        let receivedLinkResolutionRequests = try linkResolutionRequestsForConvertRequest(request)
        
        let expectedLinkResolutionRequests = [
            "doc://com.test.bundle/LinkToNowhere",
            "doc://com.test.bundle/documentation/TestBundleDisplayName/LinkToNowhere",
            "doc://com.test.bundle/tutorials/TestBundleDisplayName/LinkToNowhere",
            "doc://com.test.bundle/tutorials/LinkToNowhere",
            "doc://com.test.bundle/documentation/SmallTestingFramework/TestEnumeration/NestedTestEnumeration/TestStruct/deeplyNestedTestFunctionWithUnresolvableDocLink()/LinkToNowhere",
            "doc://com.test.bundle/documentation/SmallTestingFramework/TestEnumeration/NestedTestEnumeration/TestStruct/LinkToNowhere",
            "doc://com.test.bundle/documentation/SmallTestingFramework/LinkToNowhere",
            "doc://com.test.bundle/documentation/LinkToNowhere",
        ]
        
        XCTAssertEqual(expectedLinkResolutionRequests, receivedLinkResolutionRequests)
    }
    
    func testOrderOfLinkResolutionRequestsForSymbolLink() throws {
        let symbolGraphFile = try XCTUnwrap(
            Bundle.module.url(
                forResource: "SingleSymbolWithUnresolvableSymbolLink",
                withExtension: "symbols.json",
                subdirectory: "Test Resources"
            )
        )
        
        let symbolGraph = try Data(contentsOf: symbolGraphFile)
        
        let request = ConvertRequest(
            bundleInfo: DocumentationBundle.Info(
                displayName: "TestBundleDisplayName",
                identifier: "com.test.bundle",
                version: "1.0.0"
            ),
            externalIDsToConvert: ["s:21SmallTestingFramework43EnumerationWithSingleUnresolvableSymbolLinkO"],
            documentPathsToConvert: [],
            symbolGraphs: [symbolGraph],
            markupFiles: [],
            miscResourceURLs: []
        )
        
        let receivedLinkResolutionRequests = try linkResolutionRequestsForConvertRequest(request)
        
        let expectedLinkResolutionRequests = [
            "doc://com.test.bundle/LinkToNowhere",
            "doc://com.test.bundle/documentation/SmallTestingFramework/EnumerationWithSingleUnresolvableSymbolLink/LinkToNowhere",
            "doc://com.test.bundle/documentation/SmallTestingFramework/LinkToNowhere",
            "doc://com.test.bundle/documentation/LinkToNowhere",
        ]
        
        XCTAssertEqual(expectedLinkResolutionRequests, receivedLinkResolutionRequests)
    }
    
    func linkResolutionRequestsForConvertRequest(_ request: ConvertRequest) throws -> [String] {
        var receivedLinkResolutionRequests = [String]()
        let mockLinkResolvingService = LinkResolvingService { message in
            do {
                let payload = try XCTUnwrap(message.payload)
                let request = try JSONDecoder().decode(
                    ConvertRequestContextWrapper<OutOfProcessReferenceResolver.Request>.self,
                    from: payload
                )
                
                if case let .topic(url) = request.payload {
                    receivedLinkResolutionRequests.append(url.absoluteString)
                }
                
                let payloadData = OutOfProcessReferenceResolver.Response
                    .errorMessage("Unable to resolve reference.")
                
                return DocumentationServer.Message(
                    type: "resolve-reference-response",
                    payload: try JSONEncoder().encode(payloadData)
                )
            } catch {
                XCTFail(error.localizedDescription)
                return nil
            }
        }
        
        let server = DocumentationServer()
        server.register(service: mockLinkResolvingService)
        
        try processAndAssert(request: request, linkResolvingServer: server) { _ in }
        return receivedLinkResolutionRequests
    }

    func testReturnsErrorWhenPayloadIsEmpty() throws {
        try processAndAssert(
            message: DocumentationServer.Message(
                type: "convert",
                identifier: "test-identifier",
                payload: nil
            )
        ) { message in
            XCTAssertEqual(message.type, "convert-response-error")
            XCTAssertEqual(message.identifier, "test-identifier-response-error")
            
            let error = try JSONDecoder().decode(
                ConvertServiceError.self, from: XCTUnwrap(message.payload))
            XCTAssertEqual(error.identifier, "missing-payload")
            XCTAssertEqual(error.description, "The request is missing a payload.")
        }
    }
    
    func testReturnsErrorWhenPayloadIsInvalid() throws {
        try processAndAssert(
            message: DocumentationServer.Message(
                type: "convert",
                identifier: "test-identifier",
                payload: "not a convert request".data(using: .utf8)!
            )
        ) { message in
            XCTAssertEqual(message.type, "convert-response-error")
            XCTAssertEqual(message.identifier, "test-identifier-response-error")
            
            let error = try JSONDecoder().decode(
                ConvertServiceError.self, from: XCTUnwrap(message.payload))
            XCTAssertEqual(error.identifier, "invalid-request")
        }
    }
    
    func testReturnsErrorWhenConversionThrows() throws {
        let request = ConvertRequest(
            bundleInfo: testBundleInfo,
            externalIDsToConvert: nil,
            symbolGraphs: [],
            markupFiles: [],
            miscResourceURLs: []
        )
        
        try processAndAssert(
            request: request,
            converter: TestConverter { throw TestError.testError }
        ) { message in
            XCTAssertEqual(message.type, "convert-response-error")
            XCTAssertEqual(message.identifier, "test-identifier-response-error")
            
            let error = try JSONDecoder().decode(
                ConvertServiceError.self, from: XCTUnwrap(message.payload))
            XCTAssertEqual(error.identifier, "conversion-error")
        }
    }
    
    func testDoesNotResolveLinksUnlessBundleIDMatches() throws {
        let tempURL = try createTempFolder(content: [
            Folder(name: "unit-test.docc", content: [
                TextFile(name: "SomeExtension.md", utf8Content: """
                # ``/ModuleName/SymbolName``
                
                Some documentation extension
                """),
                
                // This catalog doesn't have any symbol graph files
                
                InfoPlist(identifier: "com.example.something")
            ])
        ])
        let bundleURL = tempURL.appendingPathComponent("unit-test.docc")
        
        let requestWithDifferentBundleID = ConvertRequest(
            bundleInfo: DocumentationBundle.Info(displayName: "DisplayName", identifier: "com.example.something-else"),
            externalIDsToConvert: [],
            bundleLocation: bundleURL,
            symbolGraphs: [],
            markupFiles: [],
            miscResourceURLs: []
        )
        XCTAssertEqual(try linkResolutionRequestsForConvertRequest(requestWithDifferentBundleID), [], "Shouldn't make any link resolution requests because the bundle IDs are different.")
        
        let requestWithSameBundleID = ConvertRequest(
            bundleInfo: DocumentationBundle.Info(displayName: "DisplayName", identifier: "com.example.something"),
            externalIDsToConvert: [],
            bundleLocation: bundleURL,
            symbolGraphs: [],
            markupFiles: [],
            miscResourceURLs: []
        )
        let linkResolutionRequests = try linkResolutionRequestsForConvertRequest(requestWithSameBundleID)
        XCTAssertFalse(linkResolutionRequests.isEmpty, "Should have made some link resolution requests to try to match the extension file")
        XCTAssert(linkResolutionRequests.allSatisfy { $0.hasSuffix("/SymbolName") }, "Should have made some link resolution requests to try to match the extension file")
    }
    
    func testReturnsErrorWhenConversionHasProblems() throws {
        let request = ConvertRequest(
            bundleInfo: testBundleInfo,
            externalIDsToConvert: nil,
            symbolGraphs: [],
            markupFiles: [],
            miscResourceURLs: []
        )
        
        let testProblem = Problem(
            diagnostic: Diagnostic(
                source: nil,
                severity: .error,
                range: nil,
                identifier: "",
                summary: ""
            ),
            possibleSolutions: []
        )
        
        try processAndAssert(
            request: request,
            converter: TestConverter { ([], [testProblem]) }
        ) { message in
            XCTAssertEqual(message.type, "convert-response-error")
            XCTAssertEqual(message.identifier, "test-identifier-response-error")
            
            let error = try JSONDecoder().decode(
                ConvertServiceError.self, from: XCTUnwrap(message.payload))
            XCTAssertEqual(error.identifier, "conversion-error")
        }
    }
    
    func processAndAssert(
        request: ConvertRequest,
        converter: DocumentationConverterProtocol? = nil,
        linkResolvingServer: DocumentationServer? = nil,
        assertion: @escaping (DocumentationServer.Message) throws -> ()
    ) throws {
        try processAndAssert(
            message: DocumentationServer.Message(
                type: "convert",
                identifier: "test-identifier",
                payload: try JSONEncoder().encode(request)),
            converter: converter,
            linkResolvingServer: linkResolvingServer,
            assertion: assertion
        )
    }
    
    func processAndAssert(
        message: DocumentationServer.Message,
        converter: DocumentationConverterProtocol? = nil,
        linkResolvingServer: DocumentationServer? = nil,
        assertion: @escaping (DocumentationServer.Message) throws -> ()
    ) throws {
        let expectation = XCTestExpectation(description: "Sends a response")
        
        ConvertService(
            converter: converter,
            linkResolvingServer: linkResolvingServer
        ).process(message) { message in
            do {
                try assertion(message)
            } catch {
                XCTFail(error.localizedDescription)
            }
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    /// Asserts that the given render reference store contains the given topic.
    func assertReferenceStoreContains(
        referenceStore: RenderReferenceStore,
        topicPath: String,
        source: URL,
        title: String?,
        isDocumentationExtensionContent: Bool,
        file: StaticString = #file,
        line: UInt = #line
    ) throws {
        let topicContentKey = try XCTUnwrap(referenceStore.topics.keys.first { $0.path == topicPath })
        
        XCTAssertEqual(
            referenceStore.topics[topicContentKey]?.source?.resolvingSymlinksInPath(),
            source.resolvingSymlinksInPath(),
            file: file,
            line: line
        )
        XCTAssertEqual(
            referenceStore.topics[topicContentKey]?.isDocumentationExtensionContent,
            isDocumentationExtensionContent,
            file: file,
            line: line
        )
        
        let topicRenderReference = try XCTUnwrap(referenceStore.topics[topicContentKey]?.renderReference as? TopicRenderReference)
        XCTAssertEqual(topicRenderReference.title, title, file: file, line: line)
    }
    
    struct TestConverter: DocumentationConverterProtocol {
        var convertDelegate: () throws -> ([Problem], [Problem])
        
        func convert(
            outputConsumer: some ConvertOutputConsumer
        ) throws -> (analysisProblems: [Problem], conversionProblems: [Problem])
        {
            try convertDelegate()
        }
    }
    
    enum TestError: Error {
        case testError
    }
    
    struct LinkResolvingService: DocumentationService {
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
}
