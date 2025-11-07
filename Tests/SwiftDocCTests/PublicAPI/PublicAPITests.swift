/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

// Import SwiftDocC without the @testable annotation, so we can test
// whether various API are actually public.
import SwiftDocC

import XCTest

class PublicAPITests: XCTestCase {

    func testPublicRenderContentMetadataInitializer() throws {
        let _ = RenderContentMetadata(
            anchor: "anchor",
            title: "title",
            abstract: [],
            deviceFrame: "device frame"
        )
    }
}
