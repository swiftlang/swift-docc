/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

extension DirectedGraph {
    /// Returns the first cycle in the graph encountered through breadth first traversal from a given starting point.
    ///
    /// The cycle starts at the earliest repeated node and ends with the node that links back to the repeated node.
    ///
    /// ## Example
    ///
    /// For example, consider the following subgraph, which can be entered from different directions:
    /// ```
    ///    ┌──────▶2◀──
    ///    │       │
    /// ──▶1───┐   │
    ///    ▲   ▼   │
    ///    └───3◀──┘
    ///        ▲
    ///        │
    /// ```
    ///
    /// When entering the subgraph from "1", there are two cycles in this graph; `1,3` and `1,2,3`.
    ///
    /// ```
    ///     ┌──────▶2         ┏━━━━━━▶2
    ///     │       │         ┃       ┃
    /// 0──▶1━━━┓   │     0──▶1───┐   ┃
    ///     ▲   ▼   │         ▲   ▼   ┃
    ///     ┗━━━3◀──┘         ┗━━━3◀━━┛
    /// ```
    ///
    /// Breadth first traversal through the graph encounters the `1,3` cycle first, so it stops iterating and only returns that cycle.
    ///
    /// Entering the same subgraph from "2" encounters the same cycle, but with "3" as the earliest repeated node, so it returns `1,3` instead.
    /// ```
    /// ┌──────▶2◀──0
    /// │       │
    /// 1━━━┓   │
    /// ▲   ▼   │
    /// ┗━━━3◀──┘
    /// ```
    ///
    /// - Note: A cycle, if found, is guaranteed to contain at least one node.
    func firstCycle(from startingPoint: Node) -> Path? {
        for case let (path, _, cycleStartIndex?) in accumulatingPaths(from: startingPoint) {
            return Array(path[cycleStartIndex...])
        }
        return nil
    }
    
    /// Returns a list of all the "unique" cycles in the graph encountered through breadth first traversal from a given starting point.
    ///
    /// Each cycle starts at the earliest repeated node and ends with the node that links back to the repeated node.
    ///
    /// Two cycles are considered the "same" if both cycles can be broken by removing the same edge in the graph. This happens when they either:
    /// - Have the same start and end points, for example: `1,2,3` and `1,3`.
    /// - Are rotations of each other, for example: `1,2,3` and `2,3,1` and `3,1,2`.
    ///
    ///  > Important:
    /// There graph may have different cycles that are reached from different starting points.
    ///
    /// ## Example: Single entry point to cycle
    ///
    /// For example, consider the following subgraph, which can be entered from different directions:
    /// ```
    ///    ┌──────▶2◀──
    ///    │       │
    /// ──▶1───┐   │
    ///    ▲   ▼   │
    ///    └───3◀──┘
    ///        ▲
    ///        │
    /// ```
    ///
    /// When entering the subgraph from "1", there are two cycles in this graph; `1,3` and `1,2,3`.
    /// These are considered the _same_ cycle because removing the `1─▶3` edge breaks both cycles.
    /// ```
    ///      ┏━━━━━━▶2
    ///      ┃       ┃
    ///  0──▶1━━━┓   ┃
    ///          ▼   ┃
    ///      └ ─ 3◀━━┛
    /// ```
    ///
    /// On the other hand, when entering the same subgraph from "2" there are two other cycles; `3,1` and `2,3,1`.
    /// These are considered _different_ cycles because they each require removing a different edge to break that cycle;
    /// `1─▶3` for the `3,1` cycle and `1─▶2` for the `2,3,1` cycle;
    /// ```
    /// ┌ ─ ─ ─ 2◀──0
    ///         ┃
    /// 1 ─ ┐   ┃
    /// ▲       ┃
    /// ┗━━━3◀━━┛
    /// ```
    ///
    /// ## Example: Multiple entry points to cycle
    ///
    /// Consider the same subgraph as before, which can be entered from different directions, where the starting point "0" enters the subgraph more than once:
    /// ```
    ///                      0──────────┐
    ///                      │          ▼
    ///     ┏━━━━━━▶2        │  ┏━━━━━━▶2         ┏━━━━━━▶2◀──┐
    ///     ┃       ┃        │  ┃       ┃         ┃       ┃   │
    /// ┌──▶1━━━┓   ┃        └─▶1━━━┓   ┃         1━━━┓   ┃   │
    /// │   ▲   ▼   ┃           ▲   ▼   ┃         ▲   ▼   ┃   │
    /// │   ┗━━━3◀━━┛           ┗━━━3◀━━┛         ┗━━━3◀━━┛   │
    /// │       ▲                                     ▲       │
    /// 0───────┘                                     └───────0
    /// ```
    ///
    /// For each of these starting points:
    /// - `1,3` and `3,1,2` are considered _different_ cycles because we need to remove the `3─▶1` edge to break the `1,3` cycle and remove the `2─▶3` to break the `3,1,2` cycle.
    /// - `1,3` and `2,3,1` are considered _different_ cycles because we need to remove the `3─▶1` edge to break the `1,3` cycle and remove the `1─▶2` to break the `2,3,1` cycle.
    /// - `3,1` and `2,3,1` are considered _different_ cycles because we need to remove the `1─▶3` edge to break the `3,1` cycle and remove the `1─▶2` to break the `2,3,1` cycle.
    ///
    /// ```
    ///                      0──────────┐
    ///                      │          ▼
    ///     ┏━━━━━━▶2        │  ┌ ─ ─ ─ 2         ┌ ─ ─ ─ 2◀──┐
    ///     ┃       ╵        │  ╷       ┃         ╷       ┃   │
    /// ┌──▶1━━━┓   ╵        └─▶1━━━┓   ┃         1 ─ ┐   ┃   │
    /// │   ╵   ▼   ╵           ╵   ▼   ┃         ▲   ╷   ┃   │
    /// │   └ ─ 3 ─ ┘           └ ─ 3◀━━┛         ┗━━━3◀━━┛   │
    /// │       ▲                                     ▲       │
    /// 0───────┘                                     └───────0
    /// ```
    ///
    /// If you remove the edge from `cycle.last` to `cycle.first` for each cycle in the returned list, you'll break all the cycles from _that_ starting point in the graph.
    /// This _doesn't_ guarantee that the graph is free of cycles from other starting points.
    ///
    /// ## Example: Rotation of cycle
    ///
    /// Consider this cyclic subgraph which can be entered from different directions:
    /// ```
    /// ┌────▶1━━━━▶2
    /// │     ▲     ┃
    /// │     ┃     ┃
    /// 0────▶3◀━━━━┛
    /// ```
    ///
    /// With two ways to enter the cycle, it will encounter both the `1,2,3` and the `3,1,2` cycle.
    /// These are considered the _same_ cycle because removing the `3─▶1` edge breaks both cycles.
    /// ```
    /// ┌────▶1━━━━▶2
    /// │     ╷     ┃
    /// │     ╷     ┃
    /// 0────▶3◀━━━━┛
    /// ```
    func cycles(from startingPoint: Node) -> [Path] {
        var cycles = [Path]()
        
        for case let (path, _, cycleStartIndex?) in accumulatingPaths(from: startingPoint) {
            let cycle = path[cycleStartIndex...]
            guard !cycles.contains(where: { areSameCycle(cycle, $0) }) else {
                continue
            }
            cycles.append(Array(cycle))
        }
        
        return cycles
    }
    
    private func areSameCycle(_ lhs: Path.SubSequence, _ rhs: Path) -> Bool {
        // Check if the cycles have the same start and end points.
        // A cycle has to contain at least one node, so it's always safe to unwrap 'first' and 'last'.
        if lhs.first! == rhs.first!, lhs.last! == rhs.last! {
            return true
        }
        
        // Check if the cycles are rotations of each other
        if lhs.count == rhs.count {
            let rhsStart = rhs.first!
            
            return (lhs + lhs)                   // Repeat one of the cycles once
                .drop(while: { $0 != rhsStart }) // Align it with the other cycle by removing its leading nodes
                .starts(with: rhs)               // See if the cycles match
        }
        // The two cycles are different.
        return false
    }
}
