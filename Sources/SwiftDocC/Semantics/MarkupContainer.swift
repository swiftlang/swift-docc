/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Markdown

/// A general purpose `Markup` semantic container.
public final class MarkupContainer: Semantic {
    /// The `Markup` elements in the container.
    public let elements: [Markup]
    
    /// Create an empty `Markup` semantic container.
    public convenience override init() {
        self.init([])
    }
    
    /// Creates a new general-purpose markup container with the given elements.
    ///
    /// - Parameter elements: Zero or more markup elements.
    public init(_ elements: Markup...) {
        self.elements = elements
    }
    
    /// Creates a new general-purpose markup container with the elements of a sequence.
    ///
    /// - Parameter elements: A sequence of markup elements.
    public init<S: Sequence>(_ elements: S) where S.Element: Markup {
        self.elements = Array(elements)
    }

    /// Creates a new general-purpose markup container with the elements of a sequence.
    ///
    /// - Parameter elements: A sequence of markup elements.
    public init<S: Sequence>(_ elements: S) where S.Element == Markup {
        self.elements = Array(elements)
    }
        
    public override func accept<V: SemanticVisitor>(_ visitor: inout V) -> V.Result {
        return visitor.visitMarkupContainer(self)
    }
}

extension MarkupContainer: RandomAccessCollection {
    public subscript(position: Array<Markup>.Index) -> Markup {
        return elements[position]
    }
    
    public var startIndex: Array<Markup>.Index {
        return elements.startIndex
    }
    
    public var endIndex: Array<Markup>.Index {
        return elements.endIndex
    }
}
