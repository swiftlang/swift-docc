/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import XCTest
@testable import SwiftDocC

class PlatformAvailabilityTests: XCTestCase {
    func testDecodePlatformAvailability() throws {
        let platformAvailabilityURL = Bundle.module.url(
            forResource: "platform-availability", withExtension: "json", subdirectory: "Rendering Fixtures")!
        
        let data = try Data(contentsOf: platformAvailabilityURL)
        let symbol = try RenderNode.decode(fromJSON: data)
        
        guard let platforms = symbol.metadata.platforms else {
            XCTFail("No platform data found in fixture")
            return
        }
        
        // The "macOS" platform in the fixture is unconditionally deprecated
        XCTAssertEqual(true, platforms.first { $0.name == "macOS" }?.unconditionallyDeprecated)

        // The "iOS" platform in the fixture is unconditionally unavailable
        XCTAssertEqual(true, platforms.first { $0.name == "iOS" }?.unconditionallyUnavailable)
    }

    /// Ensure that adding `@Available` directives in an article causes the final RenderNode to contain the appropriate availability data.
    func testPlatformAvailabilityFromArticle() throws {
        let (bundle, context) = try testBundleAndContext(named: "AvailabilityBundle")
        let reference = ResolvedTopicReference(
            bundleIdentifier: bundle.identifier,
            path: "/documentation/AvailableArticle",
            sourceLanguage: .swift
        )
        let article = try XCTUnwrap(context.entity(with: reference).semantic as? Article)
        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: reference)
        let renderNode = try XCTUnwrap(translator.visitArticle(article) as? RenderNode)
        let availability = try XCTUnwrap(renderNode.metadata.platformsVariants.defaultValue)
        XCTAssertEqual(availability.count, 1)
        let iosAvailability = try XCTUnwrap(availability.first)
        XCTAssertEqual(iosAvailability.name, "iOS")
        XCTAssertEqual(iosAvailability.introduced, "16.0")
        XCTAssert(iosAvailability.isBeta != true)
    }

    /// Ensure that adding `@Available` directives in an extension file overrides the symbol's availability.
    func testPlatformAvailabilityFromExtension() throws {
        let (bundle, context) = try testBundleAndContext(named: "AvailabilityBundle")
        let reference = ResolvedTopicReference(
            bundleIdentifier: bundle.identifier,
            path: "/documentation/MyKit/MyClass",
            sourceLanguage: .swift
        )
        let symbol = try XCTUnwrap(context.entity(with: reference).semantic as? Symbol)
        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: reference)
        let renderNode = try XCTUnwrap(translator.visitSymbol(symbol) as? RenderNode)
        let availability = try XCTUnwrap(renderNode.metadata.platformsVariants.defaultValue)
        XCTAssertEqual(availability.count, 1)
        let iosAvailability = try XCTUnwrap(availability.first)
        XCTAssertEqual(iosAvailability.name, "iOS")
        XCTAssertEqual(iosAvailability.introduced, "16.0")
        XCTAssert(iosAvailability.isBeta != true)
    }

    func testMultiplePlatformAvailabilityFromArticle() throws {
        let (bundle, context) = try testBundleAndContext(named: "AvailabilityBundle")
        let reference = ResolvedTopicReference(
            bundleIdentifier: bundle.identifier,
            path: "/documentation/AvailabilityBundle/ComplexAvailable",
            sourceLanguage: .swift
        )
        let article = try XCTUnwrap(context.entity(with: reference).semantic as? Article)
        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: reference)
        let renderNode = try XCTUnwrap(translator.visitArticle(article) as? RenderNode)
        let availability = try XCTUnwrap(renderNode.metadata.platformsVariants.defaultValue)
        XCTAssertEqual(availability.count, 3)

        XCTAssert(availability.contains(where: { item in
            item.name == "iOS" && item.introduced == "15.0"
        }))
        XCTAssert(availability.contains(where: { item in
            item.name == "macOS" && item.introduced == "12.0"
        }))
        XCTAssert(availability.contains(where: { item in
            item.name == "watchOS" && item.introduced == "7.0"
        }))
        
        XCTAssert(availability.allSatisfy { item in
            item.isBeta != true
        })
    }

    func testArbitraryPlatformAvailability() throws {
        let (bundle, context) = try testBundleAndContext(named: "AvailabilityBundle")
        let reference = ResolvedTopicReference(
            bundleIdentifier: bundle.identifier,
            path: "/documentation/AvailabilityBundle/ArbitraryPlatforms",
            sourceLanguage: .swift
        )
        let article = try XCTUnwrap(context.entity(with: reference).semantic as? Article)
        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: reference)
        let renderNode = try XCTUnwrap(translator.visitArticle(article) as? RenderNode)
        let availability = try XCTUnwrap(renderNode.metadata.platformsVariants.defaultValue)
        XCTAssertEqual(availability.count, 2)

        XCTAssert(availability.contains(where: { item in
            item.name == "SomePackage" && item.introduced == "1.0"
        }))
        XCTAssert(availability.contains(where: { item in
            item.name == "My Package" && item.introduced == "2.0"
        }))
        XCTAssert(availability.allSatisfy { item in
            item.isBeta != true
        })
    }
    
    // Test that the Info.plist default availability does not affect the deprecated/unavailable availabilities provided by the symbol graph.
    func testAvailabilityParserWithInfoPlistDefaultAvailability() throws {
        let (bundle, context) = try testBundleAndContext(named: "AvailabilityOverrideBundle")

        let reference = ResolvedTopicReference(
            bundleIdentifier: bundle.identifier,
            path: "/documentation/MyKit/MyClass",
            sourceLanguage: .swift
        )
        let symbol = try XCTUnwrap(context.entity(with: reference).semantic as? Symbol)
        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: reference)
        let renderNode = try XCTUnwrap(translator.visitSymbol(symbol) as? RenderNode)
        let availability = try XCTUnwrap(renderNode.metadata.platformsVariants.defaultValue)
        XCTAssertEqual(availability.count, 5)
        XCTAssert(availability.contains(where: { platform in
            platform.name == "iOS" && platform.deprecated != nil
        }))
        XCTAssert(availability.contains(where: { platform in
            platform.name == "macOS" && platform.deprecated != nil
        }))
        XCTAssert(availability.contains(where: { platform in
            platform.name == "watchOS" && platform.deprecated != nil
        }))
        XCTAssert(availability.contains(where: { platform in
            platform.name == "Mac Catalyst" && platform.deprecated != nil
        }))
        XCTAssert(availability.contains(where: { platform in
            platform.name == "iPadOS" && platform.deprecated != nil
        }))
        XCTAssertFalse(availability.contains(where: { platform in
            platform.name == "tvOS"
        }))
        XCTAssert(availability.allSatisfy { item in
            item.isBeta != true
        })
    }
    
    /// Ensure that adding `@Available` directives for platform versions marked as beta in an article causes the final RenderNode to contain the appropriate availability data.
    func testBetaPlatformAvailabilityFromArticle() throws {
        let platformMetadata = [
            "iOS": PlatformVersion(VersionTriplet(16, 0, 0), beta: true),
        ]
        let (bundle, context) = try testBundleWithConfiguredPlatforms(named: "AvailabilityBundle", platformMetadata: platformMetadata)
        let reference = ResolvedTopicReference(
            bundleIdentifier: bundle.identifier,
            path: "/documentation/AvailableArticle",
            sourceLanguage: .swift
        )
        let article = try XCTUnwrap(context.entity(with: reference).semantic as? Article)
        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: reference)
        let renderNode = try XCTUnwrap(translator.visitArticle(article) as? RenderNode)
        let availability = try XCTUnwrap(renderNode.metadata.platformsVariants.defaultValue)
        XCTAssertEqual(availability.count, 1)
        let iosAvailability = try XCTUnwrap(availability.first)
        XCTAssertEqual(iosAvailability.name, "iOS")
        XCTAssertEqual(iosAvailability.introduced, "16.0")
        XCTAssert(iosAvailability.isBeta == true)
    }

    func testMultipleBetaPlatformAvailabilityFromArticle() throws {
        let platformMetadata = [
            "iOS": PlatformVersion(VersionTriplet(15, 0, 0), beta: true),
            "macOS": PlatformVersion(VersionTriplet(12, 0, 0), beta: true),
            "watchOS": PlatformVersion(VersionTriplet(7, 0, 0), beta: true),
        ]
        let (bundle, context) = try testBundleWithConfiguredPlatforms(named: "AvailabilityBundle", platformMetadata: platformMetadata)
        let reference = ResolvedTopicReference(
            bundleIdentifier: bundle.identifier,
            path: "/documentation/AvailabilityBundle/ComplexAvailable",
            sourceLanguage: .swift
        )
        let article = try XCTUnwrap(context.entity(with: reference).semantic as? Article)
        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: reference)
        let renderNode = try XCTUnwrap(translator.visitArticle(article) as? RenderNode)
        let availability = try XCTUnwrap(renderNode.metadata.platformsVariants.defaultValue)
        XCTAssertEqual(availability.count, 3)

        XCTAssert(availability.contains(where: { item in
            item.name == "iOS" && item.introduced == "15.0"
        }))
        XCTAssert(availability.contains(where: { item in
            item.name == "macOS" && item.introduced == "12.0"
        }))
        XCTAssert(availability.contains(where: { item in
            item.name == "watchOS" && item.introduced == "7.0"
        }))
        
        XCTAssert(availability.allSatisfy { item in
            item.isBeta == true
        })
    }
    
    /// Ensure that adding `@Available` directives in an extension file overrides the symbol's availability.
    func testBetaPlatformAvailabilityFromExtension() throws {
        let platformMetadata = [
            "iOS": PlatformVersion(VersionTriplet(16, 0, 0), beta: true),
        ]
        let (bundle, context) = try testBundleWithConfiguredPlatforms(named: "AvailabilityBundle", platformMetadata: platformMetadata)
        let reference = ResolvedTopicReference(
            bundleIdentifier: bundle.identifier,
            path: "/documentation/MyKit/MyClass",
            sourceLanguage: .swift
        )
        let symbol = try XCTUnwrap(context.entity(with: reference).semantic as? Symbol)
        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: reference)
        let renderNode = try XCTUnwrap(translator.visitSymbol(symbol) as? RenderNode)
        let availability = try XCTUnwrap(renderNode.metadata.platformsVariants.defaultValue)
        XCTAssertEqual(availability.count, 1)
        let iosAvailability = try XCTUnwrap(availability.first)
        XCTAssertEqual(iosAvailability.name, "iOS")
        XCTAssertEqual(iosAvailability.introduced, "16.0")
        XCTAssert(iosAvailability.isBeta == true)
    }

    
    func testBundleWithConfiguredPlatforms(named testBundleName: String, platformMetadata: [String : PlatformVersion]) throws -> (DocumentationBundle, DocumentationContext) {
        let bundleURL = try XCTUnwrap(Bundle.module.url(forResource: testBundleName, withExtension: "docc", subdirectory: "Test Bundles"))
        let (_, bundle, context) = try loadBundle(from: bundleURL) { context in
            context.externalMetadata.currentPlatforms = platformMetadata
        }
        return (bundle, context)
    }

}
