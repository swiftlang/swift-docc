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

class DataAssetManagerTests: XCTestCase {
    
    func assertIsRegistered(named name: String, trait: DataTraitCollection, expectedURL: URL, manager: DataAssetManager, file: StaticString = #file, line: UInt = #line) {
        let data = manager.data(named: name, bestMatching: trait)!
        XCTAssertEqual(data.url, expectedURL)
        XCTAssertEqual(data.traitCollection, trait)
    }
    
    func testWithoutDarkVariants() throws {
        var manager = DataAssetManager()
        let images = ["Documentation/woof.png", "bark.jpg", "wuphf.jpeg", "woof.png"].compactMap(URL.init(string:))
        try manager.register(data: images)
        
        XCTAssertEqual(manager.storage.values.count, 3)
        
        // The asset manager should contain all the images.
        
        assertIsRegistered(named: "bark.jpg", trait: .init(userInterfaceStyle: .light, displayScale: .standard), expectedURL: images[1], manager: manager)
        assertIsRegistered(named: "wuphf.jpeg", trait: .init(userInterfaceStyle: .light, displayScale: .standard), expectedURL: images[2], manager: manager)
        assertIsRegistered(named: "woof.png", trait: .init(userInterfaceStyle: .light, displayScale: .standard), expectedURL: images[3], manager: manager)
        
        // The asset manager should contain not dark images.
        
        XCTAssertEqual(manager.data(named: "bark.jpg", bestMatching: .init(userInterfaceStyle: .dark))?.traitCollection, .init(userInterfaceStyle: .light, displayScale: .standard))
        XCTAssertEqual(manager.data(named: "wuphf.jpeg", bestMatching: .init(userInterfaceStyle: .dark))?.traitCollection, .init(userInterfaceStyle: .light, displayScale: .standard))
        XCTAssertEqual(manager.data(named: "woof.png", bestMatching: .init(userInterfaceStyle: .dark))?.traitCollection, .init(userInterfaceStyle: .light, displayScale: .standard))
    }
    
    func testWithDarkVariants() throws {
        var manager = DataAssetManager()
        let images = [
            "Documentation/woof.png",
            "Documentation/woof~dark.png",
            "bark.jpg",
            "bark~dark.jpg",
            "wuphf.jpeg",
            "wuphf~dark.jpeg",
        ].compactMap(URL.init(string:))
        try manager.register(data: images)
        
        XCTAssertEqual(manager.storage.values.count, 3)
        
        // The asset manager should contain all the light and dark variants.
        
        assertIsRegistered(named: "woof.png", trait: .init(userInterfaceStyle: .light, displayScale: .standard), expectedURL: images[0], manager: manager)
        assertIsRegistered(named: "woof.png", trait: .init(userInterfaceStyle: .dark, displayScale: .standard), expectedURL: images[1], manager: manager)
        
        assertIsRegistered(named: "bark.jpg", trait: .init(userInterfaceStyle: .light, displayScale: .standard), expectedURL: images[2], manager: manager)
        assertIsRegistered(named: "bark.jpg", trait: .init(userInterfaceStyle: .dark, displayScale: .standard), expectedURL: images[3], manager: manager)
        
        assertIsRegistered(named: "wuphf.jpeg", trait: .init(userInterfaceStyle: .light, displayScale: .standard), expectedURL: images[4], manager: manager)
        assertIsRegistered(named: "wuphf.jpeg", trait: .init(userInterfaceStyle: .dark, displayScale: .standard), expectedURL: images[5], manager: manager)
    }
    
    func testImageDisplayScale() throws {
        var manager = DataAssetManager()
        let images = [
            "woof.png",
            "woof~dark.png",
            "woof~dark@2x.png",
            "woof~dark@3x.png",
            "woof@2x.png",
            "woof@3x.png",
            "bark.jpg",
            "bark~dark.jpg",
            "bark~dark@2x.jpg",
        ].compactMap(URL.init(string:))
        try manager.register(data: images)
        
        XCTAssertEqual(manager.storage.values.count, 2)
        
        // The asset manager should contain all the light and dark variants, plus pixel density versions.
        
        assertIsRegistered(named: "woof.png", trait: .init(userInterfaceStyle: .light, displayScale: .standard), expectedURL: images[0], manager: manager)
        assertIsRegistered(named: "woof.png", trait: .init(userInterfaceStyle: .dark, displayScale: .standard), expectedURL: images[1], manager: manager)
        
        assertIsRegistered(named: "woof.png", trait: .init(userInterfaceStyle: .dark, displayScale: .double), expectedURL: images[2], manager: manager)
        assertIsRegistered(named: "woof.png", trait: .init(userInterfaceStyle: .dark, displayScale: .triple), expectedURL: images[3], manager: manager)
        
        assertIsRegistered(named: "woof.png", trait: .init(userInterfaceStyle: .light, displayScale: .double), expectedURL: images[4], manager: manager)
        assertIsRegistered(named: "woof.png", trait: .init(userInterfaceStyle: .light, displayScale: .triple), expectedURL: images[5], manager: manager)
        
        assertIsRegistered(named: "bark.jpg", trait: .init(userInterfaceStyle: .light, displayScale: .standard), expectedURL: images[6], manager: manager)
        assertIsRegistered(named: "bark.jpg", trait: .init(userInterfaceStyle: .dark, displayScale: .standard), expectedURL: images[7], manager: manager)
        assertIsRegistered(named: "bark.jpg", trait: .init(userInterfaceStyle: .dark, displayScale: .double), expectedURL: images[8], manager: manager)
    }
    
    func testTraitCollection() {
        let lightTrait = DataTraitCollection(userInterfaceStyle: .light)
        let darkTrait = DataTraitCollection(userInterfaceStyle: .dark, displayScale: .double)
        let trait = DataTraitCollection(traitsFrom: [lightTrait, darkTrait])
        
        XCTAssertEqual(trait.userInterfaceStyle, .dark)
        XCTAssertEqual(trait.displayScale, .double)
        
        let trait2 = DataTraitCollection(traitsFrom: [lightTrait, darkTrait, lightTrait])
        
        XCTAssertEqual(trait2.userInterfaceStyle, .light)
        XCTAssertEqual(trait2.displayScale, .double)
    }
    
    // Under the default settings this test will use `NSImage` under macOS
    func testImageSize() throws {
        let imageFile = Bundle.module.url(
            forResource: "image", withExtension: "png", subdirectory: "Test Resources")!
        XCTAssertTrue(FileManager.default.fileExists(atPath: imageFile.path))

        // Create the manager
        let workspace = DocumentationWorkspace()
        let bundle = try testBundleFromRootURL(named: "TestBundle")
        let bundleURL = Bundle.module.url(
            forResource: "TestBundle", withExtension: "docc", subdirectory: "Test Bundles")!
        let dataProvider = try LocalFileSystemDataProvider(rootURL: bundleURL)
        try workspace.registerProvider(dataProvider)
        
        var manager = DataAssetManager()
        
        // Register an image asset
        let imageFileURL = bundleURL.appendingPathComponent("figure1.png")
        try manager
            .register(data: [imageFileURL], dataProvider: workspace, bundle: bundle)

        // Check the asset is registered
        guard !manager.storage.values.isEmpty else {
            XCTFail("Failed to register image asset")
            return
        }
        assertIsRegistered(named: imageFileURL.lastPathComponent, trait: .init(userInterfaceStyle: .light, displayScale: .standard), expectedURL: imageFileURL, manager: manager)
    }
    
    func testUpdateAsset() throws {
        var manager = DataAssetManager()
        let images = [URL(string: "woof.png")!]
        try manager.register(data: images)
        
        XCTAssertEqual(manager.storage.count, 1)
        
        // Fetch the asset.
        guard var resolvedAsset = manager.allData(named: "woof.png") else {
            XCTFail("Failed to resolve registered asset")
            return
        }
        
        // Modify the asset
        resolvedAsset.context = .download
        
        // Update the manager storage
        manager.update(name: "woof.png", asset: resolvedAsset)
        
        // Fetch the updated asset.
        guard let updatedAsset = manager.allData(named: "woof.png") else {
            XCTFail("Failed to resolve updated asset")
            return
        }

        // Verify it's the up to date asset.
        XCTAssertEqual(updatedAsset.context, .download)
    }

    func testNonExistingAssets() throws {
        var manager = DataAssetManager()
        let images = ["image.png"].compactMap(URL.init(string:))
        try manager.register(data: images)
        
        XCTAssertNil(manager.allData(named: "blip"))
        XCTAssertNil(manager.allData(named: "image.jpg"))
        XCTAssertNotNil(manager.allData(named: "image.png"))
    }
    
    func testLoadsImagesWithIdenticalNameSuffixes() throws {
        var manager = DataAssetManager()
        let images = [
            "image.png",
            "assets/different_image.png",
        ].compactMap(URL.init(string:))
        try manager.register(data: images)
        
        XCTAssertEqual(manager.allData(named: "image")?.variants.first?.value.path, "image.png")
        XCTAssertEqual(manager.allData(named: "image.png")?.variants.first?.value.path, "image.png")
        
        XCTAssertEqual(manager.allData(named: "different_image")?.variants.first?.value.path, "assets/different_image.png")
        XCTAssertEqual(manager.allData(named: "different_image.png")?.variants.first?.value.path, "assets/different_image.png")
        XCTAssertNil(manager.allData(named: "assets/different_image.png"))
    }
    
    func testFuzzyLookup() throws {
        var manager = DataAssetManager()
        let images = [
            "image.png",
            "woof~dark.JPG",
        ].compactMap(URL.init(string:))
        try manager.register(data: images)

        // The fuzzy lookup will match "name" to "name.png"
        XCTAssertEqual(manager.allData(named: "image")?.variants.first?.value.path, "image.png")
        // But not "name.ext1" to "name.ext2"
        XCTAssertNil(manager.allData(named: "image.JPG"))
        
        XCTAssertNil(manager.allData(named: "woof.jpg"))
        XCTAssertEqual(manager.allData(named: "woof.JPG")?.variants.first?.value.path, "woof~dark.JPG")
        XCTAssertEqual(manager.allData(named: "woof")?.variants.first?.value.path, "woof~dark.JPG")
    }
    
    func testFuzzyLookupIndex() throws {
        var manager = DataAssetManager()
        
        // Test that we build the fuzzy index
        let images = [
            "image@2x.png",
            "assets/woof.JPG",
        ].compactMap(URL.init(string:))
        try manager.register(data: images)
        XCTAssertEqual(manager.fuzzyKeyIndex.keys.sorted().map({"\($0)"}), ["image", "woof"])

        // Test we include only unique keys in the fuzzy index
        let imagesWithDuplicates = [
            "image@2x.png",
            "assets/woof.JPG",
            "woof.png",
        ].compactMap(URL.init(string:))
        try manager.register(data: imagesWithDuplicates)
        XCTAssertEqual(manager.fuzzyKeyIndex.keys.sorted().map({"\($0)"}), ["image", "woof"])
    }
}
