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

class JSONPatchApplierTests: XCTestCase {
    func testReplacesDictionaryValue() throws {
        XCTAssertEqual(
            try apply(
                .replace(pointer: JSONPointer(pathComponents: ["baz"]), encodableValue: "boo"),
                to: Model(baz: "qux", foo: [])
            ),
            Model(
                baz: "boo",
                foo: []
            )
        )
    }
    
    func testReplacesArrayValue() throws {
        XCTAssertEqual(
            try apply(
                .replace(pointer: JSONPointer(pathComponents: ["foo", "1"]), encodableValue: 123),
                to: Model(
                    baz: "qux",
                    foo: [1, 2]
                )
            ),
            Model(
                baz: "qux",
                foo: [1, 123]
            )
        )
    }
    
    func testReplacesNestedValue() throws {
        XCTAssertEqual(
            try apply(
                .replace(
                    pointer: JSONPointer(pathComponents: ["bar", "0", "bar"]),
                    encodableValue: "new value"
                ),
                to: Model(
                    baz: "qux",
                    bar: [.init(bar: "value")]
                )
            ),
            Model(
                baz: "qux",
                bar: [.init(bar: "new value")]
            )
        )
    }
    
    func testRemovesDictionaryValue() throws {
        XCTAssertEqual(
            try apply(
                .remove(pointer: JSONPointer(pathComponents: ["baz"])),
                to: Model(baz: "qux")
            ),
            Model(baz: nil)
        )
    }
    
    func testRemovesArrayValue() throws {
        XCTAssertEqual(
            try apply(
                .remove(pointer: JSONPointer(pathComponents: ["foo", "0"])),
                to: Model(
                    baz: "qux",
                    foo: [8, 9]
                )
            ),
            Model(
                baz: "qux",
                foo: [9]
            )
        )
    }
    
    func testAddsDictionaryValue() throws {
        XCTAssertEqual(
            try apply(
                .add(pointer: JSONPointer(pathComponents: ["baz"]), encodableValue: "qux"),
                to: Model()
            ),
            Model(baz: "qux")
        )
    }

    func testAddsNestedDictionaryValue() throws {
        XCTAssertEqual(
            try apply(
                .add(pointer: JSONPointer(pathComponents: ["bar", "0", "foo"]), encodableValue: "foo"),
                to: Model(bar: [.init()])
            ),
            Model(bar: [.init(foo: "foo")])
        )
    }
    
    func testAddsArrayValue() throws {
        XCTAssertEqual(
            try apply(
                .add(pointer: JSONPointer(pathComponents: ["bar", "0"]), encodableValue: Model.Model(foo: "foo")),
                to: Model(bar: [.init()])
            ),
            Model(bar: [.init(foo: "foo"), .init()])
        )
    }
    
    func testAddsArrayValueAtTheEnd() throws {
        XCTAssertEqual(
            try apply(
                .add(pointer: JSONPointer(pathComponents: ["bar", "1"]), encodableValue: Model.Model(foo: "foo")),
                to: Model(bar: [.init()])
            ),
            Model(bar: [.init(), .init(foo: "foo")])
        )
    }

    func testAppliesMultiplePatchOperations() throws {
        XCTAssertEqual(
            try apply(
                .remove(pointer: JSONPointer(pathComponents: ["foo", "0"])),
                .replace(pointer: JSONPointer(pathComponents: ["baz"]), encodableValue: "boo"),
                to: Model(
                    baz: "qux",
                    foo: [8, 9]
                )
            ),
            Model(
                baz: "boo",
                foo: [9]
            )
        )
    }
    
    func testThrowsErrorForInvalidRemoveObjectPointer() throws {
        XCTAssertThrowsError(
            try apply(
                .remove(pointer: JSONPointer(pathComponents: ["bar", "0", "invalid-property"])),
                to: Model(
                    baz: "qux",
                    foo: [8, 9]
                )
            )
        ) { error in
            XCTAssertEqual(
                error.localizedDescription,
                "Invalid array pointer '/bar/0/invalid-property'. The index '0' is not valid for array of 0 elements."
            )
        }
    }
    
    func testThrowsErrorForInvalidRemoveArrayPointer() throws {
        XCTAssertThrowsError(
            try apply(
                .remove(pointer: JSONPointer(pathComponents: ["foo", "5"])),
                to: Model(
                    baz: "qux",
                    foo: [8, 9]
                )
            )
        ) { error in
            XCTAssertEqual(
                error.localizedDescription,
                "Invalid array pointer '/foo/5'. The index '5' is not valid for array of 2 elements."
            )
        }
    }
    
    func testThrowsErrorForInvalidAddArrayPointer() throws {
        XCTAssertThrowsError(
            try apply(
                .add(pointer: JSONPointer(pathComponents: ["foo", "5"]), encodableValue: ""),
                to: Model(
                    foo: [8, 9]
                )
            )
        ) { error in
            XCTAssertEqual(
                error.localizedDescription,
                "Invalid array pointer '/foo/5'. The index '5' is not valid for array of 2 elements."
            )
        }
    }
    
    func testThrowsErrorForInvalidValuePointer() throws {
        XCTAssertThrowsError(
            try apply(
                .remove(pointer: JSONPointer(pathComponents: ["baz", "5"])),
                to: Model(
                    baz: "qux",
                    foo: [8, 9]
                )
            )
        ) { error in
            XCTAssertEqual(
                error.localizedDescription,
                """
                Invalid value pointer '/baz/5'. The component '5' is not valid for the non-traversable value '"qux"'.
                """
            )
        }
    }
    
    private func apply(_ patch: JSONPatchOperation..., to model: Model) throws -> Model {
        try JSONDecoder().decode(
            Model.self,
            from: JSONPatchApplier().apply(patch, to: JSONEncoder().encode(model))
        )
    }
    
    private struct Model: Codable, Equatable {
        var baz: String?
        var foo: [Int] = []
        var bar: [Model] = []
        
        struct Model: Codable, Equatable {
            var bar: String? = nil
            var foo: String? = nil
        }
    }
}
