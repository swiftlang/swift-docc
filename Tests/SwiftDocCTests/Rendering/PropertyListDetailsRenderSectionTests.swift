/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024-2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Testing
@testable import SwiftDocC
import SymbolKit
import DocCCommon
import DocCTestUtilities

struct PropertyListDetailsRenderSectionTests {
    @Test(arguments: [true, false])
    func renderingDecodedPropertyDetails(arrayMode: Bool) async throws {
        let renderSection = try await makePlistDetailsSection(arrayMode: arrayMode, baseType: "string", rawKey: "property-list-key")
        #expect(renderSection.details == .init(
            rawKey: "property-list-key",
            value: [TypeDetails(baseType: "string", arrayMode: arrayMode)],
            platforms: [],
            displayName: nil,
            titleStyle: .useDisplayName
        ))
    }
    
    private func makePlistDetailsSection(
        arrayMode: Bool,
        baseType: any CustomStringConvertible,
        rawKey: any CustomStringConvertible,
        sourceLocation: SourceLocation = #_sourceLocation
    ) async throws -> PropertyListDetailsRenderSection {
        let catalog = Folder(name: "unit-test.docc") {
            JSONFile(symbolGraph: makeSymbolGraph(moduleName: "MyModule", symbols: [
                makeSymbol(id: "plist:propertylistkey", language: .init(id: "plist"), kind: .typealias, pathComponents: ["Information-Property-List", "propertylistkey"], otherMixins: [
                    SymbolGraph.Symbol.PlistDetails(
                        rawKey:    rawKey.description,
                        baseType:  baseType.description,
                        arrayMode: arrayMode
                    )
                ])
            ]))
        }
        let context = try await load(catalog: catalog)
        let node = try #require(context.documentationCache["plist:propertylistkey"], sourceLocation: sourceLocation)
        let renderNode = DocumentationNodeConverter(context: context).convert(node)
        return try #require(renderNode.primaryContentSections.mapFirst(where: { $0 as? PropertyListDetailsRenderSection }), sourceLocation: sourceLocation)
    }
}
