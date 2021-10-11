/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown

/// An overview of the educational materials under a specific technology or technology area.
public final class Technology: Semantic, DirectiveConvertible, Abstracted, Redirected {
    public static let directiveName = "Tutorials"
    public let originalMarkup: BlockDirective
    
    /// The name of the technology.
    public let name: String
    
    /// The ``Intro`` section for this technology.
    public let intro: Intro
    
    /// The sections that outline the technology.
    public let volumes: [Volume]
    
    /// Additional resources to aid in learning the technology.
    public let resources: Resources?
    
    override var children: [Semantic] {
        return [intro] + volumes as [Semantic] + (resources.map { [$0] } ?? [])
    }
    
    public var abstract: Paragraph? {
        return intro.content.first as? Paragraph
    }
    
    public let redirects: [Redirect]?
    
    init(originalMarkup: BlockDirective, name: String, intro: Intro, volumes: [Volume], resources: Resources?, redirects: [Redirect]?) {
        self.originalMarkup = originalMarkup
        self.name = name
        self.intro = intro
        self.volumes = volumes
        self.resources = resources
        self.redirects = redirects
    }
    
    enum Semantics {
        enum Name: DirectiveArgument {
            static let argumentName = "name"
        }
    }
    
    public convenience init?(from directive: BlockDirective, source: URL?, for bundle: DocumentationBundle, in context: DocumentationContext, problems: inout [Problem]) {
        precondition(directive.name == Technology.directiveName)
        
        let arguments = Semantic.Analyses.HasOnlyKnownArguments<Technology>(severityIfFound: .warning, allowedArguments: [Semantics.Name.argumentName]).analyze(directive, children: directive.children, source: source, for: bundle, in: context, problems: &problems)
        
        Semantic.Analyses.HasOnlyKnownDirectives<Technology>(severityIfFound: .warning, allowedDirectives: [Intro.directiveName, Volume.directiveName, Chapter.directiveName, Resources.directiveName, Redirect.directiveName]).analyze(directive, children: directive.children, source: source, for: bundle, in: context, problems: &problems)
    
        let requiredName = Semantic.Analyses.HasArgument<Technology, Semantics.Name>(severityIfNotFound: .warning).analyze(directive, arguments: arguments, problems: &problems)
        let requiredIntro = Semantic.Analyses.HasExactlyOne<Technology, Intro>(severityIfNotFound: .warning).analyze(directive, children: directive.children, source: source, for: bundle, in: context, problems: &problems).0
        
        var volumes: [Volume]
        var remainder: MarkupContainer
        (volumes, remainder) = Semantic.Analyses.HasAtLeastOne<Technology, Volume>(severityIfNotFound: nil).analyze(directive, children: directive.children, source: source, for: bundle, in: context, problems: &problems)

        // Retrieve chapters outside volumes.
        let chapters: [Chapter]
        (chapters, remainder) = Semantic.Analyses.HasAtLeastOne<Technology, Chapter>(severityIfNotFound: nil).analyze(directive, children: directive.children, source: source, for: bundle, in: context, problems: &problems)

        if !chapters.isEmpty {
            if !volumes.isEmpty {
                // If there are Volumes, diagnose isolated chapters.
                problems.append(contentsOf:
                    chapters.map { chapter in
                        Problem(diagnostic: Technology.isolatedChapterDiagnostic(isolatedChapter: chapter, source: source, range: chapter.originalMarkup.range), possibleSolutions: [])
                    }
                )
            } else {
                volumes.append(
                    // Create an anonymous volume.
                    Volume(originalMarkup: directive, name: nil, image: nil, content: MarkupContainer(), chapters: chapters, redirects: [])
                )
            }
        }
        
        let resources: Resources?
        (resources, remainder) = Semantic.Analyses.HasExactlyOne<Technology, Resources>(severityIfNotFound: nil).analyze(directive, children: remainder, source: source, for: bundle, in: context, problems: &problems)

        let redirects: [Redirect]
            (redirects, remainder) = Semantic.Analyses.HasAtLeastOne<Chapter, Redirect>(severityIfNotFound: nil).analyze(directive, children: remainder, source: source, for: bundle, in: context, problems: &problems)
        
        guard let name = requiredName,
            let intro = requiredIntro else {
                return nil
        }
        self.init(originalMarkup: directive, name: name, intro: intro, volumes: volumes, resources: resources, redirects: redirects.isEmpty ? nil : redirects)
    }

    static func isolatedChapterDiagnostic(isolatedChapter: Chapter, source: URL?, range: SourceRange?) -> Diagnostic {
        return Diagnostic(
            source: source,
            severity: .warning,
            range: range,
            identifier: "org.swift.docc.Technology.IsolatedChapter",
            summary: "Chapter should be in a \(Volume.directiveName.singleQuoted); either organize all Chapters in Volumes, or place them directly under your \(Technology.directiveName.singleQuoted)"
        )
    }
    
    public override func accept<V: SemanticVisitor>(_ visitor: inout V) -> V.Result {
        return visitor.visitTechnology(self)
    }
}
