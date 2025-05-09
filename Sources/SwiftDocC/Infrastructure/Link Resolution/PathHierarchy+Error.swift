/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2023-2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import struct Markdown.SourceRange
import struct Markdown.SourceLocation
import SymbolKit

extension PathHierarchy {
    /// An error finding an entry in the path hierarchy.
    enum Error: Swift.Error {
        /// Information about the portion of a link that could be found.
        ///
        /// Includes information about:
        /// - The node that was found
        /// - The portion of the path up and including to the found node and its trailing path separator.
        typealias PartialResult = (node: Node, pathPrefix: Substring)
        
        /// No element was found at the beginning of the path.
        ///
        /// Includes information about:
        /// - The portion of the path up to the first path component.
        /// - The remaining portion of the path. This may be empty
        /// - A list of the names for the top level elements.
        case notFound(pathPrefix: Substring, remaining: [PathComponent], availableChildren: Set<String>)
        
        /// No element was found at the beginning of an absolute path.
        ///
        /// Includes information about:
        /// - The portion of the path up to the first path component.
        /// - A list of the names for the available modules.
        case moduleNotFound(pathPrefix: Substring, remaining: [PathComponent], availableChildren: Set<String>)
        
        /// Matched node does not correspond to a documentation page.
        ///
        /// For partial symbol graph files, sometimes sparse nodes that don't correspond to known documentation need to be created to form a hierarchy. These nodes are not findable.
        case unfindableMatch(Node)
        
        /// A symbol link found a non-symbol match.
        ///
        /// Includes information about:
        /// - The path to the non-symbol match.
        case nonSymbolMatchForSymbolLink(path: String)
        
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
    /// Creates a value with structured information that can be used to present diagnostics about the error.
    /// - Parameters:
    ///   - fullNameOfNode: A closure that determines the full name of a node, to be displayed in collision diagnostics to precisely identify symbols and other pages.
    /// - Note: `Replacement`s produced by this function use `SourceLocation`s relative to the link text excluding its surrounding syntax.
    func makeTopicReferenceResolutionErrorInfo(fullNameOfNode: (PathHierarchy.Node) -> String) -> TopicReferenceResolutionErrorInfo {
        // Both `.unknownDisambiguation(...)` and `.lookupCollisions(...)` create solutions on the same format from the same information.
        // This is defined inline because it captures `fullNameOfNode`.
        func makeCollisionSolutions(
            from candidates: [(node: PathHierarchy.Node, disambiguation: String)],
            nextPathComponent: PathHierarchy.PathComponent,
            partialResultPrefix: Substring
        ) -> (
            pathPrefix: Substring,
            foundDisambiguation: Substring,
            solutions: [Solution]
        ) {
            guard let symbolName = candidates.first?.node.name else {
                return (partialResultPrefix, "", [])
            }
            let foundDisambiguation = nextPathComponent.full.dropFirst(symbolName.count)
            let pathPrefix: Substring = partialResultPrefix + nextPathComponent.full.prefix(symbolName.count)
            
            let replacementRange = SourceRange.makeRelativeRange(startColumn: pathPrefix.count, length: foundDisambiguation.count)
            
            let solutions: [Solution] = candidates
                .map { (fullName: fullNameOfNode($0.node), disambiguation: $0.disambiguation) }
                .sorted { lhs, rhs in
                    // Sort by name first and disambiguation second
                    if lhs.fullName == rhs.fullName {
                        return lhs.disambiguation < rhs.disambiguation
                    }
                    return lhs.fullName < rhs.fullName
                }
                .map { (fullName: String, suggestedDisambiguation: String) -> Solution in
                    // In contexts that display the solution message on a single line by removing newlines, this extra whitespace makes it look correct ─────────────╮
                    //                                                                                                                                               ▼
                    return Solution(summary: "\(Self.replacementOperationDescription(from: foundDisambiguation, to: suggestedDisambiguation, forCollision: true)) for \n\(fullName.singleQuoted)", replacements: [
                        Replacement(range: replacementRange, replacement: suggestedDisambiguation)
                    ])
                }
            return (pathPrefix, foundDisambiguation, solutions)
        }
        
        switch self {
        case .moduleNotFound(pathPrefix: let pathPrefix, remaining: let remaining, availableChildren: let availableChildren):
            let firstPathComponent = remaining.first! // This would be a .notFound error if the remaining components were empty.
            
            let replacementRange = SourceRange.makeRelativeRange(startColumn: pathPrefix.count, length: firstPathComponent.full.count)
            let nearMisses = NearMiss.bestMatches(for: availableChildren, against: String(firstPathComponent.name))
            let solutions = nearMisses.map { candidate in
                Solution(summary: "\(Self.replacementOperationDescription(from: firstPathComponent.full, to: candidate))", replacements: [
                    Replacement(range: replacementRange, replacement: candidate)
                ])
            }
            
            return TopicReferenceResolutionErrorInfo("""
                No module named \(firstPathComponent.full.singleQuoted)
                """,
                solutions: solutions
            )
            
        case .notFound(pathPrefix: let pathPrefix, remaining: let remaining, availableChildren: let availableChildren):
            guard let firstPathComponent = remaining.first else {
                return TopicReferenceResolutionErrorInfo(
                    "No local documentation matches this reference"
                )
            }
            
            let replacementRange = SourceRange.makeRelativeRange(startColumn: pathPrefix.count, length: firstPathComponent.full.count)
            let nearMisses = NearMiss.bestMatches(for: availableChildren, against: String(firstPathComponent.name))
            let solutions = nearMisses.map { candidate in
                Solution(summary: "\(Self.replacementOperationDescription(from: firstPathComponent.full, to: candidate))", replacements: [
                    Replacement(range: replacementRange, replacement: candidate)
                ])
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

        case .nonSymbolMatchForSymbolLink(path: let path):
            return TopicReferenceResolutionErrorInfo("Symbol links can only resolve symbols", solutions: [
                Solution(summary: "Use a '<doc:>' style reference.", replacements: [
                    // the SourceRange points to the opening double-backtick
                    Replacement(range: .makeRelativeRange(startColumn: -2, endColumn: 0), replacement: "<doc:"),
                    // the SourceRange points to the closing double-backtick
                    Replacement(range: .makeRelativeRange(startColumn: path.count, endColumn: path.count+2), replacement: ">"),
                ])
            ])
            
        case .unknownDisambiguation(partialResult: let partialResult, remaining: let remaining, candidates: let candidates):
            let nextPathComponent = remaining.first!
            let (pathPrefix, foundDisambiguation, solutions) = makeCollisionSolutions(from: candidates, nextPathComponent: nextPathComponent, partialResultPrefix: partialResult.pathPrefix)
            
            return TopicReferenceResolutionErrorInfo("""
                \(foundDisambiguation.dropFirst().singleQuoted) isn't a disambiguation for \(nextPathComponent.name.singleQuoted) at \(partialResult.node.pathWithoutDisambiguation().singleQuoted)
                """,
                solutions: solutions,
                rangeAdjustment: .makeRelativeRange(startColumn: pathPrefix.count, length: foundDisambiguation.count)
            )
            
        case .unknownName(partialResult: let partialResult, remaining: let remaining, availableChildren: let availableChildren):
            let nextPathComponent = remaining.first!
            let nearMisses = NearMiss.bestMatches(for: availableChildren, against: String(nextPathComponent.name))
            
            // Use the authored disambiguation to try and reduce the possible near misses. For example, if the link was disambiguated with `-struct` we should
            // only make suggestions for similarly spelled structs.
            let filteredNearMisses = nearMisses.filter { name in
                (try? partialResult.node.children[name]?.find(nextPathComponent.disambiguation)) != nil
            }

            let pathPrefix = partialResult.pathPrefix
            let solutions: [Solution]
            if filteredNearMisses.isEmpty {
                // If there are no near-misses where the authored disambiguation narrow down the results, replace the full path component
                let replacementRange = SourceRange.makeRelativeRange(startColumn: pathPrefix.count, length: nextPathComponent.full.count)
                solutions = nearMisses.map { candidate in
                    Solution(summary: "\(Self.replacementOperationDescription(from: nextPathComponent.full, to: candidate))", replacements: [
                        Replacement(range: replacementRange, replacement: candidate)
                    ])
                }
            } else {
                // If the authored disambiguation narrows down the possible near-misses, only replace the name part of the path component
                let replacementRange = SourceRange.makeRelativeRange(startColumn: pathPrefix.count, length: nextPathComponent.name.count)
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
                rangeAdjustment: .makeRelativeRange(startColumn: pathPrefix.count, length: nextPathComponent.full.count)
            )
            
        case .lookupCollision(partialResult: let partialResult, remaining: let remaining, collisions: let collisions):
            let nextPathComponent = remaining.first!
            let (pathPrefix, foundDisambiguation, solutions) = makeCollisionSolutions(
                from: collisions,
                nextPathComponent: nextPathComponent,
                partialResultPrefix: partialResult.pathPrefix)

            let rangeAdjustment: SourceRange
            if !foundDisambiguation.isEmpty {
                rangeAdjustment = .makeRelativeRange(
                    startColumn: pathPrefix.count - foundDisambiguation.count,
                    length: foundDisambiguation.count)
            } else {
                rangeAdjustment = .makeRelativeRange(
                    startColumn: pathPrefix.count - nextPathComponent.full.count,
                    length: nextPathComponent.full.count)
            }

            return TopicReferenceResolutionErrorInfo("""
                \(nextPathComponent.full.singleQuoted) is ambiguous at \(partialResult.node.pathWithoutDisambiguation().singleQuoted)
                """,
                solutions: solutions,
                rangeAdjustment: rangeAdjustment
            )
        }
    }
    
    private static func replacementOperationDescription(from: some StringProtocol, to: some StringProtocol, forCollision: Bool = false) -> String {
        if from.isEmpty {
            return "Insert \(to.singleQuoted)"
        }
        if to.isEmpty {
            return "Remove \(from.singleQuoted)"
        }
        
        guard forCollision else {
            return "Replace \(from.singleQuoted) with \(to.singleQuoted)"
        }
        
        if to.hasPrefix("->") || from.hasPrefix("->") {
            // If either the "to" or "from" descriptions are a return type disambiguation, include the full arrow for both.
            // Only a ">" prefix doesn't read as an "arrow", and it looks incorrect when only of the descriptions have a "-" prefix.
            return "Replace \(from.singleQuoted) with \(to.singleQuoted)"
        }
        // For other replacement descriptions, drop the leading "-" to focus on the text that's different.
        return "Replace \(from.dropFirst().singleQuoted) with \(to.dropFirst().singleQuoted)"
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
}

private extension SourceRange {
    static func makeRelativeRange(startColumn: Int, endColumn: Int) -> SourceRange {
        return SourceLocation(line: 0, column: startColumn, source: nil) ..< SourceLocation(line: 0, column: endColumn, source: nil)
    }
    
    static func makeRelativeRange(startColumn: Int, length: Int) -> SourceRange {
        return .makeRelativeRange(startColumn: startColumn, endColumn: startColumn + length)
    }
}
