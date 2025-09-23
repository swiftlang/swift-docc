/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SymbolKit
import XCTest
@testable import SwiftDocC

class AvailabilityRenderOrderTests: XCTestCase {
    let availabilitySGFURL = Bundle.module.url(
        forResource: "Availability.symbols", withExtension: "json", subdirectory: "Test Resources")!
    
    func testSortingAtRenderTime() async throws {
        let (_, context) = try await loadFromDisk(copyingCatalogNamed: "LegacyBundle_DoNotUseInNewTests", excludingPaths: []) { url in
            let availabilitySymbolGraphURL = url.appendingPathComponent("Availability.symbols.json")
            try? FileManager.default.copyItem(at: self.availabilitySGFURL, to: availabilitySymbolGraphURL)

            // Load the symbol graph fixture
            var availabilitySymbolGraph = try JSONDecoder().decode(SymbolGraph.self, from: try Data(contentsOf: availabilitySymbolGraphURL))

            // There should be at least one symbol in this graph
            XCTAssertEqual(1, availabilitySymbolGraph.symbols.count)
            if let tuple = availabilitySymbolGraph.symbols.first {

                let key = tuple.key
                var symbol = tuple.value

                // The symbol should have availability info specified
                XCTAssertNotNil(symbol.availability)
                if var alternateSymbols = symbol.mixins[Availability.mixinKey] as? Availability {

                    // Create a new availability item which is missing a domain (platform name).
                    let missingDomain = SymbolGraph.Symbol.Availability.AvailabilityItem(
                        domain: nil,
                        introducedVersion: nil,
                        deprecatedVersion: nil,
                        obsoletedVersion: nil,
                        message: "Don't use this function; call some other function instead.",
                        renamed: nil,
                        isUnconditionallyDeprecated: true,
                        isUnconditionallyUnavailable: false,
                        willEventuallyBeDeprecated: false
                    )

                    // Append the invalid item and update the symbol
                    alternateSymbols.availability.insert(missingDomain, at: 4)
                    symbol.mixins[Availability.mixinKey] = alternateSymbols
                }
                availabilitySymbolGraph.symbols[key] = symbol
            }

            // Update the temporary copy of the fixture
            let jsonEncoder = JSONEncoder()
            let data = try jsonEncoder.encode(availabilitySymbolGraph)
            try data.write(to: availabilitySymbolGraphURL)
        }

        let node = try context.entity(with: ResolvedTopicReference(bundleID: context.inputs.id, path: "/documentation/Availability/MyStruct", sourceLanguage: .swift))
        
        var translator = RenderNodeTranslator(context: context, identifier: node.reference)
        let renderNode = translator.visit(node.semantic as! Symbol) as! RenderNode
        
        // Verify that all the symbol's availabilities were sorted into the order
        // they need to appear for rendering (they are not in the symbol graph fixture).
        // Additionally verify all the platforms have their correctly spelled name including spaces.
        // Finally, the invalid item added above should be filtered out.
        XCTAssertEqual(renderNode.metadata.platforms?.map({ "\($0.name ?? "") \($0.introduced ?? "")" }), [
            "iOS 12.0", "iOS App Extension 12.0",
            "iPadOS 12.0",
            "Mac Catalyst 2.0", "Mac Catalyst App Extension 1.0",
            "macOS 10.12", "macOS App Extension 10.12",
            "tvOS 12.0", "tvOS App Extension 12.0",
            "visionOS 12.0",
            "watchOS 6.0", "watchOS App Extension 6.0",
            "Swift 4.2"
        ])
        
        // Test roundtrip to verify availability items are correctly
        // initialized from the display name that's used for render JSON
        // instead of the platform key which is used in the symbol graph.
        let roundtripData = try JSONEncoder().encode(renderNode)
        XCTAssertNoThrow(try RenderNode.decode(fromJSON: roundtripData))

        let roundtripNode = try RenderNode.decode(fromJSON: roundtripData)
        XCTAssertEqual(roundtripNode.metadata.platforms?.map({ "\($0.name ?? "") \($0.introduced ?? "")" }), [
            "iOS 12.0", "iOS App Extension 12.0",
            "iPadOS 12.0",
            "Mac Catalyst 2.0", "Mac Catalyst App Extension 1.0",
            "macOS 10.12", "macOS App Extension 10.12",
            "tvOS 12.0", "tvOS App Extension 12.0",
            "visionOS 12.0",
            "watchOS 6.0", "watchOS App Extension 6.0",
            "Swift 4.2"
        ])
    }
}
