/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024-2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Testing
@testable import SwiftDocC

struct DirectedGraphTests {
    @Test
    func testGraphWithSingleAdjacency() {
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
        #expect(graph.breadthFirstSearch(from: 1) == [1,2,5,8])
        #expect(graph.breadthFirstSearch(from: 2) == [2,5,8])
        #expect(graph.breadthFirstSearch(from: 3) == [3,2,5,8])
        #expect(graph.breadthFirstSearch(from: 4) == [4,5,8])
        #expect(graph.breadthFirstSearch(from: 5) == [5,8])
        #expect(graph.breadthFirstSearch(from: 6) == [6,9,8])
        #expect(graph.breadthFirstSearch(from: 7) == [7,8])
        #expect(graph.breadthFirstSearch(from: 8) == [8])
        #expect(graph.breadthFirstSearch(from: 9) == [9,8])
        
        #expect(graph.depthFirstSearch(from: 1) == [1,2,5,8])
        #expect(graph.depthFirstSearch(from: 2) == [2,5,8])
        #expect(graph.depthFirstSearch(from: 3) == [3,2,5,8])
        #expect(graph.depthFirstSearch(from: 4) == [4,5,8])
        #expect(graph.depthFirstSearch(from: 5) == [5,8])
        #expect(graph.depthFirstSearch(from: 6) == [6,9,8])
        #expect(graph.depthFirstSearch(from: 7) == [7,8])
        #expect(graph.depthFirstSearch(from: 8) == [8])
        #expect(graph.depthFirstSearch(from: 9) == [9,8])
        
        // With only a single neighbor per node, the path is the same as the traversal
        #expect(graph.allFinitePaths(from: 1) == [[1,2,5,8]])
        #expect(graph.allFinitePaths(from: 2) == [[2,5,8]])
        #expect(graph.allFinitePaths(from: 3) == [[3,2,5,8]])
        #expect(graph.allFinitePaths(from: 4) == [[4,5,8]])
        #expect(graph.allFinitePaths(from: 5) == [[5,8]])
        #expect(graph.allFinitePaths(from: 6) == [[6,9,8]])
        #expect(graph.allFinitePaths(from: 7) == [[7,8]])
        #expect(graph.allFinitePaths(from: 8) == [[8]])
        #expect(graph.allFinitePaths(from: 9) == [[9,8]])
        
        for node in 1...9 {
            #expect(graph.firstCycle(from: node) == nil)
            #expect(graph.cycles(from: node)     == [])
        }
    }
    
    @Test
    func testGraphWithTreeStructure() {
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
        
        #expect(graph.breadthFirstSearch(from: 1) == [1,2,3,4,5,6,7,8])
        
        #expect(graph.depthFirstSearch(from: 1) == [1,4,7,8,3,2,6,5])
        
        #expect(graph.allFinitePaths(from: 1) == [
            [1,3],
            [1,2,5],
            [1,2,6],
            [1,4,7,8],
        ])
        
        #expect(graph.shortestFinitePaths(from: 1) == [
            [1,3],
        ])
        
        for node in 1...8 {
            #expect(graph.firstCycle(from: node) == nil)
        }
    }
    
    @Test
    func testGraphWithTreeStructureAndMultipleAdjacency() {
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
        
        #expect(graph.breadthFirstSearch(from: 1) == [1,2,3,4,5,6])
        #expect(graph.depthFirstSearch(from: 1) == [1,4,5,6,3,2])
        
        #expect(graph.allFinitePaths(from: 1) == [
            [1,2,5,6],
            [1,3,5,6],
            [1,4,5,6],
        ])
        
        #expect(graph.shortestFinitePaths(from: 1) == [
            [1,2,5,6],
            [1,3,5,6],
            [1,4,5,6],
        ])
        
        for node in 1...6 {
            #expect(graph.firstCycle(from: node) == nil)
        }
    }
    
    @Test
    func testComplexGraphWithMultipleAdjacency() {
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
        
        #expect(graph.breadthFirstSearch(from: 1) == [1,2,3,4,5,6,7,8])
        #expect(graph.depthFirstSearch(from: 1) == [1,2,4,7,8,6,5,3])
        
        #expect(graph.allFinitePaths(from: 1) == [
            [1,2,4,6,8],
            [1,2,4,7,8],
            [1,2,3,4,6,8],
            [1,2,3,4,7,8],
            [1,2,4,5,6,8],
            [1,2,3,4,5,6,8],
        ])
        
        #expect(graph.shortestFinitePaths(from: 1) == [
            [1,2,4,6,8],
            [1,2,4,7,8],
        ])
        
        for node in 1...8 {
            #expect(graph.firstCycle(from: node) == nil)
        }
    }
    
    @Test
    func testSimpleCycle() {
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
            
            #expect(graph.cycles(from: 1) == [
                [1,3],
            ])
            #expect(graph.cycles(from: 2) == [
                [2,3,1],
                [3,1],
            ])
            #expect(graph.cycles(from: 3) == [
                [3,1],
                [3,1,2],
            ])
            
            for id in [1,2,3] {
                #expect(graph.allFinitePaths(from: id) == [], "The only path from '\(id)' is infinite (cyclic)")
                #expect(graph.shortestFinitePaths(from: id) == [], "The only path from '\(id)' is infinite (cyclic)")
                #expect(graph.reachableLeafNodes(from: id) == [], "The only path from '\(id)' is infinite (cyclic)")
            }
        }
    }
    
    @Test
    func testSimpleCycleRotation() {
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
            
            #expect(graph.cycles(from: 0) == [
                [1,2,3],
                // '3,1,2' and '2,3,1' are both rotations of '1,2,3'.
            ])
        }
    }
    
    @Test
    func testGraphWithCycleAndSingleAdjacency() {
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
        #expect(graph.breadthFirstSearch(from: 1) == [1,2,5,8,9,6])
        #expect(graph.depthFirstSearch(from: 1) == [1,2,5,8,9,6])
        
        #expect(graph.allFinitePaths(from: 1) == [], "The only path from '1' is infinite (cyclic)")
        #expect(graph.shortestFinitePaths(from: 1) == [], "The only path from '1' is infinite (cyclic)")
        #expect(graph.reachableLeafNodes(from: 1) == [], "The only path from '1' is infinite (cyclic)")
        
        for node in [1,2,3,4,5] {
            #expect(graph.firstCycle(from: node) == [5,8,9,6])
            #expect(graph.cycles(from: node) == [[5,8,9,6]])
        }
        
        for node in [7,8] {
            #expect(graph.firstCycle(from: node) == [8,9,6,5])
            #expect(graph.cycles(from: node) == [[8,9,6,5]])
        }
        #expect(graph.firstCycle(from: 6) == [6,5,8,9])
        #expect(graph.cycles(from: 6) == [[6,5,8,9]])
        
        #expect(graph.firstCycle(from: 9) == [9,6,5,8])
        #expect(graph.cycles(from: 9) == [[9,6,5,8]])
    }
    
    @Test
    func testGraphsWithCycleAndManyLeafNodes() {
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

            #expect(graph.firstCycle(from: 0) == [7,9])
            #expect(graph.firstCycle(from: 4) == [7,9])
            #expect(graph.firstCycle(from: 5) == [9,7])
            
            #expect(graph.cycles(from: 0) == [
                [7,9], // through breadth-first-traversal, 7 is reached before 9.
            ])
            
            #expect(graph.allFinitePaths(from: 0) == [
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
            
            #expect(graph.shortestFinitePaths(from: 0) == [
                [0,1],
            ])
            
            #expect(graph.reachableLeafNodes(from: 0) == [1,3,6,8,10,11])
        }
    }
    
    @Test
    func testGraphWithManyCycles() {
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

        #expect(graph.firstCycle(from: 1) == [1])
        #expect(graph.firstCycle(from: 2) == [2,3])
        #expect(graph.firstCycle(from: 4) == [7,9])
        #expect(graph.firstCycle(from: 8) == [9,7])
        
        #expect(graph.cycles(from: 1) == [
            [1],
            [1,3],
            // There's also a [1,2,3] cycle but that can also be broken by removing the edge from 3 ──▶ 1.
            [2,3],
            [7,9]
        ])
        
        #expect(graph.allFinitePaths(from: 1) == [
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
        
        #expect(graph.shortestFinitePaths(from: 1) == [
            [1, 2, 4, 7, 10],
            [1, 2, 5, 7, 10],
        ])
        
        #expect(graph.reachableLeafNodes(from: 1) == [10, 11])
    }
    
    @Test
    func testGraphWithMultiplePathsToEnterCycle() {
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
        #expect(graph.breadthFirstSearch(from: 1) == [1,2,3,4,5])
        #expect(graph.depthFirstSearch(from: 1) == [1,4,5,2,3])
        
        #expect(graph.allFinitePaths(from: 1) == [
            // The only path from 1 is cyclic
        ])
        
        #expect(graph.shortestFinitePaths(from: 1) == [
            // The only path from 1 is cyclic
        ])
        
        #expect(graph.firstCycle(from: 1) == [2,3,4,5])
        #expect(graph.cycles(from: 1) == [
            [2,3,4,5]
            // The other cycles are rotations of the first one.
        ])
    }
}

// A private helper to avoid needing to wrap the breadth first and depth first sequences into arrays to compare them.

@_disfavoredOverload // Don't use this overload if the type is known (for example `Set<Element>`)
private func ==<Element: Equatable> (lhs: some Sequence<Element>, rhs: some Sequence<Element>) -> Bool {
    lhs.elementsEqual(rhs)
}
