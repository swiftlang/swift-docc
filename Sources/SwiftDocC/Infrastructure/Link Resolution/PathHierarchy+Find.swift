/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2023-2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SymbolKit

extension PathHierarchy {
    /// Attempts to find an element in the path hierarchy for a given path relative to another element.
    ///
    /// - Parameters:
    ///   - rawPath: The documentation link path string.
    ///   - parent: An optional identifier for the node in the hierarchy to search relative to.
    ///   - onlyFindSymbols: Whether or not only symbol matches should be found.
    /// - Returns: Returns the unique identifier for the found match or raises an error if no match can be found.
    /// - Throws: Raises a ``PathHierarchy/Error`` if no match can be found.
    func find(path rawPath: String, parent: ResolvedIdentifier? = nil, onlyFindSymbols: Bool) throws -> ResolvedIdentifier {
        let node = try findNode(path: rawPath, parentID: parent, onlyFindSymbols: onlyFindSymbols)
        if node.identifier == nil {
            throw Error.unfindableMatch(node)
        }
        if onlyFindSymbols, node.symbol == nil {
            throw Error.nonSymbolMatchForSymbolLink(path: rawPath[...])
        }
        return node.identifier
    }
    
    private func findNode(path rawPath: String, parentID: ResolvedIdentifier?, onlyFindSymbols: Bool) throws -> Node {
        // The search for a documentation element can be though of as 3 steps:
        // - First, parse the path into structured path components.
        // - Second, find nodes that match the beginning of the path as starting points for the search
        // - Third, traverse the hierarchy from those starting points to search for the node.
        let (path, isAbsolute) = PathParser.parse(path: rawPath)
        guard !path.isEmpty else {
            throw Error.notFound(pathPrefix: rawPath[...], remaining: [], availableChildren: [])
        }
        
        var remaining = path[...]
        
        // If the first path component is "tutorials" or "documentation" then use that information to narrow the search.
        let isKnownTutorialPath      = remaining.first!.full == NodeURLGenerator.Path.tutorialsFolderName
        let isKnownDocumentationPath = remaining.first!.full == NodeURLGenerator.Path.documentationFolderName
        if isKnownDocumentationPath || isKnownTutorialPath {
            // Skip this component since it isn't represented in the path hierarchy.
            remaining.removeFirst()
        }
        
        guard let firstComponent = remaining.first else {
            throw Error.notFound(pathPrefix: rawPath[...], remaining: [], availableChildren: [])
        }
        
        if !onlyFindSymbols {
            // If non-symbol matches are possible there is a fixed order to try resolving the link:
            // Articles match before tutorials which match before the tutorial overview page which match before symbols.
            
            // Non-symbols have a very shallow hierarchy so the simplified search peak at the first few layers and then searches only one subtree once if finds a probable match.
            lookForArticleRoot: if !isKnownTutorialPath {
                if articlesContainer.matches(firstComponent) {
                    if let next = remaining.dropFirst().first {
                        if !articlesContainer.anyChildMatches(next) {
                            break lookForArticleRoot
                        }
                    }
                    return try searchForNode(descendingFrom: articlesContainer, pathComponents: remaining.dropFirst(), onlyFindSymbols: onlyFindSymbols, rawPathForError: rawPath)
                } else if articlesContainer.anyChildMatches(firstComponent) {
                    return try searchForNode(descendingFrom: articlesContainer, pathComponents: remaining, onlyFindSymbols: onlyFindSymbols, rawPathForError: rawPath)
                }
            }
            if !isKnownDocumentationPath {
                if tutorialContainer.matches(firstComponent) {
                    return try searchForNode(descendingFrom: tutorialContainer, pathComponents: remaining.dropFirst(), onlyFindSymbols: onlyFindSymbols, rawPathForError: rawPath)
                } else if tutorialContainer.anyChildMatches(firstComponent)  {
                    return try searchForNode(descendingFrom: tutorialContainer, pathComponents: remaining, onlyFindSymbols: onlyFindSymbols, rawPathForError: rawPath)
                }
                // The parent for tutorial overviews / technologies is "tutorials" which has already been removed above, so no need to check against that name.
                else if tutorialOverviewContainer.anyChildMatches(firstComponent)  {
                    return try searchForNode(descendingFrom: tutorialOverviewContainer, pathComponents: remaining, onlyFindSymbols: onlyFindSymbols, rawPathForError: rawPath)
                }
            }
        }
        
        // A function to avoid repeating the
        func searchForNodeInModules() throws -> Node {
            // Note: This captures `parentID`, `remaining`, and `rawPathForError`.
            if let moduleMatch = modules.first(where: { $0.matches(firstComponent) }) {
                return try searchForNode(descendingFrom: moduleMatch, pathComponents: remaining.dropFirst(), onlyFindSymbols: onlyFindSymbols, rawPathForError: rawPath)
            }
            if modules.count == 1 {
                do {
                    return try searchForNode(descendingFrom: modules.first!, pathComponents: remaining, onlyFindSymbols: onlyFindSymbols, rawPathForError: rawPath)
                } catch let error as PathHierarchy.Error {
                    switch error {
                    case .notFound:
                        // Ignore this error and raise an error about not finding the module instead.
                        break
                    case .unknownName(let partialResult, remaining: _, availableChildren: _):
                        if partialResult.node.symbol?.kind.identifier == .module {
                            // Failed to find the first path component. Ignore this error and raise an error about not finding the module instead.
                            break
                        } else {
                            // Partially resolved the link. Raise the more specific error instead of a module-not-found error.
                            throw error
                        }
                        
                    // These errors are all more specific than a module-not-found error would be.
                    case .unfindableMatch,
                         .moduleNotFound,
                         .nonSymbolMatchForSymbolLink,
                         .unknownDisambiguation,
                         .lookupCollision:
                        throw error
                    }
                }
            }
            let topLevelNames = Set(modules.map(\.name) + [articlesContainer.name, tutorialContainer.name])
            
            if isAbsolute, FeatureFlags.current.isExperimentalLinkHierarchySerializationEnabled {
                throw Error.moduleNotFound(
                    pathPrefix: pathForError(of: rawPath, droppingLast: remaining.count),
                    remaining: Array(remaining),
                    availableChildren: Set(modules.map(\.name))
                )
            } else {
                throw Error.notFound(
                    pathPrefix: pathForError(of: rawPath, droppingLast: remaining.count),
                    remaining: Array(remaining),
                    availableChildren: topLevelNames
                )
            }
        }
        
        // A recursive function to traverse up the path hierarchy searching for the matching node
        func searchForNodeUpTheHierarchy(from startingPoint: Node?, path: ArraySlice<PathComponent>) throws -> Node {
            guard let possibleStartingPoint = startingPoint else {
                // If the search has reached the top of the hierarchy, check the modules as a base case to break the recursion.
                do {
                    return try searchForNodeInModules()
                } catch {
                    // If the node couldn't be found in the modules, search the non-matching parent to achieve a more specific error message
                    if let parentID {
                        return try searchForNode(descendingFrom: lookup[parentID]!, pathComponents: path, onlyFindSymbols: onlyFindSymbols, rawPathForError: rawPath)
                    }
                    throw error
                }
            }
            
            // If the path isn't empty we would have already found a node.
            let firstComponent = path.first!
            
            // Keep track of the inner most error and raise that if no node is found.
            var innerMostError: Swift.Error?
            
            // If the starting point's children match this component, descend the path hierarchy from there.
            if possibleStartingPoint.anyChildMatches(firstComponent) {
                do {
                    return try searchForNode(descendingFrom: possibleStartingPoint, pathComponents: path, onlyFindSymbols: onlyFindSymbols, rawPathForError: rawPath)
                } catch {
                    innerMostError = error
                }
            }
            // It's possible that the component is ambiguous at the parent. Checking if this node matches the first component avoids that ambiguity.
            if possibleStartingPoint.matches(firstComponent) {
                do {
                    return try searchForNode(descendingFrom: possibleStartingPoint, pathComponents: path.dropFirst(), onlyFindSymbols: onlyFindSymbols, rawPathForError: rawPath)
                } catch {
                    if innerMostError == nil {
                        innerMostError = error
                    }
                }
            }
            
            do {
                return try searchForNodeUpTheHierarchy(from: possibleStartingPoint.parent, path: path)
            } catch {
                throw innerMostError ?? error
            }
        }
        
        if !isAbsolute, let parentID {
            // If this is a relative link with a known starting point, search from that node (or its language counterpoint) up the hierarchy.
            var startingPoint = lookup[parentID]!
            
            // If the known starting point has multiple language representations, check which language representation to search from.
            if let firstComponent = remaining.first, let counterpoint = startingPoint.counterpart {
                switch (startingPoint.anyChildMatches(firstComponent), counterpoint.anyChildMatches(firstComponent)) {
                // If only one of the language representations match the first path components, use that as the starting point
                case (true, false):
                    break
                case (false, true):
                    startingPoint = counterpoint
                    
                // Otherwise, there isn't a clear starting point. Pick one based on the languages to get stable behavior across builds.
                case _ where startingPoint.languages.contains(.swift):
                    break
                case _ where counterpoint.languages.contains(.swift):
                    startingPoint = counterpoint
                default:
                    // Only symbols have counterpoints which means that each node should always have at least one language
                    if counterpoint.languages.map(\.id).min()! < startingPoint.languages.map(\.id).min()! {
                        startingPoint = counterpoint
                    }
                }
            }
            
            return try searchForNodeUpTheHierarchy(from: startingPoint, path: remaining)
        }
        return try searchForNodeInModules()
    }
    
    private func searchForNode(
        descendingFrom startingPoint: Node,
        pathComponents: ArraySlice<PathComponent>,
        onlyFindSymbols: Bool,
        rawPathForError: String
    ) throws -> Node {
        var node = startingPoint
        var remaining = pathComponents[...]
        
        // Third, search for the match relative to the start node.
        if remaining.isEmpty {
            // If all path components were consumed, then the start of the search is the match.
            return node
        }
        
        // Search for the remaining components from the node
        while true {
            let (children, pathComponent) = try findChildContainer(node: &node, remaining: remaining, rawPathForError: rawPathForError)
            
            do {
                guard let child = try children.find(pathComponent.disambiguation) else {
                    // The search has ended with a node that doesn't have a child matching the next path component.
                    throw makePartialResultError(node: node, remaining: remaining, rawPathForError: rawPathForError)
                }
                node = child
                remaining = remaining.dropFirst()
                if remaining.isEmpty {
                    // If all path components are consumed, then the match is found.
                    return child
                }
            } catch DisambiguationContainer.Error.lookupCollision(let collisions) {
                func handleWrappedCollision() throws -> Node {
                    try handleCollision(node: node, remaining: remaining, collisions: collisions, onlyFindSymbols: onlyFindSymbols, rawPathForError: rawPathForError)
                }
                
                // When there's a collision, use the remaining path components to try and narrow down the possible collisions.
                
                // See if the collision can be resolved by looking ahead one level deeper.
                guard let nextPathComponent = remaining.dropFirst().first else {
                    // This was the last path component so there's nothing to look ahead.
                    //
                    // It's possible for a symbol that exist on multiple languages to collide with itself.
                    // Check if the collision can be resolved by finding a unique symbol or an otherwise preferred match.
                    var uniqueCollisions: [String: Node] = [:]
                    for (node, _) in collisions {
                        guard let symbol = node.symbol else {
                            // Non-symbol collisions should have already been resolved
                            return try handleWrappedCollision()
                        }
                        
                        let id = symbol.identifier.precise
                        if symbol.identifier.interfaceLanguage == "swift" || !uniqueCollisions.keys.contains(id) {
                            uniqueCollisions[id] = node
                        }
                        
                        guard uniqueCollisions.count < 2 else {
                            // Encountered more than one unique symbol
                            return try handleWrappedCollision()
                        }
                    }
                    // A wrapped error would have been raised while iterating over the collection.
                    return uniqueCollisions.first!.value
                }
                
                // Look ahead one path component to narrow down the list of collisions. 
                // For each collision where the next path component can be found unambiguously, return that matching node one level down.
                let possibleMatchesOneLevelDown = collisions.compactMap {
                    return try? $0.node.children[String(nextPathComponent.name)]?.find(nextPathComponent.disambiguation)
                }
                let onlyPossibleMatch: Node?
                
                if possibleMatchesOneLevelDown.count == 1 {
                    // Only one of the collisions found a match for the next path component
                    onlyPossibleMatch = possibleMatchesOneLevelDown.first!
                } else if !possibleMatchesOneLevelDown.isEmpty, possibleMatchesOneLevelDown.dropFirst().allSatisfy({ $0.symbol?.identifier.precise == possibleMatchesOneLevelDown.first!.symbol?.identifier.precise }) {
                    // It's also possible that different language representations of the same symbols appear as different collisions.
                    // If _all_ collisions that can find the next path component are the same symbol, then we prefer the Swift version of that symbol.
                    onlyPossibleMatch = possibleMatchesOneLevelDown.first(where: { $0.symbol?.identifier.interfaceLanguage == "swift" }) ?? possibleMatchesOneLevelDown.first!
                } else {
                    onlyPossibleMatch = nil
                }
                
                if let onlyPossibleMatch {
                    // If we found only a single match one level down then we've processed both this path component and the next.
                    remaining = remaining.dropFirst(2)
                    if remaining.isEmpty {
                        // If that was the end of the path we can simply return the result.
                        return onlyPossibleMatch
                    } else {
                        // Otherwise we continue looping over the remaining path components.
                        node = onlyPossibleMatch
                        continue
                    }
                }
                
                // Couldn't resolve the collision by look ahead.
                return try handleCollision(node: node, remaining: remaining, collisions: collisions, onlyFindSymbols: onlyFindSymbols, rawPathForError: rawPathForError)
            }
        }
    }
                        
    private func handleCollision(
        node: Node,
        remaining: ArraySlice<PathComponent>,
        collisions: [(node: PathHierarchy.Node, disambiguation: String)],
        onlyFindSymbols: Bool,
        rawPathForError: String
    ) throws -> Node {
        if let favoredMatch = collisions.singleMatch({ $0.node.specialBehaviors.contains(.disfavorInLinkCollision) == false }) {
            return favoredMatch.node
        }
        // If a module has the same name as the article root (which is named after the bundle display name) then its possible
        // for an article a symbol to collide. Articles aren't supported in symbol links but symbols are supported in general
        // documentation links (although the non-symbol result is prioritized).
        //
        // There is a later check that the returned node is a symbol for symbol links, but that won't happen if the link is a
        // collision. To fully handle the collision in both directions, the check below uses `onlyFindSymbols` in the closure
        // so that only symbol matches are returned for symbol links (when `onlyFindSymbols` is `true`) and non-symbol matches
        // for general documentation links (when `onlyFindSymbols` is `false`).
        //
        // It's a more compact way to write
        //
        //     if onlyFindSymbols {
        //        return $0.node.symbol != nil
        //     } else {
        //        return $0.node.symbol == nil
        //     }
        if let symbolOrNonSymbolMatch = collisions.singleMatch({ ($0.node.symbol != nil) == onlyFindSymbols }) {
            return symbolOrNonSymbolMatch.node
        }
        
        throw Error.lookupCollision(
            partialResult: (
                node,
                pathForError(of: rawPathForError, droppingLast: remaining.count)
            ),
            remaining: Array(remaining),
            collisions: collisions.map { ($0.node, $0.disambiguation) }
        )
    }
    
    private func makePartialResultError(
        node: Node,
        remaining: ArraySlice<PathComponent>,
        rawPathForError: String
    ) -> Error {
        if let disambiguationTree = node.children[String(remaining.first!.name)] {
            return Error.unknownDisambiguation(
                partialResult: (
                    node,
                    pathForError(of: rawPathForError, droppingLast: remaining.count)
                ),
                remaining: Array(remaining),
                candidates: disambiguationTree.disambiguatedValues().map {
                    (node: $0.value, disambiguation: String($0.disambiguation.makeSuffix().dropFirst()))
                }
            )
        }
        
        return Error.unknownName(
            partialResult: (
                node,
                pathForError(of: rawPathForError, droppingLast: remaining.count)
            ),
            remaining: Array(remaining),
            availableChildren: Set(node.children.keys)
        )
    }
    
    private func pathForError(
        of rawPath: String,
        droppingLast trailingComponentsToDrop: Int
    ) -> Substring {
        guard trailingComponentsToDrop > 0 else { return rawPath[...] }
        
        // Drop 1 less than the requested amount to keep the trailing path separator in the returned path prefix.
        let componentSubstrings = PathParser.split(rawPath).componentSubstrings.dropLast(trailingComponentsToDrop - 1)
        guard let lastSubstring = componentSubstrings.last else { return "" }
        
        return rawPath[..<lastSubstring.startIndex]
    }
    
    /// Finds the child disambiguation container for a given node that match the remaining path components.
    /// - Parameters:
    ///   - node: The current node.
    ///   - remaining: The remaining path components.
    ///   - rawPathForError: The raw path for presentation in potential error messages.
    /// - Returns: The child disambiguation container and path component it matched.
    private func findChildContainer(
        node: inout Node,
        remaining: ArraySlice<PathComponent>,
        rawPathForError: String
    ) throws -> (DisambiguationContainer, PathComponent) {
        var pathComponent = remaining.first!
        if let match = node.children[pathComponent.full] {
            // The path component parsing may treat dash separated words as disambiguation information.
            // If the parsed name didn't match, also try the original.
            pathComponent.disambiguation = nil
            return (match, pathComponent)
        } else if let match = node.children[String(pathComponent.name)] {
            return (match, pathComponent)
        }
        // The search has ended with a node that doesn't have a child matching the next path component.
        throw makePartialResultError(node: node, remaining: remaining, rawPathForError: rawPathForError)
    }
}

// MARK: Disambiguation Container

extension PathHierarchy.DisambiguationContainer {
    /// Errors finding values in the disambiguation tree
    enum Error: Swift.Error {
        /// Multiple matches found.
        ///
        /// Includes a list of values paired with their missing disambiguation suffixes.
        case lookupCollision([(node: PathHierarchy.Node, disambiguation: String)])
    }
    
    /// Attempts to find a value in the disambiguation tree based on partial disambiguation information.
    ///
    /// There are 3 possible results:
    ///  - No match is found; indicated by a `nil` return value.
    ///  - Exactly one match is found; indicated by a non-nil return value.
    ///  - More than one match is found; indicated by a raised error listing the matches and their missing disambiguation.
    func find(_ disambiguation: PathHierarchy.PathComponent.Disambiguation?) throws -> PathHierarchy.Node? {
        if storage.count <= 1, disambiguation == nil {
            return storage.first?.node
        }
        
        switch disambiguation {
        case .kindAndHash(let kind, let hash):
            switch (kind, hash) {
            case (let kind?, let hash?):
                return storage.first(where: { $0.kind == kind && $0.hash == hash })?.node
            case (let kind?, nil):
                let matches = storage.filter({ $0.kind == kind })
                guard matches.count <= 1 else {
                    // Suggest not only hash disambiguation, but also type signature disambiguation.
                    throw Error.lookupCollision(Self.disambiguatedValues(for: matches).map { ($0.value, $0.disambiguation.value()) })
                }
                return matches.first?.node
            case (nil, let hash?):
                let matches = storage.filter({ $0.hash == hash })
                guard matches.count <= 1 else {
                    throw Error.lookupCollision(matches.map { ($0.node, $0.kind!) }) // An element wouldn't match if it didn't have kind disambiguation.
                }
                return matches.first?.node
            case (nil, nil):
                break
            }
        case .typeSignature(let parameterTypes, let returnTypes):
            switch (parameterTypes, returnTypes) {
            case (let parameterTypes?, let returnTypes?):
                return storage.first(where: { typesMatch(provided: parameterTypes, actual: $0.parameterTypes) && typesMatch(provided: returnTypes, actual: $0.returnTypes) })?.node
            case (let parameterTypes?, nil):
                let matches = storage.filter({ typesMatch(provided: parameterTypes, actual: $0.parameterTypes) })
                guard matches.count <= 1 else {
                    throw Error.lookupCollision(matches.map { ($0.node, formattedTypes($0.parameterTypes)!) }) // An element wouldn't match if it didn't have parameter type disambiguation.
                }
                return matches.first?.node
            case (nil, let returnTypes?):
                let matches = storage.filter({ typesMatch(provided: returnTypes, actual: $0.returnTypes) })
                guard matches.count <= 1 else {
                    throw Error.lookupCollision(matches.map { ($0.node, formattedTypes($0.returnTypes)!) }) // An element wouldn't match if it didn't have return type disambiguation.
                }
                return matches.first?.node
            case (nil, nil):
                break
            }
        case nil:
            break
        }

        // Disambiguate by a mix of kinds and USRs
        throw Error.lookupCollision(self.disambiguatedValues().map { ($0.value, $0.disambiguation.value()) })
    }
}

// MARK: Private helper extensions

private func formattedTypes(_ types: [String]?) -> String? {
    guard let types = types else { return nil }
    switch types.count {
    case 0: return "()"
    case 1: return types[0]
    default: return "(\(types.joined(separator: ","))"
    }
}

// Allow optional substrings to be compared to non-optional strings
private func == (lhs: (some StringProtocol)?, rhs: some StringProtocol) -> Bool {
     guard let lhs else { return false }
     return lhs == rhs
 }

private extension Sequence {
    /// Returns the only element of the sequence that satisfies the given predicate.
    /// - Parameters:
    ///   - predicate: A closure that takes an element of the sequence as its argument and returns a Boolean value indicating whether the element is a match.
    /// - Returns: The only element of the sequence that satisfies `predicate`, or `nil` if  multiple elements satisfy the predicate or if no element satisfy the predicate.
    /// - Complexity: O(_n_), where _n_ is the length of the sequence.
    func singleMatch(_ predicate: (Element) -> Bool) -> Element? {
        var match: Element?
        for element in self where predicate(element) {
            guard match == nil else {
                // Found a second match. No need to check the rest of the sequence.
                return nil
            }
            match = element
        }
        return match
    }
}

private extension PathHierarchy.Node {
    func matches(_ component: PathHierarchy.PathComponent) -> Bool {
        // Check the full path component first in case the node's name has a suffix that could be mistaken for a hash disambiguation.
        if name == component.full {
            return true
        }
        // Otherwise, check if the node's symbol matches the provided disambiguation
        else if let symbol, let disambiguation = component.disambiguation {
            switch disambiguation {
            case .kindAndHash(let kind, let hash):
                return name == component.name
                    && (kind == nil || kind! == symbol.kind.identifier.identifier)
                    && (hash == nil || hash! == symbol.identifier.precise.stableHashString)
            case .typeSignature(let parameterTypes, let returnTypes):
                let functionSignatureTypeNames = PathHierarchy.functionSignatureTypeNames(for: symbol)
                return name == component.name
                    && (parameterTypes == nil || typesMatch(provided: parameterTypes!, actual: functionSignatureTypeNames?.parameterTypeNames))
                    && (returnTypes    == nil || typesMatch(provided: returnTypes!,    actual: functionSignatureTypeNames?.returnTypeNames))
            }
        }
        
        return false
    }
    
    func anyChildMatches(_ component: PathHierarchy.PathComponent) -> Bool {
        let keys = children.keys
        return keys.contains(component.full)
            || keys.contains(String(component.name))
    }
}

private func typesMatch(provided: [Substring], actual: [String]?) -> Bool {
    guard let actual = actual, provided.count == actual.count else { return false }
    for (providedType, actualType) in zip(provided, actual) where providedType != "_" && providedType != actualType {
        return false
    }
    return true
}
