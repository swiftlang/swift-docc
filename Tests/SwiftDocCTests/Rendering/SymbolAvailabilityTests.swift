/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import XCTest
import SymbolKit
@testable import SwiftDocC
import SwiftDocCTestUtilities

class SymbolAvailabilityTests: XCTestCase {
    
    private func symbolAvailability(
            defaultAvailability: [DefaultAvailability.ModuleAvailability] = [],
            symbolGraphOperatingSystemPlatformName: String,
            symbols: [SymbolGraph.Symbol],
            symbolName: String
    ) throws -> [SymbolGraph.Symbol.Availability.AvailabilityItem] {
            let catalog = Folder(
                name: "unit-test.docc",
                content: [
                    InfoPlist(defaultAvailability: [
                        "ModuleName": defaultAvailability
                    ]),
                    JSONFile(name: "ModuleName.symbols.json", content: makeSymbolGraph(
                        moduleName: "ModuleName",
                        platform: SymbolGraph.Platform(architecture: nil, vendor: nil, operatingSystem: SymbolGraph.OperatingSystem(name: symbolGraphOperatingSystemPlatformName), environment: nil),
                        symbols: symbols,
                        relationships: []
                    )),
                ]
            )
            let (_, context) = try loadBundle(catalog: catalog)
            let reference = try XCTUnwrap(context.soleRootModuleReference).appendingPath(symbolName)
            let symbol = try XCTUnwrap(context.entity(with: reference).semantic as? Symbol)
            return try XCTUnwrap(symbol.availability?.availability)
    }
    
    private func renderNodeAvailability(
        defaultAvailability: [DefaultAvailability.ModuleAvailability] = [],
        symbolGraphOperatingSystemPlatformName: String,
        symbols: [SymbolGraph.Symbol],
        symbolName: String
    ) throws -> [AvailabilityRenderItem] {
        let catalog = Folder(
            name: "unit-test.docc",
            content: [
                InfoPlist(defaultAvailability: [
                    "ModuleName": defaultAvailability
                ]),
                JSONFile(name: "ModuleName.symbols.json", content: makeSymbolGraph(
                    moduleName: "ModuleName",
                    platform: SymbolGraph.Platform(architecture: nil, vendor: nil, operatingSystem: SymbolGraph.OperatingSystem(name: symbolGraphOperatingSystemPlatformName), environment: nil),
                    symbols: symbols,
                    relationships: []
                )),
            ]
        )
        let (bundle, context) = try loadBundle(catalog: catalog)
        let reference = try XCTUnwrap(context.soleRootModuleReference).appendingPath(symbolName)
        let node = try context.entity(with: ResolvedTopicReference(bundleID: bundle.id, path: reference.path, sourceLanguage: .swift))
        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference)
        return try XCTUnwrap((translator.visit(node.semantic as! Symbol) as! RenderNode).metadata.platformsVariants.defaultValue)
    }
    
    func testSymbolGraphSymbolWithoutDeprecatedVersionAndIntroducedVersion() throws {

        let availability = try renderNodeAvailability(
            defaultAvailability: [],
            symbolGraphOperatingSystemPlatformName: "ios",
            symbols: [
                makeSymbol(
                    id: "platform-1-symbol",
                    kind: .class,
                    pathComponents: ["SymbolName"],
                    availability: [makeAvailabilityItem(domainName: "iOS", deprecated: SymbolGraph.SemanticVersion(string: "1.2.3"))]
                )
            ],
            symbolName: "SymbolName"
        )
        
        XCTAssertEqual(availability.map { "\($0.name ?? "<nil>") \($0.introduced ?? "<nil>") - \($0.deprecated ?? "<nil>")" }, [
            // The availability items wihout an introduced version should still emit the deprecated version if available.
            "iOS <nil> - 1.2.3",
            "iPadOS <nil> - 1.2.3",
            "Mac Catalyst <nil> - 1.2.3",
        ])
    }
    
    func testSymbolGraphSymbolWithObsoleteVersion() throws {

        let availability = try renderNodeAvailability(
            defaultAvailability: [],
            symbolGraphOperatingSystemPlatformName: "ios",
            symbols: [
                makeSymbol(
                    id: "platform-1-symbol",
                    kind: .class,
                    pathComponents: ["SymbolName"],
                    availability: [makeAvailabilityItem(domainName: "iOS", obsoleted: SymbolGraph.SemanticVersion(string: "1.2.3"))]
                )
            ], symbolName: "SymbolName"
        )
        XCTAssertEqual(availability.map { "\($0.name ?? "<nil>") \($0.introduced ?? "<nil>") - \($0.deprecated ?? "<nil>")" }.sorted(), [
            // The availability items that are obsolete are not rendered in the final documentation.
        ])
    }
    
}
