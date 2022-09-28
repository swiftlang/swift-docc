/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocC

class DocumentationBundleInfoTests: XCTestCase {
    // Test whether the bundle correctly loads the test bundle Info.plist file.
    func testLoadTestBundleInfoPlist() throws {
        let infoPlistURL = Bundle.module.url(
            forResource: "TestBundle", withExtension: "docc", subdirectory: "Test Bundles")!
            .appendingPathComponent("Info.plist")

        let infoPlistData = try Data(contentsOf: infoPlistURL)
        let info = try DocumentationBundle.Info(from: infoPlistData)
        
        XCTAssertEqual(info.displayName, "Test Bundle")
        XCTAssertEqual(info.identifier, "org.swift.docc.example")
        XCTAssertEqual(info.version, "0.1.0")
        XCTAssertEqual(info.defaultCodeListingLanguage, "swift")
    }

    // Test whether default availability is decoded correctly
    func testLoadTestBundleInfoPlistWithAvailability() throws {
        let infoPlistURL = Bundle.module.url(
            forResource: "Info+Availability", withExtension: "plist", subdirectory: "Test Resources")!
        
        let infoPlistData = try Data(contentsOf: infoPlistURL)
        let info = try DocumentationBundle.Info(from: infoPlistData)

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
        
        let bundleDiscoveryOptions = BundleDiscoveryOptions(
            infoPlistFallbacks: [
                "CFBundleDisplayName": "Fallback Display Name",
                "CFBundleIdentifier": "com.fallback.Identifier",
                "CFBundleVersion": "2.0.0",
            ]
        )
        
        XCTAssertEqual(
            try DocumentationBundle.Info(
                from: infoPlistWithAllFieldsData,
                bundleDiscoveryOptions: bundleDiscoveryOptions
            ),
            DocumentationBundle.Info(
                displayName: "Info Plist Display Name",
                identifier: "com.info.Plist",
                version: "1.0.0"
            )
        )
        
        XCTAssertEqual(
            try DocumentationBundle.Info(
                from: nil,
                bundleDiscoveryOptions: bundleDiscoveryOptions
            ),
            DocumentationBundle.Info(
                displayName: "Fallback Display Name",
                identifier: "com.fallback.Identifier",
                version: "2.0.0"
            )
        )
        
        XCTAssertEqual(
            try DocumentationBundle.Info(
                from: infoPlistWithoutDisplayNameData,
                bundleDiscoveryOptions: bundleDiscoveryOptions
            ),
            DocumentationBundle.Info(
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
            try DocumentationBundle.Info(
                from: infoPlistWithoutVersionData,
                bundleDiscoveryOptions: nil
            ),
            DocumentationBundle.Info(
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
        
        let decodedInfo = try DocumentationBundle.Info(from: Data(infoPlist.utf8))
        
        let propertyListEncoder = PropertyListEncoder()
        propertyListEncoder.outputFormat = .xml
        let reEncodedInfo = try propertyListEncoder.encode(decodedInfo)
        
        let reDecodedInfo = try DocumentationBundle.Info(from: reEncodedInfo)
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
    
    func testFallbackToBundleDiscoveryOptions() throws {
        let bundleDiscoveryOptions = BundleDiscoveryOptions(
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
        
        let info = try DocumentationBundle.Info(bundleDiscoveryOptions: bundleDiscoveryOptions)
        XCTAssertEqual(
            info,
            DocumentationBundle.Info(
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
    
    func testFallbackToInfoInBundleDiscoveryOptions() throws {
        let info = DocumentationBundle.Info(
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
        
        let bundleDiscoveryOptions = try BundleDiscoveryOptions(fallbackInfo: info)
        XCTAssertEqual(
            info,
            try DocumentationBundle.Info(bundleDiscoveryOptions: bundleDiscoveryOptions)
        )
    }
    
    func testDataCorruptedPlist() throws {
        let valueMissingInvalidPlist = """
        <plist version="1.0">
        <dict>
          <key>CDDefaultCodeListingLanguage</key>
          <string>swift</string>
          <key>CFBundleName</key>
          <string>Example</string>
          <key>CFBundleDisplayName</key>
          <string>Example</string>
          <key>CFBundleIdentifier</key>
          <string>org.swift.docc.example</string>
          <key>CFBundleDevelopmentRegion</key>
          <string>en</string>
          <key>CFBundleIconName</key>
          <string>DocumentationIcon</string>
          <key>CFBundleIconFile</key>
          <string>DocumentationIcon</string>
          <key>CFBundlePackageType</key>
          <string>DOCS</string>
          <key>CFBundleShortVersionString</key>
          <string>0.1.0</string>
          <key>CFBundleVersion</key>
          <string>0.1.0</string>
          <key>CDAppleDefaultAvailability</key>
        </dict>
        </plist>
        """
        
        let valueMissingInvalidPlistData = Data(valueMissingInvalidPlist.utf8)
        XCTAssertThrowsError(
            try DocumentationBundle.Info(from: valueMissingInvalidPlistData),
            "Info.plist decode didn't throw as expected"
        ) { error in
            XCTAssertTrue(error is DocumentationBundle.Info.Error)
            let errorTypeChecking: Bool
            if case DocumentationBundle.Info.Error.plistDecodingError(_) = error {
                errorTypeChecking = true
            } else {
                errorTypeChecking = false
            }
            XCTAssertTrue(errorTypeChecking)
            XCTAssertEqual(error.localizedDescription, "Unable to decode Info.plist file. Verify that it is correctly formed. Value missing for key inside <dict> at line 24")
        }
    }
    
    func testDerivedDisplayNameAsFallback() {
        let infoPlistWithoutRequiredKeys = """
        <plist version="1.0">
        <dict>
        </dict>
        </plist>
        """
        
        let infoPlistWithoutRequiredKeysData = Data(infoPlistWithoutRequiredKeys.utf8)
        
        XCTAssertEqual(
            try DocumentationBundle.Info(
                from: infoPlistWithoutRequiredKeysData,
                bundleDiscoveryOptions: nil,
                derivedDisplayName: "Derived Display Name"
            ),
            DocumentationBundle.Info(
                displayName: "Derived Display Name",
                identifier: "Derived Display Name",
                version: nil
            )
        )
    }
    
    func testDerivedDisplayNameAsFallbackWithIdentifier() {
        let infoPlistWithoutRequiredKeys = """
        <plist version="1.0">
        <dict>
        <key>CFBundleIdentifier</key>
        <string>org.swift.docc.example</string>
        </dict>
        </plist>
        """
        
        let infoPlistWithoutRequiredKeysData = Data(infoPlistWithoutRequiredKeys.utf8)
        
        XCTAssertEqual(
            try DocumentationBundle.Info(
                from: infoPlistWithoutRequiredKeysData,
                bundleDiscoveryOptions: nil,
                derivedDisplayName: "Derived Display Name"
            ),
            DocumentationBundle.Info(
                displayName: "Derived Display Name",
                identifier: "org.swift.docc.example",
                version: nil
            )
        )
    }
    
    func testDisplayNameAsIdentifierFallback() {
        let infoPlistWithoutRequiredKeys = """
        <plist version="1.0">
        <dict>
        <key>CFBundleDisplayName</key>
        <string>Example</string>
        </dict>
        </plist>
        """
        
        let infoPlistWithoutRequiredKeysData = Data(infoPlistWithoutRequiredKeys.utf8)
        
        XCTAssertEqual(
            try DocumentationBundle.Info(
                from: infoPlistWithoutRequiredKeysData,
                bundleDiscoveryOptions: nil
            ),
            DocumentationBundle.Info(
                displayName: "Example",
                identifier: "Example",
                version: nil
            )
        )
    }
}
