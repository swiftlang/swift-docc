/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Testing
@testable import SwiftDocC

struct DataAssetManagerTests {

    func assertIsRegistered(named name: String, trait: DataTraitCollection, expectedURL: URL, manager: DataAssetManager, sourceLocation: SourceLocation = #_sourceLocation) throws {
        let data = try #require(manager.data(named: name, bestMatching: trait), sourceLocation: sourceLocation)
        #expect(data.url == expectedURL, sourceLocation: sourceLocation)
        #expect(data.traitCollection == trait, sourceLocation: sourceLocation)
    }

    @Test
    func registersImagesWithoutDarkVariants() throws {
        var manager = DataAssetManager()
        let images = ["Documentation/woof.png", "bark.jpg", "wuphf.jpeg", "woof.png"].compactMap(URL.init(string:))
        try manager.register(data: images)

        #expect(manager.storage.values.count == 3)

        // The asset manager should contain all the images.
        try assertIsRegistered(named: "bark.jpg", trait: .init(userInterfaceStyle: .light, displayScale: .standard), expectedURL: images[1], manager: manager)
        try assertIsRegistered(named: "wuphf.jpeg", trait: .init(userInterfaceStyle: .light, displayScale: .standard), expectedURL: images[2], manager: manager)
        try assertIsRegistered(named: "woof.png", trait: .init(userInterfaceStyle: .light, displayScale: .standard), expectedURL: images[3], manager: manager)

        // The asset manager should contain not dark images.
        let expectedFallback = DataTraitCollection(userInterfaceStyle: .light, displayScale: .standard)
        for name in ["bark.jpg", "wuphf.jpeg", "woof.png"] {
            #expect(manager.data(named: name, bestMatching: .init(userInterfaceStyle: .dark))?.traitCollection == expectedFallback)
        }
    }

    @Test
    func registersLightAndDarkVariants() throws {
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

        #expect(manager.storage.values.count == 3)

        // The asset manager should contain all the light and dark variants.
        try assertIsRegistered(named: "woof.png", trait: .init(userInterfaceStyle: .light, displayScale: .standard), expectedURL: images[0], manager: manager)
        try assertIsRegistered(named: "woof.png", trait: .init(userInterfaceStyle: .dark, displayScale: .standard), expectedURL: images[1], manager: manager)

        try assertIsRegistered(named: "bark.jpg", trait: .init(userInterfaceStyle: .light, displayScale: .standard), expectedURL: images[2], manager: manager)
        try assertIsRegistered(named: "bark.jpg", trait: .init(userInterfaceStyle: .dark, displayScale: .standard), expectedURL: images[3], manager: manager)

        try assertIsRegistered(named: "wuphf.jpeg", trait: .init(userInterfaceStyle: .light, displayScale: .standard), expectedURL: images[4], manager: manager)
        try assertIsRegistered(named: "wuphf.jpeg", trait: .init(userInterfaceStyle: .dark, displayScale: .standard), expectedURL: images[5], manager: manager)
    }

    @Test
    func registersDisplayScaleVariants() throws {
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

        #expect(manager.storage.values.count == 2)

        // The asset manager should contain all the light and dark variants, plus pixel density versions.
        try assertIsRegistered(named: "woof.png", trait: .init(userInterfaceStyle: .light, displayScale: .standard), expectedURL: images[0], manager: manager)
        try assertIsRegistered(named: "woof.png", trait: .init(userInterfaceStyle: .dark, displayScale: .standard), expectedURL: images[1], manager: manager)

        try assertIsRegistered(named: "woof.png", trait: .init(userInterfaceStyle: .dark, displayScale: .double), expectedURL: images[2], manager: manager)
        try assertIsRegistered(named: "woof.png", trait: .init(userInterfaceStyle: .dark, displayScale: .triple), expectedURL: images[3], manager: manager)

        try assertIsRegistered(named: "woof.png", trait: .init(userInterfaceStyle: .light, displayScale: .double), expectedURL: images[4], manager: manager)
        try assertIsRegistered(named: "woof.png", trait: .init(userInterfaceStyle: .light, displayScale: .triple), expectedURL: images[5], manager: manager)

        try assertIsRegistered(named: "bark.jpg", trait: .init(userInterfaceStyle: .light, displayScale: .standard), expectedURL: images[6], manager: manager)
        try assertIsRegistered(named: "bark.jpg", trait: .init(userInterfaceStyle: .dark, displayScale: .standard), expectedURL: images[7], manager: manager)
        try assertIsRegistered(named: "bark.jpg", trait: .init(userInterfaceStyle: .dark, displayScale: .double), expectedURL: images[8], manager: manager)
    }

    @Test
    func mergesTraitCollections() {
        let lightTrait = DataTraitCollection(userInterfaceStyle: .light)
        let darkTrait = DataTraitCollection(userInterfaceStyle: .dark, displayScale: .double)
        let trait = DataTraitCollection(traitsFrom: [lightTrait, darkTrait])

        #expect(trait.userInterfaceStyle == .dark)
        #expect(trait.displayScale == .double)

        let trait2 = DataTraitCollection(traitsFrom: [lightTrait, darkTrait, lightTrait])

        #expect(trait2.userInterfaceStyle == .light)
        #expect(trait2.displayScale == .double)
    }

    // Under the default settings this test will use `NSImage` under macOS
    @Test
    func registersImageFromDisk() throws {
        let imageFileURL = try #require(
            Bundle.module.url(forResource: "image", withExtension: "png", subdirectory: "Test Resources")
        )
        #expect(FileManager.default.fileExists(atPath: imageFileURL.path))

        var manager = DataAssetManager()

        // Register an image asset
        try manager.register(data: [imageFileURL])

        // Check the asset is registered
        try assertIsRegistered(named: imageFileURL.lastPathComponent, trait: .init(userInterfaceStyle: .light, displayScale: .standard), expectedURL: imageFileURL, manager: manager)
    }

    @Test
    func updatesRegisteredAsset() throws {
        var manager = DataAssetManager()
        let images = [URL(string: "woof.png")!]
        try manager.register(data: images)

        #expect(manager.storage.count == 1)

        // Fetch the asset.
        var resolvedAsset = try #require(manager.allData(named: "woof.png"))

        // Modify the asset
        resolvedAsset.context = .download

        // Update the manager storage
        manager.update(name: "woof.png", asset: resolvedAsset)

        // Fetch the updated asset.
        let updatedAsset = try #require(manager.allData(named: "woof.png"))

        // Verify it's the up to date asset.
        #expect(updatedAsset.context == .download)
    }

    @Test(arguments: [
        (name: "blip", isRegistered: false),
        (name: "image.jpg", isRegistered: false),
        (name: "image.png", isRegistered: true),
    ])
    func resolvesOnlyRegisteredAssets(name: String, isRegistered: Bool) throws {
        var manager = DataAssetManager()
        try manager.register(data: ["image.png"].compactMap(URL.init(string:)))

        if isRegistered {
            #expect(manager.allData(named: name) != nil)
        } else {
            #expect(manager.allData(named: name) == nil)
        }
    }

    @Test
    func loadsImagesWithIdenticalNameSuffixes() throws {
        var manager = DataAssetManager()
        let images = [
            "image.png",
            "assets/different_image.png",
        ].compactMap(URL.init(string:))
        try manager.register(data: images)

        #expect(manager.allData(named: "image")?.variants.first?.value.path == "image.png")
        #expect(manager.allData(named: "image.png")?.variants.first?.value.path == "image.png")

        #expect(manager.allData(named: "different_image")?.variants.first?.value.path == "assets/different_image.png")
        #expect(manager.allData(named: "different_image.png")?.variants.first?.value.path == "assets/different_image.png")
        #expect(manager.allData(named: "assets/different_image.png") == nil)
    }

    @Test
    func fuzzyLookupMatchesNameWithoutExtension() throws {
        var manager = DataAssetManager()
        let images = [
            "image.png",
            "woof~dark.JPG",
        ].compactMap(URL.init(string:))
        try manager.register(data: images)

        // The fuzzy lookup will match "name" to "name.png"
        #expect(manager.allData(named: "image")?.variants.first?.value.path == "image.png")
        // But not "name.ext1" to "name.ext2"
        #expect(manager.allData(named: "image.JPG") == nil)

        #expect(manager.allData(named: "woof.jpg") == nil)
        #expect(manager.allData(named: "woof.JPG")?.variants.first?.value.path == "woof~dark.JPG")
        #expect(manager.allData(named: "woof")?.variants.first?.value.path == "woof~dark.JPG")
    }

    @Test
    func buildsFuzzyKeyIndexWithUniqueKeys() throws {
        var manager = DataAssetManager()

        // Test that we build the fuzzy index
        let images = [
            "image@2x.png",
            "assets/woof.JPG",
        ].compactMap(URL.init(string:))
        try manager.register(data: images)
        #expect(manager.fuzzyKeyIndex.keys.sorted().map({ "\($0)" }) == ["image", "woof"])

        // Test we include only unique keys in the fuzzy index
        let imagesWithDuplicates = [
            "image@2x.png",
            "assets/woof.JPG",
            "woof.png",
        ].compactMap(URL.init(string:))
        try manager.register(data: imagesWithDuplicates)
        #expect(manager.fuzzyKeyIndex.keys.sorted().map({ "\($0)" }) == ["image", "woof"])
    }
}
