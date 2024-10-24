/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import XCTest
@testable import SymbolKit
@testable import SwiftDocC
import SwiftDocCTestUtilities

class SymbolGraphLoaderTests: XCTestCase {
    
    func testLoadingDifferentModules() throws {
        let tempURL = try createTemporaryDirectory()
        
        var symbolGraphURLs = [URL]()
        for moduleNames in ["One", "Two", "Three"] {
            let symbolGraph = SymbolGraph(
                metadata: SymbolGraph.Metadata(
                    formatVersion: SymbolGraph.SemanticVersion(major: 1, minor: 1, patch: 1),
                    generator: "unit-test"
                ),
                module: SymbolGraph.Module(
                    name: moduleNames,
                    platform: SymbolGraph.Platform(architecture: nil, vendor: nil, operatingSystem: nil)
                ),
                symbols: [],
                relationships: []
            )
            
            let symbolGraphURL = tempURL.appendingPathComponent("\(moduleNames).symbols.json")
            symbolGraphURLs.append(symbolGraphURL)
            
            try JSONEncoder().encode(symbolGraph).write(to: symbolGraphURL)
        }
        
        var loader = try makeSymbolGraphLoader(symbolGraphURLs: symbolGraphURLs)
        XCTAssertTrue(loader.unifiedGraphs.isEmpty)
        
        try loader.loadAll()
        var moduleNameFrequency = [String: Int]()
        
        for (_, graph) in loader.unifiedGraphs {
            moduleNameFrequency[graph.moduleName, default: 0] += 1
        }
        
        XCTAssertEqual(moduleNameFrequency, ["One": 1, "Two": 1, "Three": 1])
    }
    
    func testLoadingDifferentModuleExtensions() throws {
        let tempURL = try createTemporaryDirectory()
        
        var symbolGraphURLs = [URL]()
        for moduleName in ["One", "Two", "Three"] {
            let symbolGraph = makeSymbolGraph(moduleName: moduleName)
            
            let symbolGraphURL = tempURL.appendingPathComponent("Something@\(moduleName).symbols.json")
            symbolGraphURLs.append(symbolGraphURL)
            
            try JSONEncoder().encode(symbolGraph).write(to: symbolGraphURL)
        }
        
        var loader = try makeSymbolGraphLoader(symbolGraphURLs: symbolGraphURLs)
        try loader.loadAll()
        var moduleNameFrequency = [String: Int]()
        
        for (_, graph) in loader.unifiedGraphs {
            moduleNameFrequency[graph.moduleName, default: 0] += 1
        }
        
        // The loaded module should have the name of the module that was extended.
        XCTAssertEqual(moduleNameFrequency, ["One": 1, "Two": 1, "Three": 1])
    }
    
    func testNotGroupingExtensionsWithWithTheModuleThatExtends() throws {
        let tempURL = try createTemporaryDirectory()
        
        var symbolGraphURLs = [URL]()
        
        // Create a main module
        let mainSymbolGraph = makeSymbolGraph(moduleName: "Main")
        let mainSymbolGraphURL = tempURL.appendingPathComponent("Main.symbols.json")
        symbolGraphURLs.append(mainSymbolGraphURL)
        
        try JSONEncoder().encode(mainSymbolGraph).write(to: mainSymbolGraphURL)
        
        // Create 3 extension from thise module on other modules
        for moduleName in ["One", "Two", "Three"] {
            let symbolGraph = makeSymbolGraph(moduleName: moduleName)
            
            let symbolGraphURL = tempURL.appendingPathComponent("Main@\(moduleName).symbols.json")
            symbolGraphURLs.append(symbolGraphURL)
            
            try JSONEncoder().encode(symbolGraph).write(to: symbolGraphURL)
        }
        
        var loader = try makeSymbolGraphLoader(symbolGraphURLs: symbolGraphURLs)
        try loader.loadAll()
        var moduleNameFrequency = [String: Int]()
        
        for (_, graph) in loader.unifiedGraphs {
            moduleNameFrequency[graph.moduleName, default: 0] += 1
        }
        
        // All 4 modules should have different names
        XCTAssertEqual(moduleNameFrequency, ["Main": 1, "One": 1, "Two": 1, "Three": 1])
    }
    
    // This test calls ``SymbolGraph.relationships`` which is deprecated.
    // Deprecating the test silences the deprecation warning when running the tests. It doesn't skip the test.
    @available(*, deprecated) // `SymbolGraph.relationships` doesn't specify when it will be removed
    func testLoadingHighNumberOfModulesConcurrently() throws {
        let tempURL = try createTemporaryDirectory()

        let symbolGraphSourceURL = Bundle.module.url(
            forResource: "TestBundle", withExtension: "docc", subdirectory: "Test Bundles")!
            .appendingPathComponent("mykit-iOS.symbols.json")
        var symbolGraph = try JSONDecoder().decode(SymbolGraph.self, from: try Data(contentsOf: symbolGraphSourceURL))
        
        var symbolGraphURLs = [URL]()
        for index in 0..<1000 {
            let symbolGraphURL = tempURL.appendingPathComponent("Module\(index).symbols.json")
            symbolGraphURLs.append(symbolGraphURL)
            symbolGraph.module.name = "Module\(index)"
            try JSONEncoder().encode(symbolGraph).write(to: symbolGraphURL)
        }
        
        var loader = try makeSymbolGraphLoader(symbolGraphURLs: symbolGraphURLs)
        try loader.loadAll()
        
        var loadedGraphs = 0
        
        for (_, graph) in loader.unifiedGraphs {
            loadedGraphs += 1
            XCTAssertEqual(graph.symbols.count, symbolGraph.symbols.count)
            XCTAssertEqual(graph.relationships.count, symbolGraph.relationships.count)
        }
        
        XCTAssertEqual(loadedGraphs, 1000)
    }
    
    /// Tests if we detect correctly a Mac Catalyst graph
    func testLoadingiOSAndCatalystGraphs() throws {
        func testBundleCopy(iOSSymbolGraphName: String, catalystSymbolGraphName: String) throws -> (URL, DocumentationBundle, DocumentationContext) {
            return try testBundleAndContext(copying: "TestBundle", configureBundle: { bundleURL in
                // Create an iOS symbol graph file
                let iOSGraphURL = bundleURL.appendingPathComponent("mykit-iOS.symbols.json")
                let renamediOSGraphURL = bundleURL.appendingPathComponent(iOSSymbolGraphName)
                try FileManager.default.moveItem(at: iOSGraphURL, to: renamediOSGraphURL)
                
                // Create a Catalyst symbol graph
                var catalystSymbolGraph = try JSONDecoder().decode(SymbolGraph.self, from: try Data(contentsOf: renamediOSGraphURL))
                catalystSymbolGraph.module.platform.environment = "macabi"
                
                // Update one symbol's availability to use as a verification if we're loading iOS or Catalyst symbol graph
                catalystSymbolGraph.symbols["s:5MyKit0A5ClassC"]!.mixins[SymbolGraph.Symbol.Availability.mixinKey]! = SymbolGraph.Symbol.Availability(availability: [
                    .init(domain: SymbolGraph.Symbol.Availability.Domain(rawValue: "Mac Catalyst"), introducedVersion: .init(major: 1, minor: 0, patch: 0), deprecatedVersion: nil, obsoletedVersion: nil, message: nil, renamed: nil, isUnconditionallyDeprecated: false, isUnconditionallyUnavailable: false, willEventuallyBeDeprecated: false),
                    .init(domain: SymbolGraph.Symbol.Availability.Domain(rawValue: "iOS"), introducedVersion: .init(major: 7, minor: 0, patch: 0), deprecatedVersion: nil, obsoletedVersion: nil, message: nil, renamed: nil, isUnconditionallyDeprecated: false, isUnconditionallyUnavailable: false, willEventuallyBeDeprecated: false),
                ])
                
                let catalystSymbolGraphURL = bundleURL.appendingPathComponent(catalystSymbolGraphName)
                try JSONEncoder().encode(catalystSymbolGraph).write(to: catalystSymbolGraphURL)
            })
        }
        
        // Below we simulate the two possible loading orders of the symbol graphs in the bundle
        // because we load them concurrently and we should ensure that no matter the order the results are the same.
        // We verify that the same expectations are fulfilled regardless of the loading order.
        
        // Load Catalyst graph first
        do {
            // We rename the iOS graph file to contain a "@" which makes it being loaded after main symbol graphs
            // to simulate the loading order we want to test.
            let (_, _, context) = try testBundleCopy(iOSSymbolGraphName: "faux@MyKit.symbols.json", catalystSymbolGraphName: "MyKit.symbols.json")

            guard let availability = (context.documentationCache["s:5MyKit0A5ClassC"]?.semantic as? Symbol)?.availability?.availability else {
                XCTFail("Did not find availability for symbol 's:5MyKit0A5ClassC'")
                return
            }
            
            // Verify we get the availability for the Catalyst platform
            XCTAssertNotNil(availability.first(where: { $0.domain?.rawValue == "Mac Catalyst" }))
            
            // Verify we take the iOS symbol graph availability (deprecated) instead of the Catalyst symbol graph iOS availability of 7.0.0
            XCTAssertNotNil(availability.first(where: { $0.domain?.rawValue == "iOS" }))
            XCTAssertNil(availability.first(where: { $0.domain?.rawValue == "iOS" })?.introducedVersion)
            XCTAssertEqual(availability.first(where: { $0.domain?.rawValue == "iOS" })?.deprecatedVersion?.description, "13.0.0")
        }

        // Load the iOS symbol graph first
        do {
            // We rename the Mac Catalyst graph file to contain a "@" which makes it being loaded after main symbol graphs
            // to simulate the loading order we want to test.
            let (_, _, context) = try testBundleCopy(iOSSymbolGraphName: "MyKit.symbols.json", catalystSymbolGraphName: "faux@MyKit.symbols.json")
            
            guard let availability = (context.documentationCache["s:5MyKit0A5ClassC"]?.semantic as? Symbol)?.availability?.availability else {
                XCTFail("Did not find availability for symbol 's:5MyKit0A5ClassC'")
                return
            }
            // Verify we get the merged availability from the Catalyst symbol graph (the iOS graph does not have Catalyst availability item)
            XCTAssertNotNil(availability.first(where: { $0.domain?.rawValue == "Mac Catalyst" }))
            // Verify we take the iOS symbol graph availability (unavailable)
            XCTAssertNotNil(availability.first(where: { $0.domain?.rawValue == "iOS" }))
            XCTAssertNil(availability.first(where: { $0.domain?.rawValue == "iOS" })?.introducedVersion)
            XCTAssertEqual(availability.first(where: { $0.domain?.rawValue == "iOS" })?.deprecatedVersion?.description, "13.0.0")
        }
    }
    
    // Tests if main and bystanders graphs are loaded
    func testLoadingModuleBystanderExtensions() throws {
        let (_, bundle, _) = try testBundleAndContext(copying: "TestBundle", externalResolvers: [:]) { url in
            let bystanderSymbolGraphURL = Bundle.module.url(
                forResource: "MyKit@Foundation@_MyKit_Foundation.symbols", withExtension: "json", subdirectory: "Test Resources")!
            try FileManager.default.copyItem(at: bystanderSymbolGraphURL, to: url.appendingPathComponent("MyKit@Foundation@_MyKit_Foundation.symbols.json"))
        }

        var loader = try makeSymbolGraphLoader(symbolGraphURLs: bundle.symbolGraphURLs)
        try loader.loadAll()

        // Verify both main and bystanders graphs are loaded

        var foundMainMyKitGraph = false
        var foundBystanderMyKitGraph = false

        for (_, graph) in loader.unifiedGraphs {
            for (_, moduleData) in graph.moduleData {
                if graph.moduleName == "MyKit" {
                    if moduleData.bystanders == ["Foundation"] {
                        foundBystanderMyKitGraph = true
                    } else {
                        foundMainMyKitGraph = true
                    }
                }
            }
        }
        XCTAssertTrue(foundMainMyKitGraph, "MyKit graph wasn't found")
        XCTAssertTrue(foundBystanderMyKitGraph, "MyKit / Foundation bystander graph wasn't found")
    }
    
    func testLoadingAsyncSymbolsWithJustOneFile() throws {
        // This tests the concurrent decoding behavior when the symbol graph loader is only decoding a single symbol graph file
        for (symbolGraphFileName, shouldContainAsyncVariant) in [("WithCompletionHandler", false), ("WithAsyncKeyword", true), ("DuplicateSymbolAsyncVariants", false), ("DuplicateSymbolAsyncVariantsReverseOrder", false)] {
            let symbolGraphURL = Bundle.module.url(forResource: "\(symbolGraphFileName).symbols", withExtension: "json", subdirectory: "Test Resources")!
            
            var loader = try makeSymbolGraphLoader(symbolGraphURLs: [symbolGraphURL])
            try loader.loadAll()
            
            XCTAssertEqual(loader.decodingStrategy, .concurrentlyEachFileInBatches)
            
            let symbolGraph = loader.unifiedGraphs.values.first!
            
            XCTAssertEqual(symbolGraph.moduleName, "AsyncMethods")
            
            XCTAssertEqual(symbolGraph.symbols.count, 1, "Only one of the symbols should be decoded")
            let symbol = try XCTUnwrap(symbolGraph.symbols.values.first)
            let declaration = try XCTUnwrap(symbol.mixins.values.first?[SymbolGraph.Symbol.DeclarationFragments.mixinKey] as? SymbolGraph.Symbol.DeclarationFragments)

            XCTAssertEqual(shouldContainAsyncVariant, declaration.declarationFragments.contains(where: { fragment in
                fragment.kind == .keyword && fragment.spelling == "async"
            }), "\(symbolGraphFileName).symbols.json should\(shouldContainAsyncVariant ? "" : " not") contain an async keyword declaration fragment")

            XCTAssertEqual(!shouldContainAsyncVariant, declaration.declarationFragments.contains(where: { fragment in
                fragment.kind == .externalParameter && fragment.spelling == "completionHandler"
            }), "\(symbolGraphFileName).symbols.json should\(!shouldContainAsyncVariant ? "" : " not") contain a completionHandler parameter declaration fragment")
        }
    }
    
    func testLoadingAsyncSymbolsWithJustMultipleFiles() throws {
        // This tests the decoding behavior when the symbol graph loader is decoding more than one file
        let extraSymbolGraphFile = Bundle.module.url(forResource: "Asides.symbols", withExtension: "json", subdirectory: "Test Resources")!
        
        for (symbolGraphFileName, shouldContainAsyncVariant) in [("WithCompletionHandler", false), ("WithAsyncKeyword", true), ("DuplicateSymbolAsyncVariants", false), ("DuplicateSymbolAsyncVariantsReverseOrder", false)] {
            let symbolGraphURL = Bundle.module.url(forResource: "\(symbolGraphFileName).symbols", withExtension: "json", subdirectory: "Test Resources")!
            
            var loader = try makeSymbolGraphLoader(symbolGraphURLs: [symbolGraphURL, extraSymbolGraphFile])
            try loader.loadAll()
            
            #if os(macOS) || os(iOS)
            XCTAssertEqual(loader.decodingStrategy, .concurrentlyAllFiles)
            #else
            XCTAssertEqual(loader.decodingStrategy, .concurrentlyEachFileInBatches)
            #endif
            
            var foundMainAsyncMethodsGraph = false
            
            for symbolGraph in loader.unifiedGraphs.values {
                if symbolGraph.moduleName == "AsyncMethods" {
                    foundMainAsyncMethodsGraph = true
                    
                    XCTAssertEqual(symbolGraph.symbols.count, 1, "Only one of the symbols should be decoded")
                    let symbol = try XCTUnwrap(symbolGraph.symbols.values.first)
                    let declaration = try XCTUnwrap(symbol.mixins.values.first?[SymbolGraph.Symbol.DeclarationFragments.mixinKey] as? SymbolGraph.Symbol.DeclarationFragments)
                    
                    XCTAssertEqual(shouldContainAsyncVariant, declaration.declarationFragments.contains(where: { fragment in
                        fragment.kind == .keyword && fragment.spelling == "async"
                    }), "\(symbolGraphFileName).symbols.json should\(shouldContainAsyncVariant ? "" : " not") contain an async keyword declaration fragment")
                    
                    XCTAssertEqual(!shouldContainAsyncVariant, declaration.declarationFragments.contains(where: { fragment in
                        fragment.kind == .externalParameter && fragment.spelling == "completionHandler"
                    }), "\(symbolGraphFileName).symbols.json should\(!shouldContainAsyncVariant ? "" : " not") contain a completionHandler parameter declaration fragment")
                }
            }
            XCTAssertTrue(foundMainAsyncMethodsGraph, "AsyncMethods graph wasn't found")
        }
    }

    /// Ensure that loading symbol graphs from a directory with an at-sign properly selects the
    /// `concurrentlyAllFiles` decoding strategy on macOS and iOS.
    func testLoadingSymbolsInAtSignDirectory() throws {
        let tempURL = try createTemporaryDirectory(pathComponents: "MyTempDir@2")
        let originalSymbolGraphs = [
            CopyOfFile(original: Bundle.module.url(forResource: "Asides.symbols", withExtension: "json", subdirectory: "Test Resources")!),
            CopyOfFile(original: Bundle.module.url(forResource: "WithCompletionHandler.symbols", withExtension: "json", subdirectory: "Test Resources")!)
        ]
        let symbolGraphURLs = try originalSymbolGraphs.map({ try $0.write(inside: tempURL) })

        var loader = try makeSymbolGraphLoader(symbolGraphURLs: symbolGraphURLs)
        try loader.loadAll()

        #if os(macOS) || os(iOS)
        XCTAssertEqual(loader.decodingStrategy, .concurrentlyAllFiles)
        #else
        XCTAssertEqual(loader.decodingStrategy, .concurrentlyEachFileInBatches)
        #endif
    }
    
    func testConfiguresSymbolGraphs() throws {
        let tempURL = try createTemporaryDirectory()
        
        let symbol = """
        {
            "kind": {
                "identifier": "swift.extension",
                "displayName": "Extension"
            },
            "identifier": {
                "precise": "s:e:s:EBFfunction",
                "interfaceLanguage": "swift"
            },
            "pathComponents": [
                "EBF"
            ],
            "names": {
                "title": "EBF",
            },
            "swiftExtension": {
                "extendedModule": "A",
                "typeKind": "struct"
            },
            "accessLevel": "public"
        }
        """
        
        let symbolGraphString = makeSymbolGraphString(moduleName: "MyModule", symbols: symbol)
        
        let symbolGraphURL = tempURL.appendingPathComponent("MyModule.symbols.json")
        
        try symbolGraphString.write(to: symbolGraphURL, atomically: true, encoding: .utf8)
        
        var loader = try makeSymbolGraphLoader(
            symbolGraphURLs: [symbolGraphURL],
            configureSymbolGraph: { symbolGraph in
                symbolGraph.metadata.formatVersion = .init(major: 9, minor: 9, patch: 9)
            }
        )
        XCTAssertTrue(loader.unifiedGraphs.isEmpty)
        
        try loader.loadAll()
        
        XCTAssertEqual(
            loader.unifiedGraphs.first?.value
                .metadata.first?.value
                .formatVersion.description,
            "9.9.9"
        )
    }

    func testDefaulAvailabilityWhenMissingSGFs() throws {
        // Symbol from SGF
        let symbol = """
        {
            "kind": {
                "displayName" : "Instance Property",
                "identifier" : "swift.property"
            },
            "identifier": {
                "precise": "c:@F@A",
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
                  "domain" : "tvos",
                  "introduced" : {
                    "major" : 12,
                    "minor" : 0,
                    "patch" : 0
                  }
                }
            ]
        }
        """
        let symbolGraphString = makeSymbolGraphString(
            moduleName: "MyModule",
            symbols: symbol,
            platform: """
            "operatingSystem" : {
               "minimumVersion" : {
                 "major" : 12,
                 "minor" : 0,
                 "patch" : 0
               },
               "name" : "tvos"
             }
            """
        )
        var infoPlist = """
        <plist version="1.0">
        <dict>
            <key>CDAppleDefaultAvailability</key>
            <dict>
                <key>MyModule</key>
                <array>
                    <dict>
                        <key>name</key>
                        <string>iOS</string>
                        <key>version</key>
                        <string>8.0</string>
                    </dict>
                </array>
            </dict>
        </dict>
        </plist>
        """
        // Create an empty bundle
        let targetURL = try createTemporaryDirectory(named: "test.docc")
        // Create symbol graph file
        let symbolGraphURL = targetURL.appendingPathComponent("MyModule.symbols.json")
        try symbolGraphString.write(to: symbolGraphURL, atomically: true, encoding: .utf8)
        // Create Info.plist
        let infoPlistURL = targetURL.appendingPathComponent("Info.plist")
        try infoPlist.write(to: infoPlistURL, atomically: true, encoding: .utf8)
        // Load the bundle & reference resolve symbol graph docs
        var (_, _, context) = try loadBundle(from: targetURL)
        guard let availability = (context.documentationCache["c:@F@A"]?.semantic as? Symbol)?.availability?.availability else {
            XCTFail("Did not find availability for symbol 'c:@F@A'")
            return
        }
        // Verify we add iOS and the corresponding fallback platforms (iPadOS and Catalyst)
        // when the SGF does not exists for these platforms but are defined in the Info.plist.
        XCTAssertEqual(availability.first(where: { $0.domain?.rawValue == "iOS" })?.introducedVersion, SymbolGraph.SemanticVersion(major: 8, minor: 0, patch: 0))
        XCTAssertEqual(availability.first(where: { $0.domain?.rawValue == "macCatalyst" })?.introducedVersion, SymbolGraph.SemanticVersion(major: 8, minor: 0, patch: 0))
        XCTAssertEqual(availability.first(where: { $0.domain?.rawValue == "iPadOS" })?.introducedVersion, SymbolGraph.SemanticVersion(major: 8, minor: 0, patch: 0))
        
        infoPlist = """
        <plist version="1.0">
        <dict>
            <key>CDAppleDefaultAvailability</key>
            <dict>
                <key>MyModule</key>
                <array>
                </array>
            </dict>
        </dict>
        </plist>
        """
        try infoPlist.write(to: infoPlistURL, atomically: true, encoding: .utf8)
        // Load the bundle & reference resolve symbol graph docs
        (_, _, context) = try loadBundle(from: targetURL)
        guard let availability = (context.documentationCache["c:@F@A"]?.semantic as? Symbol)?.availability?.availability else {
            XCTFail("Did not find availability for symbol 'c:@F@A'")
            return
        }
        // Verify we don't add iOS and fallback platforms when the SGF does not exists for these platforms
        // and are not defined in the Info.plist.
        XCTAssertNil(availability.first(where: { $0.domain?.rawValue == "iOS" }))
        XCTAssertNil(availability.first(where: { $0.domain?.rawValue == "macCatalyst" }))
        XCTAssertNil(availability.first(where: { $0.domain?.rawValue == "iPadOS" }))
        
        infoPlist = """
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
                        <string>iOS</string>
                        <key>version</key>
                        <string>8.0</string>
                    </dict>
                    <dict>
                        <key>name</key>
                        <string>Mac Catalyst</string>
                        <key>unavailable</key>
                        <true/>
                    </dict>
                </array>
            </dict>
        </dict>
        </plist>
        """
        try infoPlist.write(to: infoPlistURL, atomically: true, encoding: .utf8)
        // Load the bundle & reference resolve symbol graph docs
        (_, _, context) = try loadBundle(from: targetURL)
        guard let availability = (context.documentationCache["c:@F@A"]?.semantic as? Symbol)?.availability?.availability else {
            XCTFail("Did not find availability for symbol 'c:@F@A'")
            return
        }
        // Verify we add iOS and the corresponding fallback platforms (iPadOS and Catalyst)
        // except the ones marked as unavailable and the SGF does not exists for these platforms.
        XCTAssertTrue(availability.first(where: { $0.domain?.rawValue == "iOS" })?.introducedVersion == SymbolGraph.SemanticVersion(major: 8, minor: 0, patch: 0))
        XCTAssertNil(availability.first(where: { $0.domain?.rawValue == "macCatalyst" }))
        XCTAssertTrue(availability.first(where: { $0.domain?.rawValue == "iPadOS" })?.introducedVersion == SymbolGraph.SemanticVersion(major: 8, minor: 0, patch: 0))
    }
    
    func testFallbackAvailabilityVersion() throws {
        // Symbol from SG
        let symbol = """
        {
            "kind": {
                "displayName" : "Instance Property",
                "identifier" : "swift.property"
            },
            "identifier": {
                "precise": "c:@F@A",
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
                  "domain" : "iOS",
                  "introduced" : {
                    "major" : 12,
                    "minor" : 0,
                    "patch" : 0
                  }
                }
            ]
        }
        """
        let symbolGraphString = makeSymbolGraphString(
            moduleName: "MyModule",
            symbols: symbol,
            platform: """
            "operatingSystem" : {
               "minimumVersion" : {
                 "major" : 12,
                 "minor" : 0,
                 "patch" : 0
               },
               "name" : "ios"
             }
            """
        )
        // Create an empty bundle
        let targetURL = try createTemporaryDirectory(named: "test.docc")
        // Create symbol graph
        let symbolGraphURL = targetURL.appendingPathComponent("MyModule.symbols.json")
        try symbolGraphString.write(to: symbolGraphURL, atomically: true, encoding: .utf8)
        // Load the bundle & reference resolve symbol graph docs
        let (_, _, context) = try loadBundle(from: targetURL)
        guard let availability = (context.documentationCache["c:@F@A"]?.semantic as? Symbol)?.availability?.availability else {
            XCTFail("Did not find availability for symbol 'c:@F@A'")
            return
        }
        // Verify we get the availability for the fallback platforms with the same version as iOS.
        XCTAssertNotNil(availability.first(where: { $0.domain?.rawValue == "macCatalyst" }))
        XCTAssertNotNil(availability.first(where: { $0.domain?.rawValue == "iPadOS" }))
        XCTAssertEqual(availability.first(where: { $0.domain?.rawValue == "iOS" })?.introducedVersion, SymbolGraph.SemanticVersion(major: 12, minor: 0, patch: 0))
        XCTAssertEqual(availability.first(where: { $0.domain?.rawValue == "macCatalyst" })?.introducedVersion, SymbolGraph.SemanticVersion(major: 12, minor: 0, patch: 0))
        XCTAssertEqual(availability.first(where: { $0.domain?.rawValue == "iPadOS" })?.introducedVersion, SymbolGraph.SemanticVersion(major: 12, minor: 0, patch: 0))
    }
    
    func testFallbackPlatformsDontOverrideSourceAvailability() throws {
        // Symbol from SG
        let symbolGraphStringiOS = makeSymbolGraphString(
            moduleName: "MyModule",
            symbols: """
            {
                "kind": {
                    "displayName" : "Instance Property",
                    "identifier" : "swift.property"
                },
                "identifier": {
                    "precise": "c:@F@A",
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
                      "domain" : "iOS",
                      "introduced" : {
                        "major" : 12,
                        "minor" : 0,
                        "patch" : 0
                      }
                    }
                ]
            }
            """,
            platform: """
                "operatingSystem" : {
                   "minimumVersion" : {
                     "major" : 12,
                     "minor" : 0,
                     "patch" : 0
                   },
                   "name" : "ios"
                 }
            """
        )
        let symbolGraphStringCatalyst = makeSymbolGraphString(
            moduleName: "MyModule",
            symbols: """
            {
                "kind": {
                    "displayName" : "Instance Property",
                    "identifier" : "swift.property"
                },
                "identifier": {
                    "precise": "c:@F@A",
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
                      "domain" : "macCatalyst",
                      "introduced" : {
                        "major" : 6,
                        "minor" : 5,
                        "patch" : 0
                      }
                    }
                ]
            }
            """,
            platform: """
            "operatingSystem" : {
               "minimumVersion" : {
                 "major" : 6,
                 "minor" : 5,
                 "patch" : 0
               },
               "name" : "macCatalyst"
             }
            """
        )
        // Create an empty bundle
        let targetURL = try createTemporaryDirectory(named: "test.docc")
        // Create symbol graph
        try symbolGraphStringiOS.write(to: targetURL.appendingPathComponent("MyModule-ios.symbols.json"), atomically: true, encoding: .utf8)
        try symbolGraphStringCatalyst.write(to: targetURL.appendingPathComponent("MyModule-catalyst.symbols.json"), atomically: true, encoding: .utf8)
        // Load the bundle & reference resolve symbol graph docs
        let (_, _, context) = try loadBundle(from: targetURL)
        guard let availability = (context.documentationCache["c:@F@A"]?.semantic as? Symbol)?.availability?.availability else {
            XCTFail("Did not find availability for symbol 'c:@F@A'")
            return
        }
        // Verify we don't fallback to iOS if there's availability to the platform from source.
        XCTAssertNotNil(availability.first(where: { $0.domain?.rawValue == "iOS" }))
        XCTAssertNotNil(availability.first(where: { $0.domain?.rawValue == "macCatalyst" }))
        XCTAssertNotNil(availability.first(where: { $0.domain?.rawValue == "iPadOS" }))
        XCTAssertEqual(availability.first(where: { $0.domain?.rawValue == "iOS" })?.introducedVersion, SymbolGraph.SemanticVersion(major: 12, minor: 0, patch: 0))
        XCTAssertEqual(availability.first(where: { $0.domain?.rawValue == "macCatalyst" })!.introducedVersion, SymbolGraph.SemanticVersion(major: 6, minor: 5, patch: 0))
        XCTAssertEqual(availability.first(where: { $0.domain?.rawValue == "iPadOS" })?.introducedVersion, SymbolGraph.SemanticVersion(major: 12, minor: 0, patch: 0))
        
    }
    
    func testDefaultAvailabilityDontOverrideSourceAvailability() throws {
        // Symbol from SGF
        let iosSymbolGraphString = makeSymbolGraphString(
            moduleName: "MyModule",
            symbols: """
            {
                "kind": {
                    "displayName" : "Instance Property",
                    "identifier" : "swift.property"
                },
                "identifier": {
                    "precise": "c:@F@A",
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
                      "domain" : "iOS",
                      "introduced" : {
                        "major" : 12,
                        "minor" : 0
                      }
                    }
                ]
            }
            """,
            platform: """
            "operatingSystem" : {
               "minimumVersion" : {
                 "major" : 12,
                 "minor" : 0
               },
               "name" : "ios"
             }
            """
        )
        let catalystSymbolGraphString = makeSymbolGraphString(
            moduleName: "MyModule",
            symbols: """
            {
                "kind": {
                    "displayName" : "Instance Property",
                    "identifier" : "swift.property"
                },
                "identifier": {
                    "precise": "c:@F@A",
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
                      "domain" : "macCatalyst",
                      "introduced" : {
                        "major" : 6,
                        "minor" : 5
                      }
                    }
                ]
            }
            """,
            platform: """
            "operatingSystem" : {
               "minimumVersion" : {
                 "major" : 6,
                 "minor" : 5
               },
               "name" : "macCatalyst"
             }
            """
        )
        // Plist entries
        let infoPlist = """
        <plist version="1.0">
        <dict>
            <key>CDAppleDefaultAvailability</key>
            <dict>
                <key>MyModule</key>
                <array>
                    <dict>
                        <key>name</key>
                        <string>iOS</string>
                        <key>version</key>
                        <string>8.0</string>
                    </dict>
                    <dict>
                        <key>name</key>
                        <string>Mac Catalyst</string>
                        <key>version</key>
                        <string>8.0</string>
                    </dict>
                    <dict>
                        <key>name</key>
                        <string>iPadOS</string>
                        <key>version</key>
                        <string>8.0</string>
                    </dict>
                </array>
            </dict>
        </dict>
        </plist>
        """
        // Create an empty bundle
        let targetURL = try createTemporaryDirectory(named: "test.docc")
        // Create symbol graph
        try iosSymbolGraphString.write(to: targetURL.appendingPathComponent("MyModule-ios.symbols.json"), atomically: true, encoding: .utf8)
        try catalystSymbolGraphString.write(to: targetURL.appendingPathComponent("MyModule-catalyst.symbols.json"), atomically: true, encoding: .utf8)
        // Create info list
        let infoPlistURL = targetURL.appendingPathComponent("Info.plist")
        try infoPlist.write(to: infoPlistURL, atomically: true, encoding: .utf8)
        // Load the bundle & reference resolve symbol graph docs
        let (_, _, context) = try loadBundle(from: targetURL)
        guard let availability = (context.documentationCache["c:@F@A"]?.semantic as? Symbol)?.availability?.availability else {
            XCTFail("Did not find availability for symbol 'c:@F@A'")
            return
        }
        // Verify we don't display default availability because we have availability information from source.
        XCTAssertNotNil(availability.first(where: { $0.domain?.rawValue == "iOS" }))
        XCTAssertNotNil(availability.first(where: { $0.domain?.rawValue == "macCatalyst" }))
        XCTAssertNotNil(availability.first(where: { $0.domain?.rawValue == "iPadOS" }))
        XCTAssertEqual(availability.first(where: { $0.domain?.rawValue == "iOS" })?.introducedVersion, SymbolGraph.SemanticVersion(major: 12, minor: 0, patch: 0))
        XCTAssertEqual(availability.first(where: { $0.domain?.rawValue == "macCatalyst" })?.introducedVersion, SymbolGraph.SemanticVersion(major: 6, minor: 5, patch: 0))
        XCTAssertEqual(availability.first(where: { $0.domain?.rawValue == "iPadOS" })?.introducedVersion, SymbolGraph.SemanticVersion(major: 12, minor: 0, patch: 0))
    }
    
    func testDefaultAvailabilityFillSourceAvailability() throws {
        // Symbol from SGF
        let symbol = """
        {
            "kind": {
                "displayName" : "Instance Property",
                "identifier" : "swift.property"
            },
            "identifier": {
                "precise": "c:@F@A",
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
                   "domain" : "tvos",
                   "introduced" : {
                        "major" : 10,
                        "minor" : 0
                   }
                }
            ]
        }
        """
        let symbolGraphString = makeSymbolGraphString(
            moduleName: "MyModule",
            symbols: symbol,
            platform: """
            "operatingSystem" : {
               "minimumVersion" : {
                 "major" : 10,
                 "minor" : 0
               },
               "name" : "tvos"
             }
            """
        )
        // Plist entries
        let infoPlist = """
        <plist version="1.0">
        <dict>
            <key>CDAppleDefaultAvailability</key>
            <dict>
                <key>MyModule</key>
                <array>
                    <dict>
                        <key>name</key>
                        <string>iOS</string>
                        <key>version</key>
                        <string>8.0</string>
                    </dict>
                    <dict>
                        <key>name</key>
                        <string>Mac Catalyst</string>
                        <key>version</key>
                        <string>7.0</string>
                    </dict>
                    <dict>
                        <key>name</key>
                        <string>iPadOS</string>
                        <key>version</key>
                        <string>6.0</string>
                    </dict>
                </array>
            </dict>
        </dict>
        </plist>
        """
        // Create an empty bundle
        let targetURL = try createTemporaryDirectory(named: "test.docc")
        // Create symbol graph
        let symbolGraphURL = targetURL.appendingPathComponent("MyModule.symbols.json")
        try symbolGraphString.write(to: symbolGraphURL, atomically: true, encoding: .utf8)
        // Create info list
        let infoPlistURL = targetURL.appendingPathComponent("Info.plist")
        try infoPlist.write(to: infoPlistURL, atomically: true, encoding: .utf8)
        // Load the bundle & reference resolve symbol graph docs
        let (_, _, context) = try loadBundle(from: targetURL)
        guard let availability = (context.documentationCache["c:@F@A"]?.semantic as? Symbol)?.availability?.availability else {
            XCTFail("Did not find availability for symbol 'c:@F@A'")
            return
        }
        // Verify we fill the missing source availability using the default availability information from the Info.plist.
        XCTAssertNotNil(availability.first(where: { $0.domain?.rawValue == "macCatalyst" }))
        XCTAssertNotNil(availability.first(where: { $0.domain?.rawValue == "iPadOS" }))
        XCTAssertEqual(availability.first(where: { $0.domain?.rawValue == "iOS" })?.introducedVersion, SymbolGraph.SemanticVersion(major: 8, minor: 0, patch: 0))
        XCTAssertEqual(availability.first(where: { $0.domain?.rawValue == "macCatalyst" })?.introducedVersion, SymbolGraph.SemanticVersion(major: 7, minor: 0, patch: 0))
    }
    
    func testUnconditionallyunavailablePlatforms() throws {
        // Create an empty bundle
        let targetURL = try createTemporaryDirectory(named: "test.docc")
        // Symbol from SGF
        try makeSymbolGraphString(
            moduleName: "MyModule",
            symbols: """
            {
                "kind": {
                    "displayName" : "Instance Property",
                    "identifier" : "swift.property"
                },
                "identifier": {
                    "precise": "c:@F@A",
                    "interfaceLanguage": "swift"
                },
                "pathComponents": [
                    "Foo"
                ],
                "names": {
                    "title": "Foo",
                },
                "accessLevel": "public",
                "availability" : [{
                    "domain" : "iOS",
                    "introduced" : {
                        "major" : 10,
                        "minor" : 0
                    }
                }]
            }
            """,
            platform: """
            "operatingSystem" : {
               "minimumVersion" : {
                 "major" : 12,
                 "minor" : 0
               },
               "name" : "ios"
             }
            """
        ).write(to: targetURL.appendingPathComponent("MyModule-ios.symbols.json"), atomically: true, encoding: .utf8)
        try makeSymbolGraphString(
            moduleName: "MyModule",
            symbols: """
            {
                "kind": {
                    "displayName" : "Instance Property",
                    "identifier" : "swift.property"
                },
                "identifier": {
                    "precise": "c:@F@A",
                    "interfaceLanguage": "swift"
                },
                "pathComponents": [
                    "Foo"
                ],
                "names": {
                    "title": "Foo",
                },
                "accessLevel": "public",
                "availability" : [{
                    "domain" : "maccatalyst",
                    "introduced" : {
                        "major" : 12,
                        "minor" : 0
                    }
                }]
            }
            """,
            platform: """
            "environment" : "macabi",
            "operatingSystem" : {
               "minimumVersion" : {
                 "major" : 12,
                 "minor" : 0,
                 "patch" : 0
               },
               "name" : "ios"
             }
            """
        ).write(to: targetURL.appendingPathComponent("MyModule-catalyst.symbols.json"), atomically: true, encoding: .utf8)
        // Plist entries
        let infoPlist = """
        <plist version="1.0">
        <dict>
            <key>CDAppleDefaultAvailability</key>
            <dict>
                <key>MyModule</key>
                <array>
                    <dict>
                        <key>name</key>
                        <string>iOS</string>
                        <key>unavailable</key>
                        <true/>
                    </dict>
                    <dict>
                        <key>name</key>
                        <string>Mac Catalyst</string>
                        <key>unavailable</key>
                        <true/>
                    </dict>
                    <dict>
                        <key>name</key>
                        <string>iPadOS</string>
                        <key>unavailable</key>
                        <true/>
                    </dict>
                </array>
            </dict>
        </dict>
        </plist>
        """
        // Create info list
        let infoPlistURL = targetURL.appendingPathComponent("Info.plist")
        try infoPlist.write(to: infoPlistURL, atomically: true, encoding: .utf8)
        // Load the bundle & reference resolve symbol graph docs
        var (_, _, context) = try loadBundle(from: targetURL)
        guard let availability = (context.documentationCache["c:@F@A"]?.semantic as? Symbol)?.availability?.availability else {
            XCTFail("Did not find availability for symbol 'c:@F@A'")
            return
        }
        // Verify we don't add iPadOS availability since is marked as unavailable but
        // we do add catalyst since we provide source availbility for that platform
        // and the info.plsit don't override information coming from the SGF.
        XCTAssertTrue(availability.count == 2)
        XCTAssertNotNil(availability.first(where: { $0.domain?.rawValue == "iOS" }))
        XCTAssertNotNil(availability.first(where: { $0.domain?.rawValue == "macCatalyst" }))
        XCTAssertNil(availability.first(where: { $0.domain?.rawValue == "iPadOS" }))

        try makeSymbolGraphString(
            moduleName: "MyModule",
            symbols: """
            """,
            platform: """
            """
        ).write(to: targetURL.appendingPathComponent("MyModule-catalyst.symbols.json"), atomically: true, encoding: .utf8)
        (_, _, context) = try loadBundle(from: targetURL)
        guard let availability = (context.documentationCache["c:@F@A"]?.semantic as? Symbol)?.availability?.availability else {
            XCTFail("Did not find availability for symbol 'c:@F@A'")
            return
        }
        
        // Verify we don't add Catalyst availability since it's not part
        // of the SGFs.
        XCTAssertTrue(availability.count == 1)
        XCTAssertNotNil(availability.first(where: { $0.domain?.rawValue == "iOS" }))
        XCTAssertNil(availability.first(where: { $0.domain?.rawValue == "maccatalyst" }))
        XCTAssertNil(availability.first(where: { $0.domain?.rawValue == "iPadOS" }))
    }
    
    func testSymbolUnavailablePerPlatform() throws {
        // Create an empty bundle
        let targetURL = try createTemporaryDirectory(named: "test.docc")
        // Symbol from SGF
        try makeSymbolGraphString(
            moduleName: "MyModule",
            symbols: """
            {
                "kind": {
                    "displayName" : "Instance Property",
                    "identifier" : "swift.property"
                },
                "identifier": {
                    "precise": "c:@F@A",
                    "interfaceLanguage": "swift"
                },
                "pathComponents": [
                    "Foo"
                ],
                "names": {
                    "title": "Foo",
                },
                "accessLevel": "public",
                "availability" : [{
                    "domain" : "iOS",
                    "introduced" : {
                        "major" : 10,
                        "minor" : 0
                    }
                }]
            }
            """,
            platform: """
            "operatingSystem" : {
               "minimumVersion" : {
                 "major" : 12,
                 "minor" : 0,
                 "patch" : 0
               },
               "name" : "ios"
             }
            """
        ).write(to: targetURL.appendingPathComponent("MyModule-ios.symbols.json"), atomically: true, encoding: .utf8)
        try makeSymbolGraphString(
            moduleName: "MyModule",
            symbols: """
            {
                "kind": {
                    "displayName" : "Instance Property",
                    "identifier" : "swift.property"
                },
                "identifier": {
                    "precise": "c:@F@A",
                    "interfaceLanguage": "swift"
                },
                "pathComponents": [
                    "Foo"
                ],
                "names": {
                    "title": "Foo",
                },
                "accessLevel": "public",
                "availability" : [{
                    "domain" : "macCatalyst",
                    "introduced" : {
                        "major" : 12,
                        "minor" : 0
                    }
                }]
            },
            {
                "kind": {
                    "displayName" : "Instance Property",
                    "identifier" : "swift.property"
                },
                "identifier": {
                    "precise": "c:@F@B",
                    "interfaceLanguage": "swift"
                },
                "pathComponents": [
                    "Bar"
                ],
                "names": {
                    "title": "Bar",
                },
                "accessLevel": "public",
                "availability" : [{
                    "domain" : "macCatalyst",
                    "introduced" : {
                        "major" : 12,
                        "minor" : 0,
                        "patch" : 0
                    }
                }]
            }
            """,
            platform: """
            "environment" : "macabi",
            "operatingSystem" : {
               "minimumVersion" : {
                 "major" : 12,
                 "minor" : 0
               },
               "name" : "ios"
             }
            """
        ).write(to: targetURL.appendingPathComponent("MyModule-catalyst.symbols.json"), atomically: true, encoding: .utf8)
        // Load the bundle & reference resolve symbol graph docs
        var (_, _, context) = try loadBundle(from: targetURL)
        guard let availabilityFoo = (context.documentationCache["c:@F@A"]?.semantic as? Symbol)?.availability?.availability else {
            XCTFail("Did not find availability for symbol 'c:@F@A'")
            return
        }
        guard let availabilityBar = (context.documentationCache["c:@F@B"]?.semantic as? Symbol)?.availability?.availability else {
            XCTFail("Did not find availability for symbol 'c:@F@B'")
            return
        }
        
        // // Verify we don't add Catalyst availability for since it's not part
        // of it's SG and iPadOS since it's set as unavailable.
        XCTAssertTrue(availabilityFoo.count == 3)
        XCTAssertTrue(availabilityBar.count == 1)
        XCTAssertNotNil(availabilityFoo.first(where: { $0.domain?.rawValue == "macCatalyst" }))
        XCTAssertNotNil(availabilityFoo.first(where: { $0.domain?.rawValue == "iOS" }))
        XCTAssertNotNil(availabilityFoo.first(where: { $0.domain?.rawValue == "iPadOS" }))
        XCTAssertNotNil(availabilityBar.first(where: { $0.domain?.rawValue == "macCatalyst" }))
        
        // Plist entries
        let infoPlist = """
        <plist version="1.0">
        <dict>
            <key>CDAppleDefaultAvailability</key>
            <dict>
                <key>MyModule</key>
                <array>
                    <dict>
                        <key>name</key>
                        <string>iOS</string>
                        <key>unavailable</key>
                        <true/>
                    </dict>
                    <dict>
                        <key>name</key>
                        <string>Mac Catalyst</string>
                        <key>unavailable</key>
                        <true/>
                    </dict>
                    <dict>
                        <key>name</key>
                        <string>iPadOS</string>
                        <key>unavailable</key>
                        <true/>
                    </dict>
                </array>
            </dict>
        </dict>
        </plist>
        """
        // Create info list
        let infoPlistURL = targetURL.appendingPathComponent("Info.plist")
        try infoPlist.write(to: infoPlistURL, atomically: true, encoding: .utf8)
        (_, _, context) = try loadBundle(from: targetURL)
        guard let availabilityFoo = (context.documentationCache["c:@F@A"]?.semantic as? Symbol)?.availability?.availability else {
            XCTFail("Did not find availability for symbol 'c:@F@A'")
            return
        }
        guard let availabilityBar = (context.documentationCache["c:@F@B"]?.semantic as? Symbol)?.availability?.availability else {
            XCTFail("Did not find availability for symbol 'c:@F@B'")
            return
        }
        XCTAssertTrue(availabilityFoo.count == 2)
        XCTAssertTrue(availabilityBar.count == 1)
        XCTAssertNotNil(availabilityFoo.first(where: { $0.domain?.rawValue == "macCatalyst" }))
        XCTAssertNotNil(availabilityFoo.first(where: { $0.domain?.rawValue == "iOS" }))
        XCTAssertNil(availabilityFoo.first(where: { $0.domain?.rawValue == "iPadOS" }))
        XCTAssertNotNil(availabilityBar.first(where: { $0.domain?.rawValue == "macCatalyst" }))
    }
    
    func testDefaultModuleAvailability() throws {
        // Create an empty bundle
        let targetURL = try createTemporaryDirectory(named: "test.docc")
        // Symbol from SGF
        try makeSymbolGraphString(
            moduleName: "MyModule",
            symbols: """
            {
                "kind": {
                    "displayName" : "Instance Property",
                    "identifier" : "swift.property"
                },
                "identifier": {
                    "precise": "c:@F@A",
                    "interfaceLanguage": "swift"
                },
                "pathComponents": [
                    "Foo"
                ],
                "names": {
                    "title": "Foo",
                },
                "accessLevel": "public"
            }
            """,
            platform: """
            "operatingSystem" : {
               "minimumVersion" : {
                 "major" : 12,
                 "minor" : 0,
                 "patch" : 0
               },
               "name" : "macosx"
             }
            """
        ).write(to: targetURL.appendingPathComponent("MyModule-swift.symbols.json"), atomically: true, encoding: .utf8)
        // Plist entries
        let infoPlist = """
        <plist version="1.0">
        <dict>
            <key>CDAppleDefaultAvailability</key>
            <dict>
                <key>MyModule</key>
                <array>
                    <dict>
                        <key>name</key>
                        <string>macOS</string>
                        <key>version</key>
                        <string>10.0</string>
                    </dict>
                </array>
            </dict>
        </dict>
        </plist>
        """
        let infoPlistURL = targetURL.appendingPathComponent("Info.plist")
        try infoPlist.write(to: infoPlistURL, atomically: true, encoding: .utf8)
        let (_, _, context) = try loadBundle(from: targetURL)
        guard let availability = (context.documentationCache["c:@F@A"]?.semantic as? Symbol)?.availability?.availability else {
            XCTFail("Did not find availability for symbol 'c:@F@A'")
            return
        }
        XCTAssertNotNil(availability.first(where: { $0.domain?.rawValue == "macOS" }))
        XCTAssertEqual(availability.first(where: { $0.domain?.rawValue == "macOS" })?.introducedVersion, SymbolGraph.SemanticVersion(major: 10, minor: 0, patch: 0))
    }
    
    func testCanonicalPlatformNameUniformity() throws {
        
        let testBundle = Folder(name: "TestBundle.docc", content: [
            TextFile(name: "Info.plist", utf8Content: """
            <plist version="1.0">
            <dict>
                <key>CDAppleDefaultAvailability</key>
                <dict>
                    <key>MyModule</key>
                    <array>
                        <dict>
                            <key>name</key>
                            <string>Mac Catalyst</string>
                            <key>version</key>
                            <string>1.0</string>
                        </dict>
                    </array>
                </dict>
            </dict>
            </plist>
            """),
            Folder(name: "Symbols", content: [
                TextFile(name: "MyModule-tvos-objc.symbols.json", utf8Content: makeSymbolGraphString(
                    moduleName: "MyModule",
                    symbols: """
                  {
                    "accessLevel" : "public",
                    "availability" : [
                        {
                          "domain" : "tvos",
                          "introduced" : {
                            "major" : 15,
                            "minor" : 2,
                            "patch" : 0
                          }
                        },
                    ],
                    "declarationFragments" : [],
                    "functionSignature" : {
                      "parameters" : [],
                      "returns" : []
                    },
                    "identifier" : {
                      "interfaceLanguage" : "objective-c",
                      "precise" : "c:@F@A"
                    },
                    "kind" : {
                        "displayName" : "Instance Property",
                        "identifier" : "objective-c.property"
                    },
                    "names" : {
                      "subHeading" : [],
                      "title" : "A"
                    },
                    "pathComponents" : ["A"]
                  }
                """,
                    platform: """
                 "operatingSystem" : {
                   "minimumVersion" : {
                     "major" : 12,
                     "minor" : 0,
                     "patch" : 0
                   },
                   "name" : "tvos"
                 }
                """
                )),
                TextFile(name: "MyModule-catalyst-objc.symbols.json", utf8Content: makeSymbolGraphString(moduleName: "MyModule", symbols: """
                  {
                    "accessLevel" : "public",
                    "availability" : [
                        {
                          "domain" : "maccatalyst",
                          "introduced" : {
                            "major" : 15,
                            "minor" : 2,
                            "patch" : 0
                          }
                        },
                    ],
                    "declarationFragments" : [],
                    "functionSignature" : {
                      "parameters" : [],
                      "returns" : []
                    },
                    "identifier" : {
                      "interfaceLanguage" : "objective-c",
                      "precise" : "c:@F@A"
                    },
                    "kind" : {
                        "displayName" : "Instance Property",
                        "identifier" : "objective-c.property"
                    },
                    "names" : {
                      "subHeading" : [],
                      "title" : "A"
                    },
                    "pathComponents" : ["A"]
                  }
                """,
                 platform: """
                 "environment" : "macabi",
                 "operatingSystem" : {
                    "minimumVersion" : {
                      "major" : 12,
                      "minor" : 0,
                      "patch" : 0
                    },
                    "name" : "ios"
                 }
                 """)),
            ]),
        ])
        let tempURL = try createTemporaryDirectory()
        let bundleURL = try testBundle.write(inside: tempURL)
        let (_, _, context) = try loadBundle(from: bundleURL)
        guard let availability = (context.documentationCache["c:@F@A"]?.semantic as? Symbol)?.availability?.availability else {
            XCTFail("Did not find availability for symbol 'c:@F@A'")
            return
        }
        // Verify we use one canonical platform name 'macCatalyst' for both
        // 'Mac Catalyst' (info.plist) and 'maccatalyst' (SGF).
        XCTAssertTrue(availability.count == 2)
        XCTAssertTrue(availability.filter({ $0.domain?.rawValue == "macCatalyst" }).count == 1)
        XCTAssertTrue(availability.filter({ $0.domain?.rawValue == "maccatalyst" }).count == 0)
    }
    
    func testFallbackOverrideDefaultAvailability() throws {
        // Symbol from SG
        let symbolGraphStringiOS = makeSymbolGraphString(
            moduleName: "MyModule",
            symbols: """
            {
                "kind": {
                    "displayName" : "Instance Property",
                    "identifier" : "swift.property"
                },
                "identifier": {
                    "precise": "c:@F@A",
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
                      "domain" : "iOS",
                      "introduced" : {
                        "major" : 12,
                        "minor" : 0,
                        "patch" : 0
                      }
                    }
                ]
            }
            """,
            platform: """
                "operatingSystem" : {
                   "minimumVersion" : {
                     "major" : 12,
                     "minor" : 0,
                     "patch" : 0
                   },
                   "name" : "ios"
                 }
            """
        )
        let symbolGraphStringCatalyst = makeSymbolGraphString(
            moduleName: "MyModule",
            symbols: """
            {
                "kind": {
                    "displayName" : "Instance Property",
                    "identifier" : "swift.property"
                },
                "identifier": {
                    "precise": "c:@F@A",
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
                      "domain" : "iOS",
                      "introduced" : {
                        "major" : 12,
                        "minor" : 0,
                        "patch" : 0
                      }
                    }
                ]
            }
            """,
            platform: """
            "environment" : "macabi",
            "operatingSystem" : {
               "minimumVersion" : {
                 "major" : 6,
                 "minor" : 5,
                 "patch" : 0
               },
               "name" : "ios"
             }
            """
        )
        let infoPlist = """
        <plist version="1.0">
        <dict>
            <key>CDAppleDefaultAvailability</key>
            <dict>
                <key>MyModule</key>
                <array>
                    <dict>
                        <key>name</key>
                        <string>Mac Catalyst</string>
                        <key>version</key>
                        <string>1.0</string>
                    </dict>
                </array>
            </dict>
        </dict>
        </plist>
        """
        // Create an empty bundle
        let targetURL = try createTemporaryDirectory(named: "test.docc")
        // Store files
        try symbolGraphStringiOS.write(to: targetURL.appendingPathComponent("MyModule-ios.symbols.json"), atomically: true, encoding: .utf8)
        try symbolGraphStringCatalyst.write(to: targetURL.appendingPathComponent("MyModule-catalyst.symbols.json"), atomically: true, encoding: .utf8)
        try infoPlist.write(to: targetURL.appendingPathComponent("Info.plist"), atomically: true, encoding: .utf8)
        // Load the bundle & reference resolve symbol graph docs
        let (_, _, context) = try loadBundle(from: targetURL)
        let availability = try XCTUnwrap((context.documentationCache["c:@F@A"]?.semantic as? Symbol)?.availability?.availability)
        // Verify we fallback to iOS even if there's default availability for the Catalyst platform.
        XCTAssertNotNil(availability.first(where: { $0.domain?.rawValue == "iOS" }))
        XCTAssertEqual(availability.first(where: { $0.domain?.rawValue == "macCatalyst" })?.introducedVersion, SymbolGraph.SemanticVersion(major: 12, minor: 0, patch: 0))
    }
    
    func testDefaultAvailabilityWhenMissingFallbackPlatform() throws {
        // Symbol from SG
        let symbolGraphStringCatalyst = makeSymbolGraphString(
            moduleName: "MyModule",
            symbols: """
            {
                "kind": {
                    "displayName" : "Instance Property",
                    "identifier" : "swift.property"
                },
                "identifier": {
                    "precise": "c:@F@A",
                    "interfaceLanguage": "swift"
                },
                "pathComponents": [
                    "Foo"
                ],
                "names": {
                    "title": "Foo",
                },
                "accessLevel": "public",
                "availability" : []
            }
            """,
            platform: """
            "environment" : "macabi",
            "operatingSystem" : {
               "minimumVersion" : {
                 "major" : 6,
                 "minor" : 5,
                 "patch" : 0
               },
               "name" : "ios"
             }
            """
        )
        let infoPlist = """
        <plist version="1.0">
        <dict>
            <key>CDAppleDefaultAvailability</key>
            <dict>
                <key>MyModule</key>
                <array>
                    <dict>
                        <key>name</key>
                        <string>Mac Catalyst</string>
                        <key>version</key>
                        <string>1.0</string>
                    </dict>
                    <dict>
                        <key>name</key>
                        <string>iOS</string>
                        <key>version</key>
                        <string>2.0</string>
                    </dict>
                </array>
            </dict>
        </dict>
        </plist>
        """
        // Create an empty bundle
        let targetURL = try createTemporaryDirectory(named: "test.docc")
        // Store files
        try symbolGraphStringCatalyst.write(to: targetURL.appendingPathComponent("MyModule-catalyst.symbols.json"), atomically: true, encoding: .utf8)
        try infoPlist.write(to: targetURL.appendingPathComponent("Info.plist"), atomically: true, encoding: .utf8)
        // Load the bundle & reference resolve symbol graph docs
        let (_, _, context) = try loadBundle(from: targetURL)
        guard let availability = (context.documentationCache["c:@F@A"]?.semantic as? Symbol)?.availability?.availability else {
            XCTFail("Did not find availability for symbol 'c:@F@A'")
            return
        }
        // Verify we fallback to iOS even if there's default availability for the Catalyst platform.
        XCTAssertNotNil(availability.first(where: { $0.domain?.rawValue == "iOS" }))
        XCTAssertNotNil(availability.first(where: { $0.domain?.rawValue == "macCatalyst" }))
        XCTAssertEqual(availability.first(where: { $0.domain?.rawValue == "macCatalyst" })?.introducedVersion, SymbolGraph.SemanticVersion(major: 1, minor: 0, patch: 0))
    }
    
    
    func testDefaultAvailabilityWhenSymbolIsNotAvailableForThatPlatform() throws {
        // Symbol from SGF
        let symbolTVOS = """
        {
            "kind": {
                "displayName" : "Instance Property",
                "identifier" : "swift.property"
            },
            "identifier": {
                "precise": "c:@F@A",
                "interfaceLanguage": "objective-c"
            },
            "pathComponents": [
                "Foo"
            ],
            "names": {
                "title": "Foo",
            },
            "accessLevel": "public"
        }
        """
        let symbolIOS = """
        {
            "kind": {
                "displayName" : "Instance Property",
                "identifier" : "swift.property"
            },
            "identifier": {
                "precise": "c:@F@A",
                "interfaceLanguage": "objective-c"
            },
            "pathComponents": [
                "Foo"
            ],
            "names": {
                "title": "Foo",
            },
            "accessLevel": "public"
        },
        {
            "kind": {
                "displayName" : "Instance Property",
                "identifier" : "swift.property"
            },
            "identifier": {
                "precise": "c:@F@Bar",
                 "interfaceLanguage" : "objective-c",
            },
            "pathComponents": [
                "Bar"
            ],
            "names": {
                "title": "Bar",
            },
            "accessLevel": "public"
        }
        """
        let tvOSSymbolGraphString = makeSymbolGraphString(
            moduleName: "MyModule",
            symbols: symbolTVOS,
            platform: """
            "operatingSystem" : {
               "minimumVersion" : {
                 "major" : 12,
                 "minor" : 0,
                 "patch" : 0
               },
               "name" : "tvos"
             }
            """
        )
        let iOSSymbolGraphString = makeSymbolGraphString(
            moduleName: "MyModule",
            symbols: symbolIOS,
            platform: """
            "operatingSystem" : {
               "minimumVersion" : {
                 "major" : 12,
                 "minor" : 0,
                 "patch" : 0
               },
               "name" : "ios"
             }
            """
        )
        let infoPlist = """
        <plist version="1.0">
        <dict>
            <key>CDAppleDefaultAvailability</key>
            <dict>
                <key>MyModule</key>
                <array>
                    <dict>
                        <key>name</key>
                        <string>iOS</string>
                    </dict>
                    <dict>
                        <key>name</key>
                        <string>tvOS</string>
                    </dict>
                </array>
            </dict>
        </dict>
        </plist>
        """
        // Create an empty bundle
        let targetURL = try createTemporaryDirectory(named: "test.docc")
        // Create symbol graph file
        let tvOSymbolGraphURL = targetURL.appendingPathComponent("MyModule-tvos.symbols.json")
        let iOSSymbolGraphURL = targetURL.appendingPathComponent("MyModule-ios.symbols.json")
        try tvOSSymbolGraphString.write(to: tvOSymbolGraphURL, atomically: true, encoding: .utf8)
        try iOSSymbolGraphString.write(to: iOSSymbolGraphURL, atomically: true, encoding: .utf8)
        // Create Info.plist
        let infoPlistURL = targetURL.appendingPathComponent("Info.plist")
        try infoPlist.write(to: infoPlistURL, atomically: true, encoding: .utf8)
        // Load the bundle & reference resolve symbol graph docs
        let (_, _, context) = try loadBundle(from: targetURL)
        guard let availability = (context.documentationCache["c:@F@Bar"]?.semantic as? Symbol)?.availability?.availability else {
            XCTFail("Did not find availability for symbol 'c:@F@Bar'")
            return
        }
        // Verify we dont add platforms to symbols that are not in that platform SGF. Even if the
        // platform is part of the default availability.
        XCTAssertEqual(availability.count, 3)
        XCTAssertNotNil(availability.first(where: { $0.domain?.rawValue == "iOS" }))
        XCTAssertNotNil(availability.first(where: { $0.domain?.rawValue == "macCatalyst" }))
        XCTAssertNotNil(availability.first(where: { $0.domain?.rawValue == "iPadOS" }))
    }
    
    // MARK: - Helpers
    
    private func makeSymbolGraphLoader(
        symbolGraphURLs: [URL],
        configureSymbolGraph: ((inout SymbolGraph) -> ())? = nil
    ) throws -> SymbolGraphLoader {
        let bundle = DocumentationBundle(
            info: DocumentationBundle.Info(
                displayName: "Test",
                id: "com.example.test"
            ),
            baseURL: URL(string: "https://example.com/example")!,
            symbolGraphURLs: symbolGraphURLs,
            markupURLs: [],
            miscResourceURLs: []
        )
        
        return SymbolGraphLoader(
            bundle: bundle,
            dataLoader: { url, _ in
                try FileManager.default.contents(of: url)
            },
            symbolGraphTransformer: configureSymbolGraph
        )
    }
}
