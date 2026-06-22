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

struct JSONPatchOperationTests {
    @Test
    func initializesWithVariantOverride() throws {
        let patchOperation = JSONPatchOperation(
            variantPatchOperation: .replace(value: "value"),
            pointer: JSONPointer(pathComponents: ["a", "b"])
        )
        
        guard case .replace(_, let value) = patchOperation else {
            Issue.record("Unexpected patch operation")
            return
        }
        let stringValue = try #require(value.value as? String)
        #expect(stringValue == "value")
        #expect(patchOperation.pointer.pathComponents == ["a", "b"])
    }
    
    @Test
    func encodesReplaceOperation() throws {
        let encodedOperation = try JSONEncoder().encode(
            JSONPatchOperation.replace(pointer: JSONPointer(pathComponents: ["a", "b"]), encodableValue: "new value")
        )
        
        let patchOperation = try #require(
            JSONSerialization.jsonObject(with: encodedOperation) as? NSDictionary
        )
        
        #expect(patchOperation["op"] as? String == "replace")
        #expect(patchOperation["path"] as? String == "/a/b")
        #expect(patchOperation["value"] as? String == "new value")
    }
    
    @Test
    func encodesRemoveOperation() throws {
        let encodedOperation = try JSONEncoder().encode(
            JSONPatchOperation.remove(pointer: JSONPointer(pathComponents: ["a", "b"]))
        )
        
        let patchOperation = try #require(
            JSONSerialization.jsonObject(with: encodedOperation) as? NSDictionary
        )
        
        #expect(patchOperation["op"] as? String == "remove")
        #expect(patchOperation["path"] as? String == "/a/b")
    }
    
    @Test
    func decodesReplaceOperation() throws {
        let json = """
        {
            "op": "replace",
            "path": "/a/b",
            "value": "new value"
        }
        """.data(using: .utf8)!
        
        let operation = try JSONDecoder().decode(JSONPatchOperation.self, from: json)
        
        guard case .replace(let pointer, let value) = operation else {
            Issue.record("Unexpected patch operation")
            return
        }
        
        #expect(pointer.pathComponents == ["a", "b"])
        
        guard case .string(let string) = value.value as? JSON else {
            Issue.record("Unexpected JSON value")
            return
        }
        #expect(string == "new value")
    }
    
    @Test
    func decodesRemoveOperation() throws {
        let json = """
        {
            "op": "remove",
            "path": "/a/b"
        }
        """.data(using: .utf8)!
        
        let operation = try JSONDecoder().decode(JSONPatchOperation.self, from: json)
        
        guard case .remove(let pointer) = operation else {
            Issue.record("Unexpected patch operation")
            return
        }
        
        #expect(pointer.pathComponents == ["a", "b"])
    }
}
