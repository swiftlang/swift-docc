/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

public import Foundation
public import Markdown

extension Semantic.Analyses {
    /**
     Separates `children` into directives whose names match `Child.directiveName` and those remaining, attempting to convert extracted children to the semantic `Child` type.
     */
    public struct ExtractAll<Child: Semantic & DirectiveConvertible> {
        public init() {}
        
        public func analyze(_ directive: BlockDirective, children: some Sequence<Markup>, source: URL?, for bundle: DocumentationBundle, in context: DocumentationContext, problems: inout [Problem]) -> ([Child], remainder: MarkupContainer) {
            return Semantic.Analyses.extractAll(
                childType: Child.self,
                children: children,
                source: source,
                for: bundle,
                in: context,
                problems: &problems
            ) as! ([Child], MarkupContainer)
        }
    }
    
    static func extractAll(
        childType: DirectiveConvertible.Type,
        children: some Sequence<Markup>,
        source: URL?,
        for bundle: DocumentationBundle,
        in context: DocumentationContext,
        problems: inout [Problem]
    ) -> ([DirectiveConvertible], remainder: MarkupContainer) {
        let (candidates, remainder) = children.categorize { child -> BlockDirective? in
            guard let childDirective = child as? BlockDirective,
                childType.canConvertDirective(childDirective) else {
                    return nil
            }
            return childDirective
        }
        let converted = candidates.compactMap {
            childType.init(from: $0, source: source, for: bundle, in: context, problems: &problems)
        }
        return (converted, remainder: MarkupContainer(remainder))
    }
    
    /**
     Separates `children` into markup elements that are of a specific type without performing any further analysis.
     */
    public struct ExtractAllMarkup<Child: Markup> {
        public init() {}
        
        public func analyze(_ directive: BlockDirective, children: some Sequence<Markup>, source: URL?, problems: inout [Problem]) -> ([Child], remainder: MarkupContainer) {
            let (matches, remainder) = children.categorize {
                $0 as? Child
            }
            return (matches, remainder: MarkupContainer(remainder))
        }
        
        @available(*, deprecated, renamed: "analyze(_:children:source:problems:)", message: "Use 'analyze(_:children:source:problems:)' instead. This deprecated API will be removed after 6.2 is released")
        public func analyze(_ directive: BlockDirective, children: some Sequence<Markup>, source: URL?, for _: DocumentationBundle, in _: DocumentationContext, problems: inout [Problem]) -> ([Child], remainder: MarkupContainer) {
            analyze(directive, children: children, source: source, problems: &problems)
        }
    }
}

