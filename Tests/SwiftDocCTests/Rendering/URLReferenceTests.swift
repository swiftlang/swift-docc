/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2025-2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Testing
@testable import SwiftDocC

struct URLReferenceTests {
    struct MockReference: URLReference {
        static var baseURL: URL = URL(string: "/mocks/")!
    }

    @Test(arguments: [
        (URL(string: "https://example.com/")!, URL(string: "https://example.com/")!),
        (URL(string: "/mocks/example.com/mock-name")!, URL(string: "/mocks/example.com/mock-name")!),
        (URL(string: "file://full/path/to/mock-name")!, URL(string: "/mocks/mock-name")!),
    ])
    func rendersURLRelativeToBaseURL(input: URL, expected: URL) {
        #expect(MockReference().renderURL(for: input, prefixComponent: nil) == expected)
    }

    @Test
    func imageReferenceRoundtripsAcrossBundles() throws {
        // Encode the reference in bundle 1
        var encoder = RenderJSONEncoder.makeEncoder(assetPrefixComponent: "com.example.bundle1")
        var asset = DataAsset()
        asset.register(URL(string: "image.png")!, with: .init())
        let reference = ImageReference(identifier: .init("image"), imageAsset: asset)

        // Verify it was encoded correctly
        var jsonData = try encoder.encode(reference)
        var decodedReference = try RenderJSONDecoder.makeDecoder().decode(ImageReference.self, from: jsonData)
        #expect(Array(decodedReference.asset.metadata.keys) == [URL(string: "/images/com.example.bundle1/image.png")!])

        // Re-encode the reference from bundle 1 in bundle 2 and ensure that the URL has not changed
        encoder = RenderJSONEncoder.makeEncoder(assetPrefixComponent: "com.example.bundle2")
        jsonData = try encoder.encode(decodedReference)
        decodedReference = try RenderJSONDecoder.makeDecoder().decode(ImageReference.self, from: jsonData)
        #expect(Array(decodedReference.asset.metadata.keys) == [URL(string: "/images/com.example.bundle1/image.png")!])
    }

    @Test
    func downloadReferenceRoundtripsAcrossBundles() throws {
        // Encode the reference in bundle 1
        var encoder = RenderJSONEncoder.makeEncoder(assetPrefixComponent: "com.example.bundle1")
        let reference = DownloadReference(identifier: .init("download"), renderURL: URL(string: "download.zip")!, checksum: nil)

        // Verify it was encoded correctly
        var jsonData = try encoder.encode(reference)
        var decodedReference = try RenderJSONDecoder.makeDecoder().decode(DownloadReference.self, from: jsonData)
        #expect(decodedReference.url == URL(string: "/downloads/com.example.bundle1/download.zip")!)

        // Re-encode the reference from bundle 1 in bundle 2 and ensure that the URL has not changed
        encoder = RenderJSONEncoder.makeEncoder(assetPrefixComponent: "com.example.bundle2")
        jsonData = try encoder.encode(decodedReference)
        decodedReference = try RenderJSONDecoder.makeDecoder().decode(DownloadReference.self, from: jsonData)
        #expect(decodedReference.url == URL(string: "/downloads/com.example.bundle1/download.zip")!)
    }

    @Test
    func videoReferenceRoundtripsAcrossBundles() throws {
        // Encode the reference in bundle 1
        var encoder = RenderJSONEncoder.makeEncoder(assetPrefixComponent: "com.example.bundle1")
        var asset = DataAsset()
        asset.register(URL(string: "video.mov")!, with: .init())
        let reference = VideoReference(identifier: .init("video"), videoAsset: asset, poster: nil)

        // Verify it was encoded correctly
        var jsonData = try encoder.encode(reference)
        var decodedReference = try RenderJSONDecoder.makeDecoder().decode(VideoReference.self, from: jsonData)
        #expect(Array(decodedReference.asset.metadata.keys) == [URL(string: "/videos/com.example.bundle1/video.mov")!])

        // Re-encode the reference from bundle 1 in bundle 2 and ensure that the URL has not changed
        encoder = RenderJSONEncoder.makeEncoder(assetPrefixComponent: "com.example.bundle2")
        jsonData = try encoder.encode(decodedReference)
        decodedReference = try RenderJSONDecoder.makeDecoder().decode(VideoReference.self, from: jsonData)
        #expect(Array(decodedReference.asset.metadata.keys) == [URL(string: "/videos/com.example.bundle1/video.mov")!])
    }

    @Test
    func imageReferenceVariantsAreSorted() throws {
        let encoder = RenderJSONEncoder.makeEncoder(assetPrefixComponent: "com.example.bundle")
        var asset = DataAsset()
        asset.register(
            URL(fileURLWithPath: "/catalog/content/assets/overview.png"),
            with: .init(userInterfaceStyle: .light, displayScale: .double)
        )
        asset.register(
            URL(fileURLWithPath: "/catalog/assets/overview~dark.png"),
            with: .init(userInterfaceStyle: .dark, displayScale: .double)
        )
        let reference = ImageReference(identifier: .init("image"), imageAsset: asset)

        let jsonData = try encoder.encode(reference)
        let object = try #require(try JSONSerialization.jsonObject(with: jsonData) as? [String: Any])
        let variants = try #require(object["variants"] as? [[String: Any]])
        let urls = variants.compactMap { $0["url"] as? String }
        #expect(urls == [
            "/images/com.example.bundle/overview.png",
            "/images/com.example.bundle/overview~dark.png",
        ])
    }

    @Test
    func videoReferenceVariantsAreSorted() throws {
        let encoder = RenderJSONEncoder.makeEncoder(assetPrefixComponent: "com.example.bundle")
        var asset = DataAsset()
        asset.register(
            URL(fileURLWithPath: "/catalog/content/assets/overview.mov"),
            with: .init(userInterfaceStyle: .light, displayScale: .double)
        )
        asset.register(
            URL(fileURLWithPath: "/catalog/assets/overview~dark.mov"),
            with: .init(userInterfaceStyle: .dark, displayScale: .double)
        )
        let reference = VideoReference(identifier: .init("video"), videoAsset: asset, poster: nil)

        let jsonData = try encoder.encode(reference)
        let object = try #require(try JSONSerialization.jsonObject(with: jsonData) as? [String: Any])
        let variants = try #require(object["variants"] as? [[String: Any]])
        let urls = variants.compactMap { $0["url"] as? String }
        #expect(urls == [
            "/videos/com.example.bundle/overview.mov",
            "/videos/com.example.bundle/overview~dark.mov",
        ])
    }

    @Test
    func imageReferenceVariantsWithIdenticalURLsAreSortedByTraits() throws {
        let encoder = RenderJSONEncoder.makeEncoder(assetPrefixComponent: "com.example.bundle")
        var asset = DataAsset()
        asset.register(
            URL(fileURLWithPath: "/catalog/light/overview.png"),
            with: .init(userInterfaceStyle: .light, displayScale: .double)
        )
        asset.register(
            URL(fileURLWithPath: "/catalog/dark/overview.png"),
            with: .init(userInterfaceStyle: .dark, displayScale: .double)
        )
        let reference = ImageReference(identifier: .init("image"), imageAsset: asset)

        let jsonData = try encoder.encode(reference)
        let object = try #require(try JSONSerialization.jsonObject(with: jsonData) as? [String: Any])
        let variants = try #require(object["variants"] as? [[String: Any]])
        #expect(variants.compactMap { $0["url"] as? String } == [
            "/images/com.example.bundle/overview.png",
            "/images/com.example.bundle/overview.png",
        ])
        #expect(variants.compactMap { $0["traits"] as? [String] } == [["2x", "dark"], ["2x", "light"]])
    }

    @Test
    func videoReferenceVariantsWithIdenticalURLsAreSortedByTraits() throws {
        let encoder = RenderJSONEncoder.makeEncoder(assetPrefixComponent: "com.example.bundle")
        var asset = DataAsset()
        asset.register(
            URL(fileURLWithPath: "/catalog/light/overview.mov"),
            with: .init(userInterfaceStyle: .light, displayScale: .double)
        )
        asset.register(
            URL(fileURLWithPath: "/catalog/dark/overview.mov"),
            with: .init(userInterfaceStyle: .dark, displayScale: .double)
        )
        let reference = VideoReference(identifier: .init("video"), videoAsset: asset, poster: nil)

        let jsonData = try encoder.encode(reference)
        let object = try #require(try JSONSerialization.jsonObject(with: jsonData) as? [String: Any])
        let variants = try #require(object["variants"] as? [[String: Any]])
        #expect(variants.compactMap { $0["url"] as? String } == [
            "/videos/com.example.bundle/overview.mov",
            "/videos/com.example.bundle/overview.mov",
        ])
        #expect(variants.compactMap { $0["traits"] as? [String] } == [["2x", "dark"], ["2x", "light"]])
    }
}
