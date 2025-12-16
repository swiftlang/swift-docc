/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Testing
@testable import SwiftDocC
import Markdown
import SwiftDocCTestUtilities

// MARK: Using an in-memory file system

/// Loads a documentation catalog from an in-memory test file system.
///
/// - Parameters:
///   - catalog: The directory structure of the documentation catalog
///   - otherFileSystemDirectories: Any other directories in the test file system.
///   - diagnosticFilterLevel: The minimum severity for diagnostics to emit.
///   - logOutput: An output stream to capture log output from creating the context.
///   - configuration: Configuration for the created context.
/// - Returns: The loaded documentation bundle and context for the given catalog input.
func load(
    catalog: Folder,
    otherFileSystemDirectories: [Folder] = [],
    diagnosticFilterLevel: DiagnosticSeverity = .warning,
    logOutput: some TextOutputStream = LogHandle.none,
    configuration: DocumentationContext.Configuration = .init()
) async throws -> DocumentationContext {
    let fileSystem = try TestFileSystem(folders: [catalog] + otherFileSystemDirectories)
    let catalogURL = URL(fileURLWithPath: "/\(catalog.name)")
    
    let diagnosticEngine = DiagnosticEngine(filterLevel: diagnosticFilterLevel)
    diagnosticEngine.add(DiagnosticConsoleWriter(logOutput, formattingOptions: [], baseURL: catalogURL, highlight: true, dataProvider: fileSystem))
    
    let (inputs, dataProvider) = try DocumentationContext.InputsProvider(fileManager: fileSystem)
        .inputsAndDataProvider(startingPoint: catalogURL, options: .init())
    
    defer {
        diagnosticEngine.flush() // Write to the logOutput
    }
    return try await DocumentationContext(bundle: inputs, dataProvider: dataProvider, diagnosticEngine: diagnosticEngine, configuration: configuration)
}

func makeEmptyContext() async throws -> DocumentationContext {
    let bundle = DocumentationBundle(
        info: DocumentationBundle.Info(
            displayName: "Test",
            id: "com.example.test"
        ),
        baseURL: URL(string: "https://example.com/example")!,
        symbolGraphURLs: [],
        markupURLs: [],
        miscResourceURLs: []
    )
    
    return try await DocumentationContext(bundle: bundle, dataProvider: TestFileSystem(folders: []))
}

// MARK: Using the real file system

/// Loads a documentation bundle from the given source URL and creates a documentation context.
func loadFromDisk(
    catalogURL: URL,
    externalResolvers: [DocumentationBundle.Identifier: any ExternalDocumentationSource] = [:],
    externalSymbolResolver: (any GlobalExternalSymbolResolver)? = nil,
    fallbackResolver: (any ConvertServiceFallbackResolver)? = nil,
    diagnosticEngine: DiagnosticEngine = .init(filterLevel: .hint),
    configuration: DocumentationContext.Configuration = .init()
) async throws -> DocumentationContext {
    var configuration = configuration
    configuration.externalDocumentationConfiguration.sources = externalResolvers
    configuration.externalDocumentationConfiguration.globalSymbolResolver = externalSymbolResolver
    configuration.convertServiceConfiguration.fallbackResolver = fallbackResolver
    configuration.externalMetadata.diagnosticLevel = diagnosticEngine.filterLevel
    
    let (bundle, dataProvider) = try DocumentationContext.InputsProvider()
        .inputsAndDataProvider(startingPoint: catalogURL, options: .init())
    
    return try await DocumentationContext(bundle: bundle, dataProvider: dataProvider, diagnosticEngine: diagnosticEngine, configuration: configuration)
}

func loadFromDisk(
    catalogName: String,
    externalResolvers: [DocumentationBundle.Identifier: any ExternalDocumentationSource] = [:],
    fallbackResolver: (any ConvertServiceFallbackResolver)? = nil,
    configuration: DocumentationContext.Configuration = .init(),
    sourceLocation: Testing.SourceLocation = #_sourceLocation
) async throws -> DocumentationContext {
    try await loadFromDisk(
        catalogURL: try #require(Bundle.module.url(forResource: catalogName, withExtension: "docc", subdirectory: "Test Bundles"), sourceLocation: sourceLocation),
        externalResolvers: externalResolvers,
        fallbackResolver: fallbackResolver,
        configuration: configuration
    )
}

// MARK: Render node loading helpers

func renderNode(atPath path: String, fromOnDiskTestCatalogNamed catalogName: String, sourceLocation: Testing.SourceLocation = #_sourceLocation) async throws -> RenderNode {
    let context = try await loadFromDisk(catalogName: catalogName)
    let node = try context.entity(with: ResolvedTopicReference(bundleID: context.inputs.id, path: path, sourceLanguage: .swift))
    var translator = RenderNodeTranslator(context: context, identifier: node.reference)
    return try #require(translator.visit(node.semantic) as? RenderNode, sourceLocation: sourceLocation)
}

extension RenderNode {
    func applying(variant: String) throws -> RenderNode {
        let variantData = try RenderNodeVariantOverridesApplier().applyVariantOverrides(
            in: RenderJSONEncoder.makeEncoder().encode(self),
            for: [.interfaceLanguage(variant)]
        )
        
        return try RenderJSONDecoder.makeDecoder().decode(
            RenderNode.self,
            from: variantData
        )
    }
}
