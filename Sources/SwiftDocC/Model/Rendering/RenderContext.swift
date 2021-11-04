/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
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
    let bundle: DocumentationBundle
    let renderer: DocumentationContentRenderer
    
    /// Creates a new render context.
    /// - Warning: Creating a render context pre-renders all content that the context provides.
    /// - Parameters:
    ///   - documentationContext: A documentation context.
    ///   - bundle: A documentation bundle.
    public init(documentationContext: DocumentationContext, bundle: DocumentationBundle) {
        self.documentationContext = documentationContext
        self.bundle = bundle
        self.renderer = DocumentationContentRenderer(documentationContext: documentationContext, bundle: bundle)
        createRenderedContent()
    }
    
    /// The pre-rendered content per node reference.
    private(set) public var store = RenderReferenceStore()
    
    /// Creates a set of commonly used pieces of content using the nodes in the given documentation context.
    /// - Note: On macOS and iOS this function creates the content concurrently.
    private mutating func createRenderedContent() {
        let references = documentationContext.knownIdentifiers
        var topics = [ResolvedTopicReference: RenderReferenceStore.TopicContent]()
        let renderer = self.renderer
        let documentationContext = self.documentationContext
        
        let renderContentFor: (ResolvedTopicReference) -> RenderReferenceStore.TopicContent = { reference in
            var dependencies = RenderReferenceDependencies()
            let renderReference = renderer.renderReference(for: reference, dependencies: &dependencies)
            let canonicalPath = documentationContext.pathsTo(reference).first.flatMap { $0.isEmpty ? nil : $0 }
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
        
        #if os(macOS) || os(iOS) || os(Android)
        // Concurrently render content on macOS/iOS & Android
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
                let (bundleIdentifer, assetManager) = element
            
                for (name, asset) in assetManager.storage {
                    storage[
                        AssetReference(assetName: name, bundleIdentifier: bundleIdentifer)
                    ] = asset
                }
            }
        
        self.store = RenderReferenceStore(topics: topics, assets: assets)
    }
}
