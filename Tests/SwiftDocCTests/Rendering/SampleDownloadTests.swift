/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
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
    
}
