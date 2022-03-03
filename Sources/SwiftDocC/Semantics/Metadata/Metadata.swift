/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown

/// A directive that contains various metadata about a page.
///
/// This directive acts as a container for metadata and configuration without any arguments of its own.
///
/// ## Topics
/// 
/// ### Child Directives
///
/// - ``DocumentationExtension``
/// - ``TechnologyRoot``
public final class Metadata: Semantic, DirectiveConvertible {
    public static let directiveName = "Metadata"
    public let originalMarkup: BlockDirective
    
    /// Configuration that describes how this documentation extension file merges or overrides the in-source documentation.
    let documentationOptions: DocumentationExtension?
    /// Configuration to make this page root-level documentation.
    let technologyRoot: TechnologyRoot?
    /// Configuration to customize this page's symbol's display name.
    let displayName: DisplayName?
    
    /// Creates a metadata object with a given markup, documentation extension, and technology root.
    /// - Parameters:
    ///   - originalMarkup: The original markup for this metadata directive.
    ///   - documentationExtension: Optional configuration that describes how this documentation extension file merges or overrides the in-source documentation.
    ///   - technologyRoot: Optional configuration to make this page root-level documentation.
    ///   - displayName:Optional configuration to customize this page's symbol's display name.
    init(originalMarkup: BlockDirective, documentationExtension: DocumentationExtension?, technologyRoot: TechnologyRoot?, displayName: DisplayName?) {
        self.originalMarkup = originalMarkup
        self.documentationOptions = documentationExtension
        self.technologyRoot = technologyRoot
        self.displayName = displayName
    }
    
    public convenience init?(from directive: BlockDirective, source: URL?, for bundle: DocumentationBundle, in context: DocumentationContext, problems: inout [Problem]) {
        precondition(directive.name == Metadata.directiveName)
                
        _ = Semantic.Analyses.HasOnlyKnownArguments<Metadata>(severityIfFound: .warning, allowedArguments: []).analyze(directive, children: directive.children, source: source, for: bundle, in: context, problems: &problems)
        
        Semantic.Analyses.HasOnlyKnownDirectives<Metadata>(severityIfFound: .warning, allowedDirectives: [DocumentationExtension.directiveName, TechnologyRoot.directiveName, DisplayName.directiveName]).analyze(directive, children: directive.children, source: source, for: bundle, in: context, problems: &problems)
        
        var remainder: MarkupContainer
        let documentationExtension: DocumentationExtension?
        (documentationExtension, remainder) = Semantic.Analyses.HasAtMostOne<Metadata, DocumentationExtension>().analyze(directive, children: directive.children, source: source, for: bundle, in: context, problems: &problems)
        
        let technologyRoot: TechnologyRoot?
        (technologyRoot, remainder) = Semantic.Analyses.HasAtMostOne<Metadata, TechnologyRoot>().analyze(directive, children: remainder, source: source, for: bundle, in: context, problems: &problems)
        
        let displayName: DisplayName?
        (displayName, remainder) = Semantic.Analyses.HasAtMostOne<Metadata, DisplayName>().analyze(directive, children: remainder, source: source, for: bundle, in: context, problems: &problems)
        
        if !remainder.isEmpty {
            let diagnostic = Diagnostic(source: source, severity: .warning, range: directive.range, identifier: "org.swift.docc.\(Metadata.directiveName).UnexpectedContent", summary: "\(Metadata.directiveName.singleQuoted) directive has content but none is expected")
            problems.append(Problem(diagnostic: diagnostic, possibleSolutions: []))
        }
        
        // Check that something is configured in the metadata block
        if documentationExtension == nil && technologyRoot == nil && displayName == nil {
            let diagnostic = Diagnostic(source: source, severity: .information, range: directive.range, identifier: "org.swift.docc.\(Metadata.directiveName).NoConfiguration", summary: "\(Metadata.directiveName.singleQuoted) doesn't configure anything and has no effect")
            
            let solutions = directive.range.map {
                [Solution(summary: "Remove this \(Metadata.directiveName.singleQuoted) directive.", replacements: [Replacement(range: $0, replacement: "")])]
            } ?? []
            problems.append(Problem(diagnostic: diagnostic, possibleSolutions: solutions))
        }
        
        self.init(originalMarkup: directive, documentationExtension: documentationExtension, technologyRoot: technologyRoot, displayName: displayName)
    }
}

