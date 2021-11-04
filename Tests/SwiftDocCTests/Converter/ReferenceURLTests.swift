/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocC

class ReferenceURLTests: XCTestCase {
    let imageURL = Bundle.module.url(
        forResource: "image file", withExtension: "png", subdirectory: "Test Resources")!

    let videoURL = Bundle.module.url(
        forResource: "video file", withExtension: "mov", subdirectory: "Test Resources")!
                
    func testImageFileNamesWithSpaceURL() throws {
        var asset = DataAsset()
        asset.variants = [DataTraitCollection.init(userInterfaceStyle: .light, displayScale: .standard): imageURL]
        let reference = ImageReference(identifier: RenderReferenceIdentifier("image"), imageAsset: asset)
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(reference)
        
        let object = try JSONSerialization.jsonObject(with: data, options: [])

        guard let jsonReference = object as? [String: Any],
            let variants = jsonReference["variants"] as? [[String: Any]],
            let variant = variants.first,
            let url = variant["url"] as? String else {
            XCTFail("Could not parse encoded image reference.")
            return
        }
        
        XCTAssertEqual("/images/image%20file.png", url)
    }

    func testVideoFileNamesWithSpaceURL() throws {
        var asset = DataAsset()
        asset.variants = [DataTraitCollection.init(userInterfaceStyle: .light, displayScale: .standard): videoURL]
        let reference = VideoReference(identifier: RenderReferenceIdentifier("video"), videoAsset: asset, poster: nil)
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(reference)
        
        let object = try JSONSerialization.jsonObject(with: data, options: [])

        guard let jsonReference = object as? [String: Any],
            let variants = jsonReference["variants"] as? [[String: Any]],
            let variant = variants.first,
            let url = variant["url"] as? String else {
            XCTFail("Could not parse encoded image reference.")
            return
        }
        
        XCTAssertEqual("/videos/video%20file.mov", url)
    }
    
    func testImageVariantsEncodingOrder() throws {
        let lightImageURL = URL(string: "/images/figure@2x.png")!
        let darkImageURL = URL(string: "/images/figure~dark@2x.png")!
        
        var asset = DataAsset()
        asset.variants = [
            DataTraitCollection(userInterfaceStyle: .light, displayScale: .double): lightImageURL,
            DataTraitCollection(userInterfaceStyle: .dark, displayScale: .double): darkImageURL
        ]
        let reference = ImageReference(identifier: RenderReferenceIdentifier("image"), imageAsset: asset)
        
        let encoder = JSONEncoder()
        
        for _ in 0..<100 {
            let data = try encoder.encode(reference)
            
            let object = try JSONSerialization.jsonObject(with: data)
            let jsonReference = try XCTUnwrap(object as? [String: Any])
            let variants = try XCTUnwrap(jsonReference["variants"] as? [[String: Any]])
            
            let urls = variants.compactMap { $0["url"] as? String }
            XCTAssertEqual(urls, [
                lightImageURL.path,
                darkImageURL.path
            ])
        }
    }
    
    
    func testVideoVariantsEncodingOrder() throws {
        let lightImageURL = URL(string: "/videos/video.png")!
        let darkImageURL = URL(string: "/videos/video~dark.png")!
        
        var asset = DataAsset()
        asset.variants = [
            DataTraitCollection(userInterfaceStyle: .light): lightImageURL,
            DataTraitCollection(userInterfaceStyle: .dark): darkImageURL
        ]
        let reference = VideoReference(identifier: RenderReferenceIdentifier("video"), videoAsset: asset, poster: nil)
        
        let encoder = JSONEncoder()
        
        for _ in 0..<100 {
            let data = try encoder.encode(reference)
            
            let object = try JSONSerialization.jsonObject(with: data)
            let jsonReference = try XCTUnwrap(object as? [String: Any])
            let variants = try XCTUnwrap(jsonReference["variants"] as? [[String: Any]])
            
            let urls = variants.compactMap { $0["url"] as? String }
            XCTAssertEqual(urls, [
                lightImageURL.path,
                darkImageURL.path
            ])
        }
    }
}
