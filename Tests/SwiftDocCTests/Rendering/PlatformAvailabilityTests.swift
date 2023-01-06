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
        var translator = RenderNodeTranslator(
            context: context,
            bundle: bundle,
            identifier: reference,
            source: nil
        )
        let renderNode = try XCTUnwrap(translator.visitArticle(article) as? RenderNode)
        let availability = try XCTUnwrap(renderNode.metadata.platformsVariants.defaultValue)
        XCTAssertEqual(availability.count, 1)
        let iosAvailability = try XCTUnwrap(availability.first)
        XCTAssertEqual(iosAvailability.name, "iOS")
        XCTAssertEqual(iosAvailability.introduced, "16.0")
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
        var translator = RenderNodeTranslator(
            context: context,
            bundle: bundle,
            identifier: reference,
            source: nil
        )
        let renderNode = try XCTUnwrap(translator.visitSymbol(symbol) as? RenderNode)
        let availability = try XCTUnwrap(renderNode.metadata.platformsVariants.defaultValue)
        XCTAssertEqual(availability.count, 1)
        let iosAvailability = try XCTUnwrap(availability.first)
        XCTAssertEqual(iosAvailability.name, "iOS")
        XCTAssertEqual(iosAvailability.introduced, "16.0")
    }

    func testMultiplePlatformAvailabilityFromArticle() throws {
        let (bundle, context) = try testBundleAndContext(named: "AvailabilityBundle")
        let reference = ResolvedTopicReference(
            bundleIdentifier: bundle.identifier,
            path: "/documentation/AvailabilityBundle/ComplexAvailable",
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
    }
}
