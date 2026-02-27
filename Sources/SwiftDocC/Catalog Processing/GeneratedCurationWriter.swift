/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

public import Foundation
private import SymbolKit
private import DocCCommon

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
              let taskGroups = taskGroupsToWrite(for: node)
        else {
            return nil
        }
        
        let relativeLinks = linkResolver.disambiguatedRelativeLinksForDescendants(of: reference)
        
        var text = ""
        for taskGroup in taskGroups {
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
            
            text.append("\n\n### \(taskGroup.title)\n")
            if let language = taskGroup.languageFilter {
                text.append("\n@SupportedLanguage(\(language.taskGroupID))\n")
            }
            
            // Calculate the longest link to nicely align all the comments
            let longestLink = links.map(\.link.count).max()! // `links` are non-empty so it's safe to force-unwrap `.max()` here
            for (link, comment) in links {
                if let comment {
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
        
        guard var curationCrawlRoot = linkResolver.rootPages().first else {
            return [:]
        }
        
        if let symbolLink {
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
                guard reference == curationCrawlRoot || context.finitePaths(to: reference).contains(where: { path in path.suffix(depthLimit ?? .max).contains(curationCrawlRoot)}) else {
                    continue
                }
            }
            
            guard let absoluteLink = allAbsoluteLinks[usr], let curationText = defaultCurationText(for: reference) else { continue }
            if let catalogURL, let existingURL = context.documentationExtensionURL(for: reference) {
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
    
    private struct GeneratedTaskGroup: Equatable {
        var title: String
        var references: [ResolvedTopicReference]
        var languageFilter: SourceLanguage?
    }
    
    private func taskGroupsToWrite(for node: DocumentationNode) -> [GeneratedTaskGroup]? {
        // Perform source-language specific curation in a stable order
        let languagesToCurate = node.availableSourceLanguages.sorted()
        var topicsByLanguage = [SourceLanguage: [AutomaticCuration.TaskGroup]]()
        for language in languagesToCurate {
            topicsByLanguage[language] = try? AutomaticCuration.topics(for: node, withTraits: [.init(sourceLanguage: language)], context: context)
        }
        
        guard topicsByLanguage.count > 1 else {
            // If this node doesn't have curation in more than one language, return that curation _without_ a language filter.
            return topicsByLanguage.first?.value.map { .init(title: $0.title! /* Automatically-generated task groups always have a title. */, references: $0.references) }
        }
        
        // Checks if a node for the given reference is only available in the given source language.
        func isOnlyAvailableIn(_ reference: ResolvedTopicReference, _ language: SourceLanguage) -> Bool {
            context.documentationCache[reference]?.availableSourceLanguages == [language]
        }
        
        // This is defined as an inner function so that the taskGroups-loop can return to finish processing task groups for that symbol kind.
        func addProcessedTaskGroups(_ symbolKind: SymbolGraph.Symbol.KindIdentifier, into result: inout [GeneratedTaskGroup]) {
            let title = AutomaticCuration.groupTitle(for: symbolKind)
            let taskGroups: [GeneratedTaskGroup] = languagesToCurate.compactMap { language in
                topicsByLanguage[language]?
                    .first(where: { $0.title == title })
                    .map { (title, references) in
                        // Automatically-generated task groups always have a title.
                        GeneratedTaskGroup(title: title!, references: references, languageFilter: language)
                    }
            }
            guard taskGroups.count > 1 else {
                if let taskGroup = taskGroups.first {
                    if taskGroup.references.allSatisfy({ isOnlyAvailableIn($0, taskGroup.languageFilter!) }) {
                        // These symbols are all only available in one source language. We can omit the language filter.
                        result.append(.init(title: title, references: taskGroup.references))
                    } else {
                        // Add the task group as-is, with its language filter.
                        result.append(taskGroup)
                    }
                }
                return
            }
            
            // Check if the source-language specific task groups need to be emitted individually
            for taskGroup in taskGroups {
                // Gather all the references for the other task groups
                let otherReferences = taskGroups.reduce(into: Set(), { accumulator, group in
                    guard group != taskGroup else { return }
                    accumulator.formUnion(group.references)
                })
                let uniqueReferences = Set(taskGroup.references).subtracting(otherReferences)
                
                guard uniqueReferences.isEmpty || uniqueReferences.allSatisfy({ isOnlyAvailableIn($0, taskGroup.languageFilter!) }) else {
                    // If at least one of the task groups contains a a language-refined symbol that's not in the other task groups, then emit all task groups individually
                    result.append(contentsOf: taskGroups)
                    return
                }
            }
            
            // Otherwise, if the task groups all contain the same symbols or only contain single-language symbols, emit a combined task group without a language filter.
            // When DocC renders this task group it will filter out the single-language symbols, producing correct and consistent results in all language variants without
            // needing to repeat the task groups with individual language filters.
            result.append(.init(
                title: title,
                references: taskGroups.reduce(into: Set(), { $0.formUnion($1.references) }).sorted(by: \.path)
            ))
        }
        
        var result = [GeneratedTaskGroup]()
        for symbolKind in AutomaticCuration.groupKindOrder {
            addProcessedTaskGroups(symbolKind, into: &result)
        }
        return result
    }
}

private extension SourceLanguage {
    var taskGroupID: String {
        switch self {
        case .objectiveC:
            return "objc"
        default:
            return self.linkDisambiguationID
        }
    }
}
