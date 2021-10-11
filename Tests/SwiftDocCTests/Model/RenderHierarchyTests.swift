/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

@testable import SwiftDocC
import XCTest

class RenderHierarchyTests: XCTestCase {
    func testDecodableTechnologyNavigationMissing() throws {
        let json = """
        {
            "path" : "\\/tech",
            "paths" : [[]],
            "reference" : "doc:\\/\\/bundleid\\/path",
            "modules" : []
        }
        """
        let hierarchy = try JSONDecoder().decode(RenderHierarchy.self, from: json.data(using: .utf8)!)
        guard case RenderHierarchy.tutorials(_) = hierarchy else {
            XCTFail("Unexpected hierarchy type")
            return
        }
    }
}
