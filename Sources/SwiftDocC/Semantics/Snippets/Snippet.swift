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
/// Use a `Snippet` directive to embed a code example from the project's "Snippets" directory on the page.
/// The `path` argument is the relative path from the package's top-level "Snippets" directory to your snippet file without the `.swift` extension.
///
/// ```markdown
/// @Snippet(path: "example-snippet", slice: "setup")
/// ```
///
/// If you prefer, you can specify the relative path from the package's _root_ directory (by including a "Snippets/" prefix).
/// You can also include the package name---as defined in `Package.swift`---before the "Snippets/" prefix.
/// Neither of these leading path components are necessary because all your snippet code files are always located in your package's "Snippets" directory.
///
/// > Earlier Versions:
/// > Before Swift-DocC 6.2, the `@Snippet` path needed to include both the package name component and the "Snippets" component:
/// >
/// > ```markdown
/// > @Snippet(path: "my-package/Snippets/example-snippet")
/// > ```
///
/// You can define named slices of your snippet by annotating the snippet file with `// snippet.<name>` and `// snippet.end` lines.
/// A named slice automatically ends at the start of the next named slice, without an explicit `snippet.end` annotation.
///
/// If the referenced snippet includes annotated slices, you can limit the embedded code example to a certain line range by specifying a `slice` name.
/// By default, the embedded code example includes the full snippet. For more information, see <doc:adding-code-snippets-to-your-content#Slice-up-your-snippet-to-break-it-up-in-your-content>.
public final class Snippet: Semantic, AutomaticDirectiveConvertible {
    public static let introducedVersion = "5.7"
    public let originalMarkup: BlockDirective
    
    /// The relative path from your package's top-level "Snippets" directory to the snippet file that you want to embed in the page, without the `.swift` file extension.
    @DirectiveArgumentWrapped
    public var path: String
    
    /// The name of a snippet slice to limit the embedded code example to a certain line range.
    ///
    /// By default, the embedded code example includes the full snippet.
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
        guard case .success(let resolvedSnippet) = contentCompiler.context.snippetResolver.resolveSnippet(path: path) else {
            return []
        }
        let mixin = resolvedSnippet.mixin
        
        if let slice {
            guard let sliceRange = mixin.slices[slice] else {
                // The warning says that unrecognized snippet slices will ignore the entire snippet.
                return []
            }
            // Render only this slice without the explanatory content.
            let lines = mixin.lines
                // Trim the lines
                .dropFirst(sliceRange.startIndex).prefix(sliceRange.endIndex - sliceRange.startIndex)
                // Trim the whitespace
                .linesWithoutLeadingWhitespace()
                // Make dedicated copies of each line because the RenderBlockContent.codeListing requires it.
                .map { String($0) }
            
            return [RenderBlockContent.codeListing(.init(syntax: mixin.language, code: lines, metadata: nil))]
        } else {
            // Render the full snippet and its explanatory content.
            let fullCode = RenderBlockContent.codeListing(.init(syntax: mixin.language, code: mixin.lines, metadata: nil))
            
            var content: [any RenderContent] = resolvedSnippet.explanation?.children.flatMap { contentCompiler.visit($0) } ?? []
            content.append(fullCode)
            return content
        }
    }
}
