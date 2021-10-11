/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown

/// A semantic model for a view that links to a content type that you specify.
///
/// A tile is a kind of thematic content block that contains links to resources
/// such as sample code, videos, or forum topics.
public final class Tile: Semantic, DirectiveConvertible {
    /// A tile type to identify the tile during building page layout.
    public enum Identifier: String, Codable {
        /// Identifies a tile that links to documentation.
        case documentation = "documentation"
        
        /// Identifies a tile that links to sample code.
        case sampleCode = "sampleCode"
        
        /// Identifies a tile that links to downloads.
        case downloads = "downloads"
        
        /// Identifies a tile that links to videos.
        case videos = "videos"
        
        /// Identifies a tile that links to forum topics.
        case forums = "forums"
    }
    
    /// The possible directive names for a tile, corresponding to different expanded content.
    public enum DirectiveNames: String, CaseIterable {
        case documentation = "Documentation"
        case sampleCode = "SampleCode"
        case downloads = "Downloads"
        case videos = "Videos"
        case forums = "Forums"
        
        var tileIdentifier: Identifier {
            switch self {
                case .documentation: return .documentation
                case .sampleCode: return .sampleCode
                case .downloads: return .downloads
                case .videos: return .videos
                case .forums: return .forums
            }
        }
        
        var title: Semantics.Title {
            switch self {
                case .documentation: return .documentation
                case .sampleCode: return .sampleCode
                case .downloads: return .downloads
                case .videos: return .videos
                case .forums: return .forums                
            }
        }
    }
    
    /// A fake directive name, the actual tile directives are in ``DirectiveNames``.
    public static let directiveName = "Tile"
    
    public let originalMarkup: BlockDirective
    
    /// An identifier for the tile.
    public let identifier: Tile.Identifier
    
    /// The title of the tile.
    public let title: String
    
    /// The destination of the tile's primary link.
    public let destination: URL?
    
    /// The contents of the tile.
    public let content: MarkupContainer
    
    override var children: [Semantic] {
        return [content]
    }
    
    enum Semantics {        
        enum Destination: DirectiveArgument {
            typealias ArgumentValue = URL
            static let argumentName = "destination"
        }
        
        enum Title: String, DirectiveArgument {
            static let argumentName = "title"
            case documentation = "Documentation"
            case sampleCode = "Sample Code"
            case downloads = "Xcode and SDKs"
            case videos = "Videos"
            case forums = "Forums"
        }
    }
    
    init(originalMarkup: BlockDirective, identifier: Tile.Identifier, title: String, destination: URL?, content: MarkupContainer) {
        self.originalMarkup = originalMarkup
        self.identifier = identifier
        self.title = title
        self.destination = destination
        self.content = content
    }
    
    fileprivate static func firstParagraph(of directive: BlockDirective, source: URL?, for bundle: DocumentationBundle, in context: DocumentationContext, problems: inout [Problem]) -> (Paragraph?, remainder: MarkupContainer) {
        var remainder: MarkupContainer
        let paragraph: Paragraph?
        if let firstChild = directive.child(at: 0) {
            if let firstParagraph = firstChild as? Paragraph {
                paragraph = firstParagraph
                remainder = MarkupContainer(directive.children.dropFirst(1))
            } else {
                paragraph = nil
                remainder = MarkupContainer(directive.children)
            }
        } else {
            let diagnostic = Diagnostic(source: source, severity: .warning, range: directive.range, identifier: "org.swift.docc.Resources.\(directive.name).HasContent", summary: "\(directive.name.singleQuoted) directive requires an initial paragraph summarizing the contents of the tile's destination")
            problems.append(Problem(diagnostic: diagnostic, possibleSolutions: []))
            paragraph = nil
            remainder = MarkupContainer(directive.children)
        }
        return (paragraph, remainder: remainder)
    }
    
    /// Checks if the provided directive contains a list and if so returns the list and the remainder of the markup.
    /// This helper function abstracts checking for an optional list inside a "tile" directive.
    fileprivate static func list(in directive: BlockDirective, source: URL?, problems: inout [Problem]) -> (list: UnorderedList?, remainder: MarkupContainer) {
        var remainder: MarkupContainer
        let list: UnorderedList?
        
        if let element = directive.child(at: 1) as? UnorderedList {
            list = element
            remainder = MarkupContainer(directive.children.dropFirst(1))
        } else {
            list = nil
            remainder = MarkupContainer(directive.children)
        }
        
        return (list, remainder: remainder)
    }
    
    convenience init?(genericTile directive: BlockDirective, title: String, source: URL?, for bundle: DocumentationBundle, in context: DocumentationContext, problems: inout [Problem], shouldContainLinks: Bool = false) {
        let arguments = directive.arguments(problems: &problems)
        let destination = Semantic.Analyses.HasArgument<Tile, Semantics.Destination>(severityIfNotFound: nil).analyze(directive, arguments: arguments, problems: &problems)

        let _ = Tile.firstParagraph(of: directive, source: source, for: bundle, in: context, problems: &problems)
        let (list, remainder: _) = Tile.list(in: directive, source: source, problems: &problems)

        if shouldContainLinks, list == nil {
            let diagnostic = Diagnostic(source: source, severity: .warning, range: directive.range, identifier: "org.swift.docc.Resources.\(directive.name).HasLinks", summary: "\(directive.name.singleQuoted) directive should contain at least one list item")
            problems.append(Problem(diagnostic: diagnostic, possibleSolutions: []))
        }

        guard let tileIdentifier = DirectiveNames(rawValue: directive.name)?.tileIdentifier else {
            return nil
        }

        self.init(originalMarkup: directive, identifier: tileIdentifier, title: title, destination: destination, content: MarkupContainer(directive.children))
    }
    
    public convenience init?(from directive: BlockDirective, source: URL?, for bundle: DocumentationBundle, in context: DocumentationContext, problems: inout [Problem]) {
        switch directive.name {
        case Tile.DirectiveNames.documentation.rawValue:
            self.init(genericTile: directive,
                      title: Tile.Semantics.Title.documentation.rawValue,
                      source: source,
                      for: bundle,
                      in: context,
                      problems: &problems,
                      shouldContainLinks: true)
        case Tile.DirectiveNames.sampleCode.rawValue:
            self.init(genericTile: directive,
                      title: Tile.Semantics.Title.sampleCode.rawValue,
                      source: source,
                      for: bundle,
                      in: context,
                      problems: &problems,
                      shouldContainLinks: true)
        case Tile.DirectiveNames.downloads.rawValue:
            self.init(genericTile: directive,
                      title: Tile.Semantics.Title.downloads.rawValue,
                      source: source,
                      for: bundle,
                      in: context,
                      problems: &problems)
        case Tile.DirectiveNames.videos.rawValue:
            self.init(genericTile: directive,
                      title: Tile.Semantics.Title.videos.rawValue,
                      source: source,
                      for: bundle,
                      in: context,
                      problems: &problems)
        case Tile.DirectiveNames.forums.rawValue:
            self.init(genericTile: directive,
                      title: Tile.Semantics.Title.forums.rawValue,
                      source: source,
                      for: bundle,
                      in: context,
                      problems: &problems)
        default:
            let possibleTileDirectiveNames = Tile.DirectiveNames.allCases
                .map { $0.rawValue.singleQuoted }
                .list(finalConjunction: .or)
            let directiveReference = directive.name.isEmpty
                ? "anonymous child directive"
                : "child directive \(directive.name.singleQuoted)"
            let diagnostic = Diagnostic(source: source, severity: .warning, range: directive.range, identifier: "org.swift.docc.Resources.UnknownTile", summary: "Unknown \(directiveReference) of \(Resources.directiveName.singleQuoted); must be one of \(possibleTileDirectiveNames)")
            problems.append(Problem(diagnostic: diagnostic, possibleSolutions: []))
            return nil
        }
    }
    
    public override func accept<V>(_ visitor: inout V) -> V.Result where V : SemanticVisitor {
        return visitor.visitTile(self)
    }
}
