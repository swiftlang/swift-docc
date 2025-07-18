/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024-2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import XCTest
@testable import SwiftDocC
import SymbolKit
import SwiftDocCTestUtilities

class PropertyListDetailsRenderSectionTests: XCTestCase {

    func testDecoding() async throws {
        
        func getPlistDetailsSection(arrayMode: any CustomStringConvertible, baseType: any CustomStringConvertible, rawKey: any CustomStringConvertible) async throws -> PropertyListDetailsRenderSection {
            let symbolJSON = """
            {
              "accessLevel" : "public",
              "availability" : [],
              "identifier" : {
                "interfaceLanguage" : "plist",
                "precise" : "plist:propertylistkey"
              },
              "kind" : {
                "displayName" : "Property List Key",
                "identifier" : "typealias"
              },
              "names" : {
                "navigator" : [
                  {
                    "kind" : "identifier",
                    "spelling" : "propertylistkey"
                  }
                ],
                "title" : "propertylistkey"
              },
              "pathComponents" : [
                "Information-Property-List",
                "propertylistkey"
              ],
              "plistDetails" : {
                "arrayMode" : \(arrayMode),
                "baseType" : \(baseType),
                "rawKey" : \(rawKey)
              }
            }
            """
            let symbolGraphString = makeSymbolGraphString(moduleName: "MyModule", symbols: symbolJSON)
            let catalog = Folder(name: "unit-test.docc", content: [
                TextFile(name: "MyModule.symbols.json", utf8Content: symbolGraphString)
            ])
            let (bundle, context) = try await loadBundle(catalog: catalog)
            let node = try XCTUnwrap(context.documentationCache["plist:propertylistkey"])
            let converter = DocumentationNodeConverter(bundle: bundle, context: context)
            let renderNode = converter.convert(node)
            return try XCTUnwrap(renderNode.primaryContentSections.mapFirst(where: { $0 as? PropertyListDetailsRenderSection }))
        }
        
        // Assert that the Details section is correctly generated when passing valid values into the plistDetails JSON object.
        let withArrayMode = try await getPlistDetailsSection(arrayMode: true, baseType: "\"string\"", rawKey: "\"property-list-key\"")
        XCTAssertEqual(
            withArrayMode,
            PropertyListDetailsRenderSection(
               details: PropertyListDetailsRenderSection.Details(
                   rawKey: "property-list-key",
                   value: [TypeDetails(baseType: "string", arrayMode: true)],
                   platforms: [],
                   displayName: nil,
                   titleStyle: .useDisplayName
               )
           )
       )
        
        let withoutArrayMode = try await getPlistDetailsSection(arrayMode: false, baseType: "\"string\"", rawKey: "\"property-list-key\"")
        XCTAssertEqual(
            withoutArrayMode,
            PropertyListDetailsRenderSection(
               details: PropertyListDetailsRenderSection.Details(
                   rawKey: "property-list-key",
                   value: [TypeDetails(baseType: "string", arrayMode: false)],
                   platforms: [],
                   displayName: nil,
                   titleStyle: .useDisplayName
               )
           )
       )
        
        // Assert that the Details section does not decode unsupported values.
        do {
            _ = try await getPlistDetailsSection(arrayMode: true, baseType: true, rawKey: "\"property-list-key\"")
            XCTFail("Didn't raise an error")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("isn’t in the correct format"))
        }
        do {
            _ = try await getPlistDetailsSection(arrayMode: true, baseType: "\"string\"", rawKey: 1)
            XCTFail("Didn't raise an error")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("isn’t in the correct format"))
        }
    }
}
