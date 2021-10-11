/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SymbolKit

/// An intermediate model to group together an implementation reference, its parent, and a fallback name.
public struct Implementation: Hashable {
    /// The reference to the default implementation.
    public let reference: TopicReference
    /// The name of the parent type of the referenced symbol, if available.
    public let parent: String?
    /// The fallback name of the parent type of the referenced symbol, if available.
    public let fallbackName: String?
}

/// A group that represents a list of a protocol-requirement implementations.
public struct ImplementationsGroup {
    /// The group title.
    public let heading: String
    /// The references to the implementations in the group.
    public let references: [TopicReference]
}

/// A section that contains default implementations of a protocol-requirement, for example a property or a method.
///
/// Protocol extensions might provide a default implementation of a required property or a method,
/// that can optionally be available under certain conditions.
///
/// For example the `AdditiveArithmetic` protocol from the Swift Standard Library requires conforming
/// types to have the notion of zero through a requirement of a static-property member called `zero`.
/// However, if your type conforming to `AdditiveArithmetic` represents an integer and adopts `ExpressibleByIntegerLiteral`
/// it will get a default `zero` implementation, because the standard library knows how to represent
/// zero in integer arithmetic.
///
/// To aid documentation discoverability, `DefaultImplementationsSection` lists all default implementations of a
/// certain requirement, grouped by the type that provides the implementations.
public struct DefaultImplementationsSection {
    var targetFallbacks = [TopicReference: String]()
    
    /// A grouped list of the default implementations.
    public var groups: [ImplementationsGroup] {
        let grouped = Dictionary(grouping: implementations) { imp -> String in
            if let parent = imp.parent {
                // Group by parent name
                return parent
            } else if let fallbackName = imp.fallbackName {
                // Use a fallback name
                return fallbackName
            } else {
                // Use an unnamed bucket
                return ""
            }
        }
        return grouped.keys.sorted()
            .compactMap { name in
                let groupName = name.isEmpty ? "" : "\(name) "
                
                return ImplementationsGroup(
                    heading: "\(groupName)Implementations",
                    references: grouped[name]!.map { $0.reference }
                )
            }
    }
    
    /// A plain list of the default implementations.
    public private(set) var implementations = Set<Implementation>()
    
    mutating func addImplementation(_ implementation: Implementation, fallbackTarget: (reference: TopicReference, title: String)? = nil) {
        if let fallbackTarget = fallbackTarget {
            targetFallbacks[fallbackTarget.reference] = fallbackTarget.title
        }
        implementations.insert(implementation)
    }
}
