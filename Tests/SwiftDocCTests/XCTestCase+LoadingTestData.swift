/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import XCTest
@testable import SwiftDocC
import Markdown

extension XCTestCase {
    
    /// Loads a documentation bundle from the given source URL and creates a documentation context.
    func loadBundle(from bundleURL: URL, codeListings: [String : AttributedCodeListing] = [:], externalResolvers: [String: ExternalReferenceResolver] = [:], externalSymbolResolver: ExternalSymbolResolver? = nil, diagnosticFilterLevel: DiagnosticSeverity = .hint, configureContext: ((DocumentationContext) throws -> Void)? = nil) throws -> (URL, DocumentationBundle, DocumentationContext) {
        let workspace = DocumentationWorkspace()
        let context = try DocumentationContext(dataProvider: workspace, diagnosticEngine: DiagnosticEngine(filterLevel: diagnosticFilterLevel))
        context.externalReferenceResolvers = externalResolvers
        context.externalSymbolResolver = externalSymbolResolver
        context.externalMetadata.diagnosticLevel = diagnosticFilterLevel
        try configureContext?(context)
        // Load the bundle using automatic discovery
        let automaticDataProvider = try LocalFileSystemDataProvider(rootURL: bundleURL)
        // Mutate the bundle to include the code listings, then apply to the workspace using a manual provider.
        var bundle = try XCTUnwrap(automaticDataProvider.bundles().first)
        bundle.attributedCodeListings = codeListings
        let dataProvider = PrebuiltLocalFileSystemDataProvider(bundles: [bundle])
        try workspace.registerProvider(dataProvider)
        return (bundleURL, bundle, context)
    }
    
    func testBundleAndContext(copying name: String, excludingPaths excludedPaths: [String] = [], codeListings: [String : AttributedCodeListing] = [:], externalResolvers: [BundleIdentifier : ExternalReferenceResolver] = [:], externalSymbolResolver: ExternalSymbolResolver? = nil,  configureBundle: ((URL) throws -> Void)? = nil) throws -> (URL, DocumentationBundle, DocumentationContext) {
        let sourceURL = try XCTUnwrap(Bundle.module.url(
            forResource: name, withExtension: "docc", subdirectory: "Test Bundles"))
        
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
        
        return try loadBundle(from: bundleURL, codeListings: codeListings, externalResolvers: externalResolvers, externalSymbolResolver: externalSymbolResolver)
    }
    
    func testBundleAndContext(named name: String, codeListings: [String : AttributedCodeListing] = [:], externalResolvers: [String: ExternalReferenceResolver] = [:]) throws -> (DocumentationBundle, DocumentationContext) {
        let bundleURL = try XCTUnwrap(Bundle.module.url(
            forResource: name, withExtension: "docc", subdirectory: "Test Bundles"))
        let (_, bundle, context) = try loadBundle(from: bundleURL, codeListings: codeListings, externalResolvers: externalResolvers)
        return (bundle, context)
    }
    
    func testBundle(named name: String) throws -> DocumentationBundle {
        let (bundle, _) = try testBundleAndContext(named: name)
        return bundle
    }
    
    func testBundleFromRootURL(named name: String) throws -> DocumentationBundle {
        let bundleURL = try XCTUnwrap(Bundle.module.url(
            forResource: name, withExtension: "docc", subdirectory: "Test Bundles"))
        let dataProvider = try LocalFileSystemDataProvider(rootURL: bundleURL)
        
        let bundles = try dataProvider.bundles()
        return bundles[0]
    }
    
    func testBundleAndContext() throws -> (bundle: DocumentationBundle, context: DocumentationContext) {
        let bundle = DocumentationBundle(
            info: DocumentationBundle.Info(
                displayName: "Test",
                identifier: "com.example.test",
                version: "1.0"
            ),
            baseURL: URL(string: "https://example.com/example")!,
            symbolGraphURLs: [],
            markupURLs: [],
            miscResourceURLs: []
        )
        let provider = PrebuiltLocalFileSystemDataProvider(bundles: [bundle])
        let workspace = DocumentationWorkspace()
        try workspace.registerProvider(provider)
        let context = try DocumentationContext(dataProvider: workspace)
        
        return (bundle, context)
    }
    
    func parseDirective<Directive: DirectiveConvertible>(
        _ directive: Directive.Type,
        source: () -> String
    ) throws -> (problemIdentifiers: [String], directive: Directive?) {
        let (bundle, context) = try testBundleAndContext()
        
        let document = Document(parsing: source(), options: .parseBlockDirectives)
        
        let blockDirectiveContainer = try XCTUnwrap(document.child(at: 0) as? BlockDirective)
        
        var problems = [Problem]()
        let directive = directive.init(
            from: blockDirectiveContainer,
            source: nil,
            for: bundle,
            in: context,
            problems: &problems
        )
        
        let problemIDs = problems.map { problem -> String in
            let line = problem.diagnostic.range?.lowerBound.line.description ?? "unknown-line"
            
            return "\(line): \(problem.diagnostic.severity) – \(problem.diagnostic.identifier)"
        }.sorted()
        
        return (problemIDs, directive)
    }
    
    func parseDirective<Directive: RenderableDirectiveConvertible>(
        _ directive: Directive.Type,
        source: () -> String
    ) throws -> (renderBlockContent: RenderBlockContent?, problemIdentifiers: [String], directive: Directive?) {
        let (bundle, context) = try testBundleAndContext()
        
        let document = Document(parsing: source(), options: .parseBlockDirectives)
        
        let blockDirectiveContainer = try XCTUnwrap(document.child(at: 0) as? BlockDirective)
        
        var analyzer = SemanticAnalyzer(source: nil, context: context, bundle: bundle)
        let result = analyzer.visit(blockDirectiveContainer)
        
        let problemIDs = analyzer.problems.map { problem -> String in
            let line = problem.diagnostic.range?.lowerBound.line.description ?? "unknown-line"
            
            return "\(line): \(problem.diagnostic.severity) – \(problem.diagnostic.identifier)"
        }.sorted()
        
        guard let directive = result as? Directive else {
            return (nil, problemIDs, nil)
        }
        
        var contentCompiler = RenderContentCompiler(
            context: context,
            bundle: bundle,
            identifier: ResolvedTopicReference(
                bundleIdentifier: bundle.identifier,
                path: "/test-path-123",
                sourceLanguage: .swift
            )
        )
        
        let renderedContent = directive.render(with: &contentCompiler).first as? RenderBlockContent
        return (renderedContent, problemIDs, directive)
    }
}
