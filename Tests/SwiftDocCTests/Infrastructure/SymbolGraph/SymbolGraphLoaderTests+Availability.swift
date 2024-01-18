/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import XCTest
@testable import SymbolKit
@testable import SwiftDocC
import SwiftDocCTestUtilities

class SymbolGraphLoaderTestsAvailability: XCTestCase {
    
    func testLoadSymbolPlatformAvailability() throws {
        let tempURL = try createTemporaryDirectory()
        try makeSymbolGraphString(
            moduleName: "MyModule",
            symbols: makeSymbol(title: "Foo", domain: "iOS", introducedVersion: (10, 0, 0)),
            platform: makePlatform("iOS")
        ).write(to: tempURL.appendingPathComponent("ios-swift.symbols.json"), atomically: true, encoding: .utf8)
        try makeSymbolGraphString(
            moduleName: "MyModule",
            symbols: makeSymbol(title: "Foo", domain: "tvOS", introducedVersion: (8, 0, 0)),
            platform: makePlatform("tvOS")
        ).write(to: tempURL.appendingPathComponent("tvos-swift.symbols.json"), atomically: true, encoding: .utf8)
        var loader = try makeSymbolGraphLoader(
            symbolGraphURLs:[
                tempURL.appendingPathComponent("ios-swift.symbols.json"),
                tempURL.appendingPathComponent("tvos-swift.symbols.json")
            ]
        )
        try loader.loadAll()
        let expectedAvailabilitesInfo = ["tvOS":8, "iOS":10]
        // Check that the availability matches the information from the symbolgraph.
        XCTAssertEqual(expectedAvailabilitesInfo, extractSymbolAvailabilityInformation(loader))
    }
    
    func testLoadSymbolPlatformAvailabilityWithDefaultAvailability() throws {
        let tempURL = try createTemporaryDirectory()
        let infoPlistInfo = makeInfoPlistFileWithDefaultAvailability(
            availabilityInfo: [("iOS","1.0"), ("tvOS","1.0"), ("watchOS","1.0")]
        )
        let infoPlistWithAllFieldsData = Data(infoPlistInfo.utf8)
        let documentationBundleInfo = try DocumentationBundle.Info(
            from: infoPlistWithAllFieldsData
        )
        try makeSymbolGraphString(
            moduleName: "MyModule",
            symbols: makeSymbol(title: "Foo", domain: "iOS", introducedVersion: (10, 0, 0)),
            platform: makePlatform("ios")
        ).write(to: tempURL.appendingPathComponent("ios-swift.symbols.json"), atomically: true, encoding: .utf8)
        try makeSymbolGraphString(
            moduleName: "MyModule",
            symbols: makeSymbol(title: "Foo", domain: "tvOS", introducedVersion: (8, 0, 0)),
            platform: makePlatform("tvos")
        ).write(to: tempURL.appendingPathComponent("tvos-swift.symbols.json"), atomically: true, encoding: .utf8)
        try makeSymbolGraphString(
            moduleName: "MyModule",
            symbols: makeSymbol(title: "Foo", domain: "watchOS"),
            platform: makePlatform("watchos")
        ).write(to: tempURL.appendingPathComponent("watchos-swift.symbols.json"), atomically: true, encoding: .utf8)
        
        var loader = try makeSymbolGraphLoader(
            symbolGraphURLs:[
                tempURL.appendingPathComponent("ios-swift.symbols.json"),
                tempURL.appendingPathComponent("tvos-swift.symbols.json"),
                tempURL.appendingPathComponent("watchos-swift.symbols.json")
            ],
            bundleInfo: documentationBundleInfo
        )
        try loader.loadAll()
        let expectedAvailabilitesInfo = ["tvOS":8, "iOS":10, "macCatalyst": 10, "watchOS": 1]
        // Check that the availability contains the missing version information mathcing the
        // Info.plist information.
        XCTAssertEqual(expectedAvailabilitesInfo, extractSymbolAvailabilityInformation(loader))
    }
    
    // MARK: - Helpers
    
    private func makeSymbolGraphLoader(
        symbolGraphURLs: [URL],
        configureSymbolGraph: ((inout SymbolGraph) -> ())? = nil,
        bundleInfo: DocumentationBundle.Info? = nil
    ) throws -> SymbolGraphLoader {
        let workspace = DocumentationWorkspace()
        let bundle = DocumentationBundle(
            info: bundleInfo ?? DocumentationBundle.Info(
                displayName: "Test",
                identifier: "com.example.test",
                version: "1.2.3"
            ),
            baseURL: URL(string: "https://example.com/example")!,
            symbolGraphURLs: symbolGraphURLs,
            markupURLs: [],
            miscResourceURLs: []
        )
        try workspace.registerProvider(PrebuiltLocalFileSystemDataProvider(bundles: [bundle]))
        
        return SymbolGraphLoader(
            bundle: bundle,
            dataProvider: workspace,
            configureSymbolGraph: configureSymbolGraph
        )
    }
    
    private func makeSymbol(
        title: String,
        domain: String,
        introducedVersion: (major: Int, minor: Int, patch: Int)? = nil
    ) -> String {
        """
        {
            "kind": {
                "identifier": "\(domain).property",
                "displayName": "Instance Property"
            },
            "identifier": {
                "precise": "c:@\(title)",
                "interfaceLanguage": "\(domain)"
            },
            "pathComponents": [
                "\(title)"
            ],
            "names": {
                "title": "\(title)",
            },
            "accessLevel": "public",
            "availability" : [
                {
                  "domain" : "\(domain)",
                    \((introducedVersion != nil) 
                    ? """
                      "introduced" : {
                        "major" : \(introducedVersion!.major),
                        "minor" : \(introducedVersion!.minor),
                        "patch" : \(introducedVersion!.patch),
                      }
                    """ : "")
                  
                }
            ]
        }
        """
    }
    
    private func makePlatform(_ platformName: String) -> String {
        """
        "architecture" : "arm64",
        "operatingSystem" : {
          "minimumVersion" : {
            "major" : 12,
            "minor" : 0,
            "patch" : 0
          },
          "name" : "\(platformName)"
        },
        "vendor" : "apple"
        """
    }
    
    private func extractSymbolAvailabilityInformation(_ loader: SymbolGraphLoader) -> [String: Int] {
        var availabilitiesInfo: [String:Int] = [:]
        loader.symbolGraphs.forEach { (_, graph) in
            graph.symbols.forEach { (_, symbol) in
                if let availability = symbol.mixins[SymbolGraph.Symbol.Availability.mixinKey] as? SymbolGraph.Symbol.Availability {
                    availability.availability.forEach {
                        availabilitiesInfo[$0.domain!.rawValue] = $0.introducedVersion?.major
                    }
                }
            }
        }
        return availabilitiesInfo
    }
    
    private func makeInfoPlistFileWithDefaultAvailability(availabilityInfo: [(platformName: String, version: String)]) -> String {
        """
        <plist version="1.0">
        <dict>
            <key>CFBundleDisplayName</key>
            <string>MyModule</string>
            <key>CDAppleDefaultAvailability</key>
            <dict>
                <key>MyModule</key>
                <array>
                    \(availabilityInfo.map {
                        """
                        <dict>
                            <key>name</key>
                            <string>\($0.platformName)</string>
                            <key>version</key>
                            <string>\($0.version)</string>
                        </dict>
                        """
                    }.joined(separator: "\n"))
                </array>
            </dict>
        </dict>
        </plist>
        """
    }
}
