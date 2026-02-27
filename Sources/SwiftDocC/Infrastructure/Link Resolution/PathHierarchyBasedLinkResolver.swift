/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022-2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

private import Foundation
import SymbolKit
import DocCCommon

/// A type that encapsulates resolving links by searching a hierarchy of path components.
final class PathHierarchyBasedLinkResolver {
    /// A hierarchy of path components used to resolve links in the documentation.
    private(set) var pathHierarchy: PathHierarchy
    
    /// Map between resolved identifiers and resolved topic references.
    private(set) var resolvedReferenceMap = BidirectionalMap<ResolvedIdentifier, ResolvedTopicReference>()
    
    /// Initializes a link resolver with a given path hierarchy.
    init(pathHierarchy: PathHierarchy) {
        self.pathHierarchy = pathHierarchy
    }
    
    /// Creates a path string---that can be used to find documentation in the path hierarchy---from an unresolved topic reference,
    private static func path(for unresolved: UnresolvedTopicReference) -> String {
        guard let fragment = unresolved.fragment else {
            return unresolved.path
        }
        return "\(unresolved.path)#\(urlReadableFragment(fragment))"
    }
    
    /// Traverse all the pairs of symbols and their parents and counterpart parents.
    func traverseSymbolAndParents(_ observe: (_ symbol: ResolvedTopicReference, _ parent: ResolvedTopicReference, _ counterpartParent: ResolvedTopicReference?) -> Void) {
        let swiftLanguageID = SourceLanguage.swift.id
        for (id, node) in pathHierarchy.lookup {
            guard let symbol = node.symbol,
                  let parentID = node.parent?.identifier,
                  // Symbols that exist in more than one source language may have more than one parent.
                  // If this symbol has language counterparts, only call `observe` for one of the counterparts.
                  node.counterpart == nil || symbol.identifier.interfaceLanguage == swiftLanguageID
            else { continue }
                
            // Only symbols in the symbol index are added to the reference map.
            guard let reference = resolvedReferenceMap[id], let parentReference = resolvedReferenceMap[parentID] else { continue }
           
            observe(reference, parentReference, node.counterpart?.parent?.identifier.flatMap { resolvedReferenceMap[$0] })
        }
    }

    /// Returns the direct descendants of the given page that match the given source language filter.
    ///
    /// A descendant is included if it has a language representation in at least one of the languages in the given language filter or if the language filter is empty.
    ///
    /// - Parameters:
    ///   - reference: The identifier of the page whose descendants to return.
    ///   - languagesFilter: A set of source languages to filter descendants against.
    /// - Returns: The references of each direct descendant that has a language representation in at least one of the given languages.
    func directDescendants(of reference: ResolvedTopicReference, languagesFilter: SmallSourceLanguageSet) -> Set<ResolvedTopicReference> {
        guard let id = resolvedReferenceMap[reference] else { return [] }
        let node = pathHierarchy.lookup[id]!
        
        func directDescendants(of node: PathHierarchy.Node) -> [ResolvedTopicReference] {
            return node.children.flatMap { _, container in
                container.storage.compactMap { element in
                    guard let childID = element.node.identifier, // Don't include sparse nodes
                          !element.node.isExcludedFromAutomaticCuration,
                          element.node.matches(languagesFilter: languagesFilter)
                    else {
                        return nil
                    }
                    return resolvedReferenceMap[childID]
                }
            }
        }
        
        var results = Set<ResolvedTopicReference>()
        if node.matches(languagesFilter: languagesFilter) {
            results.formUnion(directDescendants(of: node))
        }
        if let counterpart = node.counterpart, counterpart.matches(languagesFilter: languagesFilter) {
            results.formUnion(directDescendants(of: counterpart))
        }
        return results
    }

    /// Returns a list of all the top level symbols.
    func topLevelSymbols() -> [ResolvedTopicReference] {
        return pathHierarchy.topLevelSymbols().map { resolvedReferenceMap[$0]! }
    }
    
    /// Returns a list of all root pages (both modules and technology roots).
    func rootPages() -> [ResolvedTopicReference] {
        return pathHierarchy.modules.map { resolvedReferenceMap[$0.identifier]! }
    }
    
    // MARK: - Adding non-symbols
    
    /// Map the resolved identifiers to resolved topic references for a given bundle's article, tutorial, and technology root pages.
    func addMappingForRoots(bundle: DocumentationBundle) {
        resolvedReferenceMap[pathHierarchy.tutorialContainer.identifier] = bundle.tutorialsContainerReference
        resolvedReferenceMap[pathHierarchy.articlesContainer.identifier] = bundle.articlesDocumentationRootReference
        resolvedReferenceMap[pathHierarchy.tutorialOverviewContainer.identifier] = bundle.tutorialTableOfContentsContainer
    }
    
    /// Map the resolved identifiers to resolved topic references for all symbols in the given symbol index.
    func addMappingForSymbols(localCache: DocumentationContext.LocalCache) {
        for (id, node) in pathHierarchy.lookup {
            guard let symbol = node.symbol, let reference = localCache.reference(symbolID: symbol.identifier.precise) else {
                continue
            }
            // Our bidirectional dictionary doesn't support nil values.
            resolvedReferenceMap[id] = reference
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
    
    private func addTutorial(reference: ResolvedTopicReference, source: URL, landmarks: [any Landmark]) {
        let tutorialID = pathHierarchy.addTutorial(name: linkName(filename: source.deletingPathExtension().lastPathComponent))
        resolvedReferenceMap[tutorialID] = reference
        
        for landmark in landmarks {
            let landmarkID = pathHierarchy.addNonSymbolChild(parent: tutorialID, name: urlReadableFragment(landmark.title), kind: "landmark")
            resolvedReferenceMap[landmarkID] = reference.withFragment(landmark.title)
        }
    }
    
    /// Adds a tutorial table-of-contents page and its volumes and chapters to the path hierarchy.
    func addTutorialTableOfContents(_ tutorialTableOfContents: DocumentationContext.SemanticResult<TutorialTableOfContents>) {
        let reference = tutorialTableOfContents.topicGraphNode.reference

        let tutorialTableOfContentsID = pathHierarchy.addTutorialOverview(name: linkName(filename: tutorialTableOfContents.source.deletingPathExtension().lastPathComponent))
        resolvedReferenceMap[tutorialTableOfContentsID] = reference

        var anonymousVolumeID: ResolvedIdentifier?
        for volume in tutorialTableOfContents.value.volumes {
            if anonymousVolumeID == nil, volume.name == nil {
                anonymousVolumeID = pathHierarchy.addNonSymbolChild(parent: tutorialTableOfContentsID, name: "$volume", kind: "volume")
                resolvedReferenceMap[anonymousVolumeID!] = reference.appendingPath("$volume")
            }
            
            let chapterParentID: ResolvedIdentifier
            let chapterParentReference: ResolvedTopicReference
            if let name = volume.name {
                chapterParentID = pathHierarchy.addNonSymbolChild(parent: tutorialTableOfContentsID, name: name, kind: "volume")
                chapterParentReference = reference.appendingPath(name)
                resolvedReferenceMap[chapterParentID] = chapterParentReference
            } else {
                chapterParentID = tutorialTableOfContentsID
                chapterParentReference = reference
            }
            
            for chapter in volume.chapters {
                let chapterID = pathHierarchy.addNonSymbolChild(parent: tutorialTableOfContentsID, name: chapter.name, kind: "volume")
                resolvedReferenceMap[chapterID] = chapterParentReference.appendingPath(chapter.name)
            }
        }
    }
    
    /// Adds a technology root article and its headings to the path hierarchy.
    func addRootArticle(_ article: DocumentationContext.SemanticResult<Article>, anchorSections: [AnchorSection]) {
        let linkName = linkName(filename: article.source.deletingPathExtension().lastPathComponent)
        let articleID = pathHierarchy.addTechnologyRoot(name: linkName)
        resolvedReferenceMap[articleID] = article.topicGraphNode.reference
        addAnchors(anchorSections, to: articleID)
    }
    
    /// Adds an article and its headings to the path hierarchy.
    func addArticle(_ article: DocumentationContext.SemanticResult<Article>, anchorSections: [AnchorSection]) {
        addArticle(filename: article.source.deletingPathExtension().lastPathComponent, reference: article.topicGraphNode.reference, anchorSections: anchorSections)
    }
    
    /// Adds an article and its headings to the path hierarchy.
    func addArticle(filename: String, reference: ResolvedTopicReference, anchorSections: [AnchorSection]) {
        let articleID = pathHierarchy.addArticle(name: linkName(filename: filename))
        resolvedReferenceMap[articleID] = reference
        addAnchors(anchorSections, to: articleID)
    }
    
    /// Adds the headings for all symbols in the symbol index to the path hierarchy.
    func addAnchorForSymbols(localCache: DocumentationContext.LocalCache) {
        for (id, node) in pathHierarchy.lookup {
            guard let symbol = node.symbol, let node = localCache[symbol.identifier.precise] else { continue }
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
        let taskGroupID = pathHierarchy.addNonSymbolChild(parent: parentID, name: urlReadableFragment(name), kind: "taskGroup")
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
    func resolve(_ unresolvedReference: UnresolvedTopicReference, in parent: ResolvedTopicReference, fromSymbolLink isCurrentlyResolvingSymbolLink: Bool) throws(PathHierarchy.Error) -> TopicReferenceResolutionResult {
        let parentID = resolvedReferenceMap[parent]
        let found = try pathHierarchy.find(path: Self.path(for: unresolvedReference), parent: parentID, onlyFindSymbols: isCurrentlyResolvingSymbolLink)
        guard let foundReference = resolvedReferenceMap[found] else {
            // It's possible for the path hierarchy to find a symbol that the local build doesn't create a page for. Such symbols can't be linked to.
            let simplifiedFoundPath = sequence(first: pathHierarchy.lookup[found]!, next: \.parent)
                .map(\.name).reversed().joined(separator: "/")
            return .failure(unresolvedReference, .init("\(simplifiedFoundPath.singleQuoted) has no page and isn't available for linking."))
        }
        
        return .success(foundReference)
    }
    
    func fullName(of node: PathHierarchy.Node, in context: DocumentationContext) -> String {
        guard let identifier = node.identifier else { return node.name }
        if let symbol = node.symbol {
            // Use the simple title for overload group symbols to avoid showing detailed type info
            if !symbol.isOverloadGroup, let fragments = symbol.declarationFragments {
                return fragments.map(\.spelling).joined().split(whereSeparator: { $0.isWhitespace || $0.isNewline }).joined(separator: " ")
            }
            return symbol.names.title
        }
        let reference = resolvedReferenceMap[identifier]!
        if reference.fragment != nil {
            return context.nodeAnchorSections[reference]!.title
        } else {
            return context.documentationCache[reference]!.name.description
        }
    }
    
    // MARK: Symbol reference creation
    
    /// Returns a map between symbol identifiers and topic references.
    ///
    /// - Parameters:
    ///   - symbolGraph: The complete symbol graph to walk through.
    ///   - context: The context that the symbols are a part of.
    func referencesForSymbols(in unifiedGraphs: [String: UnifiedSymbolGraph], context: DocumentationContext) -> [SymbolGraph.Symbol.Identifier: ResolvedTopicReference] {
        let disambiguatedPaths = pathHierarchy.caseInsensitiveDisambiguatedPaths(includeDisambiguationForUnambiguousChildren: true, includeLanguage: true, allowAdvancedDisambiguation: false)
        
        var result: [SymbolGraph.Symbol.Identifier: ResolvedTopicReference] = [:]
        
        for (moduleName, symbolGraph) in unifiedGraphs {
            let paths: [ResolvedTopicReference?] = Array(symbolGraph.symbols.values).concurrentMap { unifiedSymbol -> ResolvedTopicReference? in
                let symbol = unifiedSymbol
                let uniqueIdentifier = unifiedSymbol.uniqueIdentifier
                
                if let pathComponents = context.configuration.convertServiceConfiguration.knownDisambiguatedSymbolPathComponents?[uniqueIdentifier],
                   let componentsCount = symbol.defaultSymbol?.pathComponents.count,
                   pathComponents.count == componentsCount
                {
                    let symbolReference = SymbolReference(pathComponents: pathComponents, interfaceLanguages: symbol.sourceLanguages)
                    return ResolvedTopicReference(symbolReference: symbolReference, moduleName: moduleName, bundle: context.inputs)
                }
                
                guard let path = disambiguatedPaths[uniqueIdentifier] else {
                    return nil
                }
                
                return ResolvedTopicReference(
                    bundleID: context.inputs.documentationRootReference.bundleID,
                    path: NodeURLGenerator.Path.documentationFolder + path,
                    sourceLanguages: symbol.sourceLanguages
                )
            }
            for (symbol, reference) in zip(symbolGraph.symbols.values, paths) {
                guard let reference else { continue }
                result[symbol.defaultIdentifier] = reference
            }
        }
        return result
    }
    
    // MARK: Links
    
    /// Determines the disambiguated relative links of all the direct descendants of the given page.
    ///
    /// - Parameters:
    ///   - reference: The identifier of the page whose descendants to generate relative links for.
    /// - Returns: A map topic references to pairs of links and flags indicating if the link is disambiguated or not.
    func disambiguatedRelativeLinksForDescendants(of reference: ResolvedTopicReference) -> [ResolvedTopicReference: (link: String, hasDisambiguation: Bool)] {
        guard let nodeID = resolvedReferenceMap[reference] else { return [:] }
        
        let links = pathHierarchy.disambiguatedChildLinks(of: nodeID)
        var result = [ResolvedTopicReference: (link: String, hasDisambiguation: Bool)]()
        result.reserveCapacity(links.count)
        for (id, link) in links {
            guard let reference = resolvedReferenceMap[id] else { continue }
            result[reference] = link
        }
        return result
    }
}

/// Creates a more writable version of an articles file name for use in documentation links.
///
/// Compared to `urlReadablePath(_:)` this preserves letters in other written languages.
private func linkName(filename: some StringProtocol) -> String {
    // It would be a nice enhancement to also remove punctuation from the filename to allow an article in a file named "One, two, & three!"
    // to be referenced with a link as `"One-two-three"` instead of `"One,-two-&-three!"` (rdar://120722917)
    return filename
        // Replace continuous whitespace and dashes
        .components(separatedBy: whitespaceAndDashes)
        .filter({ !$0.isEmpty })
        .joined(separator: "-")
}

private let whitespaceAndDashes = CharacterSet.whitespaces
    .union(CharacterSet(charactersIn: "-\u{2013}\u{2014}")) // hyphen, en dash, em dash

private extension PathHierarchy.Node {
    func matches(languagesFilter: SmallSourceLanguageSet) -> Bool {
        languagesFilter.isEmpty || !self.languages.isDisjoint(with: languagesFilter)
    }
}
