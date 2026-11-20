/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

@resultBuilder
package struct HTMLBuilder {
    // Note: this is the most naive result builder implementation for array components.
    // Because it wraps every element in an array and flat-maps them together it is a bit inefficient. 
    // Fortunately, we can improve the builder performance later without breaking any API.
    
    package typealias Component = [HTMLNode]
    
    package static func buildBlock(_ components: Component...) -> Component {
        components.flatMap { $0 }
    }
    
    /// Support HTML nodes as expressions
    package static func buildExpression(_ expression: HTMLNode) -> Component {
        [expression]
    }
    
    /// Support strings as expressions
    package static func buildExpression(_ text: String) -> Component {
        [.text(text)]
    }
    
    /// Support arrays as expressions
    package static func buildExpression(_ expression: [HTMLNode]) -> Component {
        expression
    }
    
    /// Support `if` statements without an `else` statement.
    package static func buildOptional(_ component: Component?) -> Component { component ?? [] }
    
    /// Support `if-else` and `switch` statements.
    package static func buildEither(first  component: Component) -> Component { component }
    package static func buildEither(second component: Component) -> Component { component }
    
    /// Support `for-in` loops
    package static func buildArray(_ components: [Component]) -> Component {
        components.flatMap { $0 }
    }
}
