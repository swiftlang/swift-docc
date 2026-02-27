/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown
private import SymbolKit

private func invalidLinkDestinationProblem(destination: String, range: SourceRange?, severity: DiagnosticSeverity) -> Problem {
    let diagnostic = Diagnostic(source: range?.source, severity: severity, range: range, identifier: "org.swift.docc.invalidLinkDestination", summary: "Link destination \(destination.singleQuoted) is not a valid URL")
    return Problem(diagnostic: diagnostic, possibleSolutions: [])
}

private func disabledLinkDestinationProblem(reference: ResolvedTopicReference, range: SourceRange?, severity: DiagnosticSeverity) -> Problem {
    return Problem(diagnostic: Diagnostic(source: range?.source, severity: severity, range: range, identifier: "org.swift.docc.disabledLinkDestination", summary: "The topic \(reference.path.singleQuoted) cannot be linked to."), possibleSolutions: [])
}

private func removedLinkDestinationProblem(reference: ResolvedTopicReference, range: SourceRange?, severity: DiagnosticSeverity) -> Problem {
    var solutions = [Solution]()
    if let range, reference.pathComponents.count > 3 {
        // The first three path components are "/", "documentation", and the module name, so drop those
        let pathRemainder = reference.pathComponents[3...]
        solutions.append(.init(summary: "Use a plain code span instead of a symbol link", replacements: [
            .init(range: range, replacement: "`\(pathRemainder.joined(separator: "/"))`")
        ]))
    }
    let diagnostic = Diagnostic(source: range?.source, severity: severity, range: range, identifier: "org.swift.docc.removedExtensionLinkDestination", summary: "The topic \(reference.path.singleQuoted) is an empty extension page and cannot be linked to.", explanation: "This extension symbol has had all its children curated and has been removed.")
    return Problem(diagnostic: diagnostic, possibleSolutions: solutions)
}

/**
 Rewrites a ``Markup`` tree to resolve ``UnresolvedTopicReference``s using a ``DocumentationContext``.
 */
struct MarkupReferenceResolver: MarkupRewriter {
    var context: DocumentationContext
    var problems = [Problem]()
    var rootReference: ResolvedTopicReference
    
    init(context: DocumentationContext, rootReference: ResolvedTopicReference) {
        self.context = context
        self.rootReference = rootReference
    }

    // If the property is set and returns a problem, that problem will be
    // emitted instead of the default "unresolved topic" problem.
    // This property offers a customization point for when we need to try
    // resolving links in other contexts than the current one to provide more
    // precise diagnostics.
    var problemForUnresolvedReference: ((_ unresolvedReference: UnresolvedTopicReference, _ range: SourceRange?, _ fromSymbolLink: Bool, _ underlyingErrorMessage: String) -> Problem?)? = nil

    private mutating func resolve(reference: TopicReference, range: SourceRange?, severity: DiagnosticSeverity, fromSymbolLink: Bool = false) -> ResolvedTopicReference? {
        switch context.resolve(reference, in: rootReference, fromSymbolLink: fromSymbolLink) {
        case .success(let resolved):
            // If the linked node is part of the topic graph,
            // verify that linking to it is enabled, else return `nil`.
            if let node = context.topicGraph.nodeWithReference(resolved) {
                if node.isEmptyExtension {
                    problems.append(removedLinkDestinationProblem(reference: resolved, range: range, severity: severity))
                    return nil
                } else if !context.topicGraph.isLinkable(node.reference) {
                    problems.append(disabledLinkDestinationProblem(reference: resolved, range: range, severity: severity))
                    return nil
                }
            }
            return resolved
            
        case .failure(let unresolved, let error):
            if let problem = problemForUnresolvedReference?(unresolved, range, fromSymbolLink, error.message) {
                problems.append(problem)
                return nil
            }
            
            if let articleNotInHierarchy = context.uncuratedArticles[context.inputs.articlesDocumentationRootReference.appendingPathOfReference(unresolved)] {
                problems.append(makeUnfindableArticleProblem(source: range?.source, severity: severity, range: range, articleNotInHierarchy: articleNotInHierarchy, rootPageNames: context.sortedRootPageNames()))
            } else {
                problems.append(unresolvedReferenceProblem(source: range?.source, range: range, severity: severity, errorInfo: error, fromSymbolLink: fromSymbolLink))
            }
            return nil
        }
    }

    mutating func visitImage(_ image: Image) -> (any Markup)? {
        if let reference = image.reference(in: context.inputs), !context.resourceExists(with: reference) {
            problems.append(unresolvedResourceProblem(resource: reference, source: image.range?.source, range: image.range, severity: .warning))
        }

        var image = image
        let newChildren = image.children.compactMap {
            visit($0) as? (any InlineMarkup)
        }
        image.replaceChildrenInRange(0..<image.childCount, with: newChildren)
        return image
    }
    
    mutating func visitInlineHTML(_ inlineHTML: InlineHTML) -> (any Markup)? {
        return inlineHTML
    }
    
    mutating func visitLineBreak(_ lineBreak: LineBreak) -> (any Markup)? {
        return lineBreak
    }

    mutating func visitLink(_ link: Link) -> (any Markup)? {
        guard let destination = link.destination else {
            return link
        }
        guard let url = ValidatedURL(parsingAuthoredLink: destination) else {
            problems.append(invalidLinkDestinationProblem(destination: destination, range: link.range, severity: .warning))
            return link
        }
        guard url.components.scheme == ResolvedTopicReference.urlScheme else {
            return link // Create a non-topic link
        }
        let unresolved = TopicReference.unresolved(.init(topicURL: url))
        guard let resolvedURL = resolve(reference: unresolved, range: link.range, severity: .warning) else {
            return link
        }
        var link = link
        let wasAutoLink = link.isAutolink
        link.destination = resolvedURL.absoluteString
        if wasAutoLink {
            link.replaceChildrenInRange(0..<link.childCount, with: [Text(resolvedURL.absoluteString)])
            assert(link.isAutolink)
        }
        return link
    }

    mutating func resolveAbsoluteSymbolLink(unresolvedDestination: String, elementRange range: SourceRange?) -> ResolvedTopicReference? {
        if let cached = context.referenceIndex[unresolvedDestination] {
            guard context.topicGraph.isLinkable(cached) == true else {
                problems.append(disabledLinkDestinationProblem(reference: cached, range: range, severity: .warning))
                return nil
            }
            return cached
        }

        // We don't require a scheme here as the link can be a relative one, e.g. ``SwiftUI/View``.
        let url = ValidatedURL(parsingExact: unresolvedDestination)?.requiring(scheme: ResolvedTopicReference.urlScheme) ?? ValidatedURL(symbolPath: unresolvedDestination)
        return resolve(reference: .unresolved(.init(topicURL: url)), range: range, severity: .warning, fromSymbolLink: true)
    }
    
    mutating func visitSymbolLink(_ symbolLink: SymbolLink) -> (any Markup)? {
        guard let destination = symbolLink.destination else {
            return symbolLink
        }
        
        var symbolLink = symbolLink
        if let resolved = resolveAbsoluteSymbolLink(unresolvedDestination: destination, elementRange: symbolLink.range) {
            symbolLink.destination = resolved.absoluteString
        }
        
        return symbolLink
    }
    
    mutating func visitThematicBreak(_ thematicBreak: ThematicBreak) -> (any Markup)? {
        return thematicBreak
    }

    mutating func visitBlockDirective(_ blockDirective: BlockDirective) -> (any Markup)? {
        let source = blockDirective.range?.source
        switch blockDirective.name {
        case Snippet.directiveName:
            var ignoredParsingProblems = [Problem]() // Any argument parsing problems have already been reported elsewhere
            guard let snippet = Snippet(from: blockDirective, source: source, for: context.inputs, problems: &ignoredParsingProblems) else {
                return blockDirective
            }
            
            switch context.snippetResolver.resolveSnippet(path: snippet.path) {
            case .success(let resolvedSnippet):
                if let requestedSlice = snippet.slice,
                   let errorInfo = context.snippetResolver.validate(slice: requestedSlice, for: resolvedSnippet)
                {
                    problems.append(SnippetResolver.unknownSnippetSliceProblem(source: source, range: blockDirective.arguments()["slice"]?.valueRange, errorInfo: errorInfo))
                }
                return blockDirective
            case .failure(let errorInfo):
                problems.append(SnippetResolver.unresolvedSnippetPathProblem(source: source, range: blockDirective.arguments()["path"]?.valueRange, errorInfo: errorInfo))
                return blockDirective
            }
        case ImageMedia.directiveName:
            guard let imageMedia = ImageMedia(from: blockDirective, source: source, for: context.inputs) else {
                return blockDirective
            }
            
            if !context.resourceExists(with: imageMedia.source, ofType: .image) {
                problems.append(
                    unresolvedResourceProblem(
                        resource: imageMedia.source,
                        expectedType: .image,
                        source: blockDirective.range?.source,
                        range: imageMedia.originalMarkup.range,
                        severity: .warning
                    )
                )
            }
            
            return blockDirective
        case VideoMedia.directiveName:
            guard let videoMedia = VideoMedia(from: blockDirective, source: source, for: context.inputs) else {
                return blockDirective
            }
            
            if !context.resourceExists(with: videoMedia.source, ofType: .video) {
                problems.append(
                    unresolvedResourceProblem(
                        resource: videoMedia.source,
                        expectedType: .video,
                        source: source,
                        range: videoMedia.originalMarkup.range,
                        severity: .warning
                    )
                )
            }
            
            if let posterReference = videoMedia.poster,
                !context.resourceExists(with: posterReference, ofType: .image)
            {
                problems.append(
                    unresolvedResourceProblem(
                        resource: posterReference,
                        expectedType: .image,
                        source: source,
                        range: videoMedia.originalMarkup.range,
                        severity: .warning
                    )
                )
            }
            
            return blockDirective
        case Comment.directiveName:
            return blockDirective
        default:
            return defaultVisit(blockDirective)
        }
    }
}
