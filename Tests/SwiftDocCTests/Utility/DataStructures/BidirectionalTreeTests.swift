/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocC

extension BidirectionalTree where Node: Comparable {
    /// A stable dump of `Tree`'s nodes for testing purposes
    func dump(node: Node? = nil) throws -> String {
        var result = [String(describing: node ?? root)]
        try children(of: node ?? root).sorted().forEach({
            result.append(try dump(node: $0))
        })
        return result.joined(separator: ",")
    }
}

extension ResolvedTopicReference: Comparable {
    public static func < (lhs: ResolvedTopicReference, rhs: ResolvedTopicReference) -> Bool {
        return lhs.path < rhs.path
    }
}

class BidirectionalTreeTests: XCTestCase {
    /// Tests empty tree's contents
    func testEmptyTree() {
        XCTAssertEqual(try BidirectionalTree<Int>(root: 0).dump(), "0")
    }
    
    /// Tests the expected nodes and hierarchy in a tree
    func testIntTreeAddAndReplace() throws {
        // Test adding nodes
        var tree = BidirectionalTree<Int>(root: 1)
        try tree.add(2, parent: 1)
        try tree.add(3, parent: 2)
        try tree.add(4, parent: 2)
        XCTAssertEqual(try tree.dump(), "1,2,3,4")
        
        try tree.add(5, parent: 1)
        try tree.add(6, parent: 5)
        XCTAssertEqual(try tree.dump(), "1,2,3,4,5,6")
        
        // Test adding existing nodes
        XCTAssertThrowsError(try tree.add(1, parent: 1))
        XCTAssertThrowsError(try tree.add(2, parent: 1))

        // Test adding under non-existing parents
        XCTAssertThrowsError(try tree.add(100, parent: 1000))
        XCTAssertThrowsError(try tree.add(100, parent: -21))

        // Test replacing nodes
        try tree.replace(6, with: 600)
        XCTAssertEqual(try tree.dump(), "1,2,3,4,5,600")

        try tree.replace(4, with: 400)
        XCTAssertEqual(try tree.dump(), "1,2,3,400,5,600")
        
        try tree.replace(2, with: 200)
        XCTAssertEqual(try tree.dump(), "1,5,600,200,3,400") // re-ordered the dump so nodes are sorted
        
        // Test replacing non existing nodes
        XCTAssertThrowsError(try tree.replace(100, with: 200))

        // Test replacing with existing new node
        XCTAssertThrowsError(try tree.replace(2, with: 1))
        XCTAssertThrowsError(try tree.replace(2, with: 3))
    }

    /// Tests the expected nodes and hierarchy in a tree of custom nodes (topic references)
    func testReferenceTree() throws {
        let referenceFor: (String) -> ResolvedTopicReference = { path in
            return ResolvedTopicReference(bundleIdentifier: "com.bundle", path: path, sourceLanguage: .swift)
        }
        
        var tree = BidirectionalTree<ResolvedTopicReference>(root: referenceFor("/root"))
        try tree.add(referenceFor("/child1"), parent: referenceFor("/root"))
        try tree.add(referenceFor("/child2"), parent: referenceFor("/root"))
        try tree.add(referenceFor("/child3"), parent: referenceFor("/child2"))
        XCTAssertEqual(try tree.dump(), "doc://com.bundle/root,doc://com.bundle/child1,doc://com.bundle/child2,doc://com.bundle/child3")
    }
    
    /// Tests children and parents
    func testParentsAndChildren() throws {
        var tree = BidirectionalTree<Int>(root: 1)
        try tree.add(2, parent: 1)
        try tree.add(3, parent: 2)
        try tree.add(4, parent: 2)
        try tree.add(5, parent: 1)
        try tree.add(6, parent: 5)
        
        // Verify children
        XCTAssertEqual(try tree.children(of: 1), [2, 5])
        XCTAssertEqual(try tree.children(of: 2), [3, 4])
        XCTAssertEqual(try tree.children(of: 5), [6])
        XCTAssertEqual(try tree.children(of: 4), [])
        XCTAssertEqual(try tree.children(of: 6), [])
        XCTAssertThrowsError(try tree.children(of: 1010101010))
        XCTAssertThrowsError(try tree.children(of: -110))
        
        // Verify parents
        XCTAssertNil(try tree.parent(of: 1))
        XCTAssertEqual(try tree.parent(of: 2), 1)
        XCTAssertEqual(try tree.parent(of: 5), 1)
        XCTAssertEqual(try tree.parent(of: 3), 2)
        XCTAssertEqual(try tree.parent(of: 4), 2)
        XCTAssertThrowsError(try tree.parent(of: 100101001010))
        XCTAssertThrowsError(try tree.parent(of: -1020))
    }
    
    /// Tests traversing the tree
    func testTraversing() throws {
        var tree = BidirectionalTree<Int>(root: 1)
        try tree.add(2, parent: 1)
        try tree.add(3, parent: 2)
        try tree.add(4, parent: 2)
        try tree.add(5, parent: 1)
        try tree.add(6, parent: 5)
        
        // Test starting at root
        do {
            var visited = [Int]()
            try tree.traversePreOrder({ visited.append($0) })
            XCTAssertEqual(visited, [1,2,3,4,5,6])
        }

        // Test starting at node
        do {
            var visited = [Int]()
            try tree.traversePreOrder(from: 2, { visited.append($0) })
            XCTAssertEqual(visited, [2,3,4])
        }

        // Test starting at leaf
        do {
            var visited = [Int]()
            try tree.traversePreOrder(from: 6, { visited.append($0) })
            XCTAssertEqual(visited, [6])
        }
        
        // Test starting at non-existing node
        XCTAssertThrowsError(try tree.traversePreOrder(from: 1000) { _ in print("") })
    }
}
