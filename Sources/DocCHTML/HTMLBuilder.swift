/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

@resultBuilder
package struct HTMLBuilder {
    
    // Support passing HTMLNode values as expressions
    package static func buildExpression(_ expression: consuming HTMLNode) -> HTMLNode {
        expression
    }
    
    // Support passing strings as expressions
    package static func buildExpression(_ text: consuming String) -> HTMLNode {
        .text(consume text)
    }
    
    // Support `if` statements without an `else` statement.
    package static func buildOptional(_ component: consuming HTMLNode?) -> HTMLNode { component ?? .text("") }

    // Support `if-else` and `switch` statements.
    package static func buildEither(first  component: consuming HTMLNode) -> HTMLNode { component }
    package static func buildEither(second component: consuming HTMLNode) -> HTMLNode { component }

    // Support `for-in` loops
    package typealias Loop = [ [HTMLNode] ]
    package static func buildArray(_ components: consuming Loop) -> Loop {
        components
    }
    
    // This implementation makes a compromise between expressivity and performance.
    // It can be difficult to achieve good performance in a result builder that builds an array and also supports loops.
    //
    // The naive implementation makes every component an array and flat-maps the block to create the array result:
    //
    //     static func buildExpression(_ expression: HTMLNode) -> [HTMLNode] { [expression] }
    //     package static func buildBlock(_ components: [HTMLNode]...) -> [HTMLNode] { components.flatMap { $0 } }
    //
    // Such an implementation is short but can be a bit inefficient, hiding `[ [a], [b], [c] ].flatMap { $0 }` behind:
    //
    //     let _e1 = Builder.buildExpression(expr1)
    //     let _e2 = Builder.buildExpression(expr2)
    //     let _e3 = Builder.buildExpression(expr3)
    //     return Builder.buildBlock(_e1, _e2, _e3)
    //
    // In some measurements, depending on the size of the blocks and ratio between basic blocks and loops,
    // this can be 3-4 times slower than direct creation / manipulation of an array.
    //
    // Using `buildPartialBlock(...)`, introduced in SE-0348, one can improve performance over the naive implementation by about 30-35%.
    // By also leveraging a "partial" component that doesn't wrap individual expressions in arrays and using `buildFinalResult(...)` to create the final array,
    // one can push this another 15–20%, resulting in roughly a 50% improvement over the naive implementation, but still 2 times slower than direct array creation.
    // The resulting implementation becomes a series of `append()` calls, hiding behind:
    //
    //    let _e1 = Builder.buildExpression(expr1)
    //    let _e2 = Builder.buildExpression(expr2)
    //    let _e3 = Builder.buildExpression(expr3)
    //    let _v1 = Builder.buildPartialBlock(first: _e1)
    //    let _v2 = Builder.buildPartialBlock(accumulated: _v1, next: _e2)
    //    let _v3 = Builder.buildPartialBlock(accumulated: _v2, next: _e3)
    //    return Builder.buildFinalResult(_v3)
    //
    // If we _didn't_ need to support loops in the builder, a naive implementation like below would come quite close to the performance of direct array creation:
    //
    //     static func buildExpression(_ expression: HTMLNode) -> HTMLNode { expression }
    //     package static func buildBlock(_ components: HTMLNode...) -> [HTMLNode] { components }
    //
    // Because this builder isn't intended to be a general purpose library, we can put some restrictions on how loops can be used.
    // Specifically, by only supporting a single loop in a given scope, with some number of non-loops before and after,
    // we can implement specific overloads for each location that the loop may appear in the block (see below).
    // This offers a significant improvement in performance that's about 2.2 times faster than the initial implementation and only 1.15 times slower than direct array creation.
    
    // Support any number of non-loop expressions / components.
    package static func buildBlock(_ rest: HTMLNode...) -> [HTMLNode] {
        rest
    }
    
    // The ten overloads below adds support for exactly one loop within a scope,
    // when preceded by 0 through 9 non-loop expressions/components and followed by any number of non-loop expressions/components.
    //
    // If we find more cases that we need to build but aren't supported by this, we can add more `buildBlock` overloads below.
    
    package static func buildBlock(_ loop: Loop, _ rest: HTMLNode...) -> [HTMLNode] {
        var result: [HTMLNode] = []
        for elements in loop {
            result.append(contentsOf: elements)
        }
        result.append(contentsOf: rest)
        return result
    }

    package static func buildBlock(_ node0: HTMLNode, _ loop: Loop, _ rest: HTMLNode...) -> [HTMLNode] {
        var result: [HTMLNode] = [node0]
        for elements in loop {
            result.append(contentsOf: elements)
        }
        result.append(contentsOf: rest)
        return result
    }

    package static func buildBlock(_ node0: HTMLNode, _ node1: HTMLNode, _ loop: Loop, _ rest: HTMLNode...) -> [HTMLNode] {
        var result: [HTMLNode] = [node0, node1]
        for elements in loop {
            result.append(contentsOf: elements)
        }
        result.append(contentsOf: rest)
        return result
    }

    package static func buildBlock(_ node0: HTMLNode, _ node1: HTMLNode, _ node2: HTMLNode, _ loop: Loop, _ rest: HTMLNode...) -> [HTMLNode] {
        var result: [HTMLNode] = [node0, node1, node2]
        for elements in loop {
            result.append(contentsOf: elements)
        }
        result.append(contentsOf: rest)
        return result
    }

    package static func buildBlock(_ node0: HTMLNode, _ node1: HTMLNode, _ node2: HTMLNode, _ node3: HTMLNode, _ loop: Loop, _ rest: HTMLNode...) -> [HTMLNode] {
        var result: [HTMLNode] = [node0, node1, node2, node3]
        for elements in loop {
            result.append(contentsOf: elements)
        }
        result.append(contentsOf: rest)
        return result
    }

    package static func buildBlock(_ node0: HTMLNode, _ node1: HTMLNode, _ node2: HTMLNode, _ node3: HTMLNode, _ node4: HTMLNode, _ loop: Loop, _ rest: HTMLNode...) -> [HTMLNode] {
        var result: [HTMLNode] = [node0, node1, node2, node3, node4]
        for elements in loop {
            result.append(contentsOf: elements)
        }
        result.append(contentsOf: rest)
        return result
    }

    package static func buildBlock(_ node0: HTMLNode, _ node1: HTMLNode, _ node2: HTMLNode, _ node3: HTMLNode, _ node4: HTMLNode, _ node5: HTMLNode, _ loop: Loop, _ rest: HTMLNode...) -> [HTMLNode] {
        var result: [HTMLNode] = [node0, node1, node2, node3, node4, node5]
        for elements in loop {
            result.append(contentsOf: elements)
        }
        result.append(contentsOf: rest)
        return result
    }

    package static func buildBlock(_ node0: HTMLNode, _ node1: HTMLNode, _ node2: HTMLNode, _ node3: HTMLNode, _ node4: HTMLNode, _ node5: HTMLNode, _ node6: HTMLNode, _ loop: Loop, _ rest: HTMLNode...) -> [HTMLNode] {
        var result: [HTMLNode] = [node0, node1, node2, node3, node4, node5, node6]
        for elements in loop {
            result.append(contentsOf: elements)
        }
        result.append(contentsOf: rest)
        return result
    }

    package static func buildBlock(_ node0: HTMLNode, _ node1: HTMLNode, _ node2: HTMLNode, _ node3: HTMLNode, _ node4: HTMLNode, _ node5: HTMLNode, _ node6: HTMLNode, _ node7: HTMLNode, _ loop: Loop, _ rest: HTMLNode...) -> [HTMLNode] {
        var result: [HTMLNode] = [node0, node1, node2, node3, node4, node5, node6, node7]
        for elements in loop {
            result.append(contentsOf: elements)
        }
        result.append(contentsOf: rest)
        return result
    }

    package static func buildBlock(_ node0: HTMLNode, _ node1: HTMLNode, _ node2: HTMLNode, _ node3: HTMLNode, _ node4: HTMLNode, _ node5: HTMLNode, _ node6: HTMLNode, _ node7: HTMLNode, _ node8: HTMLNode, _ loop: Loop, _ rest: HTMLNode...) -> [HTMLNode] {
        var result: [HTMLNode] = [node0, node1, node2, node3, node4, node5, node6, node7, node8]
        for elements in loop {
            result.append(contentsOf: elements)
        }
        result.append(contentsOf: rest)
        return result
    }
}
