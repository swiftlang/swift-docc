/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import ArgumentParser
import Foundation
import SwiftDocC

extension Docc.ProcessArchive {
    
    struct DiffDocCArchive: ParsableCommand {
        
        // MARK: - Content and Configuration
        
        /// Command line configuration.
        static var configuration = CommandConfiguration(
            commandName: "diff-docc-archive",
            abstract: "Produce a markdown file saved as {FrameworkName}_ChangeLog.md containing the diff of added/removed symbols between the two provided DocC archives.",
            shouldDisplay: true)
        
        /// Content of the 'changeLog' template.
        static func changeLogTemplateFileContent(
            frameworkName: String,
            initialDocCArchiveVersion: String,
            newerDocCArchiveVersion: String,
            additionLinks: String,
            removalLinks: String
        ) -> [String : String] {
            [
                "\(frameworkName.localizedCapitalized)_ChangeLog.md": """
                    # \(frameworkName.localizedCapitalized) Updates
                    
                    @Metadata { @PageColor(yellow) }
                    
                    Learn about important changes to \(frameworkName.localizedCapitalized).
                    
                    ## Overview

                    Browse notable changes in \(frameworkName.localizedCapitalized).
                    
                    ## Version: Diff between \(initialDocCArchiveVersion) and \(newerDocCArchiveVersion)

                    
                    ### Change Log
                    
                    #### Additions
                    _New symbols added in \(newerDocCArchiveVersion) that did not previously exist in \(initialDocCArchiveVersion)._
                                        
                    \(additionLinks)
                    
                    
                    #### Removals
                    _Old symbols that existed in \(initialDocCArchiveVersion) that no longer exist in \(newerDocCArchiveVersion)._
                                        
                    \(removalLinks)
                    
                    """
            ]
        }
        
        // MARK: - Command Line Options & Arguments
        
        @Argument(
            help: ArgumentHelp(
                "The version of the initial DocC Archive to be compared.",
                valueName: "initialDocCArchiveVersion"))
        var initialDocCArchiveVersion: String
        
        @Argument(
            help: ArgumentHelp(
                "The path to the initial DocC Archive to be compared.",
                valueName: "initialDocCArchive"),
            transform: URL.init(fileURLWithPath:))
        var initialDocCArchivePath: URL
        
        @Argument(
            help: ArgumentHelp(
                "The version of the newer DocC Archive to be compared.",
                valueName: "newerDocCArchiveVersion"))
        var newerDocCArchiveVersion: String
        
        @Argument(
            help: ArgumentHelp(
                "The path to the newer DocC Archive to be compared.",
                valueName: "newerDocCArchive"),
            transform: URL.init(fileURLWithPath:))
        var newerDocCArchivePath: URL
        
        // MARK: - Execution
        
        public mutating func run() throws {
            let initialDocCArchiveAPIs: [URL] = try findAllSymbolLinks(initialPath: initialDocCArchivePath)
            let newDocCArchiveAPIs: [URL] = try findAllSymbolLinks(initialPath: newerDocCArchivePath)
            
            let initialSet = Set(initialDocCArchiveAPIs.map { $0 })
            let newSet = Set(newDocCArchiveAPIs.map { $0 })
            
            // Compute additions and removals to both sets
            let additionsToNewSet = newSet.subtracting(initialSet)
            let removedFromOldSet = initialSet.subtracting(newSet)
            
            // Map identifier urls in differences to external urls
            let additionsExternalURLs = Set(additionsToNewSet.map { findExternalLink(identifierURL: $0) })
            let removalsExternalURLs = Set(removedFromOldSet.map { findExternalLink(identifierURL: $0) })
            
            // The framework name is the path component after "/documentation/".
            var frameworkName: String = "No_Framework_Name"
            var potentialFrameworkName = try findFrameworkName(initialPath: initialDocCArchivePath)
            if potentialFrameworkName == nil {
                potentialFrameworkName = try findFrameworkName(initialPath: newerDocCArchivePath)
            }
            
            if potentialFrameworkName != nil {
                frameworkName = potentialFrameworkName ?? "No_Framework_Name"
            }
            
            
            let additionLinks = groupSeparateSymbols(symbolLinks: additionsExternalURLs)
            let removalLinks = groupSeparateSymbols(symbolLinks: removalsExternalURLs)
            
            
            
//            let sortedAdditionSymbols = groupSeparateSymbols(symbolLinks: additionsExternalURLs)
//            let sortedRemovalSymbols = groupSeparateSymbols(symbolLinks: removalsExternalURLs)
//            
//            var additionLinks: String = ""
//            for addition in sortedAdditionSymbols {
//                additionLinks.append("\n- <\(addition)>")
//            }
//            
//            var removalLinks: String = ""
//            for removal in sortedRemovalSymbols {
//                removalLinks.append("\n- <\(removal)>")
//            }
            
            // Create markdown file with changes in the newer DocC Archive that do not exist in the initial DocC Archive.
            for fileNameAndContent in Docc.ProcessArchive.DiffDocCArchive.changeLogTemplateFileContent(frameworkName: frameworkName, initialDocCArchiveVersion: initialDocCArchiveVersion, newerDocCArchiveVersion: newerDocCArchiveVersion, additionLinks: additionLinks, removalLinks: removalLinks) {
                let fileName = fileNameAndContent.key
                let content = fileNameAndContent.value
                let filePath = initialDocCArchivePath.deletingLastPathComponent().appendingPathComponent(fileName)
                try FileManager.default.createFile(at: filePath, contents: Data(content.utf8))
                print("\nOutput file path: \(filePath)")
            }
        }
        
        /// Pretty print all symbols' url identifiers into a pretty format, with a new line between each symbol.
        func printAllSymbols(symbols: [URL]) {
            for symbol in symbols {
                print(symbol)
            }
        }

        /// The framework name is the path component after "/documentation/".
        func findFrameworkName(initialPath: URL) throws -> String? {
            guard let enumerator = FileManager.default.enumerator(
                at: initialPath,
                includingPropertiesForKeys: [],
                options: .skipsHiddenFiles,
                errorHandler: nil
            ) else {
                return nil
            }
            
            var frameworkName: String?
            for case let filePath as URL in enumerator {
                let pathComponents = filePath.pathComponents
                var isFrameworkName = false
                for pathComponent in pathComponents {
                    if isFrameworkName {
                        frameworkName = pathComponent
                        return frameworkName
                    }
                    
                    if pathComponent == "documentation" {
                        isFrameworkName = true
                    }
                }
            }
            
            return frameworkName
        }
        
        /// Given the identifier url, cut off everything preceding /documentation/ and append this resulting string to doc:
        func findExternalLink(identifierURL: URL) -> String {
            var resultantURL = identifierURL.absoluteString
            var shouldAppend = false
            for pathComponent in identifierURL.pathComponents {
                if pathComponent == "documentation" {
                    resultantURL = "doc:"
                    shouldAppend = true
                }
                if shouldAppend {
                    resultantURL.append(pathComponent + "/")
                }
            }
            return resultantURL
        }
        
        /// Given a URL, return each of the symbols by their unique identifying links
        func findAllSymbolLinks(initialPath: URL) throws -> [URL] {
            guard let enumerator = FileManager.default.enumerator(
                at: initialPath,
                includingPropertiesForKeys: [],
                options: .skipsHiddenFiles,
                errorHandler: nil
            ) else {
                return []
            }
            
            var returnSymbolLinks: [URL] = []
            for case let filePath as URL in enumerator {
                if filePath.lastPathComponent.hasSuffix(".json") {
                    let symbolLink = try findSymbolLink(symbolPath: filePath)
                    if symbolLink != nil {
                        returnSymbolLinks.append(symbolLink!)
                    }
                }
            }
            
            return returnSymbolLinks
        }
        
        func findSymbolLink(symbolPath: URL) throws -> URL? {
            struct ContainerWithTopicReferenceIdentifier: Codable {
                var identifier: ResolvedTopicReference
            }
            
            let renderJSONData = try Data(contentsOf: symbolPath)
            let decoder = RenderJSONDecoder.makeDecoder()
            
            do {
                let identifier = try decoder.decode(ContainerWithTopicReferenceIdentifier.self, from: renderJSONData).identifier
                return identifier.url
            } catch {
                return nil
            }
        }
        
        /// Process lists of symbols to group them according to the highest level path component.
        ///
        /// If a class didn't exist in the old version but now exists in the new version:
        ///     - print that a new class was added,
        ///     - display the number of symbols added within that class beside it.
        ///
        /// Otherwise, group symbols by their highest path component below a header, and then print a nested list.
        func groupSeparateSymbols(symbolLinks: Set<String>) -> String {
            
            // Sort list alphabetically
            let sortedSymbols: [String] = symbolLinks.sorted { $0.localizedCompare($1) == .orderedAscending }
            
            // Check matching path components
            // for each path component after the initial path component....
//            for symbol in sortedSymbols {
//                // example path components: ["/", "documentation", "accelerate", "vdsp", "vector-scalar_real_arithmetic_functions"]
//                print(symbol.pathComponents)
//            }
            
            var links: String = ""
            for symbol in sortedSymbols {
                links.append("\n- <\(symbol)>")
            }
            
            return links // TODO: STUB
        }
                    
    }
}
