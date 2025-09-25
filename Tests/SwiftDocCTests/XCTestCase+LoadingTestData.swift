/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import XCTest
@testable import SwiftDocC
import Markdown
import SwiftDocCTestUtilities

extension XCTestCase {
    
    /// Loads a collection of documentation input files from the given source URL on disk and creates a documentation context.
    func loadFromDisk(
        catalogURL: URL,
        externalResolvers: [DocumentationContext.Inputs.Identifier: any ExternalDocumentationSource] = [:],
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
        
        let (inputs, dataProvider) = try DocumentationContext.InputsProvider()
            .inputsAndDataProvider(startingPoint: catalogURL, options: .init())

        return try await DocumentationContext(inputs: inputs, dataProvider: dataProvider, diagnosticEngine: diagnosticEngine, configuration: configuration)
    }
    
    /// Loads a documentation catalog from an in-memory test file system.
    /// 
    /// - Parameters:
    ///   - catalog: The directory structure of the documentation catalog
    ///   - otherFileSystemDirectories: Any other directories in the test file system.
    ///   - diagnosticEngine: The diagnostic engine for the created context.
    ///   - configuration: Configuration for the created context.
    /// - Returns: The loaded documentation bundle and context for the given catalog input.
    func load(
        catalog: Folder,
        otherFileSystemDirectories: [Folder] = [],
        diagnosticEngine: DiagnosticEngine = .init(),
        configuration: DocumentationContext.Configuration = .init()
    ) async throws -> DocumentationContext {
        let fileSystem = try TestFileSystem(folders: [catalog] + otherFileSystemDirectories)
        
        let (inputs, dataProvider) = try DocumentationContext.InputsProvider(fileManager: fileSystem)
            .inputsAndDataProvider(startingPoint: URL(fileURLWithPath: "/\(catalog.name)"), options: .init())

        return try await DocumentationContext(inputs: inputs, dataProvider: dataProvider, diagnosticEngine: diagnosticEngine, configuration: configuration)
    }
    
    func testCatalogURL(named name: String, file: StaticString = #filePath, line: UInt = #line) throws -> URL {
        try XCTUnwrap(
            Bundle.module.url(forResource: name, withExtension: "docc", subdirectory: "Test Bundles"),
            file: file, line: line
        )
    }
    
    func loadFromDisk(
        copyingCatalogNamed catalogName: String,
        excludingPaths excludedPaths: [String] = [],
        externalResolvers: [DocumentationContext.Inputs.Identifier : any ExternalDocumentationSource] = [:],
        externalSymbolResolver: (any GlobalExternalSymbolResolver)? = nil,
        fallbackResolver: (any ConvertServiceFallbackResolver)? = nil,
        diagnosticEngine: DiagnosticEngine = .init(filterLevel: .hint),
        configuration: DocumentationContext.Configuration = .init(),
        configureBundle: ((URL) throws -> Void)? = nil
    ) async throws -> (URL, DocumentationContext) {
        let sourceURL = try testCatalogURL(named: catalogName)
        
        let sourceExists = FileManager.default.fileExists(atPath: sourceURL.path)
        let copiedURL = sourceExists
            ? try createTemporaryDirectory().appendingPathComponent("\(catalogName).docc")
            : try createTemporaryDirectory(named: "\(catalogName).docc")
        
        if sourceExists {
            try FileManager.default.copyItem(at: sourceURL, to: copiedURL)
        }
        
        for path in excludedPaths {
            try FileManager.default.removeItem(at: copiedURL.appendingPathComponent(path))
        }
        
        // Do any additional setup to the custom bundle - adding, modifying files, etc
        try configureBundle?(copiedURL)
        
        let context = try await loadFromDisk(
            catalogURL: copiedURL,
            externalResolvers: externalResolvers,
            externalSymbolResolver: externalSymbolResolver,
            fallbackResolver: fallbackResolver,
            diagnosticEngine: diagnosticEngine,
            configuration: configuration
        )
        return (copiedURL, context)
    }
    
    func loadFromDisk(
        catalogName: String,
        externalResolvers: [DocumentationContext.Inputs.Identifier: any ExternalDocumentationSource] = [:],
        fallbackResolver: (any ConvertServiceFallbackResolver)? = nil,
        configuration: DocumentationContext.Configuration = .init()
    ) async throws -> (URL, DocumentationContext) {
        let catalogURL = try testCatalogURL(named: catalogName)
        let context = try await loadFromDisk(catalogURL: catalogURL, externalResolvers: externalResolvers, fallbackResolver: fallbackResolver, configuration: configuration)
        return (catalogURL, context)
    }
    
    func loadFromDisk(catalogName: String, externalResolvers: [DocumentationContext.Inputs.Identifier: any ExternalDocumentationSource] = [:]) async throws -> DocumentationContext {
        let (_, context) = try await loadFromDisk(catalogName: catalogName, externalResolvers: externalResolvers)
        return context
    }
    
    func renderNode(atPath path: String, fromOnDiskCatalogNamed catalogName: String) async throws -> RenderNode {
        let context = try await loadFromDisk(catalogName: catalogName)
        let node = try context.entity(with: ResolvedTopicReference(bundleID: context.inputs.id, path: path, sourceLanguage: .swift))
        var translator = RenderNodeTranslator(context: context, identifier: node.reference)
        return try XCTUnwrap(translator.visit(node.semantic) as? RenderNode)
    }
    
    func testInputs(named name: String) async throws -> DocumentationContext.Inputs {
        return try await loadFromDisk(catalogName: name).inputs
    }
    
    func makeEmptyContext() async throws -> DocumentationContext {
        let inputs = DocumentationContext.Inputs(
            info: DocumentationContext.Inputs.Info(
                displayName: "Test",
                id: "com.example.test"
            ),
            baseURL: URL(string: "https://example.com/example")!,
            symbolGraphURLs: [],
            markupURLs: [],
            miscResourceURLs: []
        )
        
        return try await DocumentationContext(inputs: inputs, dataProvider: TestFileSystem(folders: []))
    }
    
    func parseDirective<Directive: DirectiveConvertible>(
        _ directive: Directive.Type,
        content: () -> String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws -> (problemIdentifiers: [String], directive: Directive?) {
        let inputs = try await makeEmptyContext().inputs
        
        let source = URL(fileURLWithPath: "/path/to/test-source-\(ProcessInfo.processInfo.globallyUniqueString)")
        let document = Document(parsing: content(), source: source, options: .parseBlockDirectives)
        
        let blockDirectiveContainer = try XCTUnwrap(document.child(at: 0) as? BlockDirective, file: file, line: line)
        
        var problems = [Problem]()
        let directive = directive.init(
            from: blockDirectiveContainer,
            source: source,
            for: inputs,
            problems: &problems
        )
        
        let problemIDs = problems.map { problem -> String in
            XCTAssertNotNil(problem.diagnostic.source, "Problem \(problem.diagnostic.identifier) is missing a source URL.", file: file, line: line)
            let line = problem.diagnostic.range?.lowerBound.line.description ?? "unknown-line"
            
            return "\(line): \(problem.diagnostic.severity) – \(problem.diagnostic.identifier)"
        }.sorted()
        
        return (problemIDs, directive)
    }
    
    func parseDirective<Directive: RenderableDirectiveConvertible>(
        _ directive: Directive.Type,
        catalog: Folder,
        content: () -> String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws -> (
        renderBlockContent: [RenderBlockContent],
        problemIdentifiers: [String],
        directive: Directive?,
        collectedReferences: [String : any RenderReference]
    ) {
        let context = try await load(catalog: catalog)
        return try parseDirective(directive, context: context, content: content, file: file, line: line)
    }
    
    func parseDirective<Directive: RenderableDirectiveConvertible>(
        _ directive: Directive.Type,
        in bundleName: String? = nil,
        content: () -> String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws -> (renderBlockContent: [RenderBlockContent], problemIdentifiers: [String], directive: Directive?) {
        let (renderedContent, problems, directive, _) = try await parseDirective(
            directive,
            in: bundleName,
            content: content,
            file: file,
            line: line
        )
        
        return (renderedContent, problems, directive)
    }
    
    func parseDirective<Directive: RenderableDirectiveConvertible>(
        _ directive: Directive.Type,
        in bundleName: String? = nil,
        content: () -> String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws -> (
        renderBlockContent: [RenderBlockContent],
        problemIdentifiers: [String],
        directive: Directive?,
        collectedReferences: [String : any RenderReference]
    ) {
        let context = if let bundleName {
            try await loadFromDisk(catalogName: bundleName)
        } else {
            try await makeEmptyContext()
        }
        return try parseDirective(directive, context: context, content: content, file: file, line: line)
    }
    
    func parseDirective<Directive: RenderableDirectiveConvertible>(
        _ directive: Directive.Type,
        withAvailableAssetNames assetNames: [String],
        content: () -> String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws -> (renderBlockContent: [RenderBlockContent], problemIdentifiers: [String], directive: Directive?) {
        let context = try await load(catalog: Folder(name: "Something.docc", content: assetNames.map {
            DataFile(name: $0, data: Data())
        }))
        
        let (renderedContent, problems, directive, _) = try parseDirective(directive, context: context, content: content)
        return (renderedContent, problems, directive)
    }
    
    private func parseDirective<Directive: RenderableDirectiveConvertible>(
        _ directive: Directive.Type,
        context: DocumentationContext,
        content: () -> String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> (
        renderBlockContent: [RenderBlockContent],
        problemIdentifiers: [String],
        directive: Directive?,
        collectedReferences: [String : any RenderReference]
    ) {
        context.diagnosticEngine.clearDiagnostics()
        
        let source = URL(fileURLWithPath: "/path/to/test-source-\(ProcessInfo.processInfo.globallyUniqueString)")
        let document = Document(parsing: content(), source: source, options: [.parseBlockDirectives, .parseSymbolLinks])
        
        let blockDirectiveContainer = try XCTUnwrap(document.child(at: 0) as? BlockDirective, file: file, line: line)
        
        var analyzer = SemanticAnalyzer(source: source, inputs: context.inputs)
        let result = analyzer.visit(blockDirectiveContainer)
        context.diagnosticEngine.emit(analyzer.problems)
        
        var referenceResolver = MarkupReferenceResolver(context: context, rootReference: context.inputs.rootReference)
        
        _ = referenceResolver.visit(blockDirectiveContainer)
        context.diagnosticEngine.emit(referenceResolver.problems)
        
        func problemIDs() throws -> [String] {
            try context.problems.map { problem -> (line: Int, severity: String, id: String) in
                XCTAssertNotNil(problem.diagnostic.source, "Problem \(problem.diagnostic.identifier) is missing a source URL.", file: file, line: line)
                let line = try XCTUnwrap(problem.diagnostic.range, file: file, line: line).lowerBound.line
                return (line, problem.diagnostic.severity.description, problem.diagnostic.identifier)
            }
            .sorted { lhs, rhs in
                let (lhsLine, _, lhsID) = lhs
                let (rhsLine, _, rhsID) = rhs
                
                if lhsLine != rhsLine {
                    return lhsLine < rhsLine
                } else {
                    return lhsID < rhsID
                }
            }
            .map { (line, severity, id) in
                return "\(line): \(severity) – \(id)"
            }
        }
        
        guard let directive = result as? Directive else {
            return ([], try problemIDs(), nil, [:])
        }
        
        var contentCompiler = RenderContentCompiler(
            context: context,
            identifier: ResolvedTopicReference(
                bundleID: context.inputs.id,
                path: "/test-path-123",
                sourceLanguage: .swift
            )
        )
        
        let renderedContent = try XCTUnwrap(
            directive.render(with: &contentCompiler) as? [RenderBlockContent],
            file: file, line: line
        )
        
        let collectedReferences = contentCompiler.videoReferences
            .mapValues { $0 as (any RenderReference) }
            .merging(
                contentCompiler.imageReferences,
                uniquingKeysWith: { videoReference, _ in
                    XCTFail("Non-unique references.", file: file, line: line)
                    return videoReference
                }
            )
        
        return (renderedContent, try problemIDs(), directive, collectedReferences)
    }
    
    func renderNodeApplying(variant: String, to renderNode: RenderNode) throws -> RenderNode {
        let variantData = try RenderNodeVariantOverridesApplier().applyVariantOverrides(
            in: RenderJSONEncoder.makeEncoder().encode(renderNode),
            for: [.interfaceLanguage(variant)]
        )
        
        return try RenderJSONDecoder.makeDecoder().decode(
            RenderNode.self,
            from: variantData
        )
    }
}
