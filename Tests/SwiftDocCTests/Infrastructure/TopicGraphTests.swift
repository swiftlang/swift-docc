/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocC

class TopicGraphTests: XCTestCase {
    enum TestGraphs {
        /// Returns a ``ResolvedTopicReference`` with the given title, with a phony source language, kind, and source. These are not for testing specific relationships, only abstract graph connectivity.
        static func testNodeWithTitle(_ title: String) -> TopicGraph.Node {
            let urlSafeTitle = title.replacingOccurrences(of: " ", with: "_")
            let reference = ResolvedTopicReference(bundleIdentifier: "org.swift.docc.TopicGraphTests", path: "/\(urlSafeTitle)", sourceLanguage: .swift)
            return TopicGraph.Node(reference: reference, kind: .technology, source: .file(url: URL(fileURLWithPath: "/path/to/\(urlSafeTitle)")), title: title)
        }
        
        /// Return a graph with one node A
        static var withOneNode: TopicGraph {
            var graph = TopicGraph()
            graph.addNode(testNodeWithTitle("A"))
            return graph
        }
        
        /// Return a graph with one edge A -> B
        static var withOneEdge: TopicGraph {
            var graph = TopicGraph()
            let a = testNodeWithTitle("A")
            let b = testNodeWithTitle("B")
            graph.addEdge(from: a, to: b)
            return graph
        }
        
        /// Return a graph with:
        ///
        ///     A -> B -> C
        ///       -> D -> E
        static var complex: TopicGraph {
            var graph = TopicGraph()
            graph.addEdge(from: testNodeWithTitle("A"), to: testNodeWithTitle("B"))
            graph.addEdge(from: testNodeWithTitle("B"), to: testNodeWithTitle("C"))
            graph.addEdge(from: testNodeWithTitle("A"), to: testNodeWithTitle("D"))
            graph.addEdge(from: testNodeWithTitle("D"), to: testNodeWithTitle("E"))
            return graph
        }
        
        /// Return a cyclic graph A -> B -> C -> A
        static var withCycle: TopicGraph {
            var graph = TopicGraph()
            graph.addEdge(from: testNodeWithTitle("A"), to: testNodeWithTitle("B"))
            graph.addEdge(from: testNodeWithTitle("B"), to: testNodeWithTitle("C"))
            graph.addEdge(from: testNodeWithTitle("C"), to: testNodeWithTitle("A"))
            return graph
        }

        /// Return a graph with overload group information:
        ///
        /// ```
        /// Parent
        ///   -> A
        ///   -> B
        ///   -> Overload Group
        ///     -> A
        ///     -> B
        /// ```
        static var withOverloadGroup: TopicGraph {
            var graph = TopicGraph()

            let parent = testNodeWithTitle("Parent")
            let group = testNodeWithTitle("Overload Group")
            let a = testNodeWithTitle("A")
            let b = testNodeWithTitle("B")

            graph.addEdge(from: parent, to: a)
            graph.addEdge(from: parent, to: b)
            graph.addEdge(from: parent, to: group)

            graph.addEdge(from: group, to: a)
            graph.addEdge(from: group, to: b)

            graph.nodes[group.reference]?.isOverloadGroup = true

            return graph
        }
    }
    func testNodes() {
        XCTAssertEqual(1, TestGraphs.withOneNode.nodes.count)
        XCTAssertEqual(2, TestGraphs.withOneEdge.nodes.count)
    }
    
    func testAddNode() {
        let before = TestGraphs.withOneEdge
        var after = before
        // This should not destroy the edge from A -> B
        after.addNode(TestGraphs.testNodeWithTitle("A"))
        XCTAssertEqual(before.edges, after.edges)
    }
    
    func testReplaceNode() {
        var graph = TestGraphs.complex
        let a = TestGraphs.testNodeWithTitle("A")
        let d = TestGraphs.testNodeWithTitle("D")
        graph.removeEdges(from: d)
        
        let initialDump = graph.dump(startingAt: a)
        XCTAssertEqual(initialDump.trimmingLines(), """
        A
        ├ B
        │ ╰ C
        ╰ D
        """.trimmingLines())
        
        let b = TestGraphs.testNodeWithTitle("B")
        let e = TestGraphs.testNodeWithTitle("E")
        graph.replaceNode(b, with: e)
        
        let updatedDump = graph.dump(startingAt: a)
        XCTAssertEqual(updatedDump.trimmingLines(), """
        A
        ├ D
        ╰ E
          ╰ C
        """.trimmingLines())
    }

    func testAddEdge() {
        do {
            var graph = TopicGraph()
            graph.addEdge(from: TestGraphs.testNodeWithTitle("A"), to: TestGraphs.testNodeWithTitle("B"))
            
            // If the source or target are not already in the graph, they will be added.
            XCTAssertEqual(2, graph.nodes.count)
            
            // A -> B
            XCTAssertEqual(graph[TestGraphs.testNodeWithTitle("A")], [TestGraphs.testNodeWithTitle("B").reference])
        }
    }
    
    func testNodeWithReference() {
        XCTAssertEqual(TestGraphs.withOneNode.nodeWithReference(TestGraphs.testNodeWithTitle("A").reference),
                       TestGraphs.testNodeWithTitle("A"))
        
        XCTAssertEqual(TestGraphs.withOneEdge.nodeWithReference(TestGraphs.testNodeWithTitle("A").reference),
                       TestGraphs.testNodeWithTitle("A"))
        
        XCTAssertEqual(TestGraphs.withOneEdge.nodeWithReference(TestGraphs.testNodeWithTitle("B").reference),
                       TestGraphs.testNodeWithTitle("B"))
    }
    
    func testSubscript() {
        // One node
        XCTAssertNotNil(TestGraphs.withOneNode[TestGraphs.testNodeWithTitle("A")])
        XCTAssertEqual([], TestGraphs.withOneNode[TestGraphs.testNodeWithTitle("C")])
        
        // One edge
        XCTAssertEqual([TestGraphs.testNodeWithTitle("B").reference], TestGraphs.withOneEdge[TestGraphs.testNodeWithTitle("A")])
        XCTAssertNotNil(TestGraphs.withOneEdge[TestGraphs.testNodeWithTitle("B")])
        XCTAssertEqual([], TestGraphs.withOneNode[TestGraphs.testNodeWithTitle("C")])
    }
    
    func testPreserveEdgeInsertionOrder() {
        var graph = TopicGraph()
        
        // A -> B
        graph.addEdge(from: TestGraphs.testNodeWithTitle("A"), to: TestGraphs.testNodeWithTitle("B"))
        // A -> C
        graph.addEdge(from: TestGraphs.testNodeWithTitle("A"), to: TestGraphs.testNodeWithTitle("C"))
        // A -> D
        graph.addEdge(from: TestGraphs.testNodeWithTitle("A"), to: TestGraphs.testNodeWithTitle("D"))
        
        // A -> [B, C, D] in order.
        XCTAssertEqual([
            TestGraphs.testNodeWithTitle("B").reference,
            TestGraphs.testNodeWithTitle("C").reference,
            TestGraphs.testNodeWithTitle("D").reference,
        ], graph[TestGraphs.testNodeWithTitle("A")])
    }
    
    func testBreadthFirstSearch() {
        let graph = TestGraphs.complex
        let A = TestGraphs.testNodeWithTitle("A")
        let visited = graph.breadthFirstSearch(from: A.reference).map(\.title)
        XCTAssertEqual(["A", "B", "D", "C", "E"], visited)
    }
    
    func testBreadthFirstSearchWithCycle() {
        let graph = TestGraphs.withCycle
        let A = TestGraphs.testNodeWithTitle("A")
        let visited = graph.breadthFirstSearch(from: A.reference).map(\.title)
        XCTAssertEqual(["A", "B", "C"], visited)
    }
    
    func testBreadthFirstSearchEarlyStop() {
        let graph = TestGraphs.complex
        let A = TestGraphs.testNodeWithTitle("A")
        let visited = graph.breadthFirstSearch(from: A.reference).prefix(1).map(\.title)
        XCTAssertEqual(["A"], visited)
    }
    
    func testDepthFirstSearch() {
        let graph = TestGraphs.complex
        let A = TestGraphs.testNodeWithTitle("A")
        let visited = graph.depthFirstSearch(from: A.reference).map(\.title)
        XCTAssertEqual(["A", "D", "E", "B", "C"], visited)
    }
    
    func testDepthFirstSearchWithCycle() {
        let graph = TestGraphs.withCycle
        let A = TestGraphs.testNodeWithTitle("A")
        let visited = graph.breadthFirstSearch(from: A.reference).map(\.title)
        XCTAssertEqual(["A", "B", "C"], visited)
    }
    
    func testDepthFirstSearchEarlyStop() {
        let graph = TestGraphs.complex
        let A = TestGraphs.testNodeWithTitle("A")
        let visited = graph.depthFirstSearch(from: A.reference).prefix(1).map(\.title)
        XCTAssertEqual(["A"], visited)
    }
    
    func testEveryEdgeSourceHasNode() {
        for graph in [TestGraphs.complex, TestGraphs.withCycle, TestGraphs.withOneEdge, TestGraphs.withOneNode] {
            let edgeReferences = Set(graph.edges.keys)
            let nodeReferences = Set(graph.nodes.keys)
            
            // Verify that every edge source has a node
            
            // `edges` only store the sources but `nodes` store both sources and targets
            XCTAssertLessThanOrEqual(edgeReferences.count, nodeReferences.count)
            
            let missingEdgeReferences = edgeReferences.subtracting(nodeReferences)
            XCTAssert(missingEdgeReferences.isEmpty, """
            These \(missingEdgeReferences.count) references exist in `graph.edges` but not in `graph.nodes`:
            \(missingEdgeReferences.map { $0.description }.sorted().joined(separator: ", "))
            """)
            
            // Verify that every reverse edge source has a node

            let reverseEdgeReferences = Set(graph.reverseEdges.keys)
            // `edges` only store the sources but `nodes` store both sources and targets
            XCTAssertLessThanOrEqual(reverseEdgeReferences.count, nodeReferences.count)

            let missingReverseEdgeReferences = reverseEdgeReferences.subtracting(nodeReferences)
            XCTAssert(missingReverseEdgeReferences.isEmpty, """
            These \(missingReverseEdgeReferences.count) references exist in `graph.reverse` but not in `graph.nodes`:
            \(missingReverseEdgeReferences.map { $0.description }.sorted().joined(separator: ", "))
            """)
        }
    }
    
    func testEveryEdgeHasReverseEdge() {
        for graph in [TestGraphs.complex, TestGraphs.withCycle, TestGraphs.withOneEdge, TestGraphs.withOneNode] {
            // Verify that every edge has a reverse edge
            for (source, targets) in graph.edges {
                for target in targets {
                    XCTAssertNotNil(graph.reverseEdges[target],
                                    "No reverse edges found for \(target.description.singleQuoted) (a child of \(source.description.singleQuoted))")
                    XCTAssert(graph.reverseEdges[target]?.contains(source) ?? false,
                              "Missing reverse edge from \(target.description.singleQuoted) to \(source.description.singleQuoted)")
                }
            }
            
            // Verify that reverse every edge has an edge
            for (source, targets) in graph.reverseEdges {
                for target in targets {
                    XCTAssertNotNil(graph.edges[target],
                                    "No edges found for \(target.description.singleQuoted) (a parent of \(source.description.singleQuoted))")
                    XCTAssert(graph.edges[target]?.contains(source) ?? false,
                              "Missing edge from \(target.description.singleQuoted) to \(source.description.singleQuoted)")
                }
            }
        }
    }

    func testCollectOverloads() {
        let graph = TestGraphs.withOverloadGroup
        let overloadGroup = TestGraphs.testNodeWithTitle("Overload Group")

        XCTAssertEqual(graph.overloads(of: overloadGroup.reference), [
            TestGraphs.testNodeWithTitle("A").reference,
            TestGraphs.testNodeWithTitle("B").reference,
        ])
    }
}
