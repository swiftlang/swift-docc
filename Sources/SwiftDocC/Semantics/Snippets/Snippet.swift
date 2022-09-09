/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown

public final class Snippet: Semantic, AutomaticDirectiveConvertible {
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
