/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

public import Foundation
public import Markdown

extension Semantic.Analyses {
    /**
     Checks to see if a directive has child markup content.
     */
    public struct HasContent<Parent: Semantic & DirectiveConvertible> {
        let additionalContext: String
        public init(additionalContext: String? = nil) {
            if let additionalContext,
                !additionalContext.isEmpty {
                self.additionalContext = "; \(additionalContext)"
            } else {
                self.additionalContext = ""
            }
        }
        
        @available(*, deprecated, renamed: "analyze(_:children:source:diagnostics:)", message: "Use 'analyze(_:children:source:diagnostics:)' instead. This deprecated API will be removed after 6.5 is released.")
        public func analyze(_ directive: BlockDirective, children: some Sequence<any Markup>, source: URL?, problems: inout [Problem]) -> MarkupContainer {
            var diagnostics = [Diagnostic]()
            defer {
                problems.append(contentsOf: diagnostics.map { .init(diagnostic: $0) })
            }
            return analyze(directive, children: children, source: source, diagnostics: &diagnostics)
        }
        
        public func analyze(_ directive: BlockDirective, children: some Sequence<any Markup>, source: URL?, diagnostics: inout [Diagnostic]) -> MarkupContainer {
            let children = Array(children)
            guard children.isEmpty else {
                return MarkupContainer(children)
            }
            let diagnostic = Diagnostic(source: source, severity: .warning, range: directive.range, identifier: "org.swift.docc.\(Parent.self).HasContent"
                , summary: "\(Parent.directiveName.singleQuoted) directive has no content\(additionalContext)")
            diagnostics.append(diagnostic)
            return MarkupContainer()
        }
    }
}
