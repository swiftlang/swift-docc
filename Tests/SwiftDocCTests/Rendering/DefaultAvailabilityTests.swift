/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import XCTest
import SymbolKit
@testable import SwiftDocC

class DefaultAvailabilityTests: XCTestCase {

    // Test whether missing default availability key correctly produces nil availability
    func testBundleWithoutDefaultAvailability() throws {
        let bundle = try testBundle(named: "BundleWithoutAvailability")
        XCTAssertNil(bundle.info.defaultAvailability)
    }

    // Test resource with default availability included
    let infoPlistAvailabilityURL = Bundle.module.url(
        forResource: "Info+Availability", withExtension: "plist", subdirectory: "Test Resources")!
    
    let expectedDefaultAvailability = [
        "Mac Catalyst 13.5",
        "macOS 10.15.1",
    ]
    
    // Test whether the default availability is loaded from Info.plist and applied during render time
    func testBundleWithDefaultAvailability() throws {
        // Copy an Info.plist with default availability
        let (_, bundle, context) = try testBundleAndContext(copying: "TestBundle", excludingPaths: [], codeListings: [:]) { (url) in
            try? FileManager.default.removeItem(at: url.appendingPathComponent("Info.plist"))
            try? FileManager.default.copyItem(at: self.infoPlistAvailabilityURL, to: url.appendingPathComponent("Info.plist"))
            
            let myKitDocExtensionFile = url.appendingPathComponent("documentation", isDirectory: true).appendingPathComponent("mykit.md")
            var myKitDocExtension = try String(contentsOf: myKitDocExtensionFile)
            
            // Customize the display name of the MyKit module to verify that the default availability uses the Info.plist
            // information that's specified using the module's symbol name.
            let firstNewLineIndex = try XCTUnwrap(myKitDocExtension.firstIndex(of: "\n"))
            myKitDocExtension.insert(contentsOf: """
                
                @Metadata {
                  @DisplayName("MyKit custom display name")
                }
                
                """, at: myKitDocExtension.index(after: firstNewLineIndex))
            
            try myKitDocExtension.write(to: myKitDocExtensionFile, atomically: true, encoding: .utf8)
        }
        
        // Verify the bundle has loaded the default availability
        XCTAssertEqual(bundle.info.defaultAvailability?.modules["MyKit"]?.map({ "\($0.platformName.displayName) \($0.platformVersion)" }).sorted(), expectedDefaultAvailability)
        
        // Bail the rendering part of the test if the availability hasn't been loaded
        guard bundle.info.defaultAvailability != nil else {
            return
        }
        
        // Test if the default availability is used for modules
        do {
            let identifier = ResolvedTopicReference(bundleIdentifier: "org.swift.docc.example", path: "/documentation/MyKit", fragment: nil, sourceLanguage: .swift)
            let source = context.documentURL(for: identifier)
            let node = try context.entity(with: identifier)
            var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference, source: source)
            let renderNode = translator.visit(node.semantic) as! RenderNode
            
            XCTAssertEqual(renderNode.metadata.platforms?.map({ "\($0.name ?? "") \($0.introduced ?? "")" }).sorted(), expectedDefaultAvailability)
        }
        
        // Test if the default availability is used for symbols with no explicit availability
        do {
            let identifier = ResolvedTopicReference(bundleIdentifier: "org.swift.docc.example", path: "/documentation/MyKit/MyClass/init()-3743d", fragment: nil, sourceLanguage: .swift)
            let source = context.documentURL(for: identifier)
            let node = try context.entity(with: identifier)
            var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference, source: source)
            let renderNode = translator.visit(node.semantic) as! RenderNode
            
            XCTAssertEqual(renderNode.metadata.platforms?.map({ "\($0.name ?? "") \($0.introduced ?? "")" }).sorted(), expectedDefaultAvailability)
        }

        // Test if the default availability is NOT used for symbols with explicit availability
        do {
            let identifier = ResolvedTopicReference(bundleIdentifier: "org.swift.docc.example", path: "/documentation/MyKit/MyClass", fragment: nil, sourceLanguage: .swift)
            let source = context.documentURL(for: identifier)
            let node = try context.entity(with: identifier)
            var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference, source: source)
            let renderNode = translator.visit(node.semantic) as! RenderNode
            
            XCTAssertNotEqual(renderNode.metadata.platforms?.map({ "\($0.name ?? "") \($0.introduced ?? "")" }), expectedDefaultAvailability)
        }
    }
    
    // Test whether the default availability is merged with beta status from the command line
    func testBundleWithDefaultAvailabilityInBetaDocs() throws {
        // Copy an Info.plist with default availability
        let (_, bundle, context) = try testBundleAndContext(copying: "TestBundle", excludingPaths: [], codeListings: [:]) { (url) in
            try? FileManager.default.removeItem(at: url.appendingPathComponent("Info.plist"))
            try? FileManager.default.copyItem(at: self.infoPlistAvailabilityURL, to: url.appendingPathComponent("Info.plist"))
        }
        
        // Set a beta status for the docs (which would normally be set via command line argument)
        context.externalMetadata.currentPlatforms = [
            "macOS": PlatformVersion(VersionTriplet(10, 15, 1), beta: true),
            "Mac Catalyst": PlatformVersion(VersionTriplet(13, 5, 0), beta: true),
        ]
        
        // Test if the module availability is also "beta" for the "macOS" platform,
        // verify that the Mac Catalyst platform's name (including a space) is rendered correctly
        do {
            let identifier = ResolvedTopicReference(bundleIdentifier: "org.swift.docc.example", path: "/documentation/MyKit", fragment: nil, sourceLanguage: .swift)
            let source = context.documentURL(for: identifier)
            let node = try context.entity(with: identifier)
            var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference, source: source)
            let renderNode = translator.visit(node.semantic) as! RenderNode
            
            XCTAssertEqual(renderNode.metadata.platforms?.map({ "\($0.name ?? "") \($0.introduced ?? "")\($0.isBeta == true ? "(beta)" : "")" }).sorted(), [
                "Mac Catalyst 13.5(beta)",
                "macOS 10.15.1(beta)",
            ])
        }
    }

    private func assertRenderedPlatforms(for reference: ResolvedTopicReference, equal expected: [String], bundle: DocumentationBundle, context: DocumentationContext, file: StaticString = #file, line: UInt = #line) throws {
        // Test whether we:
        // 1) Fallback on iOS when Mac Catalyst availability is missing
        // 2) Render [Beta] or not for Mac Catalyst's inherited iOS availability
        let source = context.documentURL(for: reference)
        let node = try context.entity(with: reference)
        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: reference, source: source)
        let renderNode = translator.visit(node.semantic) as! RenderNode
        
        XCTAssertEqual(renderNode.metadata.platforms?.map({ "\($0.name ?? "") \($0.introduced ?? "")\($0.isBeta == true ? "(beta)" : "")" }).sorted(), expected, file: (file), line: line)
    }
    
    // Test whether when Mac Catalyst availability is missing we fall back on iOS availability
    func testBundleWithMissingCatalystAvailability() throws {
        // Copy an Info.plist with default availability
        let (_, bundle, context) = try testBundleAndContext(copying: "TestBundle", excludingPaths: [], codeListings: [:]) { (url) in
            do {
                try FileManager.default.removeItem(at: url.appendingPathComponent("Info.plist"))
                let infoPlist = try String(contentsOf: self.infoPlistAvailabilityURL)
                try infoPlist.replacingOccurrences(of: "Mac Catalyst", with: "iOS")
                    .write(to: url.appendingPathComponent("Info.plist"), atomically: true, encoding: .utf8)
            } catch  {
                XCTFail("Could not copy Info.plist with custom availability in the test bundle")
            }
        }

        let identifier = ResolvedTopicReference(bundleIdentifier: "org.swift.docc.example", path: "/documentation/MyKit", fragment: nil, sourceLanguage: .swift)

        // Set a beta status for both iOS and Mac Catalyst
        context.externalMetadata.currentPlatforms = [
            "iOS": PlatformVersion(VersionTriplet(13, 5, 0), beta: true),
            "Mac Catalyst": PlatformVersion(VersionTriplet(13, 5, 0), beta: true),
        ]
        
        try assertRenderedPlatforms(for: identifier, equal: [
            "Mac Catalyst 13.5(beta)",
            "iOS 13.5(beta)",
            "macOS 10.15.1",
        ], bundle: bundle, context: context)
        
        // Set a public status for both iOS and Mac Catalyst
        context.externalMetadata.currentPlatforms = [
            "iOS": PlatformVersion(VersionTriplet(13, 5, 0), beta: false),
            "Mac Catalyst": PlatformVersion(VersionTriplet(13, 5, 0), beta: false),
        ]
        
        try assertRenderedPlatforms(for: identifier, equal: [
            "Mac Catalyst 13.5",
            "iOS 13.5",
            "macOS 10.15.1",
        ], bundle: bundle, context: context)

        // Verify that a bug rendering availability as beta when
        // no platforms are provided is fixed.
        context.externalMetadata.currentPlatforms = [:]
        try assertRenderedPlatforms(for: identifier, equal: [
            "Mac Catalyst 13.5",
            "iOS 13.5",
            "macOS 10.15.1",
        ], bundle: bundle, context: context)
    }
    
    // Test whether the default availability is not beta when not matching current target platform
    func testBundleWithDefaultAvailabilityNotInBetaDocs() throws {
        // Copy an Info.plist with default availability of macOS 10.15.1
        let (_, bundle, context) = try testBundleAndContext(copying: "TestBundle", excludingPaths: [], codeListings: [:]) { (url) in
            try? FileManager.default.removeItem(at: url.appendingPathComponent("Info.plist"))
            try? FileManager.default.copyItem(at: self.infoPlistAvailabilityURL, to: url.appendingPathComponent("Info.plist"))
        }
        
        // Set a beta status for the docs (which would normally be set via command line argument)
        context.externalMetadata.currentPlatforms = ["macOS": PlatformVersion(VersionTriplet(10, 16, 0), beta: true)]
        
        // Test if the module availability is not "beta" for the "macOS" platform (since 10.15.1 != 10.16)
        do {
            let identifier = ResolvedTopicReference(bundleIdentifier: "org.swift.docc.example", path: "/documentation/MyKit", fragment: nil, sourceLanguage: .swift)
            let source = context.documentURL(for: identifier)
            let node = try context.entity(with: identifier)
            var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference, source: source)
            let renderNode = translator.visit(node.semantic) as! RenderNode
            
            XCTAssertEqual(renderNode.metadata.platforms?.map({ "\($0.name ?? "") \($0.introduced ?? "")\($0.isBeta == true ? "(beta)" : "")" }).sorted(), [
                "Mac Catalyst 13.5",
                "macOS 10.15.1",
            ])
        }
    }

    // Test that a symbol is unavailable and default availability does not precede the "unavailable" attribute.
    func testUnavailableAvailability() throws {
        let (_, bundle, context) = try testBundleAndContext(copying: "TestBundle", excludingPaths: [], codeListings: [:]) { _ in }
        
        // Set a beta status for the docs (which would normally be set via command line argument)
        context.externalMetadata.currentPlatforms = ["iOS": PlatformVersion(VersionTriplet(14, 0, 0), beta: true)]
        
        do {
            let identifier = ResolvedTopicReference(bundleIdentifier: "org.swift.docc.example", path: "/documentation/MyKit/MyClass/myFunction()", fragment: nil, sourceLanguage: .swift)
            let source = context.documentURL(for: identifier)
            let node = try context.entity(with: identifier)
            
            // Add some available and unavailable platforms to the symbol
            (node.semantic as? Symbol)?.availability = SymbolGraph.Symbol.Availability(availability: [
                // The symbol is available on iOS
                SymbolGraph.Symbol.Availability.AvailabilityItem(domain: .init(rawValue: "iOS"), introducedVersion: .init(major: 13, minor: 0, patch: 0), deprecatedVersion: nil, obsoletedVersion: nil, message: nil, renamed: nil, isUnconditionallyDeprecated: false, isUnconditionallyUnavailable: false, willEventuallyBeDeprecated: false),
                // The symbol is introduced but then removed
                SymbolGraph.Symbol.Availability.AvailabilityItem(domain: .init(rawValue: "tvOS"), introducedVersion: .init(major: 13, minor: 0, patch: 0), deprecatedVersion: nil, obsoletedVersion: nil, message: nil, renamed: nil, isUnconditionallyDeprecated: false, isUnconditionallyUnavailable: true, willEventuallyBeDeprecated: false),
                // The symbol is removed
                SymbolGraph.Symbol.Availability.AvailabilityItem(domain: .init(rawValue: "macOS"), introducedVersion: nil, deprecatedVersion: nil, obsoletedVersion: nil, message: nil, renamed: nil, isUnconditionallyDeprecated: false, isUnconditionallyUnavailable: true, willEventuallyBeDeprecated: false),
            ])
            
            var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference, source: source)
            let renderNode = translator.visit(node.semantic) as! RenderNode
            
            // Verify that the 'watchOS' & 'tvOS' platforms are filtered out because the symbol is unavailable
            XCTAssertEqual(renderNode.metadata.platforms?.map({ "\($0.name ?? "") \($0.introduced ?? "")\($0.isBeta == true ? "(beta)" : "")" }).sorted(), [
                "iOS 13.0",
            ])
        }
    }

    /// This test, along with `testInitializeWithCorrectAvailabilityWithRawValue`,
    /// verifies that `DefaultAvailability` is correctly initialized with only **one** Mac
    /// Catalyst `ModuleAvailability`.
    ///
    /// It used to be that if a bundle include "Mac Catalyst" in it's default availabilities , the ``ModuleAvailability``
    /// instances that were created would include an extra Mac Catalyst entry, where the ``PlatformName``s of
    /// the modules looked like this:
    ///
    /// ```
    /// {
    ///     rawValue: "macCatalyst",
    ///     displayName: "Mac Catalyst",
    ///     aliases: []
    /// },
    /// {
    ///     rawValue: "Mac Catalyst",
    ///     displayName: "Mac Catalyst",
    ///     aliases: []
    /// }
    /// ```
    ///
    /// - Bug: [rdar://71544773](rdar://71544773)
    func testInitializeWithCorrectAvailability() throws {
        let plistEntries: [String: [[String: String]]] = [
            "SwiftUI": [
                [
                    "name": "macOS",
                    "version": "10.15",
                ],
                [
                    "name": "iOS",
                    "version": "13.0",
                ],
                [
                    "name": "Mac Catalyst",
                    "version": "13.0",
                ],
                [
                    "name": "tvOS",
                    "version": "13.0",
                ],
                [
                    "name": "watchOS",
                    "version": "6.0",
                ],
            ],
        ]
        
        let plistData = try PropertyListEncoder().encode(plistEntries)
        let defaultAvailability = try PropertyListDecoder().decode(
            DefaultAvailability.self,
            from: plistData
        )
        
        let module = try XCTUnwrap(defaultAvailability.modules["SwiftUI"])
        XCTAssertEqual(module.count, 5)
        XCTAssertEqual(module.filter({ $0.platformName.displayName == "Mac Catalyst" }).count, 1)
    }

    func testInitializeWithCorrectAvailabilityWithRawValue() throws {
        let plistEntries: [String: [[String: String]]] = [
            "SwiftUI": [
                [
                    "name": "macOS",
                    "version": "10.15",
                ],
                [
                    "name": "iOS",
                    "version": "13.0",
                ],
                [
                    "name": "macCatalyst",
                    "version": "13.0",
                ],
                [
                    "name": "tvOS",
                    "version": "13.0",
                ],
                [
                    "name": "watchOS",
                    "version": "6.0",
                ],
            ],
        ]
        let plistData = try PropertyListEncoder().encode(plistEntries)
        let defaultAvailability = try PropertyListDecoder().decode(
            DefaultAvailability.self,
            from: plistData
        )
        
        let module = try XCTUnwrap(defaultAvailability.modules["SwiftUI"])
        XCTAssertEqual(module.count, 5)
        XCTAssertEqual(module.filter({ $0.platformName.displayName == "Mac Catalyst" }).count, 1)
        XCTAssertEqual(module.filter({ $0.platformName.rawValue == "macCatalyst" }).count, 1)
    }
    
    // Test that setting default availability doesn't prevent symbols with "universal" deprecation
    // (i.e. a platform of '*' and unconditional deprecation) from showing up as deprecated.
    func testUniversalDeprecationWithDefaultAvailability() throws {
        let (_, bundle, context) = try testBundleAndContext(copying: "BundleWithLonelyDeprecationDirective", excludingPaths: [], codeListings: [:]) { (url) in
            try? FileManager.default.removeItem(at: url.appendingPathComponent("Info.plist"))
            try? FileManager.default.copyItem(at: self.infoPlistAvailabilityURL, to: url.appendingPathComponent("Info.plist"))
        }
        
        let node = try context.entity(
            with: ResolvedTopicReference(
                bundleIdentifier: bundle.identifier,
                path: "/documentation/CoolFramework/CoolClass/doUncoolThings(with:)",
                sourceLanguage: .swift
            )
        )
        
        // Compile docs and verify contents
        let symbol = node.semantic as! Symbol
        var translator = RenderNodeTranslator(
            context: context,
            bundle: bundle,
            identifier: node.reference,
            source: nil
        )
        
        guard let renderNode = translator.visit(symbol) as? RenderNode else {
            XCTFail("Could not compile the node")
            return
        }
        
        // even though the doc bundle includes default availability, the blanket deprecation on `doUncoolThings(with:)` should still be visible
        let expected: [RenderInlineContent] = [
            .text("This class is deprecated."),
        ]
        
        XCTAssertEqual(renderNode.deprecationSummary?.firstParagraph, expected)
    }
}
