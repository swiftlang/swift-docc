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

extension Docc {
    
    struct GenerateChangelog: ParsableCommand {
        
        // MARK: - Configuration
        
        static var logHandle: LogHandle = .standardOutput

        /// Command line configuration.
        static var configuration = CommandConfiguration(
            commandName: "generate-changelog",
            abstract: "Generate a changelog with symbol diffs between documentation archives ('.doccarchive' directories).",
            shouldDisplay: true)
        
        
        // MARK: - Command Line Options & Arguments
        
        @Argument(
            help: ArgumentHelp(
                "The path to the initial DocC Archive to be compared.",
                valueName: "initialDocCArchive"),
            transform: URL.init(fileURLWithPath:))
        var initialDocCArchivePath: URL
        
        @Argument(
            help: ArgumentHelp(
                "The path to the newer DocC Archive to be compared.",
                valueName: "newerDocCArchive"),
            transform: URL.init(fileURLWithPath:))
        var newerDocCArchivePath: URL
        
        @Option(
            name: [.customLong("initial-archive-name", withSingleDash: false)],
            help: "The name of the initial DocC Archive version to be compared."
        )
        var initialArchiveName: String = "Version 1"
        
        @Option(
            name: [.customLong("newer-archive-name", withSingleDash: false)],
            help: "The name of the newer DocC Archive version to be compared."
        )
        var newerArchiveName: String = "Version 2"
        
        @Option(
            name: [.customLong("show-all", withSingleDash: false)],
            help: "Boolean value to indicate whether to produce a full symbol diff, including all properties, methods, and overrides"
        )
        var showAllSymbols: Bool = false
        
        // MARK: - Execution
        
        public mutating func run() throws {
            var initialDocCArchiveAPIs: [URL] = []
            var newDocCArchiveAPIs: [URL] = []
            
            if showAllSymbols {
                print("Showing ALL symbols.", to: &Docc.GenerateChangelog.logHandle)
                initialDocCArchiveAPIs = try findAllSymbolLinks_Full(initialPath: initialDocCArchivePath)
                newDocCArchiveAPIs = try findAllSymbolLinks_Full(initialPath: newerDocCArchivePath)
            } else {
                print("Showing ONLY high-level symbol diffs: modules, classes, protocols, and structs.", to: &Docc.GenerateChangelog.logHandle)
                initialDocCArchiveAPIs = try findAllSymbolLinks(initialPath: initialDocCArchivePath)
                newDocCArchiveAPIs = try findAllSymbolLinks(initialPath: newerDocCArchivePath)
            }
            
            let initialSet = Set(initialDocCArchiveAPIs)
            let newSet = Set(newDocCArchiveAPIs)
            
            // Compute additions and removals to both sets
            let additionsToNewSet = newSet.subtracting(initialSet)
            let removedFromOldSet = initialSet.subtracting(newSet)
            
            // The framework name is the path component after "/documentation/".
            var potentialFrameworkName = try findFrameworkName(initialPath: initialDocCArchivePath)
            if potentialFrameworkName == nil {
                potentialFrameworkName = try findFrameworkName(initialPath: newerDocCArchivePath)
            }
            let frameworkName: String = potentialFrameworkName ?? "No_Framework_Name"
            
            let additionLinks = groupSymbols(symbolLinks: additionsToNewSet, frameworkName: frameworkName)
            let removalLinks = groupSymbols(symbolLinks: removedFromOldSet, frameworkName: frameworkName)
            
            // Create markdown file with changes in the newer DocC Archive that do not exist in the initial DocC Archive.
            for fileNameAndContent in CatalogTemplateKind.changeLogTemplateFileContent(frameworkName: frameworkName, initialDocCArchiveVersion: initialArchiveName, newerDocCArchiveVersion: newerArchiveName, additionLinks: additionLinks, removalLinks: removalLinks) {
                let fileName = fileNameAndContent.key
                let content = fileNameAndContent.value
                let filePath = initialDocCArchivePath.deletingLastPathComponent().appendingPathComponent(fileName)
                try FileManager.default.createFile(at: filePath, contents: Data(content.utf8))
                print("\nOutput file path: \(filePath)", to: &Docc.GenerateChangelog.logHandle)
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
                    let symbolKind = try findKind(symbolPath: filePath)
                    
                    if (symbolLink != nil && symbolKind != nil) {
                        if let validSymbol = symbolKind?.contains("module") {
                            if validSymbol == true {
                                returnSymbolLinks.append(symbolLink!)
                            }
                        }
                        
                        if let validSymbol = symbolKind?.contains("class") {
                            if validSymbol == true {
                                returnSymbolLinks.append(symbolLink!)
                            }
                        }
                        
                        if let validSymbol = symbolKind?.contains("protocol") {
                            if validSymbol == true {
                                returnSymbolLinks.append(symbolLink!)
                            }
                        }
                        
                        if let validSymbol = symbolKind?.contains("struct") {
                            if validSymbol == true {
                                returnSymbolLinks.append(symbolLink!)
                            }
                        }
                    }
                }
            }
            return returnSymbolLinks
        }
        
        /// Given a URL, return each of the symbols by their unique identifying links
       func findAllSymbolLinks_Full(initialPath: URL) throws -> [URL] {
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
        
        func findKind(symbolPath: URL) throws -> String? {
            struct ContainerWithKind: Codable {
                var metadata: RenderMetadata
            }
            
            let renderJSONData = try Data(contentsOf: symbolPath)
            let decoder = RenderJSONDecoder.makeDecoder()
            
            do {
                let metadata = try decoder.decode(ContainerWithKind.self, from: renderJSONData).metadata
                return metadata.symbolKind
            } catch {
                return nil
            }
        }
        
        /// Process lists of symbols to group them according to the highest level path component, split by spaces.
        func groupSymbols(symbolLinks: Set<URL>, frameworkName: String) -> String {
            // Sort list alphabetically
            let sortedSymbols: [URL] = symbolLinks.sorted { $0.absoluteString.localizedCompare($1.absoluteString) == .orderedAscending }
            
            var links: String = ""
            
            // find most similar path up until framework name by iterating over path components one at a time
            guard var first = sortedSymbols.first else {
                return links
            }
            
            for symbol in sortedSymbols.dropFirst() {
                let parent: String = first.absoluteString.commonPrefix(with: symbol.absoluteString)
                
                // If there are no common path components, add a space. Then reset the first to find the next parent.
                if parent.localizedLowercase.hasSuffix(frameworkName + "/") {
                    links.append("\n")
                    first = symbol
                }
                    
                links.append("\n- <\(findExternalLink(identifierURL: symbol))>")
            }
            
            return links
        }
        
    }
}
