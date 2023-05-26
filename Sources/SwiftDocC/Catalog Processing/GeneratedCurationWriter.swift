/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2023 Apple Inc. and the Swift project authors
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
    
    public init?(
        context: DocumentationContext,
        catalogURL: URL?,
        outputURL: URL
    ) {
        self.context = context
        
        self.catalogURL = catalogURL
        self.outputURL = outputURL
        guard let linkResolver = context.hierarchyBasedLinkResolver else {
            context.diagnosticEngine.emit(
                Problem(diagnostic: Diagnostic(severity: .warning, identifier: "org.swift.docc.", summary: "Writing auto-generated curation into documentation extension files is only supported with the default link resolver."))
            )
            return nil
        }
        self.linkResolver = linkResolver
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
        
        // Any reference that is already curated should be excluded from the auto-generated curation
        let alreadyCurated = Set((symbol.topics?.taskGroups ?? []).flatMap { $0.links.compactMap(\.destination) })
        
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
                guard !alreadyCurated.contains(curatedReference.absoluteString) else { return nil }
                guard let linkInfo = relativeLinks[curatedReference] else { return nil }
                // If this link contains disambiguation, include a comment with the full symbol declaration to make it easier to know which symbol it refers to.
                if linkInfo.hasDisambiguation,
                   let symbol = context.documentationCache[curatedReference]?.symbol,
                   let fragments = symbol[mixin: SymbolGraph.Symbol.DeclarationFragments.self]?.declarationFragments
                {
                    let commentText = fragments.map(\.spelling).joined().split(whereSeparator: { $0.isWhitespace || $0.isNewline }).joined(separator: " ")
                    return (linkInfo.link, commentText)
                }
                return (linkInfo.link, nil)
                
            }
            
            guard !links.isEmpty else { continue }
            
            text.append("\n\n### \(taskGroup.title ?? "<!-- This auto-generated topic has no title -->")\n")
            
            let longestLink = links.map(\.link.count).max()! /* `links` are non-empty */ + 7 /* the extra characters used to make the link "\n- ``" before and "``" after */
            for (link, comment) in links {
                if let comment = comment {
                    text.append("\n- ``\(link)``".padding(toLength: longestLink, withPad: " ", startingAt: 0))
                    text.append(" <!-- \(comment) -->")
                } else {
                    text.append("\n- ``\(link)``")
                }
            }
        }
        
        guard !text.isEmpty else { return nil }
        
        return """
            <!-- The content below this line is auto-generated and is redundant. You should either incorporate it into your content above this line or delete it. -->
            
            ## Topics
            """ + text
    }
    
    public func generateDefaultCurationContents() throws -> [URL: String] {
        // Used in documentation extension page titles to reference symbols that don't already have a documentation extension file.
        let allAbsoluteLinks = linkResolver.pathHierarchy.disambiguatedAbsoluteLinks()
        
        var contentsToWrite = [URL: String]()
        
        for (usr, reference) in context.symbolIndex {
            guard let absoluteLink = allAbsoluteLinks[usr], let curationText = defaultCurationText(for: reference) else { continue }
            if let catalogURL = catalogURL, let existingURL = context.documentationExtensionURL(for: reference) {
                let updatedFileURL: URL
                if catalogURL == outputURL {
                    updatedFileURL = existingURL
                } else {
                    var url = catalogURL
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
                let fileName = urlReadablePath(absoluteLink)
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
