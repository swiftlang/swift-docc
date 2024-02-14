/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2023-2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SymbolKit

/// A class that resolves documentation links by orchestrating calls to other link resolver implementations.
public class LinkResolver {
    /// A list of URLs to documentation archives that the local documentation depends on.
    @_spi(ExternalLinks) // This needs to be public SPI so that the ConvertAction can set it.
    public var dependencyArchives: [URL] = []
    
    var fileManager: FileManagerProtocol = FileManager.default
    /// The link resolver to use to resolve links in the local bundle
    var localResolver: PathHierarchyBasedLinkResolver!
    /// A fallback resolver to use when the local resolver fails to resolve a link.
    ///
    /// This exist to preserve some behaviors for the convert service.
    private let fallbackResolver = FallbackResolverBasedLinkResolver()
    /// A map of link resolvers for external, already build archives
    var externalResolvers: [String: ExternalPathHierarchyResolver] = [:]
    
    /// Create link resolvers for all documentation archive dependencies.
    func loadExternalResolvers() throws {
        let resolvers = try dependencyArchives.compactMap {
            try ExternalPathHierarchyResolver(dependencyArchive: $0, fileManager: fileManager)
        }
        for resolver in resolvers {
            for moduleNode in resolver.pathHierarchy.modules {
                self.externalResolvers[moduleNode.name] = resolver
            }
        }
    }
    
    /// The minimal information about an external entity necessary to render links to it on another page.
    @_spi(ExternalLinks) // This isn't stable API yet.
    public struct ExternalEntity {
        /// Creates a new external entity.
        /// - Parameters:
        ///   - topicRenderReference: The render reference for this external topic.
        ///   - renderReferenceDependencies: Any dependencies for the render reference.
        ///   - sourceLanguages: The different source languages for which this page is available.
        @_spi(ExternalLinks)
        public init(topicRenderReference: TopicRenderReference, renderReferenceDependencies: RenderReferenceDependencies, sourceLanguages: Set<SourceLanguage>) {
            self.topicRenderReference = topicRenderReference
            self.renderReferenceDependencies = renderReferenceDependencies
            self.sourceLanguages = sourceLanguages
        }
        
        /// The render reference for this external topic.
        var topicRenderReference: TopicRenderReference
        /// Any dependencies for the render reference.
        ///
        /// For example, if the external content contains links or images, those are included here.
        var renderReferenceDependencies: RenderReferenceDependencies
        /// The different source languages for which this page is available.
        var sourceLanguages: Set<SourceLanguage>
        
        /// Creates a pre-render new topic content value to be added to a render context's reference store.
        func topicContent() -> RenderReferenceStore.TopicContent {
            return .init(
                renderReference: topicRenderReference,
                canonicalPath: nil,
                taskGroups: nil,
                source: nil,
                isDocumentationExtensionContent: false,
                renderReferenceDependencies: renderReferenceDependencies
            )
        }
    }
    
    /// Attempts to resolve an unresolved reference.
    ///
    /// - Parameters:
    ///   - unresolvedReference: The unresolved reference to resolve.
    ///   - parent: The parent reference to resolve the unresolved reference relative to.
    ///   - isCurrentlyResolvingSymbolLink: Whether or not the documentation link is a symbol link.
    ///   - context: The documentation context to resolve the link in.
    /// - Returns: The result of resolving the reference.
    func resolve(_ unresolvedReference: UnresolvedTopicReference, in parent: ResolvedTopicReference, fromSymbolLink isCurrentlyResolvingSymbolLink: Bool, context: DocumentationContext) -> TopicReferenceResolutionResult {
        // Check if the unresolved reference is external
        if let bundleID = unresolvedReference.bundleIdentifier,
           !context.registeredBundles.contains(where: { bundle in
               bundle.identifier == bundleID || urlReadablePath(bundle.displayName) == bundleID
           }) {
            if context.externalDocumentationSources[bundleID] != nil,
               let resolvedExternalReference = context.externallyResolvedLinks[unresolvedReference.topicURL] {
                // Return the successful or failed externally resolved reference.
                return resolvedExternalReference
            } else if !context.registeredBundles.contains(where: { $0.identifier == bundleID }) {
                return .failure(unresolvedReference, TopicReferenceResolutionErrorInfo("No external resolver registered for \(bundleID.singleQuoted)."))
            }
        }
        
        if let previousExternalResult = context.externallyResolvedLinks[unresolvedReference.topicURL] {
            return previousExternalResult
        }
        
        do {
            return try localResolver.resolve(unresolvedReference, in: parent, fromSymbolLink: isCurrentlyResolvingSymbolLink)
        } catch let error as PathHierarchy.Error {
            // Check if there's a known external resolver for this module.
            if case .moduleNotFound(_, let remainingPathComponents, _) = error, let resolver = externalResolvers[remainingPathComponents.first!.full] {
                let result = resolver.resolve(unresolvedReference, fromSymbolLink: isCurrentlyResolvingSymbolLink)
                context.externallyResolvedLinks[unresolvedReference.topicURL] = result
                if case .success(let resolved) = result {
                    context.externalCache[resolved] = resolver.entity(resolved)
                }
                return result
            }
            
            // If the reference didn't resolve in the path hierarchy, see if it can be resolved in the fallback resolver.
            if let resolvedFallbackReference = fallbackResolver.resolve(unresolvedReference, in: parent, fromSymbolLink: isCurrentlyResolvingSymbolLink, context: context) {
                return .success(resolvedFallbackReference)
            } else {
                return .failure(unresolvedReference, error.makeTopicReferenceResolutionErrorInfo() { localResolver.fullName(of: $0, in: context) })
            }
        } catch {
            fatalError("Only SymbolPathTree.Error errors are raised from the symbol link resolution code above.")
        }
    }
}

// MARK: Fallback resolver

extension DocumentationContext {
    /// Merge links to local pages resolved via the fallback resolver with the context.
    func mergeFallbackLinkResolutionResults() {
        linkResolver.mergeFallbackLinkResolutionResults(context: self)
    }
}

private extension LinkResolver {
    func mergeFallbackLinkResolutionResults(context: DocumentationContext) {
        let resolvedFallbackReferences = fallbackResolver.cachedResolvedFallbackResults.sync({ $0 })
        for (linkText, result) in resolvedFallbackReferences {
            // Even though the links resolved via the fallback resolver represent "local" pages they are considered "external" content
            // because their markup or symbol information wasn't passed as catalog or symbol graph input to DocC. 
            context.externallyResolvedLinks[linkText] = result
            if case .success(let reference) = result {
                context.externalCache[reference] = context.convertServiceFallbackResolver?.entityIfPreviouslyResolved(with: reference)
            }
        }
    }
}

/// A fallback resolver that replicates the exact order of resolved topic references that are attempted to resolve via a fallback resolver when the path hierarchy doesn't have a match.
private final class FallbackResolverBasedLinkResolver {
    var cachedResolvedFallbackResults = Synchronized<[ValidatedURL: TopicReferenceResolutionResult]>([:])
    
    func resolve(_ unresolvedReference: UnresolvedTopicReference, in parent: ResolvedTopicReference, fromSymbolLink isCurrentlyResolvingSymbolLink: Bool, context: DocumentationContext) -> ResolvedTopicReference? {
        let result: TopicReferenceResolutionResult? = resolve(unresolvedReference, in: parent, fromSymbolLink: isCurrentlyResolvingSymbolLink, context: context)
        guard case .success(let resolved) = result else { return nil }
        return resolved
    }
    
    private func resolve(_ unresolvedReference: UnresolvedTopicReference, in parent: ResolvedTopicReference, fromSymbolLink isCurrentlyResolvingSymbolLink: Bool, context: DocumentationContext) -> TopicReferenceResolutionResult? {
        // Check if a fallback reference resolver should resolve this
        let referenceBundleIdentifier = unresolvedReference.bundleIdentifier ?? parent.bundleIdentifier
        guard let fallbackResolver = context.convertServiceFallbackResolver,
              let knownBundleIdentifier = context.registeredBundles.first(where: { $0.identifier == referenceBundleIdentifier || urlReadablePath($0.displayName) == referenceBundleIdentifier })?.identifier
        else {
            return nil
        }
        
        if let cached = cachedResolvedFallbackResults.sync({ $0[unresolvedReference.topicURL] }) {
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
            guard let candidateReference = ValidatedURL(candidateURL).map({ UnresolvedTopicReference(topicURL: $0) }) else {
                continue
            }
            if let cached = cachedResolvedFallbackResults.sync({ $0[candidateReference.topicURL] }) {
                return cached
            }
            let fallbackResult = fallbackResolver.resolve(.unresolved(candidateReference))
            // Regardless of the outcome, cache the result of each candidate so that they're not resolved more than once.
            cachedResolvedFallbackResults.sync({ $0[candidateReference.topicURL] = fallbackResult })
            
            if case .success(let resolvedReference) = fallbackResult {
                // Cache the resolved reference's URL as well in case it's different from the unresolved reference.
                cachedResolvedFallbackResults.sync({
                    // Cache both the original unresolved reference and the resolved reference.
                    $0[unresolvedReference.topicURL] = fallbackResult
                    if let url = ValidatedURL(resolvedReference.url) {
                        $0[url] = fallbackResult
                    }
                })
                return fallbackResult
            }
        }
        // Give up: there is no local or external document for this reference.
        return nil
    }
}
