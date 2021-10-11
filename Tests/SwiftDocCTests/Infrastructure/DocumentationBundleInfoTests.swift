/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
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
        guard let infoPlist = try PropertyListSerialization.propertyList(from: infoPlistData, options: [], format: nil) as? [String: Any] else {
            throw WorkspaceError.notADictionaryAtRoot(url: infoPlistURL)
        }

        let info = try DocumentationBundle.Info(plist: infoPlist)
        
        XCTAssertEqual(info.displayName, "Test Bundle")
        XCTAssertEqual(info.identifier, "org.swift.docc.example")
        XCTAssertEqual(info.version.description, "0.1.0")
        XCTAssertEqual(info.defaultCodeListingLanguage, "swift")
    }

    // Test whether default availability is decoded correctly
    func testLoadTestBundleInfoPlistWithAvailability() throws {
        let infoPlistURL = Bundle.module.url(
            forResource: "Info+Availability", withExtension: "plist", subdirectory: "Test Resources")!
        
        let infoPlistData = try Data(contentsOf: infoPlistURL)
        guard let infoPlist = try PropertyListSerialization.propertyList(from: infoPlistData, options: [], format: nil) as? [String: Any] else {
            throw WorkspaceError.notADictionaryAtRoot(url: infoPlistURL)
        }

        let info = try DocumentationBundle.Info(plist: infoPlist)

        XCTAssertEqual(
            info.defaultAvailability?.modules["MyKit"]?.map({ "\($0.platformName.displayName) \($0.platformVersion)" }).sorted(),
            ["Mac Catalyst 13.5", "macOS 10.15.1"]
        )
    }
}
