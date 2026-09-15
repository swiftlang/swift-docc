/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Testing
@testable import SwiftDocC

struct JSONPatchApplierTests {
    @Test(arguments: [
        (
            input: Model(baz: "qux", foo: []),
            patch: JSONPatchOperation.replace(pointer: JSONPointer(pathComponents: ["baz"]), encodableValue: "boo"),
            expected: Model(baz: "boo", foo: [])
        ),
        (
            input: Model(baz: "qux", foo: [1, 2]),
            patch: .replace(pointer: JSONPointer(pathComponents: ["foo", "1"]), encodableValue: 123),
            expected: Model(baz: "qux", foo: [1, 123])
        ),
        (
            input: Model(baz: "qux", bar: [.init(bar: "value")]),
            patch: .replace(pointer: JSONPointer(pathComponents: ["bar", "0", "bar"]), encodableValue: "new value"),
            expected: Model(baz: "qux", bar: [.init(bar: "new value")])
        ),
        (
            input: Model(baz: "qux"),
            patch: .remove(pointer: JSONPointer(pathComponents: ["baz"])),
            expected: Model(baz: nil)
        ),
        (
            input: Model(baz: "qux", foo: [8, 9]),
            patch: .remove(pointer: JSONPointer(pathComponents: ["foo", "0"])),
            expected: Model(baz: "qux", foo: [9])
        ),
        (
            input: Model(),
            patch: .add(pointer: JSONPointer(pathComponents: ["baz"]), encodableValue: "qux"),
            expected: Model(baz: "qux")
        ),
        (
            input: Model(bar: [.init()]),
            patch: .add(pointer: JSONPointer(pathComponents: ["bar", "0", "foo"]), encodableValue: "foo"),
            expected: Model(bar: [.init(foo: "foo")])
        ),
        (
            input: Model(bar: [.init()]),
            patch: .add(pointer: JSONPointer(pathComponents: ["bar", "0"]), encodableValue: Model.Model(foo: "foo")),
            expected: Model(bar: [.init(foo: "foo"), .init()])
        ),
        (
            input: Model(bar: [.init()]),
            patch: .add(pointer: JSONPointer(pathComponents: ["bar", "1"]), encodableValue: Model.Model(foo: "foo")),
            expected: Model(bar: [.init(), .init(foo: "foo")])
        ),
    ])
    func appliesPatchOperation(input: Model, patch: JSONPatchOperation, expected: Model) throws {
        #expect(try apply(patch, to: input) == expected)
    }
    
    @Test
    func appliesMultiplePatchOperations() throws {
        #expect(
            try apply(
                .remove(pointer: JSONPointer(pathComponents: ["foo", "0"])),
                .replace(pointer: JSONPointer(pathComponents: ["baz"]), encodableValue: "boo"),
                to: Model(
                    baz: "qux",
                    foo: [8, 9]
                )
            ) == Model(
                baz: "boo",
                foo: [9]
            )
        )
    }
    
    @Test(arguments: [
        (
            input: Model(baz: "qux", foo: [8, 9]),
            patch: JSONPatchOperation.remove(pointer: JSONPointer(pathComponents: ["bar", "0", "invalid-property"])),
            expectedError: "Invalid array pointer '/bar/0/invalid-property'. The index '0' is not valid for array of 0 elements."
        ),
        (
            input: Model(baz: "qux", foo: [8, 9]),
            patch: .remove(pointer: JSONPointer(pathComponents: ["foo", "5"])),
            expectedError: "Invalid array pointer '/foo/5'. The index '5' is not valid for array of 2 elements."
        ),
        (
            input: Model(foo: [8, 9]),
            patch: .add(pointer: JSONPointer(pathComponents: ["foo", "5"]), encodableValue: ""),
            expectedError: "Invalid array pointer '/foo/5'. The index '5' is not valid for array of 2 elements."
        ),
        (
            input: Model(baz: "qux", foo: [8, 9]),
            patch: .remove(pointer: JSONPointer(pathComponents: ["baz", "5"])),
            expectedError: #"Invalid value pointer '/baz/5'. The component '5' is not valid for the non-traversable value '"qux"'."#
        ),
    ])
    func throwsErrorForInvalidPointer(input: Model, patch: JSONPatchOperation, expectedError: String) throws {
        do {
            _ = try apply(patch, to: input)
            Issue.record("Expected an error to be thrown")
        } catch {
            #expect(error.localizedDescription == expectedError)
        }
    }
    
    private func apply(_ patch: JSONPatchOperation..., to model: Model) throws -> Model {
        try JSONDecoder().decode(
            Model.self,
            from: JSONPatchApplier().apply(patch, to: JSONEncoder().encode(model))
        )
    }
    
    struct Model: Codable, Equatable {
        var baz: String?
        var foo: [Int] = []
        var bar: [Model] = []
        
        struct Model: Codable, Equatable {
            var bar: String? = nil
            var foo: String? = nil
        }
    }
}
