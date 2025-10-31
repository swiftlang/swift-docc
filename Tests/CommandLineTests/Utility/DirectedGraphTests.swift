/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024-2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocC

final class DirectedGraphTests: XCTestCase {
    
    func testGraphWithSingleAdjacency() throws {
        // 1───▶2◀───3
        //      │
        //      ▼
        // 4───▶5    6
        //      │    │
        //      ▼    ▼
        // 7───▶8◀───9
        let graph = DirectedGraph(edges: [
            1: [2],
            2: [5],
            3: [2],
            4: [5],
            5: [8],
            7: [8],
            6: [9],
            9: [8],
        ])
        
        // With only a single neighbor per node, breadth first and depth first perform the same traversal
        assertEqual(graph.breadthFirstSearch(from: 1), [1,2,5,8])
        assertEqual(graph.breadthFirstSearch(from: 2), [2,5,8])
        assertEqual(graph.breadthFirstSearch(from: 3), [3,2,5,8])
        assertEqual(graph.breadthFirstSearch(from: 4), [4,5,8])
        assertEqual(graph.breadthFirstSearch(from: 5), [5,8])
        assertEqual(graph.breadthFirstSearch(from: 6), [6,9,8])
        assertEqual(graph.breadthFirstSearch(from: 7), [7,8])
        assertEqual(graph.breadthFirstSearch(from: 8), [8])
        assertEqual(graph.breadthFirstSearch(from: 9), [9,8])
        
        assertEqual(graph.depthFirstSearch(from: 1), [1,2,5,8])
        assertEqual(graph.depthFirstSearch(from: 2), [2,5,8])
        assertEqual(graph.depthFirstSearch(from: 3), [3,2,5,8])
        assertEqual(graph.depthFirstSearch(from: 4), [4,5,8])
        assertEqual(graph.depthFirstSearch(from: 5), [5,8])
        assertEqual(graph.depthFirstSearch(from: 6), [6,9,8])
        assertEqual(graph.depthFirstSearch(from: 7), [7,8])
        assertEqual(graph.depthFirstSearch(from: 8), [8])
        assertEqual(graph.depthFirstSearch(from: 9), [9,8])
        
        // With only a single neighbor per node, the path is the same as the traversal
        XCTAssertEqual(graph.allFinitePaths(from: 1), [[1,2,5,8]])
        XCTAssertEqual(graph.allFinitePaths(from: 2), [[2,5,8]])
        XCTAssertEqual(graph.allFinitePaths(from: 3), [[3,2,5,8]])
        XCTAssertEqual(graph.allFinitePaths(from: 4), [[4,5,8]])
        XCTAssertEqual(graph.allFinitePaths(from: 5), [[5,8]])
        XCTAssertEqual(graph.allFinitePaths(from: 6), [[6,9,8]])
        XCTAssertEqual(graph.allFinitePaths(from: 7), [[7,8]])
        XCTAssertEqual(graph.allFinitePaths(from: 8), [[8]])
        XCTAssertEqual(graph.allFinitePaths(from: 9), [[9,8]])
        
        for node in 1...9 {
            XCTAssertNil(graph.firstCycle(from: node))
            XCTAssertEqual(graph.cycles(from: node), [])
        }
    }
    
    func testGraphWithTreeStructure() throws {
        //        ┌▶5
        //   ┌─▶2─┤
        //   │    └▶6
        // 1─┼─▶3
        //   │
        //   └─▶4──▶7──▶8
        let graph = DirectedGraph(edges: [
            1: [2,3,4],
            2: [5,6],
            4: [7],
            7: [8],
        ])
        
        assertEqual(graph.breadthFirstSearch(from: 1), [1,2,3,4,5,6,7,8])
        
        assertEqual(graph.depthFirstSearch(from: 1), [1,4,7,8,3,2,6,5])
        
        XCTAssertEqual(graph.allFinitePaths(from: 1), [
            [1,3],
            [1,2,5],
            [1,2,6],
            [1,4,7,8],
        ])
        
        XCTAssertEqual(graph.shortestFinitePaths(from: 1), [
            [1,3],
        ])
        
        for node in 1...8 {
            XCTAssertNil(graph.firstCycle(from: node))
        }
    }
    
    func testGraphWithTreeStructureAndMultipleAdjacency() throws {
        //   ┌─▶2─┐
        //   │    │
        // 1─┼─▶3─┼▶5──▶6
        //   │    │
        //   └─▶4─┘
        let graph = DirectedGraph(edges: [
            1: [2,3,4],
            2: [5],
            3: [5],
            4: [5],
            5: [6],
        ])
        
        assertEqual(graph.breadthFirstSearch(from: 1), [1,2,3,4,5,6])
        assertEqual(graph.depthFirstSearch(from: 1), [1,4,5,6,3,2])
        
        XCTAssertEqual(graph.allFinitePaths(from: 1), [
            [1,2,5,6],
            [1,3,5,6],
            [1,4,5,6],
        ])
        
        XCTAssertEqual(graph.shortestFinitePaths(from: 1), [
            [1,2,5,6],
            [1,3,5,6],
            [1,4,5,6],
        ])
        
        for node in 1...6 {
            XCTAssertNil(graph.firstCycle(from: node))
        }
    }
    
    func testComplexGraphWithMultipleAdjacency() throws {
        // 1      ┌──▶5
        // │      │   │
        // ▼      │   ▼
        // 2──▶4──┼──▶6──▶8
        // │   ▲  │       ▲
        // ▼   │  │       │
        // 3───┘  └──▶7───┘
        let graph = DirectedGraph(edges: [
            1: [2],
            2: [3,4],
            3: [4],
            4: [5,6,7],
            5: [6],
            6: [8],
            7: [8],
        ])
        
        assertEqual(graph.breadthFirstSearch(from: 1), [1,2,3,4,5,6,7,8])
        assertEqual(graph.depthFirstSearch(from: 1), [1,2,4,7,8,6,5,3])
        
        XCTAssertEqual(graph.allFinitePaths(from: 1), [
            [1,2,4,6,8],
            [1,2,4,7,8],
            [1,2,3,4,6,8],
            [1,2,3,4,7,8],
            [1,2,4,5,6,8],
            [1,2,3,4,5,6,8],
        ])
        
        XCTAssertEqual(graph.shortestFinitePaths(from: 1), [
            [1,2,4,6,8],
            [1,2,4,7,8],
        ])
        
        for node in 1...8 {
            XCTAssertNil(graph.firstCycle(from: node))
        }
    }
    
    func testSimpleCycle() throws {
        do {
            // ┌──────▶2
            // │       │
            // 1───┐   │
            // ▲   ▼   │
            // └───3◀──┘
            let graph = DirectedGraph(edges: [
                0: [2,3],
                1: [2,3],
                2: [3],
                3: [1],
            ])
            
            XCTAssertEqual(graph.cycles(from: 1), [
                [1,3],
            ])
            XCTAssertEqual(graph.cycles(from: 2), [
                [2,3,1],
                [3,1],
            ])
            XCTAssertEqual(graph.cycles(from: 3), [
                [3,1],
                [3,1,2],
            ])
            
            for id in [1,2,3] {
                XCTAssertEqual(graph.allFinitePaths(from: id), [], "The only path from '\(id)' is infinite (cyclic)")
                XCTAssertEqual(graph.shortestFinitePaths(from: id), [], "The only path from '\(id)' is infinite (cyclic)")
                XCTAssertEqual(graph.reachableLeafNodes(from: id), [], "The only path from '\(id)' is infinite (cyclic)")
            }
        }
    }
    
    func testSimpleCycleRotation() throws {
        do {
            // ┌───▶1───▶2
            // │    ▲    │
            // │    │    │
            // 0───▶3◀───┘
            let graph = DirectedGraph(edges: [
                0: [1,3],
                1: [2,],
                2: [3],
                3: [1],
            ])
            
            XCTAssertEqual(graph.cycles(from: 0), [
                [1,2,3],
                // '3,1,2' and '2,3,1' are both rotations of '1,2,3'.
            ])
        }
    }
    
    func testGraphWithCycleAndSingleAdjacency() throws {
        // 1───▶2◀───3
        //      │
        //      ▼
        // 4───▶5◀───6
        //      │    ▲
        //      ▼    │
        // 7───▶8───▶9
        let graph = DirectedGraph(edges: [
            1: [2],
            2: [5],
            3: [2],
            4: [5],
            5: [8],
            6: [5],
            7: [8],
            8: [9],
            9: [6],
        ])
        
        // With only a single neighbor per node, breadth first and depth first perform the same traversal
        assertEqual(graph.breadthFirstSearch(from: 1), [1,2,5,8,9,6])
        assertEqual(graph.depthFirstSearch(from: 1), [1,2,5,8,9,6])
        
        XCTAssertEqual(graph.allFinitePaths(from: 1), [], "The only path from '1' is infinite (cyclic)")
        XCTAssertEqual(graph.shortestFinitePaths(from: 1), [], "The only path from '1' is infinite (cyclic)")
        XCTAssertEqual(graph.reachableLeafNodes(from: 1), [], "The only path from '1' is infinite (cyclic)")
        
        for node in [1,2,3,4,5] {
            XCTAssertEqual(graph.firstCycle(from: node), [5,8,9,6])
            XCTAssertEqual(graph.cycles(from: node), [[5,8,9,6]])
        }
        
        for node in [7,8] {
            XCTAssertEqual(graph.firstCycle(from: node), [8,9,6,5])
            XCTAssertEqual(graph.cycles(from: node), [[8,9,6,5]])
        }
        XCTAssertEqual(graph.firstCycle(from: 6), [6,5,8,9])
        XCTAssertEqual(graph.cycles(from: 6), [[6,5,8,9]])
        
        XCTAssertEqual(graph.firstCycle(from: 9), [9,6,5,8])
        XCTAssertEqual(graph.cycles(from: 9), [[9,6,5,8]])
    }
    
    func testGraphsWithCycleAndManyLeafNodes() throws {
        do {
            //             6   10
            //             ▲    ▲
            //  1    3     │    │
            //  ▲    ▲  ┌─▶4───▶7
            //  │    │  │  │    ▲
            //  0───▶2──┤  │    ║
            //          │  ▼    ▼
            //          └─▶5───▶9
            //             │    │
            //             ▼    ▼
            //             8   11
            let graph = DirectedGraph(edges: [
                0: [1,2],
                2: [3,4,5],
                4: [5,6,7],
                5: [8,9],
                7: [10,9],
                9: [11,7],
            ])

            XCTAssertEqual(graph.firstCycle(from: 0), [7,9])
            XCTAssertEqual(graph.firstCycle(from: 4), [7,9])
            XCTAssertEqual(graph.firstCycle(from: 5), [9,7])
            
            XCTAssertEqual(graph.cycles(from: 0), [
                [7,9], // through breadth-first-traversal, 7 is reached before 9.
            ])
            
            XCTAssertEqual(graph.allFinitePaths(from: 0), [
                [0,1],
                [0,2,3],
                [0,2,4,6],
                [0,2,5,8],
                [0,2,4,5,8],
                [0,2,4,7,10],
                [0,2,5,9,11],
                [0,2,4,5,9,11],
                [0,2,4,7,9,11],
                [0,2,5,9,7,10],
                [0,2,4,5,9,7,10]
            ])
            
            XCTAssertEqual(graph.shortestFinitePaths(from: 0), [
                [0,1],
            ])
            
            XCTAssertEqual(graph.reachableLeafNodes(from: 0), [1,3,6,8,10,11])
        }
    }
    
    func testGraphWithManyCycles() throws {
        // ┌──┐    ┌───▶4────┐
        // │  │    │    │    │
        // │  │    │    ▼    ▼
        // └─▶1───▶2───▶5───▶7───▶10
        //    ▲    ▲    │    ▲
        //    ║    ║    │    ║
        //    ║    ▼    ▼    ▼
        //    ╚═══▶3    8───▶9───▶11
        let graph = DirectedGraph(edges: [
            1: [1,2,3],
            2: [3,4,5],
            3: [1,2],
            4: [5,7],
            5: [8,7],
            7: [10,9],
            8: [9],
            9: [11,7],
        ])

        XCTAssertEqual(graph.firstCycle(from: 1), [1])
        XCTAssertEqual(graph.firstCycle(from: 2), [2,3])
        XCTAssertEqual(graph.firstCycle(from: 4), [7,9])
        XCTAssertEqual(graph.firstCycle(from: 8), [9,7])
        
        XCTAssertEqual(graph.cycles(from: 1), [
            [1],
            [1,3],
            // There's also a [1,2,3] cycle but that can also be broken by removing the edge from 3 ──▶ 1.
            [2,3],
            [7,9]
        ])
        
        XCTAssertEqual(graph.allFinitePaths(from: 1), [
            [1, 2, 4, 7, 10],
            [1, 2, 5, 7, 10],
            [1, 2, 4, 5, 7, 10],
            [1, 2, 4, 7, 9, 11],
            [1, 2, 5, 8, 9, 11],
            [1, 2, 5, 7, 9, 11],
            [1, 3, 2, 4, 7, 10],
            [1, 3, 2, 5, 7, 10],
            [1, 2, 4, 5, 8, 9, 11],
            [1, 2, 4, 5, 7, 9, 11],
            [1, 2, 5, 8, 9, 7, 10],
            [1, 3, 2, 4, 5, 7, 10],
            [1, 3, 2, 4, 7, 9, 11],
            [1, 3, 2, 5, 8, 9, 11],
            [1, 3, 2, 5, 7, 9, 11],
            [1, 2, 4, 5, 8, 9, 7, 10],
            [1, 3, 2, 4, 5, 8, 9, 11],
            [1, 3, 2, 4, 5, 7, 9, 11],
            [1, 3, 2, 5, 8, 9, 7, 10],
            [1, 3, 2, 4, 5, 8, 9, 7, 10]
        ])
        
        XCTAssertEqual(graph.shortestFinitePaths(from: 1), [
            [1, 2, 4, 7, 10],
            [1, 2, 5, 7, 10],
        ])
        
        XCTAssertEqual(graph.reachableLeafNodes(from: 1), [10, 11])
    }
    
    func testGraphWithMultiplePathsToEnterCycle() throws {
        //    ┌─▶2◀─┐
        //    │  │  │
        //    │  ▼  │
        // 1──┼─▶3  5
        //    │  │  ▲
        //    │  ▼  │
        //    └─▶4──┘
        let graph = DirectedGraph(edges: [
            1: [2,3,4],
            2: [3],
            3: [4],
            4: [5],
            5: [2],
        ])
        
        // With only a single neighbor per node, breadth first and depth first perform the same traversal
        assertEqual(graph.breadthFirstSearch(from: 1), [1,2,3,4,5])
        assertEqual(graph.depthFirstSearch(from: 1), [1,4,5,2,3])
        
        XCTAssertEqual(graph.allFinitePaths(from: 1), [
            // The only path from 1 is cyclic
        ])
        
        XCTAssertEqual(graph.shortestFinitePaths(from: 1), [
            // The only path from 1 is cyclic
        ])
        
        XCTAssertEqual(graph.firstCycle(from: 1), [2,3,4,5])
        XCTAssertEqual(graph.cycles(from: 1), [
            [2,3,4,5]
            // The other cycles are rotations of the first one.
        ])
    }
}

// A private helper to avoid needing to wrap the breadth first and depth first sequences into arrays to compare them.
private func assertEqual<Element: Equatable>(_ lhs: some Sequence<Element>, _ rhs: some Sequence<Element>, file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertEqual(Array(lhs), Array(rhs), file: file, line: line)
}
