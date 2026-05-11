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
     Separates `children` into directives whose names match `Child.directiveName` and those remaining, attempting to convert extracted children to the semantic `Child` type.
     */
    public struct ExtractAll<Child: Semantic & DirectiveConvertible> {
        let featureFlags: FeatureFlags
        public init(featureFlags: FeatureFlags = .init()) {
            self.featureFlags = featureFlags
        }
        
        @available(*, deprecated, renamed: "analyze(_:children:source:diagnostics:)", message: "Use 'analyze(_:children:source:diagnostics:)' instead. This deprecated API will be removed after 6.5 is released.")
        public func analyze(_ directive: BlockDirective, children: some Sequence<any Markup>, source: URL?, for bundle: DocumentationBundle, problems: inout [Problem]) -> ([Child], remainder: MarkupContainer) {
            var diagnostics = [Diagnostic]()
            defer {
                problems.append(contentsOf: diagnostics.map { .init(diagnostic: $0) })
            }
            return analyze(directive, children: children, source: source, for: bundle, diagnostics: &diagnostics)
        }
        
        public func analyze(_ directive: BlockDirective, children: some Sequence<any Markup>, source: URL?, for bundle: DocumentationBundle, diagnostics: inout [Diagnostic]) -> ([Child], remainder: MarkupContainer) {
            return Semantic.Analyses.extractAll(
                childType: Child.self,
                children: children,
                source: source,
                for: bundle,
                featureFlags: featureFlags,
                diagnostics: &diagnostics
            ) as! ([Child], MarkupContainer)
        }
    }
    
    static func extractAll(
        childType: any DirectiveConvertible.Type,
        children: some Sequence<any Markup>,
        source: URL?,
        for bundle: DocumentationBundle,
        featureFlags: FeatureFlags,
        diagnostics: inout [Diagnostic]
    ) -> ([any DirectiveConvertible], remainder: MarkupContainer) {
        let (candidates, remainder) = children.categorize { child -> BlockDirective? in
            guard let childDirective = child as? BlockDirective,
                childType.canConvertDirective(childDirective) else {
                    return nil
            }
            return childDirective
        }
        let converted = candidates.compactMap {
            childType.init(from: $0, source: source, for: bundle, featureFlags: featureFlags, diagnostics: &diagnostics)
        }
        return (converted, remainder: MarkupContainer(remainder))
    }
    
    /**
     Separates `children` into markup elements that are of a specific type without performing any further analysis.
     */
    public struct ExtractAllMarkup<Child: Markup> {
        public init() {}
        
        @available(*, deprecated, renamed: "analyze(_:children:source:diagnostics:)", message: "Use 'analyze(_:children:source:diagnostics:)' instead. This deprecated API will be removed after 6.5 is released.")
        public func analyze(_ directive: BlockDirective, children: some Sequence<any Markup>, source: URL?, problems _: inout [Problem]) -> ([Child], remainder: MarkupContainer) {
            var diagnostics = [Diagnostic]()
            return analyze(directive, children: children, source: source, diagnostics: &diagnostics)
        }
        
        public func analyze(_ directive: BlockDirective, children: some Sequence<any Markup>, source: URL?, diagnostics _: inout [Diagnostic]) -> ([Child], remainder: MarkupContainer) {
            let (matches, remainder) = children.categorize {
                $0 as? Child
            }
            return (matches, remainder: MarkupContainer(remainder))
        }
    }
}

