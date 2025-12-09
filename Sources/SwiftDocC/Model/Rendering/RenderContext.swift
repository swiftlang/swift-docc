/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SymbolKit

/// A context object that pre-renders commonly used pieces of content.
///
/// Use this object for a fast pre-rendered content lookup when you are
/// converting nodes in bulk, i.e. when converting a complete documentation model for example.
public struct RenderContext {
    let documentationContext: DocumentationContext
    let renderer: DocumentationContentRenderer
    
    /// Creates a new render context.
    /// - Warning: Creating a render context pre-renders all content that the context provides.
    /// - Parameters:
    ///   - documentationContext: A documentation context.
    public init(documentationContext: DocumentationContext) {
        self.documentationContext = documentationContext
        self.renderer = DocumentationContentRenderer(context: documentationContext)
        createRenderedContent()
    }
    
    @available(*, deprecated, renamed: "init(context:)", message: "Use 'init(context:)' instead. This deprecated API will be removed after 6.4 is released.")
    public init(documentationContext: DocumentationContext, bundle _: DocumentationBundle) {
        self.init(documentationContext: documentationContext)
    }
    
    /// The pre-rendered content per node reference.
    private(set) public var store = RenderReferenceStore()
    
    /// Creates a set of commonly used pieces of content using the nodes in the given documentation context.
    /// - Note: On macOS and iOS this function creates the content concurrently.
    private mutating func createRenderedContent() {
        let references = documentationContext.knownIdentifiers
        var topics = [ResolvedTopicReference: RenderReferenceStore.TopicContent]()
        
        let renderContentFor: (ResolvedTopicReference) -> RenderReferenceStore.TopicContent = { [renderer, documentationContext] reference in
            var dependencies = RenderReferenceDependencies()
            let renderReference = renderer.renderReference(for: reference, dependencies: &dependencies)
            let canonicalPath = documentationContext.shortestFinitePath(to: reference).flatMap { $0.isEmpty ? nil : $0 }
            let reverseLookup = renderer.taskGroups(for: reference)
            
            return RenderReferenceStore.TopicContent(
                renderReference: renderReference,
                canonicalPath: canonicalPath,
                taskGroups: reverseLookup,
                source: documentationContext.documentLocationMap[reference],
                // Uncurated documentation extensions aren't part of `DocumentationContext.knownIdentifiers`, so none of
                // these references are documentation extensions.
                isDocumentationExtensionContent: false,
                renderReferenceDependencies: dependencies
            )
        }
        
        #if os(macOS) || os(iOS) || os(Android) || os(Windows) || os(FreeBSD) || os(OpenBSD)
        // Concurrently render content on macOS/iOS, Windows & Android
        let results: [(reference: ResolvedTopicReference, content: RenderReferenceStore.TopicContent)] = references.concurrentPerform { reference, results in
            results.append((reference, renderContentFor(reference)))
        }
        for result in results {
            topics[result.reference] = result.content
        }
        
        #elseif os(Linux)
        // Serially render on Linux
        references.forEach {
            topics[$0] = renderContentFor($0)
        }
        #else
        #error("Unexpected platform.")
        #endif
        
        let assets = documentationContext.assetManagers
            .reduce(into: [AssetReference: DataAsset]()) { (storage, element) in
                let (bundleID, assetManager) = element
            
                for (name, asset) in assetManager.storage {
                    storage[AssetReference(assetName: name, bundleID: bundleID)] = asset
                }
            }
        
        // Add all the external content to the topic store
        for (reference, entity) in documentationContext.externalCache {
            topics[reference] = entity.makeTopicContent()
            
            // Also include transitive dependencies in the store, so that the external entity can reference them.
            for case let dependency as TopicRenderReference in (entity.references ?? []) {
                guard let url = URL(string: dependency.identifier.identifier), let rawBundleID = url.host else {
                    // This dependency doesn't have a valid topic reference, skip adding it to the render context.
                    continue
                }
                
                let dependencyReference = ResolvedTopicReference(
                    bundleID: .init(rawValue: rawBundleID),
                    path: url.path,
                    fragment: url.fragment,
                    // TopicRenderReference doesn't have language information. Also, the reference's languages _doesn't_ specify the languages of the linked entity.
                    sourceLanguages: reference._sourceLanguages
                )
                topics[dependencyReference] = .init(renderReference: dependency, canonicalPath: nil, taskGroups: nil, source: nil, isDocumentationExtensionContent: false)
            }
        }
        
        self.store = RenderReferenceStore(topics: topics, assets: assets)
    }
}
