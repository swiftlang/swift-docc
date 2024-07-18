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
        let tempURL = try createTempFolder(content: [
            Folder(name: "unit-test.docc", content: [
                TextFile(name: "MyModule.symbols.json", utf8Content: symbolGraphString)
            ])
        ])
        let (_, bundle, context) = try loadBundle(from: tempURL)
        let node = try XCTUnwrap(context.documentationCache["plist:propertylistkey"])
        let converter = DocumentationNodeConverter(bundle: bundle, context: context)
        let renderNode = try converter.convert(node)
        let section = try XCTUnwrap(renderNode.primaryContentSections.mapFirst(where: { $0 as? PlistDetailsRenderSection }))
                              
       XCTAssertEqual(
           section,
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
