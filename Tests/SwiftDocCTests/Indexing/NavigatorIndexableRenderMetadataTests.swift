/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import XCTest
@testable import SwiftDocC

class NavigatorIndexableRenderMetadataTests: XCTestCase {
    
    // MARK: - Test Helper Methods
    
    /// Creates a test platform with the specified beta status
    private func createPlatform(name: String, isBeta: Bool) -> AvailabilityRenderItem {
        return AvailabilityRenderItem(name: name, introduced: "1.0", isBeta: isBeta)
    }
    
    /// Creates a RenderMetadata instance with the specified platforms
    private func createRenderMetadata(platforms: [AvailabilityRenderItem]?) -> RenderMetadata {
        var metadata = RenderMetadata()
        metadata.platforms = platforms
        return metadata
    }
    
    /// Creates a RenderMetadataVariantView with the specified platforms
    private func createRenderMetadataVariantView(platforms: [AvailabilityRenderItem]?) -> RenderMetadataVariantView {
        let metadata = createRenderMetadata(platforms: platforms)
        return RenderMetadataVariantView(wrapped: metadata, traits: [])
    }
    
    // MARK: - RenderMetadataVariantView Tests
    
    func testRenderMetadataVariantViewIsBeta() {
        var metadataView = createRenderMetadataVariantView(platforms: nil)
        XCTAssertFalse(metadataView.isBeta, "isBeta should be false when no platforms are defined")
        
        metadataView = createRenderMetadataVariantView(platforms: [])
        XCTAssertFalse(metadataView.isBeta, "isBeta should be false when platforms array is empty")
        
        metadataView = createRenderMetadataVariantView(platforms: [
            createPlatform(name: "iOS", isBeta: false)
        ])
        XCTAssertFalse(metadataView.isBeta, "isBeta should be false when single platform is non-beta")

        metadataView = createRenderMetadataVariantView(platforms: [
            createPlatform(name: "iOS", isBeta: false),
            createPlatform(name: "macOS", isBeta: false),
            createPlatform(name: "watchOS", isBeta: false)
        ])
        XCTAssertFalse(metadataView.isBeta, "isBeta should be false when multiple platforms are non-beta")
                
        var platform1 = AvailabilityRenderItem(name: "iOS", introduced: "1.0", isBeta: false)
        platform1.isBeta = nil
        var platform2 = AvailabilityRenderItem(name: "macOS", introduced: "1.0", isBeta: false)
        platform2.isBeta = nil

        metadataView = createRenderMetadataVariantView(platforms: [platform1, platform2])
        XCTAssertFalse(metadataView.isBeta, "isBeta should be false when platforms have nil beta status")

        metadataView = createRenderMetadataVariantView(platforms: [
            createPlatform(name: "iOS", isBeta: true),
            createPlatform(name: "macOS", isBeta: false),
            createPlatform(name: "watchOS", isBeta: true)
        ])
        XCTAssertFalse(metadataView.isBeta, "isBeta should be false when some platforms are beta and some are non-beta")
        
        metadataView = createRenderMetadataVariantView(platforms: [
            createPlatform(name: "iOS", isBeta: true)
        ])
        XCTAssertTrue(metadataView.isBeta, "isBeta should be true when single platform is beta")
        
        metadataView = createRenderMetadataVariantView(platforms: [
            createPlatform(name: "iOS", isBeta: true),
            createPlatform(name: "macOS", isBeta: true),
            createPlatform(name: "watchOS", isBeta: true)
        ])
        XCTAssertTrue(metadataView.isBeta, "isBeta should be true when multiple platforms are beta")
    }
    
    // MARK: - RenderMetadata Tests
    
    func testRenderMetadataIsBeta() {
        var metadata = createRenderMetadata(platforms: nil)
        XCTAssertFalse(metadata.isBeta, "isBeta should be false when no platforms are defined")
        
        metadata = createRenderMetadata(platforms: [])
        XCTAssertFalse(metadata.isBeta, "isBeta should be false when platforms array is empty")
        
        metadata = createRenderMetadata(platforms: [
            createPlatform(name: "macOS", isBeta: false)
        ])
        XCTAssertFalse(metadata.isBeta, "isBeta should be false when single platform is non-beta")
        
        metadata = createRenderMetadata(platforms: [
            createPlatform(name: "iOS", isBeta: false),
            createPlatform(name: "macOS", isBeta: false),
            createPlatform(name: "tvOS", isBeta: false)
        ])
        XCTAssertFalse(metadata.isBeta, "isBeta should be false when all platforms are non-beta")
        
        var platform1 = AvailabilityRenderItem(name: "iOS", introduced: "1.0", isBeta: false)
        platform1.isBeta = nil
        var platform2 = AvailabilityRenderItem(name: "macOS", introduced: "1.0", isBeta: false)
        platform2.isBeta = nil
        
        metadata = createRenderMetadata(platforms: [platform1, platform2])
        XCTAssertFalse(metadata.isBeta, "isBeta should be false when platforms have nil beta status")
        
        metadata = createRenderMetadata(platforms: [
            createPlatform(name: "iOS", isBeta: false),
            createPlatform(name: "macOS", isBeta: true),
            createPlatform(name: "tvOS", isBeta: false)
        ])
        XCTAssertFalse(metadata.isBeta, "isBeta should be false when some platforms are beta and some are non-beta")
        
        metadata = createRenderMetadata(platforms: [
            createPlatform(name: "macOS", isBeta: true)
        ])
        XCTAssertTrue(metadata.isBeta, "isBeta should be true when single platform is beta")
        
        metadata = createRenderMetadata(platforms: [
            createPlatform(name: "iOS", isBeta: true),
            createPlatform(name: "macOS", isBeta: true),
            createPlatform(name: "tvOS", isBeta: true)
        ])
        XCTAssertTrue(metadata.isBeta, "isBeta should be true when all platforms are beta")
    }
}
