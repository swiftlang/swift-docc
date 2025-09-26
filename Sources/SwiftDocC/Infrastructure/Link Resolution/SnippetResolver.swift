/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SymbolKit
import Markdown

/// A type that resolves snippet paths.
final class SnippetResolver {
    typealias SnippetMixin = SymbolKit.SymbolGraph.Symbol.Snippet
    typealias Explanation  = Markdown.Document
    
    /// Information about a resolved snippet
    struct ResolvedSnippet {
        fileprivate var path: String // For use in diagnostics
        var mixin: SnippetMixin
        var explanation: Explanation?
    }
    /// A snippet that has been resolved, either successfully or not.
    enum SnippetResolutionResult {
        case success(ResolvedSnippet)
        case failure(TopicReferenceResolutionErrorInfo)
    }
    
    private var snippets: [String: ResolvedSnippet] = [:]
    
    init(symbolGraphLoader: SymbolGraphLoader) {
        var snippets: [String: ResolvedSnippet] = [:]
        
        for graph in symbolGraphLoader.snippetSymbolGraphs.values {
            for symbol in graph.symbols.values {
                guard let snippetMixin = symbol[mixin: SnippetMixin.self] else { continue }
                
                let path: String = if symbol.pathComponents.first == "Snippets" {
                    symbol.pathComponents.dropFirst().joined(separator: "/")
                } else {
                    symbol.pathComponents.joined(separator: "/")
                }
                
                snippets[path] = .init(path: path, mixin: snippetMixin, explanation: symbol.docComment.map {
                    Document(parsing: $0.lines.map(\.text).joined(separator: "\n"), options: .parseBlockDirectives)
                })
            }
        }
        
        self.snippets = snippets
    }
 
    func resolveSnippet(path authoredPath: String) -> SnippetResolutionResult {
        // Snippet paths are relative to the root of the Swift Package.
        // The first to components are always the same (the package name followed by "Snippets").
        // The later components can either be subdirectories of the "Snippets" directory or the base name of a snippet '.swift' file (without the extension).
          
        // Drop the common package name + "Snippets" prefix (that's always the same), if the authored path includes it.
        // This enables the author to omit this prefix (but include it for backwards compatibility with older DocC versions).
        var components = authoredPath.split(separator: "/", omittingEmptySubsequences: true)
        
        // It's possible that the package name is "Snippets", resulting in two identical components. Skip until the last of those two.
        if let snippetsPrefixIndex = components.prefix(2).lastIndex(of: "Snippets"),
           // Don't search for an empty string if the snippet happens to be named "Snippets"
           let relativePathStart = components.index(snippetsPrefixIndex, offsetBy: 1, limitedBy: components.endIndex - 1)
        {
            components.removeFirst(relativePathStart)
        }
        
        let path = components.joined(separator: "/")
        if let found = snippets[path] {
            return .success(found)
        } else {
            return .failure(.init("Snippet named '\(path)' couldn't be found"))
        }
    }
    
    func validate(slice: String, for resolvedSnippet: ResolvedSnippet) -> TopicReferenceResolutionErrorInfo? {
        guard resolvedSnippet.mixin.slices[slice] == nil else {
            return nil
        }
            
        return .init("Slice named '\(slice)' doesn't exist in snippet '\(resolvedSnippet.path)'")
    }
}

// MARK: Diagnostics

extension SnippetResolver {
    static func unknownSnippetSliceProblem(source: URL?, range: SourceRange?, errorInfo: TopicReferenceResolutionErrorInfo) -> Problem {
        _problem(source: source, range: range, errorInfo: errorInfo, id: "org.swift.docc.unknownSnippetPath")
    }

    static func unresolvedSnippetPathProblem(source: URL?, range: SourceRange?, errorInfo: TopicReferenceResolutionErrorInfo) -> Problem {
        _problem(source: source, range: range, errorInfo: errorInfo, id: "org.swift.docc.unresolvedSnippetPath")
    }
    
    private static func _problem(source: URL?, range: SourceRange?, errorInfo: TopicReferenceResolutionErrorInfo, id: String) -> Problem {
        var solutions: [Solution] = []
        var notes: [DiagnosticNote] = []
        if let range {
            if let note = errorInfo.note, let source {
                notes.append(DiagnosticNote(source: source, range: range, message: note))
            }
            
            solutions.append(contentsOf: errorInfo.solutions(referenceSourceRange: range))
        }
        
        let diagnosticRange: SourceRange?
        if var rangeAdjustment = errorInfo.rangeAdjustment, let range {
            rangeAdjustment.offsetWithRange(range)
            assert(rangeAdjustment.lowerBound.column >= 0, """
                Unresolved snippet reference range adjustment created range with negative column.
                Source: \(source?.absoluteString ?? "nil")
                Range: \(rangeAdjustment.lowerBound.description):\(rangeAdjustment.upperBound.description)
                Summary: \(errorInfo.message)
                """)
            diagnosticRange = rangeAdjustment
        } else {
            diagnosticRange = range
        }
        
        let diagnostic = Diagnostic(source: source, severity: .warning, range: diagnosticRange, identifier: id, summary: errorInfo.message, notes: notes)
        return Problem(diagnostic: diagnostic, possibleSolutions: solutions)
    }
}
