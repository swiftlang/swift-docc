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
    
    /// Loads a documentation bundle from the given source URL and creates a documentation context.
    func loadBundle(
        from catalogURL: URL,
        externalResolvers: [DocumentationContext.Inputs.Identifier: any ExternalDocumentationSource] = [:],
        externalSymbolResolver: (any GlobalExternalSymbolResolver)? = nil,
        fallbackResolver: (any ConvertServiceFallbackResolver)? = nil,
        diagnosticEngine: DiagnosticEngine = .init(filterLevel: .hint),
        configuration: DocumentationContext.Configuration = .init()
    ) async throws -> (URL, DocumentationContext.Inputs, DocumentationContext) {
        var configuration = configuration
        configuration.externalDocumentationConfiguration.sources = externalResolvers
        configuration.externalDocumentationConfiguration.globalSymbolResolver = externalSymbolResolver
        configuration.convertServiceConfiguration.fallbackResolver = fallbackResolver
        configuration.externalMetadata.diagnosticLevel = diagnosticEngine.filterLevel
        
        let (bundle, dataProvider) = try DocumentationContext.InputsProvider()
            .inputsAndDataProvider(startingPoint: catalogURL, options: .init())

        let context = try await DocumentationContext(inputs: bundle, dataProvider: dataProvider, diagnosticEngine: diagnosticEngine, configuration: configuration)
        return (catalogURL, bundle, context)
    }
    
    /// Loads a documentation catalog from an in-memory test file system.
    /// 
    /// - Parameters:
    ///   - catalog: The directory structure of the documentation catalog
    ///   - otherFileSystemDirectories: Any other directories in the test file system.
    ///   - diagnosticEngine: The diagnostic engine for the created context.
    ///   - configuration: Configuration for the created context.
    /// - Returns: The loaded documentation bundle and context for the given catalog input.
    func loadBundle(
        catalog: Folder,
        otherFileSystemDirectories: [Folder] = [],
        diagnosticEngine: DiagnosticEngine = .init(),
        configuration: DocumentationContext.Configuration = .init()
    ) async throws -> (DocumentationContext.Inputs, DocumentationContext) {
        let fileSystem = try TestFileSystem(folders: [catalog] + otherFileSystemDirectories)
        
        let (bundle, dataProvider) = try DocumentationContext.InputsProvider(fileManager: fileSystem)
            .inputsAndDataProvider(startingPoint: URL(fileURLWithPath: "/\(catalog.name)"), options: .init())

        let context = try await DocumentationContext(inputs: bundle, dataProvider: dataProvider, diagnosticEngine: diagnosticEngine, configuration: configuration)
        return (bundle, context)
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
        externalResolvers: [DocumentationContext.Inputs.Identifier : any ExternalDocumentationSource] = [:],
        externalSymbolResolver: (any GlobalExternalSymbolResolver)? = nil,
        fallbackResolver: (any ConvertServiceFallbackResolver)? = nil,
        diagnosticEngine: DiagnosticEngine = .init(filterLevel: .hint),
        configuration: DocumentationContext.Configuration = .init(),
        configureBundle: ((URL) throws -> Void)? = nil
    ) async throws -> (URL, DocumentationContext.Inputs, DocumentationContext) {
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
        externalResolvers: [DocumentationContext.Inputs.Identifier: any ExternalDocumentationSource] = [:],
        fallbackResolver: (any ConvertServiceFallbackResolver)? = nil,
        configuration: DocumentationContext.Configuration = .init()
    ) async throws -> (URL, DocumentationContext.Inputs, DocumentationContext) {
        let catalogURL = try testCatalogURL(named: name)
        return try await loadBundle(from: catalogURL, externalResolvers: externalResolvers, fallbackResolver: fallbackResolver, configuration: configuration)
    }
    
    func testBundleAndContext(named name: String, externalResolvers: [DocumentationContext.Inputs.Identifier: any ExternalDocumentationSource] = [:]) async throws -> (DocumentationContext.Inputs, DocumentationContext) {
        let (_, bundle, context) = try await testBundleAndContext(named: name, externalResolvers: externalResolvers)
        return (bundle, context)
    }
    
    func renderNode(atPath path: String, fromTestBundleNamed testBundleName: String) async throws -> RenderNode {
        let (_, context) = try await testBundleAndContext(named: testBundleName)
        let node = try context.entity(with: ResolvedTopicReference(bundleID: context.inputs.id, path: path, sourceLanguage: .swift))
        var translator = RenderNodeTranslator(context: context, identifier: node.reference)
        return try XCTUnwrap(translator.visit(node.semantic) as? RenderNode)
    }
    
    func testBundle(named name: String) async throws -> DocumentationContext.Inputs {
        let (bundle, _) = try await testBundleAndContext(named: name)
        return bundle
    }
    
    func testBundleFromRootURL(named name: String) throws -> DocumentationContext.Inputs {
        let rootURL = try testCatalogURL(named: name)
        let inputProvider = DocumentationContext.InputsProvider()
        let catalogURL = try XCTUnwrap(inputProvider.findCatalog(startingPoint: rootURL))
        return try inputProvider.makeInputs(contentOf: catalogURL, options: .init())
    }
    
    func testBundleAndContext() async throws -> (bundle: DocumentationContext.Inputs, context: DocumentationContext) {
        let bundle = DocumentationContext.Inputs(
            info: DocumentationContext.Inputs.Info(
                displayName: "Test",
                id: "com.example.test"
            ),
            baseURL: URL(string: "https://example.com/example")!,
            symbolGraphURLs: [],
            markupURLs: [],
            miscResourceURLs: []
        )
        
        let context = try await DocumentationContext(inputs: bundle, dataProvider: TestFileSystem(folders: []))
        return (bundle, context)
    }
    
    func parseDirective<Directive: DirectiveConvertible>(
        _ directive: Directive.Type,
        content: () -> String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws -> (problemIdentifiers: [String], directive: Directive?) {
        let (bundle, _) = try await testBundleAndContext()
        
        let source = URL(fileURLWithPath: "/path/to/test-source-\(ProcessInfo.processInfo.globallyUniqueString)")
        let document = Document(parsing: content(), source: source, options: .parseBlockDirectives)
        
        let blockDirectiveContainer = try XCTUnwrap(document.child(at: 0) as? BlockDirective, file: file, line: line)
        
        var problems = [Problem]()
        let directive = directive.init(
            from: blockDirectiveContainer,
            source: source,
            for: bundle,
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
        let (_, context) = try await loadBundle(catalog: catalog)
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
        let context: DocumentationContext
        
        if let bundleName {
            (_, context) = try await testBundleAndContext(named: bundleName)
        } else {
            (_, context) = try await testBundleAndContext()
        }
        return try parseDirective(directive, context: context, content: content, file: file, line: line)
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
