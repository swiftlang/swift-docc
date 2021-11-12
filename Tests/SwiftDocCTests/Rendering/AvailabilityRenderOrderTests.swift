/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import XCTest
@testable import SwiftDocC

class AvailabilityRenderOrderTests: XCTestCase {
    let availabilitySGFURL = Bundle.module.url(
        forResource: "Availability.symbols", withExtension: "json", subdirectory: "Test Resources")!
    
    func testSortingAtRenderTime() throws {
        let (bundleURL, bundle, context) = try testBundleAndContext(copying: "TestBundle", excludingPaths: [], codeListings: [:]) { url in
            try? FileManager.default.copyItem(at: self.availabilitySGFURL, to: url.appendingPathComponent("Availability.symbols.json"))
        }
        defer {
            try? FileManager.default.removeItem(at: bundleURL)
        }

        let node = try context.entity(with: ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/Availability/MyStruct", sourceLanguage: .swift))
        
        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference, source: nil)
        let renderNode = translator.visit(node.semantic as! Symbol) as! RenderNode
        
        // Verify that all the symbol's availabilities were sorted into the order
        // they need to appear for rendering (they are not in the symbol graph fixture).
        // Additionally verify all the platforms have their correctly spelled name including spaces.
        XCTAssertEqual(renderNode.metadata.platforms?.map({ "\($0.name ?? "") \($0.introduced ?? "")" }), [
            "iOS 12.0", "iOS App Extension 12.0",
            "macOS 10.12", "macOS App Extension 10.12",
            "Mac Catalyst 2.0", "Mac Catalyst App Extension 1.0",
            "tvOS 12.0", "tvOS App Extension 12.0",
            "watchOS 6.0", "watchOS App Extension 6.0",
            "Swift 4.2",
        ])
        
        // Test roundtrip to verify availability items are correctly
        // initialized from the display name that's used for render JSON
        // instead of the platform key which is used in the symbol graph.
        let roundtripData = try JSONEncoder().encode(renderNode)
        XCTAssertNoThrow(try RenderNode.decode(fromJSON: roundtripData))

        let roundtripNode = try RenderNode.decode(fromJSON: roundtripData)
        XCTAssertEqual(roundtripNode.metadata.platforms?.map({ "\($0.name ?? "") \($0.introduced ?? "")" }), [
            "iOS 12.0", "iOS App Extension 12.0",
            "macOS 10.12", "macOS App Extension 10.12",
            "Mac Catalyst 2.0", "Mac Catalyst App Extension 1.0",
            "tvOS 12.0", "tvOS App Extension 12.0",
            "watchOS 6.0", "watchOS App Extension 6.0",
            "Swift 4.2",
        ])
    }
}
