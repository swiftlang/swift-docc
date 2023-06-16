/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2023 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import XCTest
@testable import SwiftDocC

class SampleDownloadTests: XCTestCase {
    func testDecodeSampleDownloadSymbol() throws {
        let downloadSymbolURL = Bundle.module.url(
            forResource: "sample-download-symbol", withExtension: "json",
            subdirectory: "Rendering Fixtures")!
        
        let data = try Data(contentsOf: downloadSymbolURL)
        let symbol = try RenderNode.decode(fromJSON: data)
        
        //
        // Sample Download Details
        //
        
        guard let section = symbol.sampleDownload else {
            XCTFail("Download section not decoded")
            return
        }
        
        guard case RenderInlineContent.reference(let identifier, let isActive, let overridingTitle, let overridingTitleInlineContent) = section.action else {
            XCTFail("Could not decode action reference")
            return
        }
        
        XCTAssertEqual(identifier.identifier, "doc://org.swift.docc.example/downloads/sample.zip")
        XCTAssertTrue(isActive)
        XCTAssertEqual(overridingTitle, "Download")
        XCTAssertEqual(overridingTitleInlineContent, [.text("Download")])
        
        XCTAssertTrue(section.headings.isEmpty)
        XCTAssertTrue(section.rawIndexableTextContent(references: [:]).isEmpty)
        XCTAssertEqual(symbol.projectFiles()?.url.absoluteString, "/downloads/project.zip")
        XCTAssertEqual(symbol.projectFiles()?.checksum, "ad4adacc8ad53230b59d")
    }
    
    func testDecodeSampleDownloadUnavailableSymbol() throws {
        let downloadSymbolURL = Bundle.module.url(
            forResource: "sample-download-unavailable-symbol", withExtension: "json",
            subdirectory: "Rendering Fixtures")!
        
        let data = try Data(contentsOf: downloadSymbolURL)
        let symbol = try RenderNode.decode(fromJSON: data)
        
        //
        // Unavailable Sample Download Details
        //
        
        guard let section = symbol.downloadNotAvailableSummary else {
            XCTFail("Download not available section not decoded.")
            return
        }
        
        XCTAssertEqual(section.count, 1)
        
        guard case let .paragraph(contentParagraph) = section.first else {
            XCTFail("Section is not a paragraph.")
            return
        }
        
        let text = contentParagraph.inlineContent.rawIndexableTextContent(references: symbol.references)
        XCTAssertEqual(text, "You can experiment with the code. Just use WiFi Access on your Mac to download WiFi access sample code.")
    }

    func testParseSampleDownload() throws {
        let renderNode = try renderNodeFromSampleBundle(at: "/documentation/SampleBundle/MySample")
        
        let sampleCodeDownload = try XCTUnwrap(renderNode.sampleDownload)
        guard case .reference(identifier: let ident, isActive: true, overridingTitle: "Download", overridingTitleInlineContent: nil) = sampleCodeDownload.action else {
            XCTFail("Unexpected action in callToAction")
            return
        }
        XCTAssertEqual(ident.identifier, "https://example.com/sample.zip")
    }

    func testParseSampleLocalDownload() throws {
        let renderNode = try renderNodeFromSampleBundle(at: "/documentation/SampleBundle/MyLocalSample")
        
        let sampleCodeDownload = try XCTUnwrap(renderNode.sampleDownload)
        guard case .reference(identifier: let ident, isActive: true, overridingTitle: "Download", overridingTitleInlineContent: nil) = sampleCodeDownload.action else {
            XCTFail("Unexpected action in callToAction")
            return
        }
        XCTAssertEqual(ident.identifier, "plus.svg")
    }

    func testSampleDownloadRoundtrip() throws {
        let renderNode = try renderNodeFromSampleBundle(at: "/documentation/SampleBundle/MySample")

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let encodedNode = try encoder.encode(renderNode)
        let decodedNode = try decoder.decode(RenderNode.self, from: encodedNode)

        guard case let .reference(
                identifier: origIdent,
                isActive: _,
                overridingTitle: _,
                overridingTitleInlineContent: _
            ) = renderNode.sampleDownload?.action,
            case let .reference(
                identifier: decodedIdent,
                isActive: _,
                overridingTitle: _,
                overridingTitleInlineContent: _
            ) = decodedNode.sampleDownload?.action
        else {
            XCTFail("RenderNode should have callToAction both before and after roundtrip")
            return
        }

        XCTAssertEqual(origIdent, decodedIdent)
    }
    
    private func renderNodeFromSampleBundle(at referencePath: String) throws -> RenderNode {
        let (bundle, context) = try testBundleAndContext(named: "SampleBundle")
        let reference = ResolvedTopicReference(
            bundleIdentifier: bundle.identifier,
            path: referencePath,
            sourceLanguage: .swift
        )
        let article = try XCTUnwrap(context.entity(with: reference).semantic as? Article)
        var translator = RenderNodeTranslator(
            context: context,
            bundle: bundle,
            identifier: reference,
            source: nil
        )
        return try XCTUnwrap(translator.visitArticle(article) as? RenderNode)
    }

    func testSampleDownloadRelativeURL() throws {
        let renderNode = try renderNodeFromSampleBundle(at: "/documentation/SampleBundle/RelativeURLSample")
        let sampleCodeDownload = try XCTUnwrap(renderNode.sampleDownload)
        guard case .reference(identifier: let ident, isActive: true, overridingTitle: "Download", overridingTitleInlineContent: nil) = sampleCodeDownload.action else {
            XCTFail("Unexpected action in callToAction")
            return
        }
        XCTAssertEqual(ident.identifier, "files/ExternalSample.zip")

        // Ensure that the encoded URL still references the entered URL
        let downloadReference = try XCTUnwrap(renderNode.references[ident.identifier] as? ExternalLocationReference)

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let encodedReference = try encoder.encode(downloadReference)
        let decodedReference = try decoder.decode(DownloadReference.self, from: encodedReference)

        XCTAssertEqual(decodedReference.url.description, "files/ExternalSample.zip")
    }

    func testExternalLocationRoundtrip() throws {
        let renderNode = try renderNodeFromSampleBundle(at: "/documentation/SampleBundle/RelativeURLSample")
        let sampleCodeDownload = try XCTUnwrap(renderNode.sampleDownload)
        guard case .reference(identifier: let ident, isActive: true, overridingTitle: "Download", overridingTitleInlineContent: nil) = sampleCodeDownload.action else {
            XCTFail("Unexpected action in callToAction")
            return
        }
        XCTAssertEqual(ident.identifier, "files/ExternalSample.zip")

        // Make sure that the ExternalLocationReference we get can round-trip as itself as well as through a DownloadReference
        let downloadReference = try XCTUnwrap(renderNode.references[ident.identifier] as? ExternalLocationReference)

        let encoder = JSONEncoder()
        encoder.outputFormatting.insert(.sortedKeys)
        let decoder = JSONDecoder()

        let encodedReference = try encoder.encode(downloadReference)

        // ExternalLocationReference -> ExternalLocationReference
        // The encoded JSON should be the same before and after re-encoding.
        do {
            let decodedReference = try decoder.decode(ExternalLocationReference.self, from: encodedReference)
            let reEncodedReference = try encoder.encode(decodedReference)

            let firstJson = String(data: encodedReference, encoding: .utf8)
            let finalJson = String(data: reEncodedReference, encoding: .utf8)

            XCTAssertEqual(firstJson, finalJson)
        }

        // ExternalLocationReference -> DownloadReference -> ExternalLocationReference
        // The reference identifier should be the same all throughout, and the final ExternalLocationReference
        // should encode to the same JSON as the initial reference.
        do {
            let decodedReference = try decoder.decode(DownloadReference.self, from: encodedReference)

            XCTAssertEqual(decodedReference.identifier, downloadReference.identifier)

            let encodedDownload = try encoder.encode(decodedReference)
            let reDecodedReference = try decoder.decode(ExternalLocationReference.self, from: encodedDownload)

            XCTAssertEqual(reDecodedReference.identifier, downloadReference.identifier)

            let reEncodedReference = try encoder.encode(reDecodedReference)

            let firstJson = String(data: encodedReference, encoding: .utf8)
            let finalJson = String(data: reEncodedReference, encoding: .utf8)

            XCTAssertEqual(firstJson, finalJson)
        }
    }
    
    func testExternalLinkOnSampleCodePage() throws {
        let renderNode = try renderNodeFromSampleBundle(at: "/documentation/SampleBundle/MyExternalSample")
        let sampleCodeDownload = try XCTUnwrap(renderNode.sampleDownload)
        guard case .reference(identifier: let identifier, isActive: true, overridingTitle: "View Source", overridingTitleInlineContent: nil) = sampleCodeDownload.action else {
            XCTFail("Unexpected action in callToAction")
            return
        }
        
        XCTAssertEqual(identifier.identifier, "https://www.example.com/source-repository.git")
        let reference = try XCTUnwrap(renderNode.references[identifier.identifier])
        XCTAssert(reference is ExternalLocationReference)
    }
    
    func testExternalLinkOnRegularArticlePage() throws {
        let renderNode = try renderNodeFromSampleBundle(at: "/documentation/SampleBundle/MyArticle")
        let sampleCodeDownload = try XCTUnwrap(renderNode.sampleDownload)
        guard case .reference(identifier: let identifier, isActive: true, overridingTitle: "Visit", overridingTitleInlineContent: nil) = sampleCodeDownload.action else {
            XCTFail("Unexpected action in callToAction")
            return
        }
        
        XCTAssertEqual(identifier.identifier, "https://www.example.com")
        let reference = try XCTUnwrap(renderNode.references[identifier.identifier])
        XCTAssert(reference is ExternalLocationReference)
    }

    /// Ensure that a DownloadReference where the URL is different from the reference identifier
    /// can still round-trip through an ExternalLocationReference with the URL and reference identifier intact.
    func testRoundTripWithDifferentUrl() throws {
        let baseReference = DownloadReference(identifier: .init("DownloadReference.zip"), renderURL: .init(string: "https://example.com/DownloadReference.zip")!, checksum: nil)

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let encodedReference = try encoder.encode(baseReference)

        let interimReference = try decoder.decode(ExternalLocationReference.self, from: encodedReference)
        let interimEncodedReference = try encoder.encode(interimReference)

        let roundTripReference = try decoder.decode(DownloadReference.self, from: interimEncodedReference)

        XCTAssertEqual(baseReference, roundTripReference)
    }

    /// Ensure that an ExternalLocationReference loaded from JSON continues to encode the same
    /// information after being decoded and re-encoded.
    func testRoundTripExternalLocationFromFixture() throws {
        let downloadSymbolURL = Bundle.module.url(
            forResource: "external-location-custom-url", withExtension: "json",
            subdirectory: "Rendering Fixtures")!

        let originalData = try Data(contentsOf: downloadSymbolURL)
        let originalRenderNode = try RenderNode.decode(fromJSON: originalData)

        let encodedRenderNode = try JSONEncoder().encode(originalRenderNode)
        let symbol = try RenderNode.decode(fromJSON: encodedRenderNode)

        //
        // Sample Download Details
        //

        guard let section = symbol.sampleDownload else {
            XCTFail("Download section not decoded")
            return
        }

        guard case RenderInlineContent.reference(let identifier, _, _, _) = section.action else {
            XCTFail("Could not decode action reference")
            return
        }

        XCTAssertEqual(identifier.identifier, "doc://org.swift.docc.example/downloads/sample.zip")

        let externalReference = try XCTUnwrap(symbol.references[identifier.identifier] as? ExternalLocationReference)
        XCTAssertEqual(externalReference.url, "https://example.com/ExternalLocation.zip")
    }
    
    func testRoundTripExternalLocationReferenceWithModifiedURL() throws {
        var reference = ExternalLocationReference(identifier: RenderReferenceIdentifier("/test/sample.zip"))
        XCTAssertEqual(reference.url, "/test/sample.zip")
        reference.url = "https://swift.org/documentation/test/sample.zip"
        let encodedReference = try JSONEncoder().encode(reference)
        let decodedReference = try JSONDecoder().decode(ExternalLocationReference.self, from: encodedReference)
        XCTAssertEqual(decodedReference.identifier.identifier, "/test/sample.zip")
        XCTAssertEqual(decodedReference.url, "https://swift.org/documentation/test/sample.zip")
    }
}
