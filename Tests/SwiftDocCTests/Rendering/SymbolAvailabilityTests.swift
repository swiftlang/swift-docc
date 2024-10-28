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
            symbols: [SymbolGraph.Symbol]
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
            let reference = try XCTUnwrap(context.soleRootModuleReference).appendingPath("SymbolName")
            let symbol = try XCTUnwrap(context.entity(with: reference).semantic as? Symbol)
            let availability = try XCTUnwrap(symbol.availability?.availability)
            return availability
    }
    
    func testSymbolGraphSymbolWithoutDeprecatedVersionAndIntroducedVersion() throws {

        let availability = try symbolAvailability(
            defaultAvailability: [],
            symbolGraphOperatingSystemPlatformName: "ios",
            symbols: [
                makeSymbol(
                    id: "platform-1-symbol",
                    kind: .class,
                    pathComponents: ["SymbolName"],
                    availability: [makeAvailabilityItem(domainName: "iOS", deprecated: SymbolGraph.SemanticVersion(string: "1.2.3"))]
                )
            ]
        )
        
        XCTAssertEqual(availability.map { "\($0.domain?.rawValue ?? "<nil>") \($0.introducedVersion?.description ?? "<nil>") - \($0.deprecatedVersion?.description ?? "<nil>")" }.sorted(), [
            // The availability items wihout an introduced version should still emit the deprecated version if available.
            "iOS <nil> - 1.2.3",
            "iPadOS <nil> - 1.2.3",
            "macCatalyst <nil> - 1.2.3",
        ])
    }
    
}
