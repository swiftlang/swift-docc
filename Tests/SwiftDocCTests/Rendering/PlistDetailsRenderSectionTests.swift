/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import XCTest
@testable import SwiftDocC
import SymbolKit
import SwiftDocCTestUtilities

class PlistDetailsRenderSectionTests: XCTestCase {

    func testDecoding() throws {
        
        let tempURL = try createTemporaryDirectory()
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
            "arrayMode" : true,
            "baseType" : "string",
            "rawKey" : "property-list-key"
          }
        }
        """
        
        let symbolGraphString = makeSymbolGraphString(moduleName: "MyModule", symbols: symbolJSON)
        let symbolGraphURL = tempURL.appendingPathComponent("MyModule.symbols.json")
        try symbolGraphString.write(to: tempURL.appendingPathComponent("MyModule.symbols.json"), atomically: true, encoding: .utf8)
        
        let workspace = DocumentationWorkspace()
        let bundle = DocumentationBundle(
            info: DocumentationBundle.Info(
                displayName: "Test",
                identifier: "com.example.test",
                version: "1.2.3"
            ),
            baseURL: URL(string: "https://example.com/example")!,
            symbolGraphURLs: [symbolGraphURL],
            markupURLs: [],
            miscResourceURLs: []
        )
        try workspace.registerProvider(PrebuiltLocalFileSystemDataProvider(bundles: [bundle]))
        let context = try DocumentationContext(dataProvider: workspace)
        let symbol = try XCTUnwrap(context.documentationCache["plist:propertylistkey"]?.semantic as? Symbol)
        let plistDetails = try XCTUnwrap(symbol.mixinsVariants.firstValue?[SymbolGraph.Symbol.PlistDetails.mixinKey] as? SymbolGraph.Symbol.PlistDetails)
        XCTAssertEqual(
            PlistDetailsSectionTranslator().generatePlistDetailsRenderSection(symbol, plistDetails: plistDetails),
            PlistDetailsRenderSection(
                kind: .plistDetails,
                details: PlistDetailsRenderSection.Details(
                    rawKey: "property-list-key",
                    value: [TypeDetails(baseType: "string", arrayMode: true)],
                    platforms: [],
                    displayName: nil,
                    titleStyle: .useDisplayName
                )
            )
        )
    }
}
