/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SymbolKit

/// A relationship to a node in the topic graph.
public enum Relationship {
    /// A conformance to a protocol, under optional constraints.
    case conformsTo(TopicReference, [SymbolGraph.Symbol.Swift.GenericConstraint]?)
    /// A type that conforms to the current node, under optional constraints.
    case conformingType(TopicReference, [SymbolGraph.Symbol.Swift.GenericConstraint]?)
    /// A parent node for the current node.
    case inheritsFrom(TopicReference)
    /// A child node for the current node.
    case inheritedBy(TopicReference)
    /// A protocol requirement of which that the current node is a default implementation.
    case defaultImplementationOf(TopicReference)
    /// A default implementation if the current node is a protocol requirement.
    case defaultImplementation(TopicReference)
    /// A protocol of which the current node is a requirement.
    case requirementOf(TopicReference)
}
