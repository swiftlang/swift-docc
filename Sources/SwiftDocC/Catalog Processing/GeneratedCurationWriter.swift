/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SymbolKit

/// A type that writes the auto-generated curation into documentation extension files.
public struct GeneratedCurationWriter {
    let context: DocumentationContext
    let catalogURL: URL?
    let outputURL: URL
    let linkResolver: PathHierarchyBasedLinkResolver
    
    public init(
        context: DocumentationContext,
        catalogURL: URL?,
        outputURL: URL
    ) {
        self.context = context
        
        self.catalogURL = catalogURL
        self.outputURL = outputURL
        
        self.linkResolver = context.linkResolver.localResolver
    }
    
    /// Generates the markdown representation of the auto-generated curation for a given symbol reference.
    ///
    /// - Parameters:
    ///   - reference: The symbol reference to generate curation text for.
    /// - Returns: The auto-generated curation text, or `nil` if this reference has no auto-generated curation.
    func defaultCurationText(for reference: ResolvedTopicReference) -> String? {
        guard let node = context.documentationCache[reference],
              let symbol = node.semantic as? Symbol,
              let automaticTopics = try? AutomaticCuration.topics(for: node, withTraits: [], context: context),
              !automaticTopics.isEmpty
        else {
            return nil
        }
        
        let relativeLinks = linkResolver.disambiguatedRelativeLinksForDescendants(of: reference)
        
        // Top-level curation has a few special behaviors regarding symbols with different representations in multiple languages.
        let isForTopLevelCuration = symbol.kind.identifier == .module
        
        var text = ""
        for taskGroup in automaticTopics {
            if isForTopLevelCuration, let firstReference = taskGroup.references.first, context.documentationCache[firstReference]?.symbol?.kind.identifier == .typeProperty {
                // Skip type properties in top-level curation. It's not clear what's the right place for these symbols are since they exist in
                // different places in different source languages (which documentation extensions don't yet have a way of representing).
                continue
            }
            
            let links: [(link: String, comment: String?)] = taskGroup.references.compactMap { (curatedReference: ResolvedTopicReference) -> (String, String?)? in
                guard let linkInfo = relativeLinks[curatedReference] else { return nil }
                // If this link contains disambiguation, include a comment with the full symbol declaration to make it easier to know which symbol the link refers to.
                var commentText: String?
                if linkInfo.hasDisambiguation {
                    commentText = context.documentationCache[curatedReference]?.symbol?.declarationFragments?.map(\.spelling)
                        // Replace sequences of whitespace and newlines with a single space
                        .joined().split(whereSeparator: { $0.isWhitespace || $0.isNewline }).joined(separator: " ")
                }
                
                return ("\n- ``\(linkInfo.link)``", commentText.map { " <!-- \($0) -->" })
            }
            
            guard !links.isEmpty else { continue }
            
            text.append("\n\n### \(taskGroup.title ?? "<!-- This auto-generated topic has no title -->")\n")
            
            // Calculate the longest link to nicely align all the comments
            let longestLink = links.map(\.link.count).max()! // `links` are non-empty so it's safe to force-unwrap `.max()` here
            for (link, comment) in links {
                if let comment = comment {
                    text.append(link.padding(toLength: longestLink, withPad: " ", startingAt: 0))
                    text.append(comment)
                } else {
                    text.append(link)
                }
            }
        }
        
        guard !text.isEmpty else { return nil }
        
        var prefix = "<!-- The content below this line is auto-generated and is redundant. You should either incorporate it into your content above this line or delete it. -->"
        
        // Add "## Topics" to the curation text unless the symbol already had some manual curation.
        let hasAnyManualCuration = symbol.topics?.taskGroups.isEmpty == false
        if !hasAnyManualCuration {
            prefix.append("\n\n## Topics")
        }
        return "\(prefix)\(text)\n"
    }
    
    enum Error: DescribedError {
        case symbolLinkNotFound(TopicReferenceResolutionErrorInfo)
        
        var errorDescription: String {
            switch self {
            case .symbolLinkNotFound(let errorInfo):
                var errorMessage = "'--from-symbol <symbol-link>' not found: \(errorInfo.message)"
                for solution in errorInfo.solutions {
                    errorMessage.append("\n\(solution.summary.replacingOccurrences(of: "\n", with: ""))")
                }
                return errorMessage
            }
        }
    }
    
    /// Generates documentation extension content with a markdown representation of DocC's auto-generated curation.
    /// - Parameters:
    ///   - symbolLink: A link to the symbol whose sub hierarchy the curation writer will descend.
    ///   - depthLimit: The depth limit of how far the curation writer will descend from its starting point symbol.
    /// - Returns: A collection of file URLs and their markdown content.
    public func generateDefaultCurationContents(fromSymbol symbolLink: String? = nil, depthLimit: Int? = nil) throws -> [URL: String] {
        // Used in documentation extension page titles to reference symbols that don't already have a documentation extension file.
        let allAbsoluteLinks = linkResolver.pathHierarchy.disambiguatedAbsoluteLinks()
        
        guard var curationCrawlRoot = linkResolver.modules().first else {
            return [:]
        }
        
        if let symbolLink = symbolLink {
            switch context.linkResolver.resolve(UnresolvedTopicReference(topicURL: .init(symbolPath: symbolLink)), in: curationCrawlRoot, fromSymbolLink: true, context: context) {
            case .success(let foundSymbol):
                curationCrawlRoot = foundSymbol
            case .failure(_, let errorInfo):
                throw Error.symbolLinkNotFound(errorInfo)
            }
        }
        
        var contentsToWrite = [URL: String]()
        for (usr, reference) in context.documentationCache.referencesBySymbolID {
            // Filter out symbols that aren't in the specified sub hierarchy.
            if symbolLink != nil || depthLimit != nil {
                guard reference == curationCrawlRoot || context.pathsTo(reference).contains(where: { path in path.suffix(depthLimit ?? .max).contains(curationCrawlRoot)}) else {
                    continue
                }
            }
            
            guard let absoluteLink = allAbsoluteLinks[usr], let curationText = defaultCurationText(for: reference) else { continue }
            if let catalogURL = catalogURL, let existingURL = context.documentationExtensionURL(for: reference) {
                let updatedFileURL: URL
                if catalogURL == outputURL {
                    updatedFileURL = existingURL
                } else {
                    var url = outputURL
                    let relativeComponents = existingURL.standardizedFileURL.pathComponents.dropFirst(catalogURL.standardizedFileURL.pathComponents.count)
                    for component in relativeComponents.dropLast() {
                        url.appendPathComponent(component, isDirectory: true)
                    }
                    url.appendPathComponent(relativeComponents.last!, isDirectory: false)
                    updatedFileURL = url
                }
                // Append to the end of the file. See if we can avoid reading the existing contents on disk.
                var contents = try String(contentsOf: existingURL)
                contents.append("\n")
                contents.append(curationText)
                contentsToWrite[updatedFileURL] = contents
            } else {
                let relativeReferencePath = reference.url.pathComponents.dropFirst(2).joined(separator: "/")
                let fileName = urlReadablePath("/" + relativeReferencePath)
                let newFileURL = NodeURLGenerator.fileSafeURL(outputURL.appendingPathComponent("\(fileName).md"))
                
                let contents = """
                # ``\(absoluteLink)``
                
                \(curationText)
                """
                contentsToWrite[newFileURL] = contents
            }
        }
        
        return contentsToWrite
    }
}
