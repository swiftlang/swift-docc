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
            variantPatchOperation: .replace(value: "value"),
            pointer: JSONPointer(pathComponents: ["a", "b"])
        )
        
        guard case .replace(_, let value) = patchOperation else {
            XCTFail("Unexpected patch operation")
            return
        }
        XCTAssertEqual(value.value as! String, "value")
        XCTAssertEqual(patchOperation.pointer.pathComponents, ["a", "b"])
    }
    
    func testEncodeReplaceOperation() throws {
        let encodedOperation = try JSONEncoder().encode(
            JSONPatchOperation.replace(pointer: JSONPointer(pathComponents: ["a", "b"]), encodableValue: "new value")
        )
        
        let patchOperation = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encodedOperation) as? NSDictionary
        )
        
        XCTAssertEqual(patchOperation["op"] as? String, "replace")
        XCTAssertEqual(patchOperation["path"] as? String, "/a/b")
        XCTAssertEqual(patchOperation["value"] as? String, "new value")
    }
    
    func testEncodeRemoveOperation() throws {
        let encodedOperation = try JSONEncoder().encode(
            JSONPatchOperation.remove(pointer: JSONPointer(pathComponents: ["a", "b"]))
        )
        
        let patchOperation = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encodedOperation) as? NSDictionary
        )
        
        XCTAssertEqual(patchOperation["op"] as? String, "remove")
        XCTAssertEqual(patchOperation["path"] as? String, "/a/b")
    }
    
    func testDecodeReplaceOperation() throws {
        let json = """
        {
            "op": "replace",
            "path": "/a/b",
            "value": "new value"
        }
        """.data(using: .utf8)!
        
        let operation = try JSONDecoder().decode(JSONPatchOperation.self, from: json)
        
        guard case .replace(let pointer, let value) = operation else {
            XCTFail("Unexpected patch operation")
            return
        }
        
        XCTAssertEqual(pointer.pathComponents, ["a", "b"])
        
        guard case .string(let string) = value.value as? JSON else {
            XCTFail("Unexpected JSON value")
            return
        }
        XCTAssertEqual(string, "new value")
    }
    
    func testDecodeRemoveOperation() throws {
        let json = """
        {
            "op": "remove",
            "path": "/a/b"
        }
        """.data(using: .utf8)!
        
        let operation = try JSONDecoder().decode(JSONPatchOperation.self, from: json)
        
        guard case .remove(let pointer) = operation else {
            XCTFail("Unexpected patch operation")
            return
        }
        
        XCTAssertEqual(pointer.pathComponents, ["a", "b"])
    }
}
