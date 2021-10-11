/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// A semantic object is an abstract element with children which also are semantic objects.
///
/// The children of one semantic object doesn't need to be the same type as their parent or even the same as each other.
/// This allows semantic objects to describe a hierarchy of information that can be visited and altered in a structured manner using a ``SemanticVisitor``.
///
/// Semantic objects are used to model the in-memory representation of documentation. Some key examples are ``Article``, ``Symbol``,
/// and directives such as ``Tutorial``, ``Chapter`` and ``Volume``.
open class Semantic: Equatable {
    
    /// The logical children of the semantic object.
    ///
    /// - Note: Attribute-like data, such as what you might find in an XML node's attributes, should not be considered children.
    var children: [Semantic] {
        return []
    }
    
    /// Creates a new semantic object.
    public init() {}
    
    /// Inform the ``SemanticVisitor`` to visit this node.
    ///
    /// - Note: It is not necessary to call this method directly. The default implementation for ``SemanticVisitor`` will call ``accept(_:)`` on this node.
    public func accept<V: SemanticVisitor>(_ visitor: inout V) -> V.Result {
        return visitor.visit(self)
    }
    
    /// Visit the semantic object and all its children—and their children—to construct a string representation of the semantic hierarchy.
    ///
    /// - Returns: A string representation of the semantic hierarchy.
    public func dump() -> String {
        var dumper = SemanticTreeDumper()
        dumper.visit(self)
        return dumper.result
    }
    
    /// General purpose analyses that can apply to many directives.
    public enum Analyses {
        // Files that add analyses that apply to many directives should extend this type so that they're accessible
        // as `Semantic.Analysis.NameOfGeneralAnalysis`. Place these files in the "General Purpose Analyses" folder.
    }
    
    /// Returns whether or not two semantics values are equal.
    ///
    /// - Parameters:
    ///   - lhs: A semantic to compare.
    ///   - rhs: Another semantic to compare.
    /// - Returns: Whether or not the two semantics values are equal.
    public static func ==(lhs: Semantic, rhs: Semantic) -> Bool {
        return lhs === rhs
    }
}
