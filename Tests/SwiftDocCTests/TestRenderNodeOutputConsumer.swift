/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
@testable import SwiftDocC
import XCTest

class TestRenderNodeOutputConsumer: ConvertOutputConsumer {
    var renderNodes = Synchronized<[RenderNode]>([])
    
    func consume(renderNode: RenderNode) throws {
        renderNodes.sync { renderNodes in
            renderNodes.append(renderNode)
        }
    }
    
    func consume(problems: [Problem]) throws { }
    func consume(assetsInBundle bundle: DocumentationBundle) throws { }
    func consume(linkableElementSummaries: [LinkDestinationSummary]) throws { }
    func consume(indexingRecords: [IndexingRecord]) throws { }
    func consume(assets: [RenderReferenceType: [RenderReference]]) throws { }
    func consume(benchmarks: Benchmark) throws { }
    func consume(documentationCoverageInfo: [CoverageDataEntry]) throws { }
    func consume(renderReferenceStore: RenderReferenceStore) throws { }
    func consume(buildMetadata: BuildMetadata) throws { }
}

extension TestRenderNodeOutputConsumer {
    func allRenderNodes() -> [RenderNode] {
        renderNodes.sync { $0 }
    }
    
    func renderNodes(withInterfaceLanguages interfaceLanguages: Set<String>?) -> [RenderNode] {
        renderNodes.sync { renderNodes in
            renderNodes.filter { renderNode in
                guard let interfaceLanguages = interfaceLanguages else {
                    // If there are no interface languages set, return the nodes with no variants.
                    return renderNode.variants == nil
                }
                
                guard let variants = renderNode.variants else {
                    return false
                }
                
                let actualInterfaceLanguages: [String] = variants.flatMap { variant in
                    variant.traits.compactMap { trait in
                        guard case .interfaceLanguage(let interfaceLanguage) = trait else {
                            return nil
                        }
                        return interfaceLanguage
                    }
                }
                
                return Set(actualInterfaceLanguages) == interfaceLanguages
            }
        }
    }
    
    func renderNode(withIdentifier identifier: String) throws -> RenderNode {
        try renderNode(where: { renderNode in renderNode.metadata.externalID == identifier })
    }
    
    func renderNode(withTitle title: String) throws -> RenderNode {
        try renderNode(where: { renderNode in renderNode.metadata.title == title })
    }
    
    func renderNode(where predicate: (RenderNode) -> Bool) throws -> RenderNode {
        let renderNode = renderNodes.sync { renderNodes in
            renderNodes.first { renderNode in
                predicate(renderNode)
            }
        }
        
        return try XCTUnwrap(renderNode)
    }
}

extension XCTestCase {
    func renderNodeConsumer(
        for bundleName: String,
        configureBundle: ((URL) throws -> Void)? = nil,
        configureConverter: ((inout DocumentationConverter) throws -> Void)? = nil
    ) throws -> TestRenderNodeOutputConsumer {
        let (bundleURL, _, context) = try testBundleAndContext(
            copying: bundleName,
            configureBundle: configureBundle
        )
        
        var converter = DocumentationConverter(
            documentationBundleURL: bundleURL,
            emitDigest: false,
            documentationCoverageOptions: .noCoverage,
            currentPlatforms: nil,
            workspace: context.dataProvider as! DocumentationWorkspace,
            context: context,
            dataProvider: try LocalFileSystemDataProvider(rootURL: bundleURL),
            bundleDiscoveryOptions: BundleDiscoveryOptions()
        )
        
        try configureConverter?(&converter)
        
        let outputConsumer = TestRenderNodeOutputConsumer()
        let (_, _) = try converter.convert(outputConsumer: outputConsumer)
        
        return outputConsumer
    }
}
