/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2022 Apple Inc. and the Swift project authors
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
        XCTAssertEqual(symbol.projectFiles()?.sha512Checksum, "ad4adacc8ad53230b59d")
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
        let (bundle, context) = try testBundleAndContext(named: "SampleBundle")
        let reference = ResolvedTopicReference(
            bundleIdentifier: bundle.identifier,
            path: "/documentation/SampleBundle/MySample",
            sourceLanguage: .swift
        )
        let article = try XCTUnwrap(context.entity(with: reference).semantic as? Article)
        var translator = RenderNodeTranslator(
            context: context,
            bundle: bundle,
            identifier: reference,
            source: nil
        )
        let renderNode = try XCTUnwrap(translator.visitArticle(article) as? RenderNode)
        let sampleCodeDownload = try XCTUnwrap(renderNode.sampleDownload)
        guard case .reference(identifier: let ident, isActive: true, overridingTitle: "Download", overridingTitleInlineContent: nil) = sampleCodeDownload.action else {
            XCTFail("Unexpected action in callToAction")
            return
        }
        XCTAssertEqual(ident.identifier, "https://example.com/sample.zip")
    }

    func testParseSampleLocalDownload() throws {
        let (bundle, context) = try testBundleAndContext(named: "SampleBundle")
        let reference = ResolvedTopicReference(
            bundleIdentifier: bundle.identifier,
            path: "/documentation/SampleBundle/MyLocalSample",
            sourceLanguage: .swift
        )
        let article = try XCTUnwrap(context.entity(with: reference).semantic as? Article)
        var translator = RenderNodeTranslator(
            context: context,
            bundle: bundle,
            identifier: reference,
            source: nil
        )
        let renderNode = try XCTUnwrap(translator.visitArticle(article) as? RenderNode)
        let sampleCodeDownload = try XCTUnwrap(renderNode.sampleDownload)
        guard case .reference(identifier: let ident, isActive: true, overridingTitle: "Download", overridingTitleInlineContent: nil) = sampleCodeDownload.action else {
            XCTFail("Unexpected action in callToAction")
            return
        }
        XCTAssertEqual(ident.identifier, "plus.svg")
    }

    func testSampleDownloadRoundtrip() throws {
        let (bundle, context) = try testBundleAndContext(named: "SampleBundle")
        let reference = ResolvedTopicReference(
            bundleIdentifier: bundle.identifier,
            path: "/documentation/SampleBundle/MySample",
            sourceLanguage: .swift
        )
        let article = try XCTUnwrap(context.entity(with: reference).semantic as? Article)
        var translator = RenderNodeTranslator(
            context: context,
            bundle: bundle,
            identifier: reference,
            source: nil
        )
        let renderNode = try XCTUnwrap(translator.visitArticle(article) as? RenderNode)

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
    
}
