/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2023 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import struct Markdown.SourceRange
import struct Markdown.SourceLocation
import SymbolKit

// The path hierarchy implementation is divided into different files for different responsibilities.
// This file defines error messages and suggested solutions for user facing diagnostics.

extension PathHierarchy {
    /// An error finding an entry in the path hierarchy.
    enum Error: Swift.Error {
        /// Information about the portion of a link that could be found.
        ///
        /// Includes information about:
        /// - The node that was found
        /// - The remaining portion of the path.
        typealias PartialResult = (node: Node, path: [PathComponent])
        
        /// No element was found at the beginning of the path.
        ///
        /// Includes information about:
        /// - The remaining portion of the path. This may be empty
        /// - A list of the names for the top level elements.
        case notFound(remaining: [PathComponent], availableChildren: Set<String>)
        
        /// Matched node does not correspond to a documentation page.
        ///
        /// For partial symbol graph files, sometimes sparse nodes that don't correspond to known documentation need to be created to form a hierarchy. These nodes are not findable.
        case unfindableMatch(Node)
        
        /// A symbol link found a non-symbol match.
        case nonSymbolMatchForSymbolLink
        
        /// Encountered an unknown disambiguation for a found node.
        ///
        /// Includes information about:
        /// - The partial result for as much of the path that could be found.
        /// - The remaining portion of the path.
        /// - A list of possible matches paired with the disambiguation suffixes needed to distinguish them.
        case unknownDisambiguation(partialResult: PartialResult, remaining: [PathComponent], candidates: [(node: Node, disambiguation: String)])
        
        /// Encountered an unknown name in the path.
        ///
        /// Includes information about:
        /// - The partial result for as much of the path that could be found.
        /// - The remaining portion of the path.
        /// - A list of the names for the children of the partial result.
        case unknownName(partialResult: PartialResult, remaining: [PathComponent], availableChildren: Set<String>)
        
        /// Multiple matches are found partway through the path.
        ///
        /// Includes information about:
        /// - The partial result for as much of the path that could be found unambiguously.
        /// - The remaining portion of the path.
        /// - A list of possible matches paired with the disambiguation suffixes needed to distinguish them.
        case lookupCollision(partialResult: PartialResult, remaining: [PathComponent], collisions: [(node: Node, disambiguation: String)])
    }
}

extension PathHierarchy.Error {
    /// Generate a ``TopicReferenceResolutionError`` from this error using the given `context` and `originalReference`.
    ///
    /// The resulting ``TopicReferenceResolutionError`` is human-readable and provides helpful solutions.
    ///
    /// - Parameters:
    ///     - context: The ``DocumentationContext`` the `originalReference` was resolved in.
    ///     - originalReference: The raw input string that represents the body of the reference that failed to resolve. This string is
    ///     used to calculate the proper replacement-ranges for fixits.
    ///
    /// - Note: `Replacement`s produced by this function use `SourceLocation`s relative to the `originalReference`, i.e. the beginning
    /// of the _body_ of the original reference.
    func asTopicReferenceResolutionErrorInfo(context: DocumentationContext, originalReference: String) -> TopicReferenceResolutionErrorInfo {
        
        // This is defined inline because it captures `context`.
        func collisionIsBefore(_ lhs: (node: PathHierarchy.Node, disambiguation: String), _ rhs: (node: PathHierarchy.Node, disambiguation: String)) -> Bool {
            return lhs.node.fullNameOfValue(context: context) + lhs.disambiguation
                 < rhs.node.fullNameOfValue(context: context) + rhs.disambiguation
        }
        
        switch self {
        case .notFound(remaining: let remaining, availableChildren: let availableChildren):
            guard let firstPathComponent = remaining.first else {
                return TopicReferenceResolutionErrorInfo(
                    "No local documentation matches this reference"
                )
            }
            
            let solutions: [Solution]
            if let pathComponentIndex = originalReference.range(of: firstPathComponent.full) {
                let startColumn = originalReference.distance(from: originalReference.startIndex, to: pathComponentIndex.lowerBound)
                let replacementRange = SourceRange.makeRelativeRange(startColumn: startColumn, length: firstPathComponent.full.count)
                
                let nearMisses = NearMiss.bestMatches(for: availableChildren, against: String(firstPathComponent.name))
                solutions = nearMisses.map { candidate in
                    Solution(summary: "\(Self.replacementOperationDescription(from: firstPathComponent.full, to: candidate))", replacements: [
                        Replacement(range: replacementRange, replacement: candidate)
                    ])
                }
            } else {
                solutions = []
            }
            
            return TopicReferenceResolutionErrorInfo("""
                Can't resolve \(firstPathComponent.full.singleQuoted)
                """,
                solutions: solutions
            )

        case .unfindableMatch(let node):
            return TopicReferenceResolutionErrorInfo("""
                \(node.name.singleQuoted) can't be linked to in a partial documentation build
            """)

        case .nonSymbolMatchForSymbolLink:
            return TopicReferenceResolutionErrorInfo("Symbol links can only resolve symbols", solutions: [
                Solution(summary: "Use a '<doc:>' style reference.", replacements: [
                    // the SourceRange points to the opening double-backtick
                    Replacement(range: .makeRelativeRange(startColumn: -2, endColumn: 0), replacement: "<doc:"),
                    // the SourceRange points to the closing double-backtick
                    Replacement(range: .makeRelativeRange(startColumn: originalReference.count, endColumn: originalReference.count+2), replacement: ">"),
                ])
            ])
            
        case .unknownDisambiguation(partialResult: let partialResult, remaining: let remaining, candidates: let candidates):
            let nextPathComponent = remaining.first!
            var validPrefix = ""
            if !partialResult.path.isEmpty {
                validPrefix += PathHierarchy.joined(partialResult.path) + "/"
            }
            validPrefix += nextPathComponent.name
            
            let disambiguations = nextPathComponent.full.dropFirst(nextPathComponent.name.count)
            let replacementRange = SourceRange.makeRelativeRange(startColumn: validPrefix.count, length: disambiguations.count)
            
            let solutions: [Solution] = candidates
                .sorted(by: collisionIsBefore)
                .map { (node: PathHierarchy.Node, disambiguation: String) -> Solution in
                    let toDisplay = disambiguation.first == ">" ? ("-" + disambiguation) : disambiguation
                    return Solution(summary: "\(Self.replacementOperationDescription(from: disambiguations.dropFirst(), to: toDisplay)) for\n\(node.fullNameOfValue(context: context).singleQuoted)", replacements: [
                        Replacement(range: replacementRange, replacement: "-" + disambiguation)
                    ])
                }
            
            return TopicReferenceResolutionErrorInfo("""
                \(disambiguations.dropFirst().singleQuoted) isn't a disambiguation for \(nextPathComponent.name.singleQuoted) at \(partialResult.node.pathWithoutDisambiguation().singleQuoted)
                """,
                solutions: solutions,
                rangeAdjustment: .makeRelativeRange(startColumn: validPrefix.count, length: disambiguations.count)
            )
            
        case .unknownName(partialResult: let partialResult, remaining: let remaining, availableChildren: let availableChildren):
            let nextPathComponent = remaining.first!
            let nearMisses = NearMiss.bestMatches(for: availableChildren, against: String(nextPathComponent.name))
            
            // Use the authored disambiguation to try and reduce the possible near misses. For example, if the link was disambiguated with `-struct` we should
            // only make suggestions for similarly spelled structs.
            let filteredNearMisses = nearMisses.filter { name in
                (try? partialResult.node.children[name]?.find(nextPathComponent)) != nil
            }

            var validPrefix = ""
            if !partialResult.path.isEmpty {
                validPrefix += PathHierarchy.joined(partialResult.path) + "/"
            }
            let solutions: [Solution]
            if filteredNearMisses.isEmpty {
                // If there are no near-misses where the authored disambiguation narrow down the results, replace the full path component
                let replacementRange = SourceRange.makeRelativeRange(startColumn: validPrefix.count, length: nextPathComponent.full.count)
                solutions = nearMisses.map { candidate in
                    Solution(summary: "\(Self.replacementOperationDescription(from: nextPathComponent.full, to: candidate))", replacements: [
                        Replacement(range: replacementRange, replacement: candidate)
                    ])
                }
            } else {
                // If the authored disambiguation narrows down the possible near-misses, only replace the name part of the path component
                let replacementRange = SourceRange.makeRelativeRange(startColumn: validPrefix.count, length: nextPathComponent.name.count)
                solutions = filteredNearMisses.map { candidate in
                    Solution(summary: "\(Self.replacementOperationDescription(from: nextPathComponent.name, to: candidate))", replacements: [
                        Replacement(range: replacementRange, replacement: candidate)
                    ])
                }
            }
            
            return TopicReferenceResolutionErrorInfo("""
                \(nextPathComponent.full.singleQuoted) doesn't exist at \(partialResult.node.pathWithoutDisambiguation().singleQuoted)
                """,
                solutions: solutions,
                rangeAdjustment: .makeRelativeRange(startColumn: validPrefix.count, length: nextPathComponent.full.count)
            )
            
        case .lookupCollision(partialResult: let partialResult, remaining: let remaining, collisions: let collisions):
            let nextPathComponent = remaining.first!
            
            var validPrefix = ""
            if !partialResult.path.isEmpty {
                validPrefix += PathHierarchy.joined(partialResult.path) + "/"
            }
            validPrefix += nextPathComponent.name

            let disambiguations = nextPathComponent.full.dropFirst(nextPathComponent.name.count)
            let replacementRange = SourceRange.makeRelativeRange(startColumn: validPrefix.count, length: disambiguations.count)
            
            let solutions: [Solution] = collisions.sorted(by: collisionIsBefore).map { (node: PathHierarchy.Node, disambiguation: String) -> Solution in
                let toDisplay = disambiguation.first == ">" ? ("-" + disambiguation) : disambiguation
                return Solution(summary: "\(Self.replacementOperationDescription(from: disambiguations.dropFirst(), to: toDisplay)) for\n\(node.fullNameOfValue(context: context).singleQuoted)", replacements: [
                    Replacement(range: replacementRange, replacement: "-" + disambiguation)
                ])
            }
            
            return TopicReferenceResolutionErrorInfo("""
                \(nextPathComponent.full.singleQuoted) is ambiguous at \(partialResult.node.pathWithoutDisambiguation().singleQuoted)
                """,
                solutions: solutions,
                rangeAdjustment: .makeRelativeRange(startColumn: validPrefix.count - nextPathComponent.full.count, length: nextPathComponent.full.count)
            )
        }
    }
    
    private static func replacementOperationDescription<S1: StringProtocol, S2: StringProtocol>(from: S1, to: S2) -> String {
        if from.isEmpty {
            return "Insert \(to.singleQuoted)"
        }
        if to.isEmpty {
            return "Remove \(from.singleQuoted)"
        }
        return "Replace \(from.singleQuoted) with \(to.singleQuoted)"
    }
}

private extension PathHierarchy.Node {
    /// Creates a path string without any disambiguation.
    ///
    /// > Note: This value is only intended for error messages and other presentation.
    func pathWithoutDisambiguation() -> String {
        var components = [name]
        var node = self
        while let parent = node.parent {
            components.insert(parent.name, at: 0)
            node = parent
        }
        return "/" + components.joined(separator: "/")
    }
    
    /// Determines the full name of a node's value using information from the documentation context.
    ///
    /// > Note: This value is only intended for error messages and other presentation.
    func fullNameOfValue(context: DocumentationContext) -> String {
        guard let identifier = identifier else { return name }
        if let symbol = symbol {
            if let fragments = symbol[mixin: SymbolGraph.Symbol.DeclarationFragments.self]?.declarationFragments {
                return fragments.map(\.spelling).joined().split(whereSeparator: { $0.isWhitespace || $0.isNewline }).joined(separator: " ")
            }
            return context.nodeWithSymbolIdentifier(symbol.identifier.precise)!.name.description
        }
        // This only gets called for PathHierarchy error messages, so hierarchyBasedLinkResolver is never nil.
        let reference = context.hierarchyBasedLinkResolver.resolvedReferenceMap[identifier]!
        if reference.fragment != nil {
            return context.nodeAnchorSections[reference]!.title
        } else {
            return context.documentationCache[reference]!.name.description
        }
    }
}

private extension SourceRange {
    static func makeRelativeRange(startColumn: Int, endColumn: Int) -> SourceRange {
        return SourceLocation(line: 0, column: startColumn, source: nil) ..< SourceLocation(line: 0, column: endColumn, source: nil)
    }
    
    static func makeRelativeRange(startColumn: Int, length: Int) -> SourceRange {
        return .makeRelativeRange(startColumn: startColumn, endColumn: startColumn + length)
    }
}
