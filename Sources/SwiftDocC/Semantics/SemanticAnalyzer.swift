/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown

struct SemanticAnalyzer: MarkupVisitor {
    var problems = [Problem]()
    let source: URL?
    let context: DocumentationContext
    let bundle: DocumentationBundle
    
    init(source: URL?, context: DocumentationContext, bundle: DocumentationBundle) {
        self.source = source
        self.context = context
        self.bundle = bundle
    }

    private mutating func analyzeChildren(of markup: Markup) -> [Semantic] {
        var semanticChildren = [Semantic]()
        for child in markup.children {
            guard let semantic = visit(child) else {
                continue
            }
            semanticChildren.append(semantic)
        }
        return semanticChildren
    }
    
    /// Analyses the given document and returns the semantic object that the analyzer parsed from the document's content.
    /// - Returns: The parsed semantic object or `nil` if the analyzer couldn't parse a semantic object from the document.
    mutating func visitDocument(_ document: Document) -> Semantic? {
        if let range = document.range, range.isEmpty {
            return nil
        }
        
        let semanticChildren = analyzeChildren(of: document)
        let topLevelChildren = semanticChildren.filter {
            return $0 is Technology ||
            $0 is Tutorial ||
            $0 is TutorialArticle
        }

        let topLevelDirectives = BlockDirective.topLevelDirectiveNames
            .map { $0.singleQuoted }
            .list(finalConjunction: .or)
        
        if let source = source {
            if !topLevelChildren.isEmpty, !DocumentationBundleFileTypes.isTutorialFile(source) {
                // Only tutorials support top level directives. This document has top level directives but is not a tutorial file.
                let directiveName = type(of: topLevelChildren.first! as! DirectiveConvertible).directiveName
                let diagnostic = Diagnostic(source: source, severity: .warning, range: document.range, identifier: "org.swift.docc.unsupportedTopLevelChild", summary: "Found unsupported \(directiveName.singleQuoted) directive in '.\(source.pathExtension)' file", explanation: "Only '.tutorial' files support top-level directives")
                problems.append(Problem(diagnostic: diagnostic, possibleSolutions: []))
                return nil
            } else if topLevelChildren.isEmpty, !DocumentationBundleFileTypes.isReferenceDocumentationFile(source) {
                // Only reference documentation support all markdown content. This document has no top level directives but is not a reference documentation file.
                let diagnostic = Diagnostic(
                    source: source,
                    severity: .warning,
                    range: document.range,
                    identifier: "org.swift.docc.missingTopLevelChild",
                    summary: "No valid content was found in this file",
                    explanation: """
                    A '.\(source.pathExtension)' file should contain a top-level directive \
                    (\(topLevelDirectives)) and valid child content. \
                    Only '.md' files support content without a top-level directive
                    """
                )
                problems.append(Problem(diagnostic: diagnostic, possibleSolutions: []))
                return nil
            }
        }
        
        if topLevelChildren.isEmpty {
            guard let article = Article(from: document, source: source, for: bundle, in: context, problems: &problems) else {
                // We've already diagnosed the invalid article.
                return nil
            }
            
            return article
        }
        
        // Diagnose more than one top-level directive
        for extraneousTopLevelChild in topLevelChildren.suffix(from: 1) {
            if let directiveConvertible = extraneousTopLevelChild as? DirectiveConvertible,
                let range = directiveConvertible.originalMarkup.range {
                let diagnostic = Diagnostic(source: source, severity: .warning, range: range, identifier: "org.swift.docc.extraneousTopLevelChild", summary: "Only one top-level directive from \(topLevelDirectives) may exist in a document; this directive will be ignored")
                let solution = Solution(summary: "Remove this extraneous directive", replacements: [Replacement(range: range, replacement: "")])
                problems.append(Problem(diagnostic: diagnostic, possibleSolutions: [solution]))
            }
        }
        return topLevelChildren.first
    }

    mutating func visitBlockDirective(_ blockDirective: BlockDirective) -> Semantic? {
        switch blockDirective.name {
        case Technology.directiveName:
            return Technology(from: blockDirective, source: source, for: bundle, in: context, problems: &problems)
        case Volume.directiveName:
            return Volume(from: blockDirective, source: source, for: bundle, in: context, problems: &problems)
        case Chapter.directiveName:
            return Chapter(from: blockDirective, source: source, for: bundle, in: context, problems: &problems)
        case TutorialReference.directiveName:
            return TutorialReference(from: blockDirective, source: source, for: bundle, in: context, problems: &problems)
        case ContentAndMedia.directiveName:
            return ContentAndMedia(from: blockDirective, source: source, for: bundle, in: context, problems: &problems)
        case Intro.directiveName:
            return Intro(from: blockDirective, source: source, for: bundle, in: context, problems: &problems)
        case ImageMedia.directiveName:
            return ImageMedia(from: blockDirective, source: source, for: bundle, in: context, problems: &problems)
        case VideoMedia.directiveName:
            return VideoMedia(from: blockDirective, source: source, for: bundle, in: context, problems: &problems)
        case Tutorial.directiveName:
            return Tutorial(from: blockDirective, source: source, for: bundle, in: context, problems: &problems)
        case TutorialArticle.directiveName:
            return TutorialArticle(from: blockDirective, source: source, for: bundle, in: context, problems: &problems)
        case XcodeRequirement.directiveName:
            return XcodeRequirement(from: blockDirective, source: source, for: bundle, in: context, problems: &problems)
        case Assessments.directiveName:
            return Assessments(from: blockDirective, source: source, for: bundle, in: context, problems: &problems)
        case MultipleChoice.directiveName:
            return MultipleChoice(from: blockDirective, source: source, for: bundle, in: context, problems: &problems)
        case Choice.directiveName:
            return Choice(from: blockDirective, source: source, for: bundle, in: context, problems: &problems)
        case Justification.directiveName:
            return Justification(from: blockDirective, source: source, for: bundle, in: context, problems: &problems)
        case TutorialSection.directiveName:
            return TutorialSection(from: blockDirective, source: source, for: bundle, in: context, problems: &problems)
        case Step.directiveName:
            return Step(from: blockDirective, source: source, for: bundle, in: context, problems: &problems)
        case Resources.directiveName:
            return Resources(from: blockDirective, source: source, for: bundle, in: context, problems: &problems)
        case Comment.directiveName:
            return Comment(from: blockDirective, source: source, for: bundle, in: context, problems: &problems)
        case DeprecationSummary.directiveName:
            return DeprecationSummary(from: blockDirective, source: source, for: bundle, in: context, problems: &problems)
        case Metadata.directiveName:
            return Metadata(from: blockDirective, source: source, for: bundle, in: context, problems: &problems)
        case Redirect.directiveName:
            return Redirect(from: blockDirective, source: source, for: bundle, in: context, problems: &problems)
        case DocumentationExtension.directiveName:
            return DocumentationExtension(from: blockDirective, source: source, for: bundle, in: context, problems: &problems)
        case Snippet.directiveName:
            // A snippet directive does not need to stay around as a Semantic object.
            // we only need to check the path argument and that it doesn't
            // have any inner content as a convenience to the author.
            // The path will resolve as a symbol link later in the
            // MarkupReferenceResolver.
            _ = Snippet(from: blockDirective, source: source, for: bundle, in: context, problems: &problems)
            return nil
        case Options.directiveName:
            return nil
        default:
            guard let directiveType = DirectiveIndex.shared.indexedDirectives[blockDirective.name]?.type else {
                let diagnostic = Diagnostic(source: source, severity: .warning, range: blockDirective.range, identifier: "org.swift.docc.unknownDirective", summary: "Unknown directive \(blockDirective.name.singleQuoted); this element will be ignored")
                problems.append(Problem(diagnostic: diagnostic, possibleSolutions: []))
                
                return nil
            }
            
            guard let directive = directiveType.init(
                from: blockDirective,
                source: source,
                for: bundle,
                in: context,
                problems: &problems
            ) else {
                return nil
            }
            
            // Analyze any structured markup directives (like @Row or @Column)
            // that are contained in the child markup of this directive.
            if let markupContainingDirective = directive as? MarkupContaining {
                for markupElement in markupContainingDirective.childMarkup {
                    _ = visit(markupElement)
                }
            }
            
            return directive as? Semantic
        }
    }

    func defaultVisit(_ markup: Markup) -> Semantic? {
        return MarkupContainer(markup)
    }
    
    typealias Result = Semantic?
    
}
