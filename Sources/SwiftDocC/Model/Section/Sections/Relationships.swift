/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown
import SymbolKit

extension Relationship {
    /// Converted from ``Relationship`` to `RelationshipsGroup.Kind`.
    var groupKind: RelationshipsGroup.Kind? {
        switch self {
        case .conformsTo: return .conformsTo
        case .conformingType: return .conformingTypes
        case .inheritsFrom: return .inheritsFrom
        case .inheritedBy: return .inheritedBy
        default: return nil
        }
    }
}

/// A group of symbol relationships.
///
/// Group together references to multiple symbols having
/// the same `Kind` of relationship to the current symbol.
/// One `RelationshipsGroup` lists all parent symbols
/// of the current symbol and provides its sorting index and
/// a presentation-friendly title for the group to a renderer.
///
/// For example the `Collection` protocol from the Swift Standard Library
/// is inherited by the following group of protocols:
///
/// ### Conforming Types
/// * `BidirectionalCollection`
/// * `LazyCollectionProtocol`
/// * `MutableCollection`
/// * `RangeReplaceableCollection`
public struct RelationshipsGroup {
    
    /// Possible symbol relationships.
    public enum Kind: String {
        /// One or more protocols to which a type conforms.
        case conformsTo
        
        /// One or more types that conform to a protocol.
        case conformingTypes
        
        /// One or more types that are parents of the symbol.
        case inheritsFrom
        
        /// One or more types that are children of the symbol.
        case inheritedBy
    }
    
    /// Creates a new relationship group of the given kind, and with the given symbols.
    public init(kind: Kind, destinations: [TopicReference]) {
        self.kind = kind
        self.destinations = Set(destinations)
    }
    
    let kind: Kind
    
    /// Rendering of the group's title as a heading.
    var heading: Heading {
        return Heading(level: 3, Text(sectionTitle))
    }
    
    fileprivate(set) var destinations = Set<TopicReference>()
    
    /// The plain-text group title.
    var sectionTitle: String {
        switch kind {
        case .conformsTo: return "Conforms To"
        case .conformingTypes: return "Conforming Types"
        case .inheritsFrom: return "Inherits From"
        case .inheritedBy: return "Inherited By"
        }
    }
    
    /// A sorting order for the group.
    var sectionOrder: Int {
        switch kind {
        case .inheritsFrom: return 1
        case .inheritedBy: return 2
        case .conformsTo, .conformingTypes: return 3
        }
    }
}

extension TopicReference {
    var url: URL? {
        switch self {
        case .resolved(.success(let resolved)):
            return resolved.url
        case .unresolved(let unresolved), .resolved(.failure(let unresolved, _)):
            return unresolved.topicURL.components.url
        }
    }
}

/// A section that contains symbol-relationship groups.
///
/// This section contains all the different kinds of relationships a symbol might
/// have. For example a protocol might have an "Inherits From" section to link to
/// a parent protocol, and also a "Conforming Types" section to list all implementation
/// types for the this protocol.
public struct RelationshipsSection {
    public static let title = "Relationships"
    
    /// All relationship groups in the section.
    public var groups = [RelationshipsGroup]()
    
    /// Any fallback symbol names for symbols when available.
    var targetFallbacks = [TopicReference: String]()
    
    /// Generics constraints to attach to a destination
    var constraints = [TopicReference: [SymbolGraph.Symbol.Swift.GenericConstraint]]()
    
    /// Adds a new relationship to the given symbol reference.
    /// - Parameters:
    ///   - reference: A topic reference for the target symbol of the relationship.
    ///   - groupKind: One of the pre-defined relationship kinds.
    mutating func addReference(reference: TopicReference, groupKind: RelationshipsGroup.Kind) {
        if let index = groups.firstIndex(where: { group -> Bool in
            group.kind == groupKind
        }) {
            var group = groups[index]
            group.destinations.insert(reference)
            groups[index] = group
        } else {
            let group = RelationshipsGroup(
                kind: groupKind,
                destinations: [reference]
            )
            groups.append(group)
        }
    }
    
    /// Adds a new relationship to the section.
    mutating func addRelationship(_ relationship: Relationship) {
        switch relationship {
        case let .conformsTo(reference, constraints),
             let .conformingType(reference, constraints):
            
            addReference(reference: reference, groupKind: relationship.groupKind!)
            self.constraints[reference] = constraints
            
        case let .inheritsFrom(reference),
             let .inheritedBy(reference):
            
            addReference(reference: reference, groupKind: relationship.groupKind!)
            
        default: break
        }
    }
}
