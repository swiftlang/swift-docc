/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024-2025 Apple Inc. and the Swift project authors
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
    
    private func renderNodeAvailability(
        defaultAvailability: [DefaultAvailability.ModuleAvailability] = [],
        symbolGraphOperatingSystemPlatformName: String,
        symbolGraphEnvironmentName: String? = nil,
        symbols: [SymbolGraph.Symbol],
        symbolName: String
    ) async throws -> [AvailabilityRenderItem] {
        let catalog = Folder(
            name: "unit-test.docc",
            content: [
                InfoPlist(defaultAvailability: [
                    "ModuleName": defaultAvailability
                ]),
                JSONFile(name: "ModuleName.symbols.json", content: makeSymbolGraph(
                    moduleName: "ModuleName",
                    platform: SymbolGraph.Platform(architecture: nil, vendor: nil, operatingSystem: SymbolGraph.OperatingSystem(name: symbolGraphOperatingSystemPlatformName), environment: symbolGraphEnvironmentName),
                    symbols: symbols,
                    relationships: []
                )),
            ]
        )
        let (_, context) = try await loadBundle(catalog: catalog)
        let reference = try XCTUnwrap(context.soleRootModuleReference).appendingPath(symbolName)
        let node = try context.entity(with: ResolvedTopicReference(bundleID: context.inputs.id, path: reference.path, sourceLanguage: .swift))
        var translator = RenderNodeTranslator(context: context, identifier: node.reference)
        return try XCTUnwrap((translator.visit(node.semantic as! Symbol) as! RenderNode).metadata.platformsVariants.defaultValue)
    }
    
    func testSymbolGraphSymbolWithoutDeprecatedVersionAndIntroducedVersion() async throws {

        var availability = try await renderNodeAvailability(
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
        
        availability = try await renderNodeAvailability(
            defaultAvailability: [
                DefaultAvailability.ModuleAvailability(platformName: PlatformName(operatingSystemName: "iOS"), platformVersion: "1.2.3")
            ],
            symbolGraphOperatingSystemPlatformName: "ios",
            symbolGraphEnvironmentName: "macabi",
            symbols: [
                makeSymbol(
                    id: "platform-1-symbol",
                    kind: .class,
                    pathComponents: ["SymbolName"],
                    availability: [
                        makeAvailabilityItem(domainName: "iOS", deprecated: SymbolGraph.SemanticVersion(string: "1.2.3")),
                        makeAvailabilityItem(domainName: "visionOS", deprecated: SymbolGraph.SemanticVersion(string: "1.0.0"))
                    ]
                )
            ],
            symbolName: "SymbolName"
        )
        
        XCTAssertEqual(availability.map { "\($0.name ?? "<nil>") \($0.introduced ?? "<nil>") - \($0.deprecated ?? "<nil>")" }, [
            // The default availability for iOS shouldnt be copied to visionOS.
            "iOS 1.2.3 - 1.2.3",
            "iPadOS 1.2.3 - <nil>",
            "Mac Catalyst 1.2.3 - 1.2.3",
            "visionOS <nil> - 1.0",
        ])
    }
    
    func testSymbolGraphSymbolWithObsoleteVersion() async throws {

        let availability = try await renderNodeAvailability(
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
