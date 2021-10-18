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

class JSONPatchOperationTests: XCTestCase {
    func testInitializesWithVariantOverride() {
        let patchOperation = JSONPatchOperation(
            variantPatch: VariantPatchOperation(operation: .replace, value: "value"),
            pointer: JSONPointer(components: ["a", "b"])
        )
        
        XCTAssertEqual(patchOperation.operation, .replace)
        XCTAssertEqual(patchOperation.value.value as! String, "value")
        XCTAssertEqual(patchOperation.pointer.components, ["a", "b"])
    }
}
