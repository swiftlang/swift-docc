/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SymbolKit

// This code is extracted from the DocumentationContext to make it easier to isolate and replace.

/// A type that encapsulates resolving links by looking up references in a documentation cache.
final class DocumentationCacheBasedLinkResolver {
    
    func unregisterBundle(identifier: BundleIdentifier) {
        referenceCache.sync { $0.removeAll() }
    }
    
    func addPreparedSymbol(symbolReference: ResolvedTopicReference, referenceAliases: [ResolvedTopicReference]) {
        for alias in referenceAliases where alias != symbolReference {
            registerAliasReference(alias, for: symbolReference)
        }
    }
    
    // MARK: - Reference aliases
    
    /// The canonical references for each with alias reference.
    ///
    /// When multiple references resolve to the same documentation, use this to find the canonical reference that is associated with the node in the topic graph.
    ///
    /// The key is the alias reference and the value is the canonical reference..
    /// A main reference can have many aliases but an alias can only have one main reference.
    private(set) var canonicalReferences = [ResolvedTopicReference: ResolvedTopicReference]()
    
    /// The alias references for each canonical reference.
    private(set) var referenceAliases = [ResolvedTopicReference: Set<ResolvedTopicReference>]()
    
    /// Registers the given alias for the given canonical reference.
    private func registerAliasReference(
        _ aliasReference: ResolvedTopicReference,
        for canonicalReference: ResolvedTopicReference
    ) {
        canonicalReferences[aliasReference] = canonicalReference
        referenceAliases[canonicalReference, default: Set()].insert(aliasReference)
    }
    
    /// Returns the canonical reference for the given reference.
    ///
    /// If no canonical reference is registered for the given reference, then it's considered to be the canonical reference and it's returned.
    func canonicalReference(for reference: ResolvedTopicReference) -> ResolvedTopicReference {
        canonicalReferences[reference] ?? reference
    }
    
    /// Returns the aliases registered for the given canonical reference, if any.
    private func aliasReferences(for canonicalReference: ResolvedTopicReference) -> Set<ResolvedTopicReference> {
        referenceAliases[canonicalReference] ?? []
    }
    
    // MARK: Reference resolving
    
    
    /// Reference lookup index.
    var referencesIndex = [String: ResolvedTopicReference]()
    
    func registerReference(_ resolvedReference: ResolvedTopicReference) {
        referencesIndex[resolvedReference.absoluteString] = resolvedReference
    }
    
    /// Looks up the topic graph directly using a symbol link path.
    /// - Parameters:
    ///   - path: A possibly absolute symbol path.
    ///   - parent: A resolved reference.
    /// - Returns: A resolved topic reference, `nil` if no node matched the path.
    func referenceFor(absoluteSymbolPath path: String, parent: ResolvedTopicReference) -> ResolvedTopicReference? {
        // Check if `destination` is a known absolute reference URL.
        if let match = referencesIndex[path] { return match }
        
        // Check if `destination` is a known absolute symbol path.
        let referenceURLString = "doc://\(parent.bundleIdentifier)/documentation/\(path.hasPrefix("/") ? String(path.dropFirst()) : path)"
        return referencesIndex[referenceURLString]
    }
    
    /// A synchronized reference cache to store resolved references.
    let referenceCache = Synchronized([String: ResolvedTopicReference]())
    
    /// Safely add a resolved reference to the reference cache
    func cacheReference(_ resolved: ResolvedTopicReference, withKey key: ResolvedTopicReferenceCacheKey) {
        referenceCache.sync { $0[key] = resolved }
    }
    
    /**
     Attempt to resolve an unresolved topic reference.
     
     - Parameters:
       - unresolvedReference: An unresolved reference.
       - parentIdentifier: The *resolved* identifier that serves as an enclosing search context, especially the parent identifier's bundle identifier.
       - fromSymbolLink: If `true` will try to resolve relative links *only* in documentation symbol locations in the hierarchy. If `false` it will try to resolve relative links as tutorials, articles, symbols, etc.
     - Returns: The resolved identifier for the topic if the parent provided the correct context and the topic exists.
     
     We have four approaches to trying to resolve a reference:
     
     1. we check if the link is already resolved, i.e. the path is fully formed and there is a matching documentation node
     2. we check if the link is resolvable in the local context (e.g. the parent), i.e. "MyClass" ~> "MyClass/myFunction()"
     3. we check if the link is resolvable as a sibling to the parent, i.e. "MyClass/myFunction()" ~> "MyClass/path"
     4. we check if the link is resolvable in the root context (e.g. the module) of its parent, i.e. we will try resolving 'MyClass' as 'MyKit/MyClass'
     5. we check if there is a registered external resolver for the link's bundle id and if so, use that resolver
     
     If none of these succeeds we will return the original unresolved reference.
     */
    public func resolve(_ unresolvedReference: UnresolvedTopicReference, in parent: ResolvedTopicReference, fromSymbolLink isCurrentlyResolvingSymbolLink: Bool, context: DocumentationContext) -> TopicReferenceResolutionResult {
        // Check if that unresolved reference was already resolved in that parent context
        if let cachedReference: ResolvedTopicReference = self.referenceCache.sync({
            return $0[ResolvedTopicReference.cacheIdentifier(unresolvedReference, fromSymbolLink: isCurrentlyResolvingSymbolLink, in: parent)]
        }) {
            if isCurrentlyResolvingSymbolLink && !(context.documentationCache[cachedReference]?.semantic is Symbol) {
                // When resolving a symbol link, ignore non-symbol matches,
                // do continue to try resolving the symbol as if cached match was not found.
            } else {
                return .success(cachedReference)
            }
        }
        
        let absolutePath = unresolvedReference.path.prependingLeadingSlash
        
        // Ensure we are resolving either relative links or "doc:" scheme links
        guard unresolvedReference.topicURL.url.scheme == nil || ResolvedTopicReference.urlHasResolvedTopicScheme(unresolvedReference.topicURL.url) else {
            // Not resolvable in the topic graph
            return .failure(unresolvedReference, errorMessage: "Reference URL \(unresolvedReference.description.singleQuoted) doesn't have \"doc:\" scheme.")
        }
        
        // Fall back on the parent's bundle identifier for relative paths
        let referenceBundleIdentifier = unresolvedReference.topicURL.components.host ?? parent.bundleIdentifier
        
        // Keep track of all the resolution candidates so that we can resolve them externally
        // if they weren't resolvable internally.
        var allCandidateURLs = [URL]()
        
        /// Returns the given reference if it resolves. Otherwise, returns nil.
        ///
        /// Adds any non-resolving reference to the `allCandidateURLs` collection.
        func attemptToResolve(_ reference: ResolvedTopicReference) -> TopicReferenceResolutionResult? {
            if let resolved = context.topicGraph.nodeWithReference(reference)?.reference {
                // If resolving a symbol link, only match symbol nodes.
                if isCurrentlyResolvingSymbolLink && !(context.documentationCache[resolved]?.semantic is Symbol) {
                    allCandidateURLs.append(reference.url)
                    return nil
                }
                cacheReference(resolved, withKey: ResolvedTopicReference.cacheIdentifier(unresolvedReference, fromSymbolLink: isCurrentlyResolvingSymbolLink, in: parent))
                return .success(resolved)
            } else if reference.fragment != nil, context.nodeAnchorSections.keys.contains(reference) {
                return .success(reference)
            } else if let alias = canonicalReferences[reference] {
                return .success(alias)
            } else {
                // Grab the aliases of the reference's parent (rather than the contextual parent) and check if the
                // reference can be resolved as any of their child.
                let referenceParent = reference.removingLastPathComponent()
                for parentAlias in aliasReferences(for: referenceParent) {
                    let aliasReference = parentAlias.appendingPath(reference.lastPathComponent)
                    if let alias = canonicalReferences[aliasReference] {
                        return .success(alias)
                    }
                }
                
                allCandidateURLs.append(reference.url)
                return nil
            }
        }
        
        // If a known bundle is referenced via the "doc:" scheme try to resolve in topic graph
        if let knownBundleIdentifier = context.registeredBundles.first(where: { bundle -> Bool in
            return bundle.identifier == referenceBundleIdentifier || urlReadablePath(bundle.displayName) == referenceBundleIdentifier
        })?.identifier {
            // 1. Check if reference is already resolved but not found in the cache
            let alreadyResolved = ResolvedTopicReference(
                bundleIdentifier: knownBundleIdentifier,
                path: absolutePath,
                fragment: unresolvedReference.topicURL.components.fragment,
                sourceLanguages: parent.sourceLanguages
            )
            if let resolved = attemptToResolve(alreadyResolved) {
                return resolved
            }
            
            // 2. Check if resolvable in any of the root non-symbol contexts
            let currentBundle = context.bundle(identifier: knownBundleIdentifier)!
            if !isCurrentlyResolvingSymbolLink {
                // First look up articles path
                let articleReference = currentBundle.articlesDocumentationRootReference.appendingPathOfReference(unresolvedReference)
                if let resolved = attemptToResolve(articleReference) {
                    return resolved
                }
                
                // Then technology tutorials root path (for individual tutorial pages)
                let tutorialReference = currentBundle.technologyTutorialsRootReference.appendingPathOfReference(unresolvedReference)
                if let resolved = attemptToResolve(tutorialReference) {
                    return resolved
                }
                
                // Then tutorials root path (for tutorial table of contents pages)
                let tutorialRootReference = currentBundle.tutorialsRootReference.appendingPathOfReference(unresolvedReference)
                if let resolved = attemptToResolve(tutorialRootReference) {
                    return resolved
                }
            }
            
            // 3. Try resolving in the local context (as child)
            let childSymbolReference = parent.appendingPathOfReference(unresolvedReference)
            if let resolved = attemptToResolve(childSymbolReference) {
                return resolved
            }
            
            // 4. Try resolving as a sibling and within `Self`.
            // To look for siblings we require at least a module (first)
            // and a symbol (second) path components.
            let parentPath = parent.path.components(separatedBy: "/").dropLast()
            let siblingSymbolReference: ResolvedTopicReference?
            if parentPath.count >= 2 {
                siblingSymbolReference = ResolvedTopicReference(
                    bundleIdentifier: knownBundleIdentifier,
                    path: parentPath.joined(separator: "/"),
                    fragment: unresolvedReference.topicURL.components.fragment,
                    sourceLanguages: parent.sourceLanguages
                ).appendingPathOfReference(unresolvedReference)
                
                if let resolved = attemptToResolve(siblingSymbolReference!) {
                    return resolved
                }
            } else {
                siblingSymbolReference = nil
            }
            
            // 5. Try resolving in root symbol context
            
            // Check that the parent is not an article (ignoring if absolute or relative link)
            // because we cannot resolve in the parent context if it's not a symbol.
            if parent.path.hasPrefix(currentBundle.documentationRootReference.path) && parentPath.count > 2 {
                let rootPath = currentBundle.documentationRootReference.appendingPath(parentPath[2])
                let resolvedInRoot = rootPath.appendingPathOfReference(unresolvedReference)
                
                // Confirm here that we we're not already considering this link. We only need to specifically
                // consider the parent reference when looking for deeper links.
                //
                // e.g. if the link is `documentation/MyKit` we'll find the parent context when we're resolving under `documentation`
                // for a deeper link link like `documentation/MyKit/MyClass/myFunction()` we need to specifically hit the parent reference to try resolving links.
                if resolvedInRoot.path != siblingSymbolReference?.path {
                    if let resolved = attemptToResolve(resolvedInRoot) {
                        return resolved
                    }
                }
            }
            
            let moduleSymbolReference = currentBundle.documentationRootReference.appendingPathOfReference(unresolvedReference)
            if let resolved = attemptToResolve(moduleSymbolReference) {
                return resolved
            }
        }
        
        // 5. Check if a pre-resolved external link.
        if let bundleID = unresolvedReference.topicURL.components.host {
            if context.externalReferenceResolvers[bundleID] != nil,
               let resolvedExternalReference = context.externallyResolvedLinks[unresolvedReference.topicURL] {
                // Return the successful or failed externally resolved reference.
                return resolvedExternalReference
            } else if !context.registeredBundles.contains(where: { $0.identifier == bundleID }) {
                return .failure(unresolvedReference, errorMessage: "No external resolver registered for \(bundleID.singleQuoted).")
            }
        }
        
        // External symbols are already pre-resolved while loading the symbol graph
        // so they will be fetched from the context.
        
        // If a fallback resolver exists for this bundle, try to resolve the link externally.
        if let fallbackResolver = context.fallbackReferenceResolvers[referenceBundleIdentifier] {
            for candidateURL in allCandidateURLs {
                let unresolvedReference = UnresolvedTopicReference(topicURL: ValidatedURL(candidateURL)!)
                let reference = fallbackResolver.resolve(.unresolved(unresolvedReference), sourceLanguage: parent.sourceLanguage)
                
                if case .success(let resolvedReference) = reference {
                    cacheReference(resolvedReference, withKey: ResolvedTopicReference.cacheIdentifier(unresolvedReference, fromSymbolLink: isCurrentlyResolvingSymbolLink, in: parent))
                    
                    // Register the resolved reference in the context so that it can be looked up via its absolute
                    // path. We only do this for in-bundle content, and since we've just resolved an in-bundle link,
                    // we register the reference.
                    registerReference(resolvedReference)
                    return .success(resolvedReference)
                }
            }
        }
        
        // Give up: there is no local or external document for this reference.
        
        // External references which failed to resolve will already have returned a more specific error message.
        return .failure(unresolvedReference, errorMessage: "No local documentation matches this reference.")
    }
    
    
    // MARK: Symbol reference creation
    
    /// Returns a map between symbol identifiers and topic references.
    ///
    /// - Parameters:
    ///   - symbolGraph: The complete symbol graph to walk through.
    ///   - bundle: The bundle to use when creating symbol references.
    func referencesForSymbols(in unifiedGraphs: [String: UnifiedSymbolGraph], bundle: DocumentationBundle, context: DocumentationContext) -> [SymbolGraph.Symbol.Identifier: [ResolvedTopicReference]] {
        // The implementation of this function is fairly tricky because in most cases it has to preserve past behavior.
        //
        // This is because symbol references bake the disambiguators into the path, making it the only version of that
        // path that resolves to that symbol. In other words, a reference with "too few" or "too many" disambiguators
        // will fail to resolve. Changing what's considered the "correct" disambiguators for a symbol means that links
        // that used to resolve will break with the new behavior.
        //
        // The tests in `SymbolDisambiguationTests` cover the known behaviors that should be preserved.
        //
        // The real solution to this problem is to allow symbol links to over-specify disambiguators and improve the
        // diagnostics when symbol links are ambiguous. (rdar://78518537)
        // That will allow for fixes to the least amount of disambiguation without breaking existing links.
        
        
        // The current implementation works in 3 phases:
        //  - First, it computes the paths without disambiguators to identify colliding paths.
        //  - Second, it computes the "correct" disambiguators for each collision.
        //  - Lastly, it joins together the results in a stable order to avoid non-deterministic behavior.
        
        
        let totalSymbolCount = unifiedGraphs.values.map { $0.symbols.count }.reduce(0, +)
        
        /// Temporary data structure to hold input to compute paths with or without disambiguation.
        struct PathCollisionInfo {
            let symbol: UnifiedSymbolGraph.Symbol
            let moduleName: String
            var languages: Set<SourceLanguage>
        }
        var pathCollisionInfo = [String: [PathCollisionInfo]]()
        pathCollisionInfo.reserveCapacity(totalSymbolCount)
        
        // Group symbols by path from all of the available symbol graphs
        for (moduleName, symbolGraph) in unifiedGraphs {
            let symbols = Array(symbolGraph.symbols.values)
            let pathsAndLanguages: [[(String, SourceLanguage)]] = symbols.concurrentMap { referencesWithoutDisambiguationFor($0, moduleName: moduleName, bundle: bundle, context: context).map {
                ($0.path.lowercased(), $0.sourceLanguage)
            } }

            for (symbol, symbolPathsAndLanguages) in zip(symbols, pathsAndLanguages) {
                for (path, language) in symbolPathsAndLanguages {
                    if let existingReferences = pathCollisionInfo[path] {
                        if existingReferences.allSatisfy({ $0.symbol.uniqueIdentifier != symbol.uniqueIdentifier}) {
                            // A collision - different symbol but same paths
                            pathCollisionInfo[path]!.append(PathCollisionInfo(symbol: symbol, moduleName: moduleName, languages: [language]))
                        } else {
                            // Same symbol but in a different source language.
                            pathCollisionInfo[path]! = pathCollisionInfo[path]!.map { PathCollisionInfo(symbol: $0.symbol, moduleName: $0.moduleName, languages: $0.languages.union([language])) }
                        }
                    } else {
                        // First occurrence of this path
                        pathCollisionInfo[path] = [PathCollisionInfo(symbol: symbol, moduleName: moduleName, languages: [language])]
                    }
                }
            }
        }
        
        /// Temporary data structure to hold groups of disambiguated references
        ///
        /// Since the order of `pathCollisionInfo` isn't stable across program executions, simply joining the results for a given symbol that has different
        /// paths in different source languages would also result in an unstable order (depending on the order that the different paths were processed).
        /// Instead we gather all groups of results and join them in a stable order.
        struct IntermediateResultGroup {
            let conflictingSymbolLanguage: SourceLanguage
            let disambiguatedReferences: [ResolvedTopicReference]
        }
        var resultGroups = [SymbolGraph.Symbol.Identifier: [IntermediateResultGroup]]()
        resultGroups.reserveCapacity(totalSymbolCount)
        
        // Translate symbols to topic references, adjust paths where necessary.
        for collisions in pathCollisionInfo.values {
            let disambiguationSuffixes = collisions.map(\.symbol).requiredDisambiguationSuffixes
            
            for (collisionInfo, disambiguationSuffix) in zip(collisions, disambiguationSuffixes) {
                let language = collisionInfo.languages.contains(.swift) ? .swift : collisionInfo.languages.first!
                
                // If the symbol has externally provided disambiguated path components, trust that those are accurate.
                if let knownDisambiguatedComponents = context.knownDisambiguatedSymbolPathComponents?[collisionInfo.symbol.uniqueIdentifier],
                   collisionInfo.symbol.defaultSymbol?.pathComponents.count == knownDisambiguatedComponents.count
                {
                    let symbolReference = SymbolReference(pathComponents: knownDisambiguatedComponents, interfaceLanguages: collisionInfo.symbol.sourceLanguages)
                    resultGroups[collisionInfo.symbol.defaultIdentifier, default: []].append(
                        IntermediateResultGroup(
                            conflictingSymbolLanguage: language,
                            disambiguatedReferences: [ResolvedTopicReference(symbolReference: symbolReference, moduleName: collisionInfo.moduleName, bundle: bundle)]
                        )
                    )
                    continue
                }
                
                // If this is a multi-language collision that doesn't need disambiguation, only emit that symbol once.
                if collisionInfo.languages.count > 1, disambiguationSuffix == (false, false) {
                    let symbolReference = SymbolReference(
                        collisionInfo.symbol.uniqueIdentifier,
                        interfaceLanguages: collisionInfo.symbol.sourceLanguages,
                        defaultSymbol: collisionInfo.symbol.defaultSymbol,
                        shouldAddHash: false,
                        shouldAddKind: false
                    )
                    
                    resultGroups[collisionInfo.symbol.defaultIdentifier, default: []].append(
                        IntermediateResultGroup(
                            conflictingSymbolLanguage: language,
                            disambiguatedReferences:[ResolvedTopicReference(symbolReference: symbolReference, moduleName: collisionInfo.moduleName, bundle: bundle)]
                        )
                    )
                    continue
                }
                
                // Emit the disambiguated references for all languages for this symbol's collision.
                var symbolSelectors = [collisionInfo.symbol.defaultSelector!]
                for selector in collisionInfo.symbol.mainGraphSelectors where !symbolSelectors.contains(selector) {
                    symbolSelectors.append(selector)
                }
                symbolSelectors = symbolSelectors.filter { collisionInfo.languages.contains(SourceLanguage(id: $0.interfaceLanguage)) }
                
                resultGroups[collisionInfo.symbol.defaultIdentifier, default: []].append(
                    IntermediateResultGroup(
                        conflictingSymbolLanguage: language,
                        disambiguatedReferences: symbolSelectors.map { selector  in
                            let symbolReference = SymbolReference(
                                collisionInfo.symbol.uniqueIdentifier,
                                interfaceLanguages: collisionInfo.symbol.sourceLanguages,
                                defaultSymbol: collisionInfo.symbol.symbol(forSelector: selector),
                                shouldAddHash: disambiguationSuffix.shouldAddIdHash,
                                shouldAddKind: disambiguationSuffix.shouldAddKind
                            )
                            return ResolvedTopicReference(symbolReference: symbolReference, moduleName: collisionInfo.moduleName, bundle: bundle)
                        }
                    )
                )
            }
        }
        
        return resultGroups.mapValues({
            return $0.sorted(by: { lhs, rhs in
                switch (lhs.conflictingSymbolLanguage, rhs.conflictingSymbolLanguage) {
                // If only one result group is Swift, that comes before the other result.
                case (.swift, let other) where other != .swift:
                    return true
                case (let other, .swift) where other != .swift:
                    return false
                    
                // Otherwise, compare the first path to ensure a deterministic order.
                default:
                    return lhs.disambiguatedReferences[0].path < rhs.disambiguatedReferences[0].path
                }
            }).flatMap({ $0.disambiguatedReferences })
        })
    }
    
    private func referencesWithoutDisambiguationFor(_ symbol: UnifiedSymbolGraph.Symbol, moduleName: String, bundle: DocumentationBundle, context: DocumentationContext) -> [ResolvedTopicReference] {
        if let pathComponents = context.knownDisambiguatedSymbolPathComponents?[symbol.uniqueIdentifier],
           let componentsCount = symbol.defaultSymbol?.pathComponents.count,
           pathComponents.count == componentsCount
        {
            let symbolReference = SymbolReference(pathComponents: pathComponents, interfaceLanguages: symbol.sourceLanguages)
            return [ResolvedTopicReference(symbolReference: symbolReference, moduleName: moduleName, bundle: bundle)]
        }
        
        // A unified symbol that exist in multiple languages may have multiple references.
        
        // Find all of the relevant selectors, starting with the `defaultSelector`.
        // Any reference after the first is considered an alias/alternative to the first reference
        // and will resolve to the first reference.
        var symbolSelectors = [symbol.defaultSelector]
        for selector in symbol.mainGraphSelectors where !symbolSelectors.contains(selector) {
            symbolSelectors.append(selector)
        }
        
        return symbolSelectors.map { selector  in
            let defaultSymbol = symbol.symbol(forSelector: selector)!
            let symbolReference = SymbolReference(
                symbol.uniqueIdentifier,
                interfaceLanguages: symbol.sourceLanguages.filter { $0 == SourceLanguage(id: defaultSymbol.identifier.interfaceLanguage) },
                defaultSymbol: defaultSymbol,
                shouldAddHash: false,
                shouldAddKind: false
            )
            return ResolvedTopicReference(symbolReference: symbolReference, moduleName: moduleName, bundle: bundle)
        }
    }
    
    private func currentReferenceFor(reference: ResolvedTopicReference, symbolsURLHierarchy: inout BidirectionalTree<ResolvedTopicReference>) throws -> ResolvedTopicReference {
        // Check if a possible child of a re-written symbol path; we don't account for module name collisions.
        // `pathComponents` starts with a "/", then we have "documentation", and then a name of a root symbol
        // therefore for the currently processed symbol to be a child of a re-written symbol it needs to have
        // at least 3 components. It's a fair optimization to make since graphs will include a lot of root level symbols.
        guard reference.pathComponents.count > 3,
                // Fetch the symbol's parent
                let parentReference = try symbolsURLHierarchy.parent(of: reference),
                // If the parent path matches the current reference path, bail out
                parentReference.pathComponents != reference.pathComponents.dropLast(),
                // If the parent is not from the same module (because we're dealing with a
                // default implementation of an external protocol), bail out
                parentReference.pathComponents[..<3] == reference.pathComponents[..<3]
        else { return reference }
        
        // Build an up to date reference path for the current node based on the parent path
        return parentReference.appendingPath(reference.lastPathComponent)
    }

    /// Method called when walking the symbol url tree that checks if a parent of a symbol has had its
    /// path modified during loading the symbol graph. If that's the case the method replaces
    /// `reference` with an updated reference with a correct reference path.
    func updateNodeWithReferenceIfCollisionChild(_ reference: ResolvedTopicReference, symbolsURLHierarchy: inout BidirectionalTree<ResolvedTopicReference>, symbolIndex: inout [String: DocumentationNode], context: DocumentationContext) throws {
        let newReference = try currentReferenceFor(reference: reference, symbolsURLHierarchy: &symbolsURLHierarchy)
        guard newReference != reference else { return }
        
        // Update the reference of the node in the documentation cache
        var documentationNode = context.documentationCache.removeValue(forKey: reference)
        documentationNode?.reference = newReference
        context.documentationCache[newReference] = documentationNode

        // Rewrite the symbol index
        if let symbolIdentifier = documentationNode?.symbol?.identifier {
            symbolIndex.removeValue(forKey: symbolIdentifier.precise)
            symbolIndex[symbolIdentifier.precise] = documentationNode
        }
        
        // Replace the topic graph node
        if let node = context.topicGraph.nodeWithReference(reference) {
            let newNode = TopicGraph.Node(reference: newReference, kind: node.kind, source: node.source, title: node.title)
            context.topicGraph.replaceNode(node, with: newNode)
        }

        // Check if this relationship hasn't been created by another symbol graph (e.g. same module / different platform)
        let newRefParent = try? symbolsURLHierarchy.parent(of: newReference) // might not exist, just checking
        let refParent = try symbolsURLHierarchy.parent(of: reference)
        if newRefParent != refParent {
            // Replace the url hierarchy node
            try symbolsURLHierarchy.replace(reference, with: newReference)
        }
    }
}
