/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022-2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocC

class SemaToRenderNodeArticleOnlyCatalogTests: XCTestCase {
    func testDoesNotEmitVariantsForPagesInArticleOnlyCatalog() async throws {
        for renderNode in try await renderNodeConsumer(for: "BundleWithTechnologyRoot").allRenderNodes() {
            XCTAssertNil(renderNode.variants)
        }
    }
}
