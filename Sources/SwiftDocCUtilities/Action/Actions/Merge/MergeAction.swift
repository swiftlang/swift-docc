/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SwiftDocC
import Markdown

/// An action that merges a list of documentation archives into a combined archive.
struct MergeAction: AsyncAction {
    var archives: [URL]
    var landingPageInfo: LandingPageInfo
    var outputURL: URL
    var fileManager: any FileManagerProtocol
    
    /// Information about how the merge action should create landing page content for the combined archive
    enum LandingPageInfo {
        // This enum will have a case for a landing page catalog when we add support for that.
        
        /// The merge action should synthesize a minimal landing page with a given configuration.
        case synthesize(SynthesizeConfiguration)
        
        struct SynthesizeConfiguration {
            var name: String
            var kind: String
            var style: TopicsVisualStyle.Style
        }
    }
    
    func perform(logHandle: inout LogHandle) async throws -> ActionResult {
        guard let firstArchive = archives.first else {
            // A validation warning should have already been raised in `Docc/Merge/InputAndOutputOptions/validate()`.
            return ActionResult(didEncounterError: true, outputs: [])
        }
        
        try validateThatOutputIsEmpty()
        try validateThatArchivesHaveDisjointData()
        let supportsStaticHosting = try validateThatAllArchivesOrNoArchivesSupportStaticHosting()
        
        let targetURL = try Self.createUniqueDirectory(inside: fileManager.uniqueTemporaryDirectory(), template: firstArchive, fileManager: fileManager)
        defer {
            try? fileManager.removeItem(at: targetURL)
        }
      
        // TODO: Merge the LMDB navigator index
        
        let jsonIndexURL = targetURL.appendingPathComponent("index/index.json")
        guard let jsonIndexData = fileManager.contents(atPath: jsonIndexURL.path) else {
            throw CocoaError.error(.fileReadNoSuchFile, userInfo: [NSFilePathErrorKey: jsonIndexURL.path])
        }
        var combinedJSONIndex = try JSONDecoder().decode(RenderIndex.self, from: jsonIndexData)
        
        // Ensure that the destination has a data directory in case the first archive didn't have any pages.
        try? fileManager.createDirectory(at: targetURL.appendingPathComponent("data", isDirectory: true), withIntermediateDirectories: false, attributes: nil)
        
        let directoriesToCopy = ["data/documentation", "data/tutorials", "images", "videos", "downloads"] + (supportsStaticHosting ? ["documentation", "tutorials"] : [])
        for archive in archives.dropFirst() {
            for directoryToCopy in directoriesToCopy {
                let fromDirectory = archive.appendingPathComponent(directoryToCopy, isDirectory: true)
                let toDirectory = targetURL.appendingPathComponent(directoryToCopy, isDirectory: true)

                // Ensure that the destination directory exist in case the first archive didn't have that kind of pages.
                // This is necessary when merging a reference-only archive with a tutorial-only archive.
                try? fileManager.createDirectory(at: toDirectory, withIntermediateDirectories: false, attributes: nil)
                for from in (try? fileManager.contentsOfDirectory(at: fromDirectory, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)) ?? [] {
                    // Copy each file or subdirectory
                    try fileManager._copyItem(at: from, to: toDirectory.appendingPathComponent(from.lastPathComponent))
                }
            }
            guard let jsonIndexData = fileManager.contents(atPath: archive.appendingPathComponent("index/index.json").path) else {
                throw CocoaError.error(.fileReadNoSuchFile, userInfo: [NSFilePathErrorKey: archive.appendingPathComponent("index/index.json").path])
            }
            let renderIndex = try JSONDecoder().decode(RenderIndex.self, from: jsonIndexData)
            
            // TODO: Combine link-hierarchy.json, linkable-entities.json, and metadata.json
            
            try combinedJSONIndex.merge(renderIndex)
        }
        
        switch landingPageInfo {
        case .synthesize(let configuration):
            try synthesizeLandingPage(configuration, combinedIndex: &combinedJSONIndex, targetURL: targetURL)
        }
        
        try fileManager.createFile(at: jsonIndexURL, contents: RenderJSONEncoder.makeEncoder(emitVariantOverrides: false).encode(combinedJSONIndex))
        
        try Self.moveOutput(from: targetURL, to: outputURL, fileManager: fileManager)
        
        return ActionResult(didEncounterError: false, outputs: [outputURL])
    }
    
    private func synthesizeLandingPage(
        _ configuration: LandingPageInfo.SynthesizeConfiguration,
        combinedIndex: inout RenderIndex,
        targetURL: URL
    ) throws {
        let landingPageName = configuration.name
        
        let languages = combinedIndex.interfaceLanguages.keys.map { SourceLanguage(id: $0) }
        let language = languages.sorted().first ?? .swift
        
        let reference = ResolvedTopicReference(bundleID: .init(rawValue: landingPageName), path: "/documentation", sourceLanguage: language)
        
        let rootRenderReferences = try readRootNodeRenderReferencesIn(dataDirectory: targetURL.appendingPathComponent("data", isDirectory: true))
        
        guard !rootRenderReferences.isEmpty else {
            // No need to synthesize a landing page if the combined archive is empty.
            return
        }
        
        let renderNode = makeSynthesizedLandingPage(
            name: landingPageName,
            reference: reference,
            roleHeading: configuration.kind,
            topicsStyle: configuration.style,
            rootRenderReferences: rootRenderReferences
        )
        
        try fileManager.createFile(
            at: targetURL.appendingPathComponent("data/documentation.json"),
            contents: RenderJSONEncoder.makeEncoder().encode(renderNode)
        )
        // It's expected that this will fail if combined archive doesn't support static hosting.
        try? fileManager._copyItem(
            at: targetURL.appendingPathComponent("index.html"),
            to: targetURL.appendingPathComponent("/documentation/index.html")
        )
        
        combinedIndex.insertRoot(named: landingPageName)
    }
    
    /// Validate that the different archives don't have overlapping data.
    private func validateThatArchivesHaveDisjointData() throws {
        // Check that the archives don't have overlapping data
        typealias ArchivesByDirectoryName = [String: [String: Set<String>]]
        
        var archivesByTopLevelDirectory = ArchivesByDirectoryName()
        
        // Gather all the top level /data/documentation and /data/tutorials directories to ensure that the different archives don't have overlapping data
        for archive in archives {
            for typeOfDocumentation in (try? fileManager.contentsOfDirectory(at: archive.appendingPathComponent("data", isDirectory: true), includingPropertiesForKeys: nil, options: .skipsHiddenFiles)) ?? [] {
                for moduleOrTechnologyName in (try? fileManager.contentsOfDirectory(at: typeOfDocumentation, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)) ?? [] {
                    archivesByTopLevelDirectory[typeOfDocumentation.lastPathComponent, default: [:]][moduleOrTechnologyName.deletingPathExtension().lastPathComponent, default: []].insert(archive.lastPathComponent)
                }
            }
        }
        
        // Only data directories found in a multiple archives is a problem
        archivesByTopLevelDirectory = archivesByTopLevelDirectory.mapValues { collected in
            collected.filter { $0.value.count > 1 }
        }
        
        guard archivesByTopLevelDirectory.allSatisfy({ $0.value.isEmpty }) else {
            struct OverlappingDataError: DescribedError {
                var archivesByTopLevelDirectory: ArchivesByDirectoryName
                
                var errorDescription: String {
                    var message = "Input archives contain overlapping data"
                    for (typeOfDocumentation, archivesByData) in archivesByTopLevelDirectory.sorted(by: { $0.key < $1.key }) {
                        if let overlappingDocumentationDescription = overlapDescription(archivesByData: archivesByData, pathComponentName: typeOfDocumentation) {
                            message.append(overlappingDocumentationDescription)
                        }
                    }
                    return message
                }
                
                private func overlapDescription(archivesByData: ArchivesByDirectoryName.Value, pathComponentName: String) -> String? {
                    guard !archivesByData.isEmpty else {
                        return nil
                    }
                    
                    var description = "\n"
                    for (topLevelDirectory, archives) in archivesByData.mapValues({ $0.sorted() }) {
                        if archives.count == 2 {
                            description.append("\n'\(archives.first!)' and '\(archives.last!)' both ")
                        } else {
                            description.append("\n\(archives.dropLast().map({ "'\($0)'" }).joined(separator: ", ")), and '\(archives.last!)' all ")
                        }
                        description.append("contain '/data/\(pathComponentName)/\(topLevelDirectory)/'")
                    }
                    return description
                }
            }
            
            throw OverlappingDataError(archivesByTopLevelDirectory: archivesByTopLevelDirectory)
        }
    }
    
    /// Validate that the output directory is empty.
    private func validateThatOutputIsEmpty() throws {
        guard fileManager.directoryExists(atPath: outputURL.path) else {
            return
        }
        
        let existingContents = (try? fileManager.contentsOfDirectory(at: outputURL, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)) ?? []
        guard existingContents.isEmpty else {
            struct NonEmptyOutputError: DescribedError {
                var existingContents: [URL]
                var fileManager: any FileManagerProtocol
                
                var errorDescription: String {
                    var contentDescriptions = existingContents
                        .sorted(by: { $0.lastPathComponent < $1.lastPathComponent })
                        .prefix(6)
                        .map { " - \($0.lastPathComponent)\(fileManager.directoryExists(atPath: $0.path) ? "/" : "")" }
                    
                    if existingContents.count > 6 {
                        contentDescriptions[5] = "and \(existingContents.count - 5) more files and directories"
                    }
                    
                    return """
                    Output directory is not empty. It contains:
                    \(contentDescriptions.joined(separator: "\n"))
                    """
                }
            }
        
            throw NonEmptyOutputError(existingContents: existingContents, fileManager: fileManager)
        }
    }
    
    /// Validate that either all archives support static hosting or that no archives support static hosting.
    /// - Returns: `true` if all archives support static hosting; `false` otherwise.
    private func validateThatAllArchivesOrNoArchivesSupportStaticHosting() throws -> Bool {
        let nonEmptyArchives = archives.filter {
            fileManager.directoryExists(atPath: $0.appendingPathComponent("data").path)
        }
        
        let archivesWithStaticHostingSupport = nonEmptyArchives.filter {
            return fileManager.directoryExists(atPath: $0.appendingPathComponent("documentation").path)
                || fileManager.directoryExists(atPath: $0.appendingPathComponent("tutorials").path)
        }
        
        guard archivesWithStaticHostingSupport.count == nonEmptyArchives.count // All archives support static hosting
           || archivesWithStaticHostingSupport.count == 0 // No archives support static hosting
        else {
            struct DifferentStaticHostingSupportError: DescribedError {
                var withSupport: Set<String>
                var withoutSupport: Set<String>
                
                var errorDescription: String {
                    """
                    Different static hosting support in different archives.
                    
                    \(withSupport.sorted().joined(separator: ", ")) support\(withSupport.count == 1 ? "s" : "") static hosting \
                    but \(withoutSupport.sorted().joined(separator: ", ")) do\(withoutSupport.count == 1 ? "es" : "")n't.
                    """
                }
            }
            let allArchiveNames = Set(nonEmptyArchives.map(\.lastPathComponent))
            let archiveNamesWithStaticHostingSupport = Set(archivesWithStaticHostingSupport.map(\.lastPathComponent))
            
            throw DifferentStaticHostingSupportError(
                withSupport: archiveNamesWithStaticHostingSupport,
                withoutSupport: allArchiveNames.subtracting(archiveNamesWithStaticHostingSupport)
            )
        }
        
        return !archivesWithStaticHostingSupport.isEmpty
    }
}
