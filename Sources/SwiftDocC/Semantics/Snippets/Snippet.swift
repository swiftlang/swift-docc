/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
public import Markdown
import SymbolKit

/// Embeds a code example from the project's code snippets.
///
/// ```markdown
/// @Snippet(path: "my-package/Snippets/example-snippet", slice: "setup")
/// ```
///
/// Place the `Snippet` directive to embed a code example from the project's snippet directory.
/// The path that references the snippet is identified with three parts:
///
/// 1. The package name as defined in `Package.swift`
///
/// 2. The directory path to the snippet file, starting with "Snippets".
///
/// 3. The name of your snippet file without the `.swift` extension
///
/// If the snippet had slices annotated within it, an individual slice of the snippet can be referenced with the `slice` option.
/// Without the option defined, the directive embeds the entire snippet.
public final class Snippet: Semantic, AutomaticDirectiveConvertible {
    public static let introducedVersion = "5.7"
    public let originalMarkup: BlockDirective
    
    /// The path components of a symbol link that would be used to resolve a reference to a snippet,
    /// only occurring as a block directive argument.
    @DirectiveArgumentWrapped
    public var path: String
    
    /// An optional named range to limit the lines shown.
    @DirectiveArgumentWrapped
    public var slice: String? = nil
    
    static var keyPaths: [String : AnyKeyPath] = [
        "path"  : \Snippet._path,
        "slice" : \Snippet._slice,
    ]
    
    @available(*, deprecated, message: "Do not call directly. Required for 'AutomaticDirectiveConvertible'.")
    init(originalMarkup: BlockDirective) {
        self.originalMarkup = originalMarkup
        super.init()
    }
    
    func validate(problems: inout [Problem], source: URL?) -> Bool {
        if path.isEmpty {
            problems.append(Problem(diagnostic: Diagnostic(source: source, severity: .warning, range: originalMarkup.range, identifier: "org.swift.docc.EmptySnippetLink", summary: "No path provided to snippet; use a symbol link path to a known snippet"), possibleSolutions: []))
            return false
        }
        
        return true
    }
}

extension Snippet: RenderableDirectiveConvertible {
    func render(with contentCompiler: inout RenderContentCompiler) -> [any RenderContent] {
        guard let snippet = Snippet(from: originalMarkup, for: contentCompiler.bundle) else {
                return []
            }
            
            guard let snippetReference = contentCompiler.resolveSymbolReference(destination: snippet.path),
                  let snippetEntity = try? contentCompiler.context.entity(with: snippetReference),
                  let snippetSymbol = snippetEntity.symbol,
                  let snippetMixin = snippetSymbol.mixins[SymbolGraph.Symbol.Snippet.mixinKey] as? SymbolGraph.Symbol.Snippet else {
                return []
            }
            
            if let requestedSlice = snippet.slice,
               let requestedLineRange = snippetMixin.slices[requestedSlice] {
                // Render only the slice.
                let lineRange = requestedLineRange.lowerBound..<min(requestedLineRange.upperBound, snippetMixin.lines.count)
                let lines = snippetMixin.lines[lineRange]
                let minimumIndentation = lines.map { $0.prefix { $0.isWhitespace }.count }.min() ?? 0
                let trimmedLines = lines.map { String($0.dropFirst(minimumIndentation)) }
                let copy = FeatureFlags.current.isExperimentalCodeBlockAnnotationsEnabled
                return [RenderBlockContent.codeListing(.init(syntax: snippetMixin.language, code: trimmedLines, metadata: nil, copyToClipboard: copy))]
            } else {
                // Render the whole snippet with its explanation content.
                let docCommentContent = snippetEntity.markup.children.flatMap { contentCompiler.visit($0) }
                let copy = FeatureFlags.current.isExperimentalCodeBlockAnnotationsEnabled
                let code = RenderBlockContent.codeListing(.init(syntax: snippetMixin.language, code: snippetMixin.lines, metadata: nil, copyToClipboard: copy))
                return docCommentContent + [code]
            }
    }
}
