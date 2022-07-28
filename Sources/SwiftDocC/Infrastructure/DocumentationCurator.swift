/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown
import SymbolKit

/// Crawls a context and curates nodes if necessary.
struct DocumentationCurator {
    /// The documentation context to crawl.
    private let context: DocumentationContext
    
    /// The current bundle.
    private let bundle: DocumentationBundle
    
    private(set) var problems = [Problem]()
    
    init(in context: DocumentationContext, bundle: DocumentationBundle, initial: Set<ResolvedTopicReference> = []) {
        self.context = context
        self.bundle = bundle
        self.curatedNodes = initial
    }
    
    /// The list of topics that have been curated during the crawl.
    private(set) var curatedNodes: Set<ResolvedTopicReference>
    
    /// Tries to resolve a symbol link in the current module/context.
    func referenceFromSymbolLink(link: SymbolLink, resolved: ResolvedTopicReference) -> ResolvedTopicReference? {
        guard let destination = link.destination else {
            return nil
        }
        
        // Optimization for absolute links.
        if let cached = context.documentationCacheBasedLinkResolver.referenceFor(absoluteSymbolPath: destination, parent: resolved) {
            return cached
        }
        
        // The symbol link may be written with a scheme and bundle identifier.
        let url = ValidatedURL(parsingExact: destination)?.requiring(scheme: ResolvedTopicReference.urlScheme) ?? ValidatedURL(symbolPath: destination)
        if case let .success(resolved) = context.resolve(.unresolved(.init(topicURL: url)), in: resolved, fromSymbolLink: true) {
            return resolved
        }
        return nil
    }
    
    /// Tries to resolve a link in the current module/context.
    mutating func referenceFromLink(link: Link, resolved: ResolvedTopicReference, source: URL?) -> ResolvedTopicReference? {
        // Try a link to a topic
        guard let unresolved = link.destination.flatMap(ValidatedURL.init(parsingAuthoredLink:))?
            .requiring(scheme: ResolvedTopicReference.urlScheme)
            .map(UnresolvedTopicReference.init(topicURL:)) else {
                // Emit a warning regarding the invalid link found in a task group.
                problems.append(Problem(diagnostic: Diagnostic(source: source, severity: .warning, range: link.range, identifier: "org.swift.docc.InvalidDocumentationLink", summary: "The link \((link.destination ?? "").singleQuoted) isn't valid", explanation: "Expected a well-formed URL that uses the \(ResolvedTopicReference.urlScheme.singleQuoted) scheme. You can only curate external links in a 'See Also' section."), possibleSolutions: []))
                return nil
        }
        let maybeResolved = context.resolve(.unresolved(unresolved), in: resolved)
        
        if case let .success(resolved) = maybeResolved {
            // The link resolves to a known topic.
            if let node = context.topicGraph.nodeWithReference(resolved) {
                // Make sure to remove any articles that have been registered in the topic graph
                // from the context's uncurated articles
                if node.kind == .article, context.uncuratedArticles.keys.contains(resolved) {
                    context.uncuratedArticles.removeValue(forKey: resolved)
                }
                return resolved
            }
            // The link resolves to a known content section, emit a warning.
            if resolved.fragment != nil, context.nodeAnchorSections.keys.contains(resolved) {
                problems.append(Problem(diagnostic: Diagnostic(source: source, severity: .warning, range: link.range, identifier: "org.swift.docc.SectionCuration", summary: "The content section link \((link.destination ?? "").singleQuoted) isn't allowed in a Topics link group", explanation: "Content sections cannot participate in the documentation hierarchy."), possibleSolutions: []))
                return resolved
            }
        }
        
        // Check if the link has been externally resolved already.
        if let bundleID = unresolved.topicURL.components.host,
           context.externalReferenceResolvers[bundleID] != nil || context.fallbackReferenceResolvers[bundleID] != nil {
            if case .success(let resolvedExternalReference) = context.externallyResolvedLinks[unresolved.topicURL] {
                return resolvedExternalReference
            } else {
                return nil // This link has already failed to resolve.
            }
        }
        
        // Try extracting an article from the cache
        let articleFilename = unresolved.topicURL.components.path.components(separatedBy: "/").last!
        let sourceArticlePath = NodeURLGenerator.Path.article(bundleName: bundle.displayName, articleName: articleFilename).stringValue
        
        let reference = ResolvedTopicReference(
            bundleIdentifier: resolved.bundleIdentifier,
            path: sourceArticlePath,
            sourceLanguages: resolved.sourceLanguages)
        
        guard let currentArticle = self.context.uncuratedArticles[reference],
            let documentationNode = try? DocumentationNode(reference: reference, article: currentArticle.value) else { return nil }
        
        // An article has been found which needs to be extracted from the article cache
        // and curated under the current symbol. To do this we need to re-create the reference
        // to include the current module, update the file location map, and create a new
        // documentation node with the new reference and new semantic article.
        
        // Add reference in the file location map
        context.documentLocationMap[currentArticle.source] = reference
        
        // Add the curated node to the topic graph
        let node = currentArticle.topicGraphNode
        let curatedNode = TopicGraph.Node(reference: reference, kind: node.kind, source: node.source, title: node.title)
        context.topicGraph.addNode(curatedNode)
        
        // Move the article from the article cache to the documentation
        
        if let hierarchyBasedLinkResolver = context.hierarchyBasedLinkResolver {
            hierarchyBasedLinkResolver.addArticle(filename: articleFilename, reference: reference, anchorSections: documentationNode.anchorSections)
        }
        
        context.documentationCache[reference] = documentationNode
        for anchor in documentationNode.anchorSections {
            context.nodeAnchorSections[anchor.reference] = anchor
        }
        context.uncuratedArticles.removeValue(forKey: reference)
        
        return reference
    }
    
    private func isReference(_ childReference: ResolvedTopicReference, anAncestorOf nodeReference: ResolvedTopicReference) -> Bool {
        return context.pathsTo(nodeReference).contains { $0.contains(childReference) }
    }
    
    /// Crawls the topic graph starting at a given root node, curates articles during.
    /// - Parameters:
    ///   - nodeReference: The root reference to start crawling.
    ///   - prepareForCuration: An optional closure to call just before walking the node's task group links.
    ///   - relateNodes: A closure to call when a parent <-> child relationship is found.
    mutating func crawlChildren(of nodeReference: ResolvedTopicReference, prepareForCuration: (ResolvedTopicReference) -> Void = {_ in}, relateNodes: (ResolvedTopicReference, ResolvedTopicReference) -> Void) throws {
        // Keeping track if all articles have been curated.
        curatedNodes.insert(nodeReference)

        guard let documentationNode = context.documentationCache[nodeReference] else {
            return
        }

        func source() -> URL? {
            return context.documentLocationMap[nodeReference]
        }
        
        let topics: TopicsSection?
        let seeAlso: SeeAlsoSection?
        let automaticallyGeneratedTaskGroups: [AutomaticTaskGroupSection]?
        
        switch documentationNode.semantic {
        case let article as Article:
            topics = article.topics
            seeAlso = article.seeAlso
            automaticallyGeneratedTaskGroups = article.automaticTaskGroups
        case let symbol as Symbol:
            topics = symbol.topics
            seeAlso = symbol.seeAlso
            automaticallyGeneratedTaskGroups = symbol.automaticTaskGroups
        default:
            topics = nil
            seeAlso = nil
            automaticallyGeneratedTaskGroups = nil
        }

        let taskGroups = topics?.taskGroups ?? []
        let authoredSeeAlsoGroups = seeAlso?.taskGroups ?? []
        let addedGroups = automaticallyGeneratedTaskGroups ?? []
        
        // Validate the node groups' links
        (taskGroups + authoredSeeAlsoGroups).forEach({ group in
            problems.append(contentsOf:
                group.problemsForGroupLinks().map({ problem -> Problem in
                    var diagnostic = problem.diagnostic
                    diagnostic.source = context.documentLocationMap[nodeReference]
                    return Problem(diagnostic: diagnostic, possibleSolutions: problem.possibleSolutions)
                })
            )
        })

        // Crawl the automated curation
        try addedGroups.forEach { section in
            try section.references.forEach { childReference in
                // Descend further into curated topics
                try crawlChildren(of: childReference, prepareForCuration: prepareForCuration, relateNodes: relateNodes)
            }
        }
        
        // If the node docs include a topics section, remove the default curation
        // from the symbol graph because we will do custom curation based on the
        // task group links.
        prepareForCuration(nodeReference)
        
        for (groupIndex, group) in taskGroups.enumerated() {
            for (linkIndex, link) in group.links.enumerated() {
                let resolved: ResolvedTopicReference?
                switch link {
                case let link as Link:
                    resolved = referenceFromLink(link: link, resolved: nodeReference, source: source())
                case let symbolLink as SymbolLink:
                    resolved = referenceFromSymbolLink(link: symbolLink, resolved: nodeReference)
                default:
                    // Programmer error, a new conformance was added to ``AnyLink``
                    fatalError("Unexpected link type")
                }
                
                /// Return the link's range or, when unavailable, fall back on any original ranges.
                func range() -> SourceRange? {
                    if let range = link.range {
                        return range
                    }
                    if let topics = topics,
                        topics.originalLinkRangesByGroup.count > groupIndex,
                        topics.originalLinkRangesByGroup[groupIndex].count > linkIndex {
                        return topics.originalLinkRangesByGroup[groupIndex][linkIndex]
                    }
                    return nil
                }
                
                guard let childReference = resolved else {
                    // This problem will be raised when the references are resolved.
                    continue
                }

                guard let childDocumentationNode = context.documentationCache[childReference],
                    (childDocumentationNode.kind == .article || childDocumentationNode.kind.isSymbol || childDocumentationNode.kind == .tutorial || childDocumentationNode.kind == .tutorialArticle) else {
                        continue
                }
                
                guard childDocumentationNode.kind != .module else {
                    problems.append(Problem(diagnostic: Diagnostic(source: source(), severity: .warning, range: range(), identifier: "org.swift.docc.ModuleCuration", summary: "Linking to \((link.destination ?? "").singleQuoted) from a Topics group in \(nodeReference.absoluteString.singleQuoted) isn't allowed", explanation: "The former is a module, and modules only exist at the root"), possibleSolutions: []))
                    continue
                }
                
                // Verify we are not creating a graph cyclic relationship.
                guard childReference != nodeReference else {
                    problems.append(Problem(diagnostic: Diagnostic(source: source(), severity: .warning, range: range(), identifier: "org.swift.docc.CyclicReference", summary: "A symbol can't link to itself from within its Topics group in \(nodeReference.absoluteString.singleQuoted)"), possibleSolutions: []))
                    continue
                }
                
                guard !isReference(childReference, anAncestorOf: nodeReference) else {
                    problems.append(Problem(diagnostic: Diagnostic(source: source(), severity: .warning, range: range(), identifier: "org.swift.docc.CyclicReference", summary: "Linking to \((link.destination ?? "").singleQuoted) from a Topics group in \(nodeReference.absoluteString.singleQuoted) isn't allowed", explanation: "The former is an ancestor of the latter"), possibleSolutions: []))
                    continue
                }
                
                // Link reference successfully resolved to a topic node
                relateNodes(nodeReference, childReference)
                
                guard !curatedNodes.contains(childReference) else {
                    // Don't crawl the same symbol more than once. 
                    continue
                }
                
                // Descend further into curated topics
                try crawlChildren(of: childReference, prepareForCuration: prepareForCuration, relateNodes: relateNodes)
            }
        }
    }
}
