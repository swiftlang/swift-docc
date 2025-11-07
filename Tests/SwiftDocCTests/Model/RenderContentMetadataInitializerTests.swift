/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

// Import SwiftDocC without the @testable annotation, so we can test there
// is a public initializer for RenderContentMetadata.
import SwiftDocC
import XCTest

class RenderContentMetadataInitializerTests: XCTestCase {
    func testMetadataPublicInitializer() throws {
        let metadata = RenderContentMetadata(
            anchor: "anchor",
            title: "title",
            abstract: [],
            deviceFrame: "device frame"
        )

        XCTAssertNotNil(metadata)
        XCTAssertEqual("anchor", metadata.anchor)
        XCTAssertEqual("title", metadata.title)
        XCTAssertEqual([], metadata.abstract)
        XCTAssertEqual("device frame", metadata.deviceFrame)
    }
}
