/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import XCTest
@testable import SwiftDocC

class VariantCollection_VariantTests: XCTestCase {
    let testVariant = VariantCollection<String>.Variant<String>(
        traits: [.interfaceLanguage("a")],
        patch: [
            .replace(value: "replace"),
            .add(value: "add"),
            .remove,
        ]
    )
    
    func testMapPatch() throws {
        XCTAssertEqual(
            testVariant.mapPatch { "\($0) transformed" }.patch.map(\.value),
            ["replace transformed", "add transformed", nil]
        )
    }
}

private extension VariantPatchOperation {
    var value: Value? {
        switch self {
        case let .replace(value):
            return value
        case let .add(value):
            return value
        case .remove:
            return nil
        }
    }
}
