/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

public import Foundation
public import Markdown

/// Additional resources that help users learn a technology.
///
/// A documentation section that provides additional resources,
/// such as references to sample code, videos, and external documentation.
public final class Resources: Semantic, DirectiveConvertible, Abstracted, Redirected {
    public static let directiveName = "Resources"
    public static let introducedVersion = "5.5"
    
    /// A user-facing title that describes the directive.
    public static let title = "Resources"
    
    public let originalMarkup: BlockDirective
    
    /// Introductory content to display before the tiles.
    public let content: MarkupContainer
    
    /// The ``Tile``s to display on the resources section.
    public let tiles: [Tile]
        
    override var children: [Semantic] {
        return [content as Semantic] + tiles
    }
    
    public var abstract: Paragraph? {
        return content.first as? Paragraph
    }
    
    public let redirects: [Redirect]?
    
    /// Creates a new resources section from the given parameters.
    /// 
    /// - Parameters:
    ///   - originalMarkup: A directive that represents the section.
    ///   - content: The section's introductory content.
    ///   - tiles: A collection of thematic content blocks to display on the section.
    ///   - redirects: A collection of URLs that redirect to the section.
    init(originalMarkup: BlockDirective, content: MarkupContainer, tiles: [Tile], redirects: [Redirect]?) {
        self.originalMarkup = originalMarkup
        self.content = content
        self.tiles = tiles
        self.redirects = redirects
    }
    
    @available(*, deprecated, renamed: "init(from:source:for:featureFlags:diagnostics:)", message: "Use 'init(from:source:for:featureFlags:diagnostics:)' instead. This deprecated API will be removed after 6.5 is released.")
    public convenience init?(from directive: BlockDirective, source: URL?, for bundle: DocumentationBundle, featureFlags: FeatureFlags, problems: inout [Problem]) {
        var diagnostics = [Diagnostic]()
        defer {
            problems.append(contentsOf: diagnostics.map { .init(diagnostic: $0) })
        }
        self.init(from: directive, source: source, for: bundle, featureFlags: featureFlags, diagnostics: &diagnostics)
    }
    
    public convenience init?(from directive: BlockDirective, source: URL?, for bundle: DocumentationBundle, featureFlags: FeatureFlags, diagnostics: inout [Diagnostic]) {
        precondition(directive.name == Resources.directiveName)
        
        var remainder: [any Markup]
        let requiredParagraph: Paragraph?
        if let firstParagraph = directive.child(at: 0) as? Paragraph {
            requiredParagraph = firstParagraph
            remainder = Array(directive.children.dropFirst(1))
        } else {
            let diagnostic = Diagnostic(source: source, severity: .warning, range: directive.range, identifier: "org.swift.docc.Resources.HasContent", summary: "\(Resources.directiveName.singleQuoted) directive requires a brief initial paragraph describing what the reader will find on the \(Resources.title) page")
            diagnostics.append(diagnostic)
            remainder = Array(directive.children)
            requiredParagraph = nil
        }

        Semantic.Analyses.HasOnlyKnownDirectives<Resources>(severityIfFound: .warning, allowedDirectives: Tile.DirectiveNames.allCases.map { $0.rawValue } + [Redirect.directiveName]).analyze(directive, children: directive.children, source: source, diagnostics: &diagnostics)
        
        let redirects: [Redirect]
        (redirects, remainder) = remainder.categorize { child -> Redirect? in
            guard let childDirective = child as? BlockDirective, childDirective.name == Redirect.directiveName else {
                return nil
            }
            return Redirect(from: childDirective, source: source, for: bundle, featureFlags: featureFlags, diagnostics: &diagnostics)
        }
        
        let tiles: [Tile]
        (tiles, remainder) = remainder.categorize { child -> Tile? in
            guard let childDirective = child as? BlockDirective, Tile.DirectiveNames(rawValue: childDirective.name) != nil else {
                return nil
            }
            return Tile(from: childDirective, source: source, for: bundle, featureFlags: featureFlags, diagnostics: &diagnostics)
        }
        
        var seenTileDirectiveNames = Set<String>()
        let tilesWithoutDuplicates = tiles.filter { tile in
            let tileName = tile.originalMarkup.name
            guard !seenTileDirectiveNames.contains(tile.title) else {
                if !tileName.isEmpty,
                    let range = tile.originalMarkup.range {
                    let solution = Solution.init(summary: "Remove extraneous \(tileName.singleQuoted) directive", replacements: [.init(range: range, replacement: "")])
                    let diagnostic = Diagnostic(source: source, severity: .warning, range: tile.originalMarkup.range, identifier: "org.swift.docc.Resources.DuplicateTile", summary: "Duplicate child directive \(tileName.singleQuoted) in \(Resources.directiveName.singleQuoted)", solutions: [solution])
                    diagnostics.append(diagnostic)
                }
                return false
            }
            
            seenTileDirectiveNames.insert(tileName)
            return true
        }
        
        for extraneousElement in remainder {
            let solutions: [Solution] = if let range = extraneousElement.range {
                [Solution(summary: "Remove extraneous element", replacements: [.init(range: range, replacement: "")])]
            } else {
                []
            }
            diagnostics.append(
                Diagnostic(source: source, severity: .warning, range: extraneousElement.range, identifier: "org.swift.docc.Resources.ExtraneousContent", summary: "Extraneous child element of \(Resources.directiveName.singleQuoted) directive", solutions: solutions)
            )
        }
        
        guard let paragraph = requiredParagraph else {
            return nil
        }
        
        self.init(originalMarkup: directive, content: MarkupContainer(paragraph), tiles: tilesWithoutDuplicates, redirects: redirects.isEmpty ? nil : redirects)
    }
    
    public override func accept<V: SemanticVisitor>(_ visitor: inout V) -> V.Result {
        return visitor.visitResources(self)
    }
}

