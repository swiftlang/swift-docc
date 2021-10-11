/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

extension RenderNode {

    /**
     Returns a list of references for children pages.
     
     - Returns: A list of `RenderRelationshipsGroup`.
     */
    public func childrenRelationship(for language: String? = nil) -> [RenderRelationshipsGroup] {
        var groups = [RenderRelationshipsGroup]()
        
        switch kind {
        case .overview:
            for case let section as VolumeRenderSection in sections  {
                let chapters = section.chapters
                for chapter in chapters {
                    let name = chapter.name
                    
                    // Extract the identifiers of linked chapters.
                    let tutorials = chapter.tutorials.map { $0.identifier }
                    // Get the references preserving the order.
                    let references = tutorials.compactMap { self.references[$0] } as! [TopicRenderReference]

                    groups.append(RenderRelationshipsGroup(name: name, abstract: nil, references: references))
                }
            }
        default:
            let topicReferences: [TopicRenderReference] = self.references.values.filter { $0 is TopicRenderReference } as! [TopicRenderReference]
            let references: [String : TopicRenderReference] = Dictionary(uniqueKeysWithValues: topicReferences.map{ ($0.identifier.identifier, $0) })
            
            func processBlock(nestingReferences: Bool) -> ((TaskGroupRenderSection) -> ()) {
                return { topicSection in
                    // Get all the related identifiers
                    let identifiers = topicSection.identifiers
                    // Map the references preserving the order
                    let relationships = identifiers.map { references[$0]! }
                    // Get the abstract
                    let abstract = topicSection.abstract?.map { $0.rawIndexableTextContent(references: self.references) }.joined(separator: " ")
                    
                    // Append the group to the result
                    groups.append(RenderRelationshipsGroup(name: topicSection.title, abstract: abstract, references: relationships, referencesAreNested: nestingReferences))
                }
            }
            
            topicSections.forEach(processBlock(nestingReferences: false))
            defaultImplementationsSections.forEach(processBlock(nestingReferences: true))
        }
        
        return groups
    }
    
    /**
    Return the project files for a given `RenderNode`, if possible.
     
     - Returns: The single `DownloadReference` listed as `projectFiles` in the Intro section.
    */
    public func projectFiles() -> DownloadReference? {
        // sampleDownload is provided by pages which are of type "sample code".
        // This section provides an action which includes a download referece.
        if let sampleDownload = sampleDownload, case let RenderInlineContent.reference(identifier, _, _, _) = sampleDownload.action,
           let reference = references[identifier.identifier] {
            return reference as? DownloadReference
        }
        // In case we can't find a sample code reference, we fallback to look for
        // the project file in the Intro section, which is normally used by tutorials.
        guard let intro = sections.first as? IntroRenderSection else { return nil }
        guard let projectFiles = intro.projectFiles else { return nil }
        guard let reference = references[projectFiles.identifier] else { return nil }
        return reference as? DownloadReference
    }
    
    /**
     Return all the download references found in a single `RenderNode`.
     
     - Returns: A list of `DownloadReference` for all the content that can be downloaded from the page.
     */
    public func downloadReferences() -> [DownloadReference] {
        // Extract all the download references.
        return references.values.filter { $0 is DownloadReference } as! [DownloadReference]
    }
}

/**
 A structure holding the information about a given group of references.
 The group can have a title and an abstract that can be rendered if necessary.
 */
public struct RenderRelationshipsGroup {

    /// The optional name of the group of references.
    public let name: String?
    
    /// The optional abstract of the group of references.
    public let abstract: String?
    
    /// The `TopicRenderReferences`related to the `RenderNode`.
    public let references: [TopicRenderReference]
    
    /// Indicates if the group should nest sub-references or not. Default: false.
    public let referencesAreNested: Bool
    
    public init(name: String?, abstract: String?, references: [TopicRenderReference], referencesAreNested: BooleanLiteralType = false) {
        self.name = name
        self.abstract = abstract
        self.references = references
        self.referencesAreNested = referencesAreNested
    }
}

