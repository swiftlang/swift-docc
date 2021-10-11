/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown

/// Additional resources that help users learn a technology.
///
/// A documentation section that provides additional resources,
/// such as references to sample code, videos, and external documentation.
public final class Resources: Semantic, DirectiveConvertible, Abstracted, Redirected {
    public static let directiveName = "Resources"
    
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
    
    public convenience init?(from directive: BlockDirective, source: URL?, for bundle: DocumentationBundle, in context: DocumentationContext, problems: inout [Problem]) {
        precondition(directive.name == Resources.directiveName)
        
        var remainder: [Markup]
        let requiredParagraph: Paragraph?
        if let firstParagraph = directive.child(at: 0) as? Paragraph {
            requiredParagraph = firstParagraph
            remainder = Array(directive.children.dropFirst(1))
        } else {
            let diagnostic = Diagnostic(source: source, severity: .warning, range: directive.range, identifier: "org.swift.docc.Resources.HasContent", summary: "\(Resources.directiveName.singleQuoted) directive requires a brief initial paragraph describing what the reader will find on the \(Resources.title) page")
            problems.append(Problem(diagnostic: diagnostic, possibleSolutions: []))
            remainder = Array(directive.children)
            requiredParagraph = nil
        }

        Semantic.Analyses.HasOnlyKnownDirectives<Resources>(severityIfFound: .warning, allowedDirectives: Tile.DirectiveNames.allCases.map { $0.rawValue } + [Redirect.directiveName]).analyze(directive, children: directive.children, source: source, for: bundle, in: context, problems: &problems)
        
        let redirects: [Redirect]
        (redirects, remainder) = remainder.categorize { child -> Redirect? in
            guard let childDirective = child as? BlockDirective, childDirective.name == Redirect.directiveName else {
                return nil
            }
            return Redirect(from: childDirective, source: source, for: bundle, in: context, problems: &problems)
        }
        
        let tiles: [Tile]
        (tiles, remainder) = remainder.categorize { child -> Tile? in
            guard let childDirective = child as? BlockDirective, Tile.DirectiveNames(rawValue: childDirective.name) != nil else {
                return nil
            }
            return Tile(from: childDirective, source: source, for: bundle, in: context, problems: &problems)
        }
        
        var seenTileDirectiveNames = Set<String>()
        let tilesWithoutDuplicates = tiles.filter { tile in
            let tileName = tile.originalMarkup.name
            guard !seenTileDirectiveNames.contains(tile.title) else {
                if !tileName.isEmpty,
                    let range = tile.originalMarkup.range {
                    let diagnostic = Diagnostic(source: source, severity: .warning, range: tile.originalMarkup.range, identifier: "org.swift.docc.Resources.DuplicateTile", summary: "Duplicate child directive \(tileName.singleQuoted) in \(Resources.directiveName.singleQuoted)")
                    let solution = Solution.init(summary: "Remove extraneous \(tileName.singleQuoted) directive", replacements: [Replacement(range: range, replacement: "")])
                    problems.append(Problem(diagnostic: diagnostic, possibleSolutions: [solution]))
                }
                return false
            }
            
            seenTileDirectiveNames.insert(tileName)
            return true
        }
        
        for extraneousElement in remainder {
            let diagnostic = Diagnostic(source: source, severity: .warning, range: extraneousElement.range, identifier: "org.swift.docc.Resources.ExtraneousContent", summary: "Extraneous child element of \(Resources.directiveName.singleQuoted) directive")
            if let range = extraneousElement.range {
                let solution = Solution(summary: "Remove extraneous element", replacements: [Replacement(range: range, replacement: "")])
                problems.append(Problem(diagnostic: diagnostic, possibleSolutions: [solution]))
            } else {
                problems.append(Problem(diagnostic: diagnostic, possibleSolutions: []))
            }
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

