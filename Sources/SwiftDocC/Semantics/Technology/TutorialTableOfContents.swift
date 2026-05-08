/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

public import Foundation
public import Markdown

/// A top-level page that organizes a collection of tutorials into a hierarchy of volumes and chapters.
///
/// ## See Also
///
/// - ``Volume``
/// - ``Chapter``
public final class TutorialTableOfContents: Semantic, DirectiveConvertible, Abstracted, Redirected {
    public static let directiveName = "Tutorials"
    public static let introducedVersion = "5.5"
    public let originalMarkup: BlockDirective
    
    /// The name of the technology that this collection of tutorials is about
    public let name: String
    
    /// The ``Intro`` section for this table of contents page.
    public let intro: Intro
    
    /// The sections that organize the tutorials into a recommend reading order.
    public let volumes: [Volume]
    
    /// Additional resources to aid in learning the technology that this collection of tutorials is about.
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
    
    @available(*, deprecated, renamed: "init(from:source:for:featureFlags:diagnostics:)", message: "Use 'init(from:source:for:featureFlags:diagnostics:)' instead. This deprecated API will be removed after 6.5 is released.")
    public convenience init?(from directive: BlockDirective, source: URL?, for bundle: DocumentationBundle, featureFlags: FeatureFlags, problems: inout [Problem]) {
        var diagnostics = [Diagnostic]()
        defer {
            problems.append(contentsOf: diagnostics.map { .init(diagnostic: $0) })
        }
        self.init(from: directive, source: source, for: bundle, featureFlags: featureFlags, diagnostics: &diagnostics)
    }
    
    public convenience init?(from directive: BlockDirective, source: URL?, for bundle: DocumentationBundle, featureFlags: FeatureFlags, diagnostics: inout [Diagnostic]) {
        precondition(directive.name == TutorialTableOfContents.directiveName)
        
        let arguments = Semantic.Analyses.HasOnlyKnownArguments<TutorialTableOfContents>(severityIfFound: .warning, allowedArguments: [Semantics.Name.argumentName]).analyze(directive, children: directive.children, source: source, diagnostics: &diagnostics)
        
        Semantic.Analyses.HasOnlyKnownDirectives<TutorialTableOfContents>(severityIfFound: .warning, allowedDirectives: [Intro.directiveName, Volume.directiveName, Chapter.directiveName, Resources.directiveName, Redirect.directiveName]).analyze(directive, children: directive.children, source: source, diagnostics: &diagnostics)
    
        let requiredName = Semantic.Analyses.HasArgument<TutorialTableOfContents, Semantics.Name>(severityIfNotFound: .warning).analyze(directive, arguments: arguments, diagnostics: &diagnostics)
        let requiredIntro = Semantic.Analyses.HasExactlyOne<TutorialTableOfContents, Intro>(severityIfNotFound: .warning, featureFlags: featureFlags).analyze(directive, children: directive.children, source: source, for: bundle, diagnostics: &diagnostics).0
        
        var volumes: [Volume]
        var remainder: MarkupContainer
        (volumes, remainder) = Semantic.Analyses.HasAtLeastOne<TutorialTableOfContents, Volume>(severityIfNotFound: nil, featureFlags: featureFlags).analyze(directive, children: directive.children, source: source, for: bundle, diagnostics: &diagnostics)

        // Retrieve chapters outside volumes.
        let chapters: [Chapter]
        (chapters, remainder) = Semantic.Analyses.HasAtLeastOne<TutorialTableOfContents, Chapter>(severityIfNotFound: nil, featureFlags: featureFlags).analyze(directive, children: directive.children, source: source, for: bundle, diagnostics: &diagnostics)

        if !chapters.isEmpty {
            if !volumes.isEmpty {
                // If there are Volumes, diagnose isolated chapters.
                diagnostics.append(contentsOf:
                    chapters.map { chapter in
                        TutorialTableOfContents.isolatedChapterDiagnostic(isolatedChapter: chapter, source: source, range: chapter.originalMarkup.range)
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
        (resources, remainder) = Semantic.Analyses.HasExactlyOne<TutorialTableOfContents, Resources>(severityIfNotFound: nil, featureFlags: featureFlags).analyze(directive, children: remainder, source: source, for: bundle, diagnostics: &diagnostics)

        let redirects: [Redirect]
        (redirects, remainder) = Semantic.Analyses.HasAtLeastOne<Chapter, Redirect>(severityIfNotFound: nil, featureFlags: featureFlags).analyze(directive, children: remainder, source: source, for: bundle, diagnostics: &diagnostics)
        
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
            identifier: "org.swift.docc.TutorialTableOfContents.IsolatedChapter",
            summary: "Chapter should be in a \(Volume.directiveName.singleQuoted); either organize all Chapters in Volumes, or place them directly under your \(TutorialTableOfContents.directiveName.singleQuoted)"
        )
    }
    
    public override func accept<V: SemanticVisitor>(_ visitor: inout V) -> V.Result {
        return visitor.visitTutorialTableOfContents(self)
    }
}
