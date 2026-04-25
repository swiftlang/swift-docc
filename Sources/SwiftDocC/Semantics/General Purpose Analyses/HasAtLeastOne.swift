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
     Checks to see if a parent directive has at least one child directive of a specified type. If so, return those that match and those that don't.
     */
    public struct HasAtLeastOne<Parent: Semantic & DirectiveConvertible, Child: Semantic & DirectiveConvertible> {
        let severityIfNotFound: DiagnosticSeverity?
        let featureFlags: FeatureFlags
        public init(severityIfNotFound: DiagnosticSeverity?, featureFlags: FeatureFlags = .init()) {
            self.severityIfNotFound = severityIfNotFound
            self.featureFlags = featureFlags
        }
        
        @available(*, deprecated, renamed: "analyze(_:children:source:for:diagnostics:)", message: "Use analyze(_:children:source:for:diagnostics:)' instead. This deprecated API will be removed after 6.5 is released.")
        public func analyze(_ directive: BlockDirective, children: some Sequence<any Markup>, source: URL?, for bundle: DocumentationBundle, problems: inout [Problem]) -> ([Child], remainder: MarkupContainer) {
            var diagnostics = [Diagnostic]()
            defer {
                problems.append(contentsOf: diagnostics.map { .init(diagnostic: $0) })
            }
            return analyze(directive, children: children, source: source, for: bundle, diagnostics: &diagnostics)
        }
        
        public func analyze(_ directive: BlockDirective, children: some Sequence<any Markup>, source: URL?, for bundle: DocumentationBundle, diagnostics: inout [Diagnostic]) -> ([Child], remainder: MarkupContainer) {
            Semantic.Analyses.extractAtLeastOne(
                childType: Child.self,
                parentDirective: directive,
                children: children,
                source: source,
                for: bundle,
                severityIfNotFound: severityIfNotFound,
                featureFlags: featureFlags,
                diagnostics: &diagnostics
            ) as! ([Child], MarkupContainer)
        }
    }
    
    static func extractAtLeastOne(
        childType: any DirectiveConvertible.Type,
        parentDirective: BlockDirective,
        children: some Sequence<any Markup>,
        source: URL?,
        for bundle: DocumentationBundle,
        severityIfNotFound: DiagnosticSeverity? = .warning,
        featureFlags: FeatureFlags,
        diagnostics: inout [Diagnostic]
    ) -> ([any DirectiveConvertible], remainder: MarkupContainer) {
        let (matches, remainder) = children.categorize { child -> BlockDirective? in
            guard let childDirective = child as? BlockDirective,
                childType.canConvertDirective(childDirective)
            else {
                    return nil
            }
            return childDirective
        }
        
        if matches.isEmpty, let severityIfNotFound {
            let diagnostic = Diagnostic(
                source: source,
                severity: severityIfNotFound,
                range: parentDirective.range,
                identifier: "org.swift.docc.HasAtLeastOne<\(parentDirective.name), \(childType)>",
                summary: "Missing required \(childType.directiveName.singleQuoted) child directive",
                explanation:
                    """
                    The \(parentDirective.name.singleQuoted) directive requires at least one \
                    \(childType.directiveName.singleQuoted) child directive
                    """
            )
            diagnostics.append(diagnostic)
        }
        
        let converted = matches.compactMap { childDirective -> (any DirectiveConvertible)? in
            return childType.init(
                from: childDirective,
                source: source,
                for: bundle,
                featureFlags: featureFlags,
                diagnostics: &diagnostics
            )
        }
        
        return (converted, remainder: MarkupContainer(remainder))
    }
}

