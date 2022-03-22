/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocC

class DocumentationCatalogInfoTests: XCTestCase {
    // Test whether the catalog correctly loads the test catalog Info.plist file.
    func testLoadTestCatalogInfoPlist() throws {
        let infoPlistURL = Bundle.module.url(
            forResource: "TestCatalog", withExtension: "docc", subdirectory: "Test Catalogs")!
            .appendingPathComponent("Info.plist")

        let infoPlistData = try Data(contentsOf: infoPlistURL)
        let info = try DocumentationCatalog.Info(from: infoPlistData)
        
        XCTAssertEqual(info.displayName, "Test Catalog")
        XCTAssertEqual(info.identifier, "org.swift.docc.example")
        XCTAssertEqual(info.version, "0.1.0")
        XCTAssertEqual(info.defaultCodeListingLanguage, "swift")
    }

    // Test whether default availability is decoded correctly
    func testLoadTestCatalogInfoPlistWithAvailability() throws {
        let infoPlistURL = Bundle.module.url(
            forResource: "Info+Availability", withExtension: "plist", subdirectory: "Test Resources")!
        
        let infoPlistData = try Data(contentsOf: infoPlistURL)
        let info = try DocumentationCatalog.Info(from: infoPlistData)

        XCTAssertEqual(
            info.defaultAvailability?.modules["MyKit"]?.map({ "\($0.platformName.displayName) \($0.platformVersion)" }).sorted(),
            ["Mac Catalyst 13.5", "macOS 10.15.1"]
        )
    }
    
    func testLoadInfoPlistWithFallbackValues() throws {
        let infoPlistWithAllFields = """
        <plist version="1.0">
        <dict>
            <key>CFBundleDisplayName</key>
            <string>Info Plist Display Name</string>
            <key>CFBundleIdentifier</key>
            <string>com.info.Plist</string>
            <key>CFBundleVersion</key>
            <string>1.0.0</string>
        </dict>
        </plist>
        """
        
        let infoPlistWithAllFieldsData = Data(infoPlistWithAllFields.utf8)
        
        let infoPlistWithoutDisplayName = """
        <plist version="1.0">
        <dict>
            <key>CFBundleIdentifier</key>
            <string>com.info.Plist</string>
            <key>CFBundleVersion</key>
            <string>1.0.0</string>
        </dict>
        </plist>
        """
        
        let infoPlistWithoutDisplayNameData = Data(infoPlistWithoutDisplayName.utf8)
        
        let catalogDiscoveryOptions = CatalogDiscoveryOptions(
            infoPlistFallbacks: [
                "CFBundleDisplayName": "Fallback Display Name",
                "CFBundleIdentifier": "com.fallback.Identifier",
                "CFBundleVersion": "2.0.0",
            ]
        )
        
        XCTAssertEqual(
            try DocumentationCatalog.Info(
                from: infoPlistWithAllFieldsData,
                catalogDiscoveryOptions: catalogDiscoveryOptions
            ),
            DocumentationCatalog.Info(
                displayName: "Info Plist Display Name",
                identifier: "com.info.Plist",
                version: "1.0.0"
            )
        )
        
        XCTAssertEqual(
            try DocumentationCatalog.Info(
                from: nil,
                catalogDiscoveryOptions: catalogDiscoveryOptions
            ),
            DocumentationCatalog.Info(
                displayName: "Fallback Display Name",
                identifier: "com.fallback.Identifier",
                version: "2.0.0"
            )
        )
        
        XCTAssertEqual(
            try DocumentationCatalog.Info(
                from: infoPlistWithoutDisplayNameData,
                catalogDiscoveryOptions: catalogDiscoveryOptions
            ),
            DocumentationCatalog.Info(
                displayName: "Fallback Display Name",
                identifier: "com.info.Plist",
                version: "1.0.0"
            )
        )
        
        let infoPlistWithoutVersion = """
        <plist version="1.0">
        <dict>
            <key>CFBundleDisplayName</key>
            <string>Info Plist Display Name</string>
            <key>CFBundleIdentifier</key>
            <string>com.info.Plist</string>
        </dict>
        </plist>
        """
        
        let infoPlistWithoutVersionData = Data(infoPlistWithoutVersion.utf8)
        
        XCTAssertEqual(
            try DocumentationCatalog.Info(
                from: infoPlistWithoutVersionData,
                catalogDiscoveryOptions: nil
            ),
            DocumentationCatalog.Info(
                displayName: "Info Plist Display Name",
                identifier: "com.info.Plist",
                version: nil
            )
        )
    }
    
    func testRoundTripCodingInfoPlist() throws {
        let infoPlist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>CDAppleDefaultAvailability</key>
            <dict>
                <key>FillIntroduced</key>
                <array>
                    <dict>
                        <key>name</key>
                        <string>macOS</string>
                        <key>version</key>
                        <string>10.9</string>
                    </dict>
                    <dict>
                        <key>name</key>
                        <string>iOS</string>
                        <key>version</key>
                        <string>11.1</string>
                    </dict>
                    <dict>
                        <key>name</key>
                        <string>tvOS</string>
                        <key>version</key>
                        <string>12.2</string>
                    </dict>
                    <dict>
                        <key>name</key>
                        <string>watchOS</string>
                        <key>version</key>
                        <string>13.3</string>
                    </dict>
                    <dict>
                        <key>name</key>
                        <string>Mac Catalyst</string>
                        <key>version</key>
                        <string>11.1</string>
                    </dict>
                </array>
            </dict>
            <key>CDDefaultCodeListingLanguage</key>
            <string>swift</string>
            <key>CDDefaultModuleKind</key>
            <string>Executable</string>
            <key>CFBundleDisplayName</key>
            <string>ShapeKit</string>
            <key>CFBundleIdentifier</key>
            <string>com.shapes.ShapeKit</string>
            <key>CFBundleVersion</key>
            <string>0.1.0</string>
        </dict>
        </plist>
        
        """
        
        let decodedInfo = try DocumentationCatalog.Info(from: Data(infoPlist.utf8))
        
        let propertyListEncoder = PropertyListEncoder()
        propertyListEncoder.outputFormat = .xml
        let reEncodedInfo = try propertyListEncoder.encode(decodedInfo)
        
        let reDecodedInfo = try DocumentationCatalog.Info(from: reEncodedInfo)
        XCTAssertEqual(decodedInfo, reDecodedInfo)
        
        let reEncodedString = try XCTUnwrap(String(
            data: try propertyListEncoder.encode(reDecodedInfo),
            encoding: .utf8
        ))
        
        XCTAssertEqual(
            reEncodedString.replacingOccurrences(of: "\t", with: "    "),
            infoPlist
        )
    }
    
    func testFallbackToCatalogDiscoveryOptions() throws {
        let catalogDiscoveryOptions = CatalogDiscoveryOptions(
            fallbackDisplayName: "Display Name",
            fallbackIdentifier: "swift.org.Identifier",
            fallbackVersion: "1.0.0",
            fallbackDefaultCodeListingLanguage: "swift",
            fallbackDefaultModuleKind: "Executable",
            fallbackDefaultAvailability: DefaultAvailability(
                with: [
                    "MyModule": [
                        DefaultAvailability.ModuleAvailability(
                            platformName: .iOS,
                            platformVersion: "7.0.0"
                        )
                    ]
                ]
            )
        )
        
        let info = try DocumentationCatalog.Info(catalogDiscoveryOptions: catalogDiscoveryOptions)
        XCTAssertEqual(
            info,
            DocumentationCatalog.Info(
                displayName: "Display Name",
                identifier: "swift.org.Identifier",
                version: "1.0.0",
                defaultCodeListingLanguage: "swift",
                defaultModuleKind: "Executable",
                defaultAvailability: DefaultAvailability(
                    with: [
                        "MyModule": [
                            DefaultAvailability.ModuleAvailability(
                                platformName: .iOS,
                                platformVersion: "7.0.0"
                            )
                        ]
                    ]
                )
            )
        )
    }
    
    func testFallbackToInfoInCatalogDiscoveryOptions() throws {
        let info = DocumentationCatalog.Info(
            displayName: "Display Name",
            identifier: "swift.org.Identifier",
            version: "1.0.0",
            defaultCodeListingLanguage: "swift",
            defaultModuleKind: "Executable",
            defaultAvailability: DefaultAvailability(
                with: [
                    "MyModule": [
                        DefaultAvailability.ModuleAvailability(
                            platformName: .iOS,
                            platformVersion: "7.0.0"
                        )
                    ]
                ]
            )
        )
        
        let catalogDiscoveryOptions = try CatalogDiscoveryOptions(fallbackInfo: info)
        XCTAssertEqual(
            info,
            try DocumentationCatalog.Info(catalogDiscoveryOptions: catalogDiscoveryOptions)
        )
    }
}
