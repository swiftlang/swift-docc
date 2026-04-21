/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import XCTest
@testable import SwiftDocC
import Markdown
import DocCTestUtilities
import DocCCommon

extension XCTestCase {
    
    /// Loads a documentation bundle from the given source URL and creates a documentation context.
    func loadBundle(
        from catalogURL: URL,
        externalResolvers: [DocumentationBundle.Identifier: any ExternalDocumentationSource] = [:],
        externalSymbolResolver: (any GlobalExternalSymbolResolver)? = nil,
        fallbackResolver: (any ConvertServiceFallbackResolver)? = nil,
        diagnosticEngine: DiagnosticEngine = .init(filterLevel: .information),
        configuration: DocumentationContext.Configuration = .init()
    ) async throws -> (URL, DocumentationBundle, DocumentationContext) {
        let context = try await loadFromDisk(
            catalogURL: catalogURL,
            externalResolvers: externalResolvers,
            externalSymbolResolver: externalSymbolResolver,
            fallbackResolver: fallbackResolver,
            diagnosticEngine: diagnosticEngine,
            configuration: configuration
        )
        return (catalogURL, context.inputs, context)
    }
    
    /// Loads a documentation catalog from an in-memory test file system.
    /// 
    /// - Parameters:
    ///   - catalog: The directory structure of the documentation catalog
    ///   - otherFileSystemDirectories: Any other directories in the test file system.
    ///   - diagnosticFilterLevel: The minimum severity for diagnostics to emit.
    ///   - logOutput: An output stream to capture log output from creating the context.
    ///   - configuration: Configuration for the created context.
    /// - Returns: The loaded documentation bundle and context for the given catalog input.
    func loadBundle(
        catalog: Folder,
        otherFileSystemDirectories: [Folder] = [],
        diagnosticFilterLevel: DiagnosticSeverity = .warning,
        logOutput: some TextOutputStream = LogHandle.none,
        configuration: DocumentationContext.Configuration = .init()
    ) async throws -> (DocumentationBundle, DocumentationContext) {
        let context = try await SwiftDocCTests.load(
            catalog: catalog,
            otherFileSystemDirectories: otherFileSystemDirectories,
            diagnosticFilterLevel: diagnosticFilterLevel,
            logOutput: logOutput,
            configuration: configuration
        )
        return (context.inputs, context)
    }
    
    func testCatalogURL(named name: String, file: StaticString = #filePath, line: UInt = #line) throws -> URL {
        try XCTUnwrap(
            Bundle.module.url(forResource: name, withExtension: "docc", subdirectory: "Test Bundles"),
            file: file, line: line
        )
    }
    
    func testBundleAndContext(
        copying name: String,
        excludingPaths excludedPaths: [String] = [],
        externalResolvers: [DocumentationBundle.Identifier : any ExternalDocumentationSource] = [:],
        externalSymbolResolver: (any GlobalExternalSymbolResolver)? = nil,
        fallbackResolver: (any ConvertServiceFallbackResolver)? = nil,
        diagnosticEngine: DiagnosticEngine = .init(filterLevel: .information),
        configuration: DocumentationContext.Configuration = .init(),
        configureBundle: ((URL) throws -> Void)? = nil
    ) async throws -> (URL, DocumentationBundle, DocumentationContext) {
        let sourceURL = try testCatalogURL(named: name)
        
        let sourceExists = FileManager.default.fileExists(atPath: sourceURL.path)
        let bundleURL = sourceExists
            ? try createTemporaryDirectory().appendingPathComponent("\(name).docc")
            : try createTemporaryDirectory(named: "\(name).docc")
        
        if sourceExists {
            try FileManager.default.copyItem(at: sourceURL, to: bundleURL)
        }
        
        for path in excludedPaths {
            try FileManager.default.removeItem(at: bundleURL.appendingPathComponent(path))
        }
        
        // Do any additional setup to the custom bundle - adding, modifying files, etc
        try configureBundle?(bundleURL)
        
        return try await loadBundle(
            from: bundleURL,
            externalResolvers: externalResolvers,
            externalSymbolResolver: externalSymbolResolver,
            fallbackResolver: fallbackResolver,
            diagnosticEngine: diagnosticEngine,
            configuration: configuration
        )
    }
    
    func testBundleAndContext(
        named name: String,
        externalResolvers: [DocumentationBundle.Identifier: any ExternalDocumentationSource] = [:],
        fallbackResolver: (any ConvertServiceFallbackResolver)? = nil,
        configuration: DocumentationContext.Configuration = .init()
    ) async throws -> (URL, DocumentationBundle, DocumentationContext) {
        let catalogURL = try testCatalogURL(named: name)
        let context = try await loadFromDisk(catalogURL: catalogURL, externalResolvers: externalResolvers, fallbackResolver: fallbackResolver, configuration: configuration)
        return (catalogURL, context.inputs, context)
    }
    
    func testBundleAndContext(named name: String, externalResolvers: [DocumentationBundle.Identifier: any ExternalDocumentationSource] = [:]) async throws -> (DocumentationBundle, DocumentationContext) {
        let context = try await loadFromDisk(catalogURL: try testCatalogURL(named: name), externalResolvers: externalResolvers)
        return (context.inputs, context)
    }
    
    func renderNode(atPath path: String, fromTestBundleNamed testCatalogName: String, configuration: DocumentationContext.Configuration = .init()) async throws -> RenderNode {
        let context = try await loadFromDisk(catalogURL: try testCatalogURL(named: testCatalogName), configuration: configuration)
        let node = try context.entity(with: ResolvedTopicReference(bundleID: context.inputs.id, path: path, sourceLanguage: .swift))
        var translator = RenderNodeTranslator(context: context, identifier: node.reference)
        return try XCTUnwrap(translator.visit(node.semantic) as? RenderNode)
    }
    
    func testBundle(named name: String) async throws -> DocumentationBundle {
        let context = try await loadFromDisk(catalogURL: try testCatalogURL(named: name))
        return context.inputs
    }
    
    func testBundleFromRootURL(named name: String) throws -> DocumentationBundle {
        let rootURL = try testCatalogURL(named: name)
        let inputProvider = DocumentationContext.InputsProvider()
        let catalogURL = try XCTUnwrap(inputProvider.findCatalog(startingPoint: rootURL))
        return try inputProvider.makeInputs(contentOf: catalogURL, options: .init())
    }
    
    func testBundleAndContext(configuration: DocumentationContext.Configuration = .init()) async throws -> (bundle: DocumentationBundle, context: DocumentationContext) {
        let context = try await makeEmptyContext(configuration: configuration)
        return (context.inputs, context)
    }
    
    func parseDirective<Directive: DirectiveConvertible>(
        _ directive: Directive.Type,
        content: () -> String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws -> (problemIdentifiers: [String], directive: Directive?) {
        let context = try await makeEmptyContext()
        
        let source = URL(fileURLWithPath: "/path/to/test-source-\(ProcessInfo.processInfo.globallyUniqueString)")
        let document = Document(parsing: content(), source: source, options: .parseBlockDirectives)
        
        let blockDirectiveContainer = try XCTUnwrap(document.child(at: 0) as? BlockDirective, file: file, line: line)
        
        var diagnostics = [Diagnostic]()
        let directive = directive.init(
            from: blockDirectiveContainer,
            source: source,
            for: context.inputs,
            featureFlags: context.configuration.featureFlags,
            diagnostics: &diagnostics
        )
        
        let diagnosticDescriptions = diagnostics.map { diagnostic -> String in
            XCTAssertNotNil(diagnostic.source, "Diagnostic \(diagnostic.identifier) is missing a source URL.", file: file, line: line)
            let line = diagnostic.range?.lowerBound.line.description ?? "unknown-line"
            
            return "\(line): \(diagnostic.severity) – \(diagnostic.identifier)"
        }.sorted()
        
        return (diagnosticDescriptions, directive)
    }
    
    func parseDirective<Directive: RenderableDirectiveConvertible>(
        _ directive: Directive.Type,
        catalog: Folder,
        configuration: DocumentationContext.Configuration = .init(),
        content: () -> String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws -> (
        renderBlockContent: [RenderBlockContent],
        problemIdentifiers: [String],
        directive: Directive?,
        collectedReferences: [String : any RenderReference]
    ) {
        let (_, context) = try await loadBundle(catalog: catalog, configuration: configuration)
        return try parseDirective(directive, context: context, content: content, file: file, line: line)
    }
    
    func parseDirective<Directive: RenderableDirectiveConvertible>(
        _ directive: Directive.Type,
        in bundleName: String? = nil,
        content: () -> String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws -> (renderBlockContent: [RenderBlockContent], problemIdentifiers: [String], directive: Directive?) {
        let (renderedContent, diagnostics, directive, _) = try await parseDirective(directive, in: bundleName, content: content, file: file, line: line)
        return (renderedContent, diagnostics, directive)
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
        let context: DocumentationContext
        if let bundleName {
            (_, context) = try await testBundleAndContext(named: bundleName)
        } else {
            (_, context) = try await testBundleAndContext()
        }
        return try parseDirective(directive, context: context, content: content, file: file, line: line)
    }
    
    func parseDirective<Directive: RenderableDirectiveConvertible>(
        _ directive: Directive.Type,
        withAvailableAssetNames assetNames: [String],
        configuration: DocumentationContext.Configuration = .init(),
        content: () -> String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws -> (renderBlockContent: [RenderBlockContent], problemIdentifiers: [String], directive: Directive?) {
        let (_, context) = try await loadBundle(catalog: Folder(name: "Something.docc", content: assetNames.map {
            DataFile(name: $0, data: Data())
        }), configuration: configuration)
        
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
        
        var analyzer = SemanticAnalyzer(source: source, bundle: context.inputs, featureFlags: context.configuration.featureFlags)
        let result = analyzer.visit(blockDirectiveContainer)
        context.diagnosticEngine.emit(analyzer.diagnostics)
        
        var referenceResolver = MarkupReferenceResolver(context: context, rootReference: context.inputs.rootReference)
        
        _ = referenceResolver.visit(blockDirectiveContainer)
        context.diagnosticEngine.emit(referenceResolver.diagnostics)
        
        func problemIDs() throws -> [String] {
            try context.diagnostics.map { problem -> (line: Int, severity: String, id: String) in
                XCTAssertNotNil(problem.source, "Diagnostic \(problem.identifier) is missing a source URL.", file: file, line: line)
                let line = try XCTUnwrap(problem.range, file: file, line: line).lowerBound.line
                return (line, problem.severity.description, problem.identifier)
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
        try renderNode.applying(variant: variant)
    }
}
