/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import XCTest
@testable import SwiftDocC

class RenderContextTests: XCTestCase {
    func testCreatesRenderReferences() async throws {
        let (inputs, context) = try await testBundleAndContext(named: "LegacyBundle_DoNotUseInNewTests")
        
        let renderContext = RenderContext(documentationContext: context, inputs: inputs)
        
        // Verify render references are created for all topics
        XCTAssertEqual(Array(renderContext.store.topics.keys.sorted(by: { $0.absoluteString < $1.absoluteString })), context.knownIdentifiers.sorted(by: { $0.absoluteString < $1.absoluteString }), "Didn't create render references for all context topics.")
        
        // Verify render references are created for all assets
        XCTAssertEqual(
            renderContext.store.assets.keys.map(\.assetName).sorted(),
            context.assetManagers.values.flatMap(\.storage.keys).sorted(),
            "Didn't create render references for all assets"
        )
    }
}
