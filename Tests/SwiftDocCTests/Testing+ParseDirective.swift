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
import DocCTestUtilities

// MARK: Using an in-memory file system

func parseDirective<Directive: DirectiveConvertible>(
    _ directive: Directive.Type,
    content: () -> String,
    sourceLocation: Testing.SourceLocation = #_sourceLocation
) async throws -> (problemIdentifiers: [String], directive: Directive?) {
    let source = URL(fileURLWithPath: "/path/to/test-source-\(ProcessInfo.processInfo.globallyUniqueString)")
    let document = Document(parsing: content(), source: source, options: .parseBlockDirectives)
    
    let blockDirectiveContainer = try #require(document.child(at: 0) as? BlockDirective, sourceLocation: sourceLocation)
    
    var problems = [Problem]()
    let inputs = try await makeEmptyContext().inputs
    let directive = directive.init(from: blockDirectiveContainer, source: source, for: inputs, problems: &problems)
    
    let problemIDs = problems.map { problem -> String in
        #expect(problem.diagnostic.source != nil, "Problem \(problem.diagnostic.identifier) is missing a source URL.", sourceLocation: sourceLocation)
        let line = problem.diagnostic.range?.lowerBound.line.description ?? "unknown-line"
        
        return "\(line): \(problem.diagnostic.severity) – \(problem.diagnostic.identifier)"
    }.sorted()
    
    return (problemIDs, directive)
}

func parseDirective<Directive: RenderableDirectiveConvertible>(
    _ directive: Directive.Type,
    catalog: Folder,
    content: () -> String,
    sourceLocation: Testing.SourceLocation = #_sourceLocation
) async throws -> (
    renderBlockContent: [RenderBlockContent],
    problemIdentifiers: [String],
    directive: Directive?,
    collectedReferences: [String : any RenderReference]
) {
    let context = try await load(catalog: catalog)
    return try parseDirective(directive, context: context, content: content, sourceLocation: sourceLocation)
}

func parseDirective<Directive: RenderableDirectiveConvertible>(
    _ directive: Directive.Type,
    withAvailableAssetNames assetNames: [String],
    content: () -> String,
    sourceLocation: Testing.SourceLocation = #_sourceLocation
) async throws -> (renderBlockContent: [RenderBlockContent], problemIdentifiers: [String], directive: Directive?) {
    let context = try await load(catalog: Folder(name: "Something.docc", content: assetNames.map {
        DataFile(name: $0, data: Data())
    }))
    
    let (renderedContent, problems, directive, _) = try parseDirective(directive, context: context, content: content, sourceLocation: sourceLocation)
    return (renderedContent, problems, directive)
}

// MARK: Using the real file system

func parseDirective<Directive: RenderableDirectiveConvertible>(
    _ directive: Directive.Type,
    loadingOnDiskCatalogNamed catalogName: String? = nil,
    content: () -> String,
    sourceLocation: Testing.SourceLocation = #_sourceLocation
) async throws -> (
    renderBlockContent: [RenderBlockContent],
    problemIdentifiers: [String],
    directive: Directive?
) {
    let (renderedContent, problems, directive, _) = try await parseDirective(directive, loadingOnDiskCatalogNamed: catalogName, content: content, sourceLocation: sourceLocation)
    return (renderedContent, problems, directive)
}

func parseDirective<Directive: RenderableDirectiveConvertible>(
    _ directive: Directive.Type,
    loadingOnDiskCatalogNamed catalogName: String? = nil,
    content: () -> String,
    sourceLocation: Testing.SourceLocation = #_sourceLocation
) async throws -> (
    renderBlockContent: [RenderBlockContent],
    problemIdentifiers: [String],
    directive: Directive?,
    collectedReferences: [String : any RenderReference]
) {
    let context: DocumentationContext = if let catalogName {
        try await loadFromDisk(catalogName: catalogName)
    } else {
        try await makeEmptyContext()
    }
    return try parseDirective(directive, context: context, content: content, sourceLocation: sourceLocation)
}

// MARK: - Private implementation

private func parseDirective<Directive: RenderableDirectiveConvertible>(
    _ directive: Directive.Type,
    context: DocumentationContext,
    content: () -> String,
    sourceLocation: Testing.SourceLocation = #_sourceLocation
) throws -> (
    renderBlockContent: [RenderBlockContent],
    problemIdentifiers: [String],
    directive: Directive?,
    collectedReferences: [String : any RenderReference]
) {
    context.diagnosticEngine.clearDiagnostics()
    
    let source = URL(fileURLWithPath: "/path/to/test-source-\(ProcessInfo.processInfo.globallyUniqueString)")
    let document = Document(parsing: content(), source: source, options: [.parseBlockDirectives, .parseSymbolLinks])
    
    let blockDirectiveContainer = try #require(document.child(at: 0) as? BlockDirective, sourceLocation: sourceLocation)
    
    var analyzer = SemanticAnalyzer(source: source, bundle: context.inputs)
    let result = analyzer.visit(blockDirectiveContainer)
    context.diagnosticEngine.emit(analyzer.problems)
    
    var referenceResolver = MarkupReferenceResolver(context: context, rootReference: context.inputs.rootReference)
    
    _ = referenceResolver.visit(blockDirectiveContainer)
    context.diagnosticEngine.emit(referenceResolver.problems)
    
    func problemIDs() throws -> [String] {
        try context.problems.map { problem -> (line: Int, severity: String, id: String) in
            #expect(problem.diagnostic.source != nil, "Problem \(problem.diagnostic.identifier) is missing a source URL.", sourceLocation: sourceLocation)
            let line = try #require(problem.diagnostic.range, sourceLocation: sourceLocation).lowerBound.line
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
    
    let renderedContent = try #require(directive.render(with: &contentCompiler) as? [RenderBlockContent], sourceLocation: sourceLocation)
    
    let collectedReferences = contentCompiler.videoReferences
        .mapValues { $0 as (any RenderReference) }
        .merging(
            contentCompiler.imageReferences,
            uniquingKeysWith: { videoReference, _ in
                Issue.record("Non-unique references.", sourceLocation: sourceLocation)
                return videoReference
            }
        )
    
    return (renderedContent, try problemIDs(), directive, collectedReferences)
}
