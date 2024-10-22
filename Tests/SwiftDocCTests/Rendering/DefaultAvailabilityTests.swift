/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import XCTest
import SymbolKit
@testable import SwiftDocC
import SwiftDocCTestUtilities

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
        let (_, bundle, context) = try testBundleAndContext(copying: "TestBundle", excludingPaths: []) { (url) in
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
        XCTAssertEqual(
            bundle.info.defaultAvailability?
                .modules["MyKit"]?
                .map({ "\($0.platformName.displayName) \($0.introducedVersion ?? "")" })
                .sorted(),
            expectedDefaultAvailability
        )
        
        // Bail the rendering part of the test if the availability hasn't been loaded
        guard bundle.info.defaultAvailability != nil else {
            return
        }
        
        // Test if the default availability is used for modules
        do {
            let identifier = ResolvedTopicReference(id: "org.swift.docc.example", path: "/documentation/MyKit", fragment: nil, sourceLanguage: .swift)
            let node = try context.entity(with: identifier)
            var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference)
            let renderNode = translator.visit(node.semantic) as! RenderNode
            
            XCTAssertEqual(renderNode.metadata.platforms?.map({ "\($0.name ?? "") \($0.introduced ?? "")" }).sorted(), expectedDefaultAvailability)
        }
        
        // Test if the default availability is used for symbols with no explicit availability
        do {
            let identifier = ResolvedTopicReference(id: "org.swift.docc.example", path: "/documentation/MyKit/MyClass/init()-3743d", fragment: nil, sourceLanguage: .swift)
            let node = try context.entity(with: identifier)
            var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference)
            let renderNode = translator.visit(node.semantic) as! RenderNode
            
            XCTAssertEqual(renderNode.metadata.platforms?.map({ "\($0.name ?? "") \($0.introduced ?? "")" }).sorted(), ["Mac Catalyst ", "iOS ", "iPadOS ", "macOS 10.15.1"])
        }

        // Test if the default availability is NOT used for symbols with explicit availability
        do {
            let identifier = ResolvedTopicReference(id: "org.swift.docc.example", path: "/documentation/MyKit/MyClass", fragment: nil, sourceLanguage: .swift)
            let node = try context.entity(with: identifier)
            var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference)
            let renderNode = translator.visit(node.semantic) as! RenderNode
            
            XCTAssertNotEqual(renderNode.metadata.platforms?.map({ "\($0.name ?? "") \($0.introduced ?? "")" }), expectedDefaultAvailability)
        }
    }
    
    // Test whether the default availability is merged with beta status from the command line
    func testBundleWithDefaultAvailabilityInBetaDocs() throws {
        // Beta status for the docs (which would normally be set via command line argument)
        try assertRenderedPlatformsFor(currentPlatforms: [
            "macOS": PlatformVersion(VersionTriplet(10, 15, 1), beta: true),
            "Mac Catalyst": PlatformVersion(VersionTriplet(13, 5, 0), beta: true),
        ], equal: [
            "Mac Catalyst 13.5(beta)",
            "macOS 10.15.1(beta)",
        ])
        
        // Repeat the assertions, but use an earlier platform version this time
        try assertRenderedPlatformsFor(currentPlatforms: [
            "macOS": PlatformVersion(VersionTriplet(10, 14, 1), beta: true),
            "Mac Catalyst": PlatformVersion(VersionTriplet(13, 5, 0), beta: true),
        ], equal: [
            "Mac Catalyst 13.5(beta)",
            "macOS 10.15.1(beta)",
        ])
    }

    private func assertRenderedPlatformsFor(currentPlatforms: [String : PlatformVersion], equal expected: [String], file: StaticString = #file, line: UInt = #line) throws {
        var configuration = DocumentationContext.Configuration()
        configuration.externalMetadata.currentPlatforms = currentPlatforms
        
        let catalog = Folder(name: "unit-test.docc", content: [
            CopyOfFile(original: self.infoPlistAvailabilityURL, newName: "Info.plist"),
            // This module name needs to match what's specified in the Info.plist
            JSONFile(name: "MyKit.symbols.json", content: makeSymbolGraph(moduleName: "MyKit")),
        ])
        
        let (_, bundle, context) = try loadBundle(from: createTempFolder(content: [catalog]), configuration: configuration)
        let reference = try XCTUnwrap(context.soleRootModuleReference, file: file, line: line)
        
        // Test whether we:
        // 1) Fallback on iOS when Mac Catalyst availability is missing
        // 2) Render [Beta] or not for Mac Catalyst's inherited iOS availability
        let node = try context.entity(with: reference)
        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: reference)
        let renderNode = translator.visit(node.semantic) as! RenderNode
        
        XCTAssertEqual(renderNode.metadata.platforms?.map({ "\($0.name ?? "") \($0.introduced ?? "")\($0.isBeta == true ? "(beta)" : "")" }).sorted(), expected, file: (file), line: line)
    }
    
    // Test whether when Mac Catalyst availability is missing we fall back on
    // Mac Catalyst info.plist availability and not on iOS availability.
    func testBundleWithMissingCatalystAvailability() throws {
        // Beta status for both iOS and Mac Catalyst
        try assertRenderedPlatformsFor(currentPlatforms: [
            "iOS": PlatformVersion(VersionTriplet(13, 5, 0), beta: true),
            "Mac Catalyst": PlatformVersion(VersionTriplet(13, 5, 0), beta: true),
        ], equal: [
            "Mac Catalyst 13.5(beta)",
            "macOS 10.15.1",
        ])
        
        // Public status for Mac Catalyst
        try assertRenderedPlatformsFor(currentPlatforms: [
            "Mac Catalyst": PlatformVersion(VersionTriplet(13, 5, 0), beta: false),
        ], equal: [
            "Mac Catalyst 13.5",
            "macOS 10.15.1",
        ])

        // Verify that a bug rendering availability as beta when no platforms are provided is fixed.
        try assertRenderedPlatformsFor(currentPlatforms: [:], equal: [
            "Mac Catalyst 13.5",
            "macOS 10.15.1",
        ])
    }
    
    // Test whether the default availability is not beta when not matching current target platform
    func testBundleWithDefaultAvailabilityNotInBetaDocs() throws {
        var configuration = DocumentationContext.Configuration()
        // Set a beta status for the docs (which would normally be set via command line argument)
        configuration.externalMetadata.currentPlatforms = ["macOS": PlatformVersion(VersionTriplet(10, 16, 0), beta: true)]
        
        let (_, bundle, context) = try testBundleAndContext(copying: "TestBundle", configuration: configuration) { (url) in
            // Copy an Info.plist with default availability of macOS 10.15.1
            try? FileManager.default.removeItem(at: url.appendingPathComponent("Info.plist"))
            try? FileManager.default.copyItem(at: self.infoPlistAvailabilityURL, to: url.appendingPathComponent("Info.plist"))
        }
        
        // Test if the module availability is not "beta" for the "macOS" platform (since 10.15.1 != 10.16)
        do {
            let identifier = ResolvedTopicReference(id: "org.swift.docc.example", path: "/documentation/MyKit", fragment: nil, sourceLanguage: .swift)
            let node = try context.entity(with: identifier)
            var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference)
            let renderNode = translator.visit(node.semantic) as! RenderNode
            
            XCTAssertEqual(renderNode.metadata.platforms?.map({ "\($0.name ?? "") \($0.introduced ?? "")\($0.isBeta == true ? "(beta)" : "")" }).sorted(), [
                "Mac Catalyst 13.5",
                "macOS 10.15.1",
            ])
        }
    }

    // Test that a symbol is unavailable and default availability does not precede the "unavailable" attribute.
    func testUnavailableAvailability() throws {
        var configuration = DocumentationContext.Configuration()
        // Set a beta status for the docs (which would normally be set via command line argument)
        configuration.externalMetadata.currentPlatforms = ["iOS": PlatformVersion(VersionTriplet(14, 0, 0), beta: true)]
        let (_, bundle, context) = try testBundleAndContext(named: "TestBundle", configuration: configuration)
        
        do {
            let identifier = ResolvedTopicReference(id: "org.swift.docc.example", path: "/documentation/MyKit/MyClass/myFunction()", fragment: nil, sourceLanguage: .swift)
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
            
            var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference)
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
        XCTAssertEqual(module.count, 6)
        XCTAssertEqual(module.filter({ $0.platformName.displayName == "Mac Catalyst" }).count, 1)
        XCTAssertEqual(module.filter({ $0.platformName.displayName == "iPadOS" }).count, 1)
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
        XCTAssertEqual(module.count, 6)
        XCTAssertEqual(module.filter({ $0.platformName.displayName == "Mac Catalyst" }).count, 1)
        XCTAssertEqual(module.filter({ $0.platformName.rawValue == "macCatalyst" }).count, 1)
        XCTAssertEqual(module.filter({ $0.platformName.displayName == "iPadOS" }).count, 1)
    }
    
    // Test that setting default availability doesn't prevent symbols with "universal" deprecation
    // (i.e. a platform of '*' and unconditional deprecation) from showing up as deprecated.
    func testUniversalDeprecationWithDefaultAvailability() throws {
        let (_, bundle, context) = try testBundleAndContext(copying: "BundleWithLonelyDeprecationDirective", excludingPaths: []) { (url) in
            try? FileManager.default.removeItem(at: url.appendingPathComponent("Info.plist"))
            try? FileManager.default.copyItem(at: self.infoPlistAvailabilityURL, to: url.appendingPathComponent("Info.plist"))
        }
        
        let node = try context.entity(
            with: ResolvedTopicReference(
                id: bundle.id,
                path: "/documentation/CoolFramework/CoolClass/doUncoolThings(with:)",
                sourceLanguage: .swift
            )
        )
        
        // Compile docs and verify contents
        let symbol = node.semantic as! Symbol
        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference)
        
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
    
    func testUnconditionallyUnavailable() throws {
        let infoPlist = """
            <plist version="1.0">
            <dict>
                <key>CFBundleDisplayName</key>
                <string>MyModule</string>
                <key>CFBundleIdentifier</key>
                <string>com.apple.MyModule</string>
                <key>CDAppleDefaultAvailability</key>
                <dict>
                    <key>MyModule</key>
                    <array>
                        <dict>
                            <key>name</key>
                            <string>visionOS</string>
                            <key>unavailable</key>
                            <true/>
                        </dict>
                        <dict>
                            <key>name</key>
                            <string>Catalyst</string>
                            <key>unavailable</key>
                            <true/>
                        </dict>
                        <dict>
                            <key>unavailable</key>
                            <true/>
                            <key>name</key>
                            <string>tvOS</string>
                            <key>version</key>
                            <string>1.0</string>
                        </dict>
                        <dict>
                            <key>name</key>
                            <string>watchOS</string>
                            <key>version</key>
                            <string>1.0</string>
                        </dict>
                        <dict>
                            <key>name</key>
                            <string>iOS</string>
                            <key>version</key>
                            <string>1.0</string>
                        </dict>
                    </array>
                </dict>
            </dict>
            </plist>
            """
        
        let decodedInfo = try DocumentationBundle.Info(from: Data(infoPlist.utf8))
        let reEncodedInfo = try PropertyListEncoder().encode(decodedInfo.defaultAvailability)
        let defaultAvailability = try PropertyListDecoder().decode(
            DefaultAvailability.self,
            from: reEncodedInfo
        )
        let module = try XCTUnwrap(defaultAvailability.modules["MyModule"])
        XCTAssertEqual(module.count, 7)
        XCTAssertEqual(
            module.filter({ $0.platformName.displayName == "visionOS" }).first?.versionInformation,
            .unavailable
        )
        XCTAssertEqual(
            module.filter({ $0.platformName.displayName == "Catalyst" }).first?.versionInformation,
            .unavailable
        )
        XCTAssertEqual(
            module.filter({ $0.platformName.displayName == "tvOS" }).first?.versionInformation,
            .unavailable
        )
        XCTAssertEqual(
            module.filter({ $0.platformName.displayName == "watchOS" }).first?.versionInformation,
            .available(version: "1.0")
        )
        XCTAssertEqual(
            module.filter({ $0.platformName.displayName == "iOS" }).first?.introducedVersion,
            "1.0"
        )
        XCTAssertEqual(
            module.filter({ $0.platformName.displayName == "iPadOS" }).first?.introducedVersion,
            "1.0"
        )
    }
    
    func testFallbackAvailability() throws {
        func unwrapModuleDefaultAvailability(_ plistEntries: [String: [[String: String]]]) throws -> [DefaultAvailability.ModuleAvailability] {
            let plistData = try PropertyListEncoder().encode(plistEntries)
            let defaultAvailability = try PropertyListDecoder().decode(
                DefaultAvailability.self,
                from: plistData
            )
            
            return try XCTUnwrap(defaultAvailability.modules["SwiftUI"])
        }
        // When there's no iOS availability test that Catalyst and iPadOS
        // are not added through fallback behaviour.
        var plistEntries: [String: [[String: String]]] = [
            "SwiftUI": [
                [
                    "name": "macOS",
                    "version": "10.15",
                ]
            ],
        ]
        var module = try unwrapModuleDefaultAvailability(plistEntries)
        XCTAssertEqual(module.count, 1)
        XCTAssertEqual(module.filter({ $0.platformName.displayName == "macOS" }).count, 1)
        // When there is iOS availability test that Catalyst and iPadOS
        // are added through fallback behaviour.
        plistEntries = [
            "SwiftUI": [
                [
                    "name": "iOS",
                    "version": "8.0",
                ]
            ],
        ]
        module = try unwrapModuleDefaultAvailability(plistEntries)
        XCTAssertEqual(module.count, 3)
        XCTAssertEqual(module.filter({ $0.platformName.displayName == "iOS" }).count, 1)
        XCTAssertEqual(module.filter({ $0.platformName.displayName == "iPadOS" }).count, 1)
        XCTAssertEqual(module.filter({ $0.platformName.displayName == "Mac Catalyst" }).count, 1)
        XCTAssertEqual(
            module.filter({ $0.platformName.displayName == "iPadOS" }).first?.versionInformation,
            .available(version: "8.0")
        )
        XCTAssertEqual(
            module.filter({ $0.platformName.displayName == "Mac Catalyst" }).first?.versionInformation,
            .available(version: "8.0")
        )
        // When there is iOS availability test that Catalyst and iPadOS
        // are added through fallback behaviour.
        plistEntries = [
            "SwiftUI": [
                [
                    "name": "iOS",
                    "version": "8.0",
                ],
                [
                    "name": "Mac Catalyst",
                    "version": "9.0",
                ]
            ],
        ]
        module = try unwrapModuleDefaultAvailability(plistEntries)
        XCTAssertEqual(
            module.filter({ $0.platformName.displayName == "iPadOS" }).first?.versionInformation,
            .available(version: "8.0")
        )
        XCTAssertEqual(
            module.filter({ $0.platformName.displayName == "Mac Catalyst" }).first?.versionInformation,
            .available(version: "9.0")
        )
        // When there is iOS availability test that Catalyst and iPadOS
        // are added through fallback behaviour.
        plistEntries = [
            "SwiftUI": [
                [
                    "name": "iOS",
                    "version": "8.0",
                ],
                [
                    "name": "Mac Catalyst",
                    "version": "9.0",
                ],
                [
                    "name": "iPadOS",
                    "version": "10.0",
                ]
            ],
        ]
        module = try unwrapModuleDefaultAvailability(plistEntries)
        XCTAssertEqual(
            module.filter({ $0.platformName.displayName == "iOS" }).first?.versionInformation,
            .available(version: "8.0")
        )
        XCTAssertEqual(
            module.filter({ $0.platformName.displayName == "Mac Catalyst" }).first?.versionInformation,
            .available(version: "9.0")
        )
        XCTAssertEqual(
            module.filter({ $0.platformName.displayName == "iPadOS" }).first?.versionInformation,
            .available(version: "10.0")
        )
    }
    
    func testInheritDefaultAvailabilityOptions() throws {
        func makeInfoPlist(
            defaultAvailability: String
        ) -> String {
            return """
               <plist version="1.0">
               <dict>
                   <key>CDAppleDefaultAvailability</key>
                   <dict>
                       <key>MyModule</key>
                       <array>
                           \(defaultAvailability)
                       </array>
                   </dict>
               </dict>
               </plist>
               """
        }
        func setupContext(
            defaultAvailability: String
        ) throws -> (DocumentationBundle, DocumentationContext) {
            // Create an empty bundle
            let targetURL = try createTemporaryDirectory(named: "test.docc")
            // Create symbol graph
            let symbolGraphURL = targetURL.appendingPathComponent("MyModule.symbols.json")
            try symbolGraphString.write(to: symbolGraphURL, atomically: true, encoding: .utf8)
            // Create info plist
            let infoPlistURL = targetURL.appendingPathComponent("Info.plist")
            let infoPlist = makeInfoPlist(defaultAvailability: defaultAvailability)
            try infoPlist.write(to: infoPlistURL, atomically: true, encoding: .utf8)
            // Load the bundle & reference resolve symbol graph docs
            let (_, bundle, context) = try loadBundle(from: targetURL)
            return (bundle, context)
        }
        
        let symbols = """
           {
               "kind": {
                   "displayName" : "Instance Property",
                   "identifier" : "swift.property"
               },
               "identifier": {
                   "precise": "c:@F@SymbolWithAvailability",
                   "interfaceLanguage": "swift"
               },
               "pathComponents": [
                   "Foo"
               ],
               "names": {
                   "title": "Foo",
               },
               "accessLevel": "public",
               "availability" : [
                   {
                      "domain" : "ios",
                      "introduced" : {
                           "major" : 10,
                           "minor" : 0
                      }
                   }
               ]
           },
           {
               "kind": {
                   "displayName" : "Instance Property",
                   "identifier" : "swift.property"
               },
               "identifier": {
                   "precise": "c:@F@SymbolWithoutAvailability",
                   "interfaceLanguage": "swift"
               },
               "pathComponents": [
                   "Foo"
               ],
               "names": {
                   "title": "Bar",
               },
               "accessLevel": "public"
           }
           """
        let symbolGraphString = makeSymbolGraphString(
            moduleName: "MyModule",
            symbols: symbols,
            platform: """
               "operatingSystem" : {
                  "minimumVersion" : {
                    "major" : 10,
                    "minor" : 0
                  },
                  "name" : "ios"
                }
               """
        )
        
        // Don't use default availability version.
        
        var (bundle, context) = try setupContext(
            defaultAvailability: """
               <dict>
                   <key>name</key>
                   <string>iOS</string>
               </dict>
               """
        )
        
        // Verify we add the version number into the symbols that have availability annotation.
        guard let availability = (context.documentationCache["c:@F@SymbolWithAvailability"]?.semantic as? Symbol)?.availability?.availability else {
            XCTFail("Did not find availability for symbol 'c:@F@SymbolWithAvailability'")
            return
        }
        XCTAssertNotNil(availability.first(where: { $0.domain?.rawValue == "iOS" }))
        XCTAssertEqual(availability.first(where: { $0.domain?.rawValue == "iOS" })?.introducedVersion, SymbolGraph.SemanticVersion(major: 10, minor: 0, patch: 0))
        // Verify we don't add the version number into the symbols that don't have availability annotation.
        guard let availability = (context.documentationCache["c:@F@SymbolWithoutAvailability"]?.semantic as? Symbol)?.availability?.availability else {
            XCTFail("Did not find availability for symbol 'c:@F@SymbolWithoutAvailability'")
            return
        }
        XCTAssertNotNil(availability.first(where: { $0.domain?.rawValue == "iOS" }))
        XCTAssertEqual(availability.first(where: { $0.domain?.rawValue == "iOS" })?.introducedVersion, nil)
        // Verify we remove the version from the module availability information.
        var identifier = ResolvedTopicReference(id: "test", path: "/documentation/MyModule", fragment: nil, sourceLanguage: .swift)
        var node = try context.entity(with: identifier)
        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: identifier)
        var renderNode = translator.visit(node.semantic) as! RenderNode
        XCTAssertEqual(renderNode.metadata.platforms?.count, 1)
        XCTAssertEqual(renderNode.metadata.platforms?.first?.name, "iOS")
        XCTAssertEqual(renderNode.metadata.platforms?.first?.introduced, nil)
        
        // Add an extra default availability to test behaviour when mixin in source with default behaviour.
        (bundle, context) = try setupContext(defaultAvailability: """
               <dict>
                   <key>name</key>
                   <string>iOS</string>
                   <key>version</key>
                   <string>8.0</string>
               </dict>
               <dict>
                  <key>name</key>
                  <string>watchOS</string>
               </dict>
               """
        )
        
        // Verify we add the version number into the symbols that have availability annotation.
        guard let availability = (context.documentationCache["c:@F@SymbolWithAvailability"]?.semantic as? Symbol)?.availability?.availability else {
            XCTFail("Did not find availability for symbol 'c:@F@SymbolWithAvailability'")
            return
        }
        XCTAssertNotNil(availability.first(where: { $0.domain?.rawValue == "iOS" }))
        XCTAssertNotNil(availability.first(where: { $0.domain?.rawValue == "watchOS" }))
        XCTAssertEqual(availability.first(where: { $0.domain?.rawValue == "iOS" })?.introducedVersion, SymbolGraph.SemanticVersion(major: 10, minor: 0, patch: 0))
        XCTAssertEqual(availability.first(where: { $0.domain?.rawValue == "watchOS" })?.introducedVersion, nil)
        
        guard let availability = (context.documentationCache["c:@F@SymbolWithoutAvailability"]?.semantic as? Symbol)?.availability?.availability else {
            XCTFail("Did not find availability for symbol 'c:@F@SymbolWithAvailability'")
            return
        }
        XCTAssertNotNil(availability.first(where: { $0.domain?.rawValue == "iOS" }))
        XCTAssertNotNil(availability.first(where: { $0.domain?.rawValue == "watchOS" }))
        XCTAssertEqual(availability.first(where: { $0.domain?.rawValue == "iOS" })?.introducedVersion, SymbolGraph.SemanticVersion(major: 8, minor: 0, patch: 0))
        XCTAssertEqual(availability.first(where: { $0.domain?.rawValue == "watchOS" })?.introducedVersion, nil)
        
        // Verify the module availability shows as expected.
        identifier = ResolvedTopicReference(id: "test", path: "/documentation/MyModule", fragment: nil, sourceLanguage: .swift)
        node = try context.entity(with: identifier)
        translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: identifier)
        renderNode = translator.visit(node.semantic) as! RenderNode
        XCTAssertEqual(renderNode.metadata.platforms?.count, 4)
        var moduleAvailability = try XCTUnwrap(renderNode.metadata.platforms?.first(where: {$0.name == "iOS"}))
        XCTAssertEqual(moduleAvailability.introduced, "8.0")
        moduleAvailability = try XCTUnwrap(renderNode.metadata.platforms?.first(where: {$0.name == "watchOS"}))
        XCTAssertEqual(moduleAvailability.introduced, nil)
    }
}
