/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocC

class URLReferenceTests: XCTestCase {
    struct MockReference: URLReference {
        static var baseURL: URL = URL(string: "/mocks/")!
    }
    func testRenderURLIgnoresAbsoluteWebURLs() throws {
        let testUrl = try XCTUnwrap(URL(string: "https://example.com/"))
        let urlReference = MockReference()
        XCTAssertEqual(urlReference.renderURL(for: testUrl, prefixComponent: nil), testUrl)
    }
    
    func testRenderURLIgnoresPrefacedURLs() throws {
        let testUrl = try XCTUnwrap(URL(string: "/mocks/example.com/mock-name"))
        let urlReference = MockReference()
        XCTAssertEqual(urlReference.renderURL(for: testUrl, prefixComponent: nil), testUrl)
    }
    
    func testRenderURLPreparesUnprefacedURLs() throws {
        let testUrl = try XCTUnwrap(URL(string: "file://full/path/to/mock-name"))
        let expectedUrl = try XCTUnwrap(URL(string: "/mocks/mock-name"))
        let urlReference = MockReference()
        XCTAssertEqual(urlReference.renderURL(for: testUrl, prefixComponent: nil), expectedUrl)
    }
    
    func testImageReferenceRoundtripsAcrossBundles() throws {
        // Encode the reference in bundle 1
        var encoder = RenderJSONEncoder.makeEncoder(assetPrefixComponent: "com.example.bundle1")
        var asset = DataAsset()
        asset.register(URL(string: "image.png")!, with: .init())
        let reference = ImageReference(identifier: .init("image"), imageAsset: asset)
        
        // Verify it was encoded correctly
        var jsonData = try XCTUnwrap(try encoder.encode(reference))
        var decodedReference = try RenderJSONDecoder.makeDecoder().decode(ImageReference.self, from: jsonData)
        XCTAssertEqual(Array(decodedReference.asset.metadata.keys), [URL(string: "/images/com.example.bundle1/image.png")!])
        
        // Re-encode the reference from bundle 1 in bundle 2 and ensure that the URL has not changed
        encoder = RenderJSONEncoder.makeEncoder(assetPrefixComponent: "com.example.bundle2")
        jsonData = try XCTUnwrap(try encoder.encode(decodedReference))
        decodedReference = try RenderJSONDecoder.makeDecoder().decode(ImageReference.self, from: jsonData)
        XCTAssertEqual(Array(decodedReference.asset.metadata.keys), [URL(string: "/images/com.example.bundle1/image.png")!])
    }
    
    func testDownloadReferenceRoundtripsAcrossBundles() throws {
        // Encode the reference in bundle 1
        var encoder = RenderJSONEncoder.makeEncoder(assetPrefixComponent: "com.example.bundle1")
        let reference = DownloadReference(identifier: .init("download"), renderURL: URL(string: "download.zip")!, checksum: nil)
        
        // Verify it was encoded correctly
        var jsonData = try XCTUnwrap(try encoder.encode(reference))
        var decodedReference = try RenderJSONDecoder.makeDecoder().decode(DownloadReference.self, from: jsonData)
        XCTAssertEqual(decodedReference.url, URL(string: "/downloads/com.example.bundle1/download.zip")!)
        
        // Re-encode the reference from bundle 1 in bundle 2 and ensure that the URL has not changed
        encoder = RenderJSONEncoder.makeEncoder(assetPrefixComponent: "com.example.bundle2")
        jsonData = try XCTUnwrap(try encoder.encode(decodedReference))
        decodedReference = try RenderJSONDecoder.makeDecoder().decode(DownloadReference.self, from: jsonData)
        XCTAssertEqual(decodedReference.url, URL(string: "/downloads/com.example.bundle1/download.zip")!)
    }
    
    func testVideoReferenceRoundtripsAcrossBundles() throws {
        // Encode the reference in bundle 1
        var encoder = RenderJSONEncoder.makeEncoder(assetPrefixComponent: "com.example.bundle1")
        var asset = DataAsset()
        asset.register(URL(string: "video.mov")!, with: .init())
        let reference = VideoReference(identifier: .init("video"), videoAsset: asset, poster: nil)
        
        // Verify it was encoded correctly
        var jsonData = try XCTUnwrap(try encoder.encode(reference))
        var decodedReference = try RenderJSONDecoder.makeDecoder().decode(VideoReference.self, from: jsonData)
        XCTAssertEqual(Array(decodedReference.asset.metadata.keys), [URL(string: "/videos/com.example.bundle1/video.mov")!])

        // Re-encode the reference from bundle 1 in bundle 2 and ensure that the URL has not changed
        encoder = RenderJSONEncoder.makeEncoder(assetPrefixComponent: "com.example.bundle2")
        jsonData = try XCTUnwrap(try encoder.encode(decodedReference))
        decodedReference = try RenderJSONDecoder.makeDecoder().decode(VideoReference.self, from: jsonData)
        XCTAssertEqual(Array(decodedReference.asset.metadata.keys), [URL(string: "/videos/com.example.bundle1/video.mov")!])
    }
}
