/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SymbolKit

/// A type that encapsulates resolving links by searching a hierarchy of path components.
final class PathHierarchyBasedLinkResolver {
    /// A hierarchy of path components used to resolve links in the documentation.
    private(set) var pathHierarchy: PathHierarchy!
    
    /// Map between resolved identifiers and resolved topic references.
    private(set) var resolvedReferenceMap = BidirectionalMap<ResolvedIdentifier, ResolvedTopicReference>()
    
    /// Initializes a link resolver with a given path hierarchy.
    init(pathHierarchy: PathHierarchy) {
        self.pathHierarchy = pathHierarchy
    }
    
    /// Remove all matches from a given documentation bundle from the link resolver.
    func unregisterBundle(identifier: BundleIdentifier) {
        var newMap = BidirectionalMap<ResolvedIdentifier, ResolvedTopicReference>()
        for (id, reference) in resolvedReferenceMap {
            if reference.bundleIdentifier == identifier {
                pathHierarchy.removeNodeWithID(id)
            } else {
                newMap[id] = reference
            }
        }
        resolvedReferenceMap = newMap
    }
    
    /// Creates a path string—that can be used to find documentation in the path hierarchy—from an unresolved topic reference,
    private static func path(for unresolved: UnresolvedTopicReference) -> String {
        guard let fragment = unresolved.fragment else {
            return unresolved.path
        }
        return "\(unresolved.path)#\(urlReadableFragment(fragment))"
    }
    
    /// Traverse all the pairs of symbols and their parents.
    func traverseSymbolAndParentPairs(_ observe: (_ symbol: ResolvedTopicReference, _ parent: ResolvedTopicReference) -> Void) {
        for (id, node) in pathHierarchy.lookup {
            guard node.symbol != nil else { continue }
            
            guard let parentID = node.parent?.identifier else { continue }
            
            // Only symbols in the symbol index are added to the reference map.
            guard let reference = resolvedReferenceMap[id], let parentReference = resolvedReferenceMap[parentID] else { continue }
            observe(reference, parentReference)
        }
    }
    
    /// Returns a list of all the top level symbols.
    func topLevelSymbols() -> [ResolvedTopicReference] {
        return pathHierarchy.topLevelSymbols().map { resolvedReferenceMap[$0]! }
    }
    
    // MARK: - Adding non-symbols
    
    /// Map the resolved identifiers to resolved topic references for a given bundle's article, tutorial, and technology root pages.
    func addMappingForRoots(bundle: DocumentationBundle) {
        resolvedReferenceMap[pathHierarchy.tutorialContainer.identifier] = bundle.tutorialsRootReference
        resolvedReferenceMap[pathHierarchy.articlesContainer.identifier] = bundle.articlesDocumentationRootReference
        resolvedReferenceMap[pathHierarchy.tutorialOverviewContainer.identifier] = bundle.technologyTutorialsRootReference
    }
    
    /// Map the resolved identifiers to resolved topic references for all symbols in the given symbol index.
    func addMappingForSymbols(symbolIndex: [String: DocumentationNode]) {
        for (id, node) in pathHierarchy.lookup {
            guard let symbol = node.symbol, let node = symbolIndex[symbol.identifier.precise] else {
                continue
            }
            resolvedReferenceMap[id] = node.reference
        }
    }
    
    /// Adds a tutorial and its landmarks to the path hierarchy.
    func addTutorial(_ tutorial: DocumentationContext.SemanticResult<Tutorial>) {
        addTutorial(
            reference: tutorial.topicGraphNode.reference,
            source: tutorial.source,
            landmarks: tutorial.value.landmarks
        )
    }
    
    /// Adds a tutorial article and its landmarks to the path hierarchy.
    func addTutorialArticle(_ tutorial: DocumentationContext.SemanticResult<TutorialArticle>) {
        addTutorial(
            reference: tutorial.topicGraphNode.reference,
            source: tutorial.source,
            landmarks: tutorial.value.landmarks
        )
    }
    
    private func addTutorial(reference: ResolvedTopicReference, source: URL, landmarks: [Landmark]) {
        let tutorialID = pathHierarchy.addTutorial(name: urlReadablePath(source.deletingPathExtension().lastPathComponent))
        resolvedReferenceMap[tutorialID] = reference
        
        for landmark in landmarks {
            let landmarkID = pathHierarchy.addNonSymbolChild(parent: tutorialID, name: urlReadableFragment(landmark.title), kind: "landmark")
            resolvedReferenceMap[landmarkID] = reference.withFragment(landmark.title)
        }
    }
    
    /// Adds a technology and its volumes and chapters to the path hierarchy.
    func addTechnology(_ technology: DocumentationContext.SemanticResult<Technology>) {
        let reference = technology.topicGraphNode.reference

        let technologyID = pathHierarchy.addTutorialOverview(name: urlReadablePath(technology.source.deletingPathExtension().lastPathComponent))
        resolvedReferenceMap[technologyID] = reference
        
        var anonymousVolumeID: ResolvedIdentifier?
        for volume in technology.value.volumes {
            if anonymousVolumeID == nil, volume.name == nil {
                anonymousVolumeID = pathHierarchy.addNonSymbolChild(parent: technologyID, name: "$volume", kind: "volume")
                resolvedReferenceMap[anonymousVolumeID!] = reference.appendingPath("$volume")
            }
            
            let chapterParentID: ResolvedIdentifier
            let chapterParentReference: ResolvedTopicReference
            if let name = volume.name {
                chapterParentID = pathHierarchy.addNonSymbolChild(parent: technologyID, name: name, kind: "volume")
                chapterParentReference = reference.appendingPath(name)
                resolvedReferenceMap[chapterParentID] = chapterParentReference
            } else {
                chapterParentID = technologyID
                chapterParentReference = reference
            }
            
            for chapter in volume.chapters {
                let chapterID = pathHierarchy.addNonSymbolChild(parent: technologyID, name: chapter.name, kind: "volume")
                resolvedReferenceMap[chapterID] = chapterParentReference.appendingPath(chapter.name)
            }
        }
    }
    
    /// Adds a technology root article and its headings to the path hierarchy.
    func addRootArticle(_ article: DocumentationContext.SemanticResult<Article>, anchorSections: [AnchorSection]) {
        let articleID = pathHierarchy.addTechnologyRoot(name: article.source.deletingPathExtension().lastPathComponent)
        resolvedReferenceMap[articleID] = article.topicGraphNode.reference
        addAnchors(anchorSections, to: articleID)
    }
    
    /// Adds an article and its headings to the path hierarchy.
    func addArticle(_ article: DocumentationContext.SemanticResult<Article>, anchorSections: [AnchorSection]) {
        let articleID = pathHierarchy.addArticle(name: article.source.deletingPathExtension().lastPathComponent)
        resolvedReferenceMap[articleID] = article.topicGraphNode.reference
        addAnchors(anchorSections, to: articleID)
    }
    
    /// Adds a article and its headings to the path hierarchy.
    func addArticle(filename: String, reference: ResolvedTopicReference, anchorSections: [AnchorSection]) {
        let articleID = pathHierarchy.addArticle(name: filename)
        resolvedReferenceMap[articleID] = reference
        addAnchors(anchorSections, to: articleID)
    }
    
    /// Adds the headings for all symbols in the symbol index to the path hierarchy.
    func addAnchorForSymbols(symbolIndex: [String: DocumentationNode]) {
        for (id, node) in pathHierarchy.lookup {
            guard let symbol = node.symbol, let node = symbolIndex[symbol.identifier.precise] else { continue }
            addAnchors(node.anchorSections, to: id)
        }
    }
    
    private func addAnchors(_ anchorSections: [AnchorSection], to parent: ResolvedIdentifier) {
        for anchor in anchorSections {
            let identifier = pathHierarchy.addNonSymbolChild(parent: parent, name: anchor.reference.fragment!, kind: "anchor")
            resolvedReferenceMap[identifier] = anchor.reference
        }
    }
    
    /// Adds a task group on a given page to the documentation hierarchy.
    func addTaskGroup(named name: String, reference: ResolvedTopicReference, to parent: ResolvedTopicReference) {
        let parentID = resolvedReferenceMap[parent]!
        let taskGroupID = pathHierarchy.addNonSymbolChild(parent: parentID, name: urlReadablePath(name), kind: "taskGroup")
        resolvedReferenceMap[taskGroupID] = reference
    }
    
    // MARK: Reference resolving
    
    /// Attempts to resolve an unresolved reference.
    ///
    /// - Parameters:
    ///   - unresolvedReference: The unresolved reference to resolve.
    ///   - parent: The parent reference to resolve the unresolved reference relative to.
    ///   - isCurrentlyResolvingSymbolLink: Whether or not the documentation link is a symbol link.
    ///   - context: The documentation context to resolve the link in.
    /// - Returns: The result of resolving the reference.
    public func resolve(_ unresolvedReference: UnresolvedTopicReference, in parent: ResolvedTopicReference, fromSymbolLink isCurrentlyResolvingSymbolLink: Bool, context: DocumentationContext) -> TopicReferenceResolutionResult {
        // Check if the unresolved reference is external
        if let bundleID = unresolvedReference.bundleIdentifier,
           !context.registeredBundles.contains(where: { bundle in
               bundle.identifier == bundleID || urlReadablePath(bundle.displayName) == bundleID
           }) {
            
            if context.externalReferenceResolvers[bundleID] != nil,
               let resolvedExternalReference = context.externallyResolvedLinks[unresolvedReference.topicURL] {
                // Return the successful or failed externally resolved reference.
                return resolvedExternalReference
            } else if !context.registeredBundles.contains(where: { $0.identifier == bundleID }) {
                return .failure(unresolvedReference, errorMessage: "No external resolver registered for \(bundleID.singleQuoted).")
            }
        }
        
        do {
            let parentID = resolvedReferenceMap[parent]
            let found = try pathHierarchy.find(path: Self.path(for: unresolvedReference), parent: parentID, onlyFindSymbols: isCurrentlyResolvingSymbolLink)
            let foundReference = resolvedReferenceMap[found]!
            
            return .success(foundReference)
        } catch let error as PathHierarchy.Error {
            // If the reference didn't resolve in the path hierarchy, see if it can be resolved in the fallback resolver.
            if let resolvedFallbackReference = fallbackResolver.resolve(unresolvedReference, in: parent, fromSymbolLink: isCurrentlyResolvingSymbolLink, context: context) {
                return .success(resolvedFallbackReference)
            } else {
                return .failure(unresolvedReference, errorMessage: error.errorMessage(context: context))
            }
        } catch {
            fatalError("Only SymbolPathTree.Error errors are raised from the symbol link resolution code above.")
        }
    }
    
    private let fallbackResolver = FallbackResolverBasedLinkResolver()
    
    // MARK: Symbol reference creation
    
    /// Returns a map between symbol identifiers and topic references.
    ///
    /// - Parameters:
    ///   - symbolGraph: The complete symbol graph to walk through.
    ///   - bundle: The bundle to use when creating symbol references.
    func referencesForSymbols(in unifiedGraphs: [String: UnifiedSymbolGraph], bundle: DocumentationBundle, context: DocumentationContext) -> [SymbolGraph.Symbol.Identifier: ResolvedTopicReference] {
        let disambiguatedPaths = pathHierarchy.caseInsensitiveDisambiguatedPaths(includeDisambiguationForUnambiguousChildren: true, includeLanguage: true)
        
        var result: [SymbolGraph.Symbol.Identifier: ResolvedTopicReference] = [:]
        
        for (moduleName, symbolGraph) in unifiedGraphs {
            let paths: [ResolvedTopicReference?] = Array(symbolGraph.symbols.values).concurrentMap { unifiedSymbol -> ResolvedTopicReference? in
                let symbol = unifiedSymbol
                let uniqueIdentifier = unifiedSymbol.uniqueIdentifier
                
                if let pathComponents = context.knownDisambiguatedSymbolPathComponents?[uniqueIdentifier],
                   let componentsCount = symbol.defaultSymbol?.pathComponents.count,
                   pathComponents.count == componentsCount
                {
                    let symbolReference = SymbolReference(pathComponents: pathComponents, interfaceLanguages: symbol.sourceLanguages)
                    return ResolvedTopicReference(symbolReference: symbolReference, moduleName: moduleName, bundle: bundle)
                }
                
                guard let path = disambiguatedPaths[uniqueIdentifier] else {
                    return nil
                }
                
                return ResolvedTopicReference(
                    bundleIdentifier: bundle.documentationRootReference.bundleIdentifier,
                    path: NodeURLGenerator.Path.documentationFolder + path,
                    sourceLanguages: symbol.sourceLanguages
                )
            }
            for (symbol, reference) in zip(symbolGraph.symbols.values, paths) {
                guard let reference = reference else { continue }
                result[symbol.defaultIdentifier] = reference
            }
         }
        return result
    }
}

/// A fallback resolver that replicates the exact order of resolved topic references that are attempted to resolve via a fallback resolver when the path hierarchy doesn't have a match.
private final class FallbackResolverBasedLinkResolver {
    var cachedResolvedFallbackReferences = Synchronized<[String: ResolvedTopicReference]>([:])
    
    func resolve(_ unresolvedReference: UnresolvedTopicReference, in parent: ResolvedTopicReference, fromSymbolLink isCurrentlyResolvingSymbolLink: Bool, context: DocumentationContext) -> ResolvedTopicReference? {
        // Check if a fallback reference resolver should resolve this
        let referenceBundleIdentifier = unresolvedReference.bundleIdentifier ?? parent.bundleIdentifier
        guard !context.fallbackReferenceResolvers.isEmpty,
              let knownBundleIdentifier = context.registeredBundles.first(where: { $0.identifier == referenceBundleIdentifier || urlReadablePath($0.displayName) == referenceBundleIdentifier })?.identifier,
              let fallbackResolver = context.fallbackReferenceResolvers[knownBundleIdentifier]
        else {
            return nil
        }
        
        if let cached = cachedResolvedFallbackReferences.sync({ $0[unresolvedReference.topicURL.absoluteString] }) {
            return cached
        }
        var allCandidateURLs = [URL]()
        
        let alreadyResolved = ResolvedTopicReference(
            bundleIdentifier: referenceBundleIdentifier,
            path: unresolvedReference.path.prependingLeadingSlash,
            fragment: unresolvedReference.topicURL.components.fragment,
            sourceLanguages: parent.sourceLanguages
        )
        allCandidateURLs.append(alreadyResolved.url)
        
        let currentBundle = context.bundle(identifier: knownBundleIdentifier)!
        if !isCurrentlyResolvingSymbolLink {
            // First look up articles path
            allCandidateURLs.append(contentsOf: [
                // First look up articles path
                currentBundle.articlesDocumentationRootReference.url.appendingPathComponent(unresolvedReference.path),
                // Then technology tutorials root path (for individual tutorial pages)
                currentBundle.technologyTutorialsRootReference.url.appendingPathComponent(unresolvedReference.path),
                // Then tutorials root path (for tutorial table of contents pages)
                currentBundle.tutorialsRootReference.url.appendingPathComponent(unresolvedReference.path),
            ])
        }
        // Try resolving in the local context (as child)
        allCandidateURLs.append(parent.appendingPathOfReference(unresolvedReference).url)
        
        // To look for siblings we require at least a module (first)
        // and a symbol (second) path components.
        let parentPath = parent.path.components(separatedBy: "/").dropLast()
        if parentPath.count >= 2 {
            allCandidateURLs.append(parent.url.deletingLastPathComponent().appendingPathComponent(unresolvedReference.path))
        }
        
        // Check that the parent is not an article (ignoring if absolute or relative link)
        // because we cannot resolve in the parent context if it's not a symbol.
        if parent.path.hasPrefix(currentBundle.documentationRootReference.path) && parentPath.count > 2 {
            let rootPath = currentBundle.documentationRootReference.appendingPath(parentPath[2])
            let resolvedInRoot = rootPath.url.appendingPathComponent(unresolvedReference.path)
            
            // Confirm here that we we're not already considering this link. We only need to specifically
            // consider the parent reference when looking for deeper links.
            if resolvedInRoot.path != allCandidateURLs.last?.path {
                allCandidateURLs.append(resolvedInRoot)
            }
        }
        
        allCandidateURLs.append(currentBundle.documentationRootReference.url.appendingPathComponent(unresolvedReference.path))
        
        for candidateURL in allCandidateURLs {
            if let cached = cachedResolvedFallbackReferences.sync({ $0[candidateURL.absoluteString] }) {
                return cached
            }
            let unresolvedReference = UnresolvedTopicReference(topicURL: ValidatedURL(candidateURL)!)
            let reference = fallbackResolver.resolve(.unresolved(unresolvedReference), sourceLanguage: parent.sourceLanguage)
            
            if case .success(let resolvedReference) = reference {
                cachedResolvedFallbackReferences.sync({ $0[resolvedReference.absoluteString] = resolvedReference })
                return resolvedReference
            }
        }
        // Give up: there is no local or external document for this reference.
        return nil
    }
}
