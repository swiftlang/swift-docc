/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown

extension Semantic.Analyses {
    /**
     Checks to see if a directive has child markup content.
     */
    public struct HasContent<Parent: Semantic & DirectiveConvertible>: SemanticAnalysis {
        let additionalContext: String
        public init(additionalContext: String? = nil) {
            if let additionalContext = additionalContext,
                !additionalContext.isEmpty {
                self.additionalContext = "; \(additionalContext)"
            } else {
                self.additionalContext = ""
            }
        }
        
        public func analyze<Children: Sequence>(_ directive: BlockDirective, children: Children, source: URL?, for bundle: DocumentationBundle, in context: DocumentationContext, problems: inout [Problem]) -> MarkupContainer where Children.Element == Markup {
            let children = Array(children)
            guard children.isEmpty else {
                return MarkupContainer(children)
            }
            let diagnostic = Diagnostic(source: source, severity: .warning, range: directive.range, identifier: "org.swift.docc.\(Parent.self).HasContent"
                , summary: "\(Parent.directiveName.singleQuoted) directive has no content\(additionalContext)")
            problems.append(Problem(diagnostic: diagnostic, possibleSolutions: []))
            return MarkupContainer()
        }
    }
}
