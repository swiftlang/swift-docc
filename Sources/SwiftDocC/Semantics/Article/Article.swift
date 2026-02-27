/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

public import Foundation
public import Markdown

/// The in-memory representation of an article.
///
/// An article is written using markdown headers and paragraphs. There is an implicit meaning to the structure of an article that's parsed from its markup
/// when the article is instantiated. For example, the leading level 1 heading is considered the article's title, the first paragraph of text is considered the
/// article's abstract, and following paragraphs up to the next heading is considered the article's discussion.
public final class Article: Semantic, MarkupConvertible, Abstracted, Redirected, AutomaticTaskGroupsProviding {
    /// The markup that makes up this article's content.
    let markup: (any Markup)?
    /// An optional container for metadata that's unrelated to the article's content.
    private(set) var metadata: Metadata?
    /// An optional container for options that are unrelated to the article's content.
    private(set) var options: [Options.Scope : Options]
    /// An optional list of previously known locations for this article.
    private(set) public var redirects: [Redirect]?
    
    /// Initializes a new article from a given markup, metadata, and list of redirects.
    ///
    /// - Parameters:
    ///   - markup: The markup that makes up this article's content.
    ///   - metadata: An optional container for metadata that's unrelated to the article's content.
    ///   - redirects: An optional list of previously known locations for this article.
    init(markup: (any Markup)?, metadata: Metadata?, redirects: [Redirect]?, options: [Options.Scope : Options]) {
        let markupModel = markup.map { DocumentationMarkup(markup: $0) }

        self.markup = markup
        self.options = options
        self.metadata = metadata
        self.redirects = redirects
        self.discussion = markupModel?.discussionSection
        self.abstractSection = markupModel?.abstractSection
        self.topics = markupModel?.topicsSection
        self.seeAlso = markupModel?.seeAlsoSection
        self.title = markupModel?.titleHeading
        self.deprecationSummary = markupModel?.deprecation
        self.automaticTaskGroups = []
    }

    convenience init(title: Heading?, abstractSection: AbstractSection?, discussion: DiscussionSection?, topics: TopicsSection?, seeAlso: SeeAlsoSection?, deprecationSummary: MarkupContainer?, metadata: Metadata?, redirects: [Redirect]?, automaticTaskGroups: [AutomaticTaskGroupSection]? = nil) {
        self.init(markup: nil, metadata: metadata, redirects: redirects, options: [:])
        self.title = title
        self.abstractSection = abstractSection
        self.discussion = discussion
        self.topics = topics
        self.seeAlso = seeAlso
        self.deprecationSummary = deprecationSummary
        self.automaticTaskGroups = automaticTaskGroups ?? []
    }

    /// The conceptual abstract for this article.
    ///
    /// This content is parsed from the markup that the article was initialized with.
    public var abstract: Paragraph? {
        return abstractSection?.paragraph
    }

    /// The list of supported languages for the article, if present.
    ///
    /// This information is available via `@SupportedLanguage` in the `@Metadata` directive.
    public var supportedLanguages: Set<SourceLanguage>? {
        guard let metadata = self.metadata else {
            return nil
        }

        let langs = metadata.supportedLanguages.map(\.language)
        return langs.isEmpty ? nil : Set(langs)
    }

    /// An optional custom deprecation summary for a deprecated symbol.
    private(set) public var deprecationSummary: MarkupContainer?
    
    /// The conceptual discussion section for this article.
    ///
    /// The discussion section is parsed from the markup content between the ``abstract``  and the "Topics" section.
    private(set) public var discussion: DiscussionSection?
    
    /// The abstract section of the article.
    private(set) public var abstractSection: AbstractSection?
    
    /// The Topic curation section of the article.
    internal(set) public var topics: TopicsSection?
    
    /// The See Also section of the article.
    private(set) public var seeAlso: SeeAlsoSection?
    
    /// The title of the article.
    internal(set) public var title: Heading?
    
    /// Any automatically created task groups.
    var automaticTaskGroups: [AutomaticTaskGroupSection]

    /// Initializes a new article with a given markup and source for a given documentation bundle and documentation context.
    ///
    /// - Parameters:
    ///   - markup: The markup that makes up this article's content.
    ///   - source: The location of the file that this article's content comes from.
    ///   - bundle: The documentation bundle that the source file belongs to.
    ///   - problems: A mutable collection of problems to update with any problem encountered while initializing the article.
    public convenience init?(from markup: any Markup, source: URL?, for bundle: DocumentationBundle, problems: inout [Problem]) {
        guard let title = markup.child(at: 0) as? Heading, title.level == 1 else {
            let range = markup.child(at: 0)?.range ?? SourceLocation(line: 1, column: 1, source: nil)..<SourceLocation(line: 1, column: 1, source: nil)
            let diagnostic = Diagnostic(source: source, severity: .warning, range: range, identifier: "org.swift.docc.Article.Title.NotFound", summary: "An article is expected to start with a top-level heading title")

            let replacementText: String
            if let firstChild = markup.child(at: 0) as? Paragraph {
                replacementText = """
                     # \(firstChild.plainText)
                     """
            } else {
                replacementText = """
                     # <#Title#>
                     """
            }

            let replacement = Replacement(range: range, replacement: replacementText)
            let solution = Solution(summary: "Add a title", replacements: [replacement])
            problems.append(Problem(diagnostic: diagnostic, possibleSolutions: [solution]))

            return nil
        }
        
        var remainder: [any Markup]
        var redirects: [Redirect]
        (redirects, remainder) = markup.children.categorize { child -> Redirect? in
            guard let childDirective = child as? BlockDirective, childDirective.name == Redirect.directiveName else {
                return nil
            }
            return Redirect(from: childDirective, source: source, for: bundle, problems: &problems)
        }
        
        var optionalMetadata = DirectiveParser()
            .parseSingleDirective(
                Metadata.self,
                from: &remainder,
                parentType: Article.self,
                source: source,
                bundle: bundle,
                problems: &problems
            )

        // Append any redirects found in the metadata to the redirects
        // found in the main content.
        if let redirectsFromMetadata = optionalMetadata?.redirects {
            redirects.append(contentsOf: redirectsFromMetadata)
        }

        let options: [Options]
        (options, remainder) = remainder.categorize { child -> Options? in
            guard let childDirective = child as? BlockDirective, childDirective.name == Options.directiveName else {
                return nil
            }
            return Options(
                from: childDirective,
                source: source,
                for: bundle,
                problems: &problems
            )
        }
        
        let allCategorizedOptions = Dictionary(grouping: options, by: \.scope)
        
        for (scope, options) in allCategorizedOptions {
            let extraOptions = options.dropFirst()
            guard !extraOptions.isEmpty else {
                continue
            }
            
            let extraOptionsProblems = extraOptions.map { extraOptionsDirective -> Problem in
                let diagnostic = Diagnostic(
                    source: source,
                    severity: .warning,
                    range: extraOptionsDirective.originalMarkup.range,
                    identifier: "org.swift.docc.HasAtMostOne<\(Article.self), \(Options.self), \(scope)>.DuplicateChildren",
                    summary: "Duplicate \(scope) \(Options.directiveName.singleQuoted) directive",
                    explanation: """
                    An article can only contain a single \(Options.directiveName.singleQuoted) \
                    directive with the \(scope.rawValue.singleQuoted) scope.
                    """
                )
                
                guard let range = extraOptionsDirective.originalMarkup.range else {
                    return Problem(diagnostic: diagnostic)
                }
                
                let solution = Solution(
                    summary: "Remove extraneous \(scope) \(Options.directiveName.singleQuoted) directive",
                    replacements: [
                        Replacement(range: range, replacement: "")
                    ]
                )
                
                return Problem(diagnostic: diagnostic, possibleSolutions: [solution])
            }
            
            problems.append(contentsOf: extraOptionsProblems)
        }
        
        let relevantCategorizedOptions = allCategorizedOptions.compactMapValues(\.first)
        
        let isDocumentationExtension = title.startsWithAnyLink
        if !isDocumentationExtension, let metadata = optionalMetadata, let displayName = metadata.displayName {
            let diagnosticSummary = """
            A \(DisplayName.directiveName.singleQuoted) directive is only supported in documentation extension files. To customize the display name of an article, change the content of the level-1 heading.
            """

            let diagnostic = Diagnostic(source: source, severity: .warning, range: metadata.originalMarkup.range, identifier: "org.swift.docc.Article.DisplayName.NotSupported", summary: diagnosticSummary, explanation: nil, notes: [])
            
            let solutions: [Solution]
            if let displayNameRange = displayName.originalMarkup.range, let titleRange = title.range {
                let removeDisplayNameReplacement = Replacement(range: displayNameRange, replacement: "")
                let changeTitleReplacement = Replacement(range: titleRange, replacement: "# \(displayName.name)")
                
                solutions = [Solution(summary: "Change the title", replacements: [removeDisplayNameReplacement, changeTitleReplacement])]
            } else {
                solutions = []
            }
            
            problems.append(Problem(diagnostic: diagnostic, possibleSolutions: solutions))
            
            metadata.displayName = nil
            optionalMetadata = metadata
        }
        
        self.init(
            markup: markup,
            metadata: optionalMetadata,
            redirects: redirects.isEmpty ? nil : redirects,
            options: relevantCategorizedOptions
        )
    }
    
    /// Visit the article using a semantic visitor and return the result of visiting the article.
    ///
    /// - Parameter visitor: The semantic visitor to visit this article.
    /// - Returns: The result of visiting the article.
    public override func accept<V: SemanticVisitor>(_ visitor: inout V) -> V.Result {
        return visitor.visitArticle(self)
    }
}

