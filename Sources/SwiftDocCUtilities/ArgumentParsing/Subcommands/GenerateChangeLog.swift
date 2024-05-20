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
        
        // MARK: - Content and Configuration

        /// Command line configuration.
        static var configuration = CommandConfiguration(
            commandName: "generate-changelog",
            abstract: "Generate a changelog with symbol diffs between documentation archives ('.doccarchive' directories).",
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
                "\(frameworkName.localizedCapitalized)_Changelog.md": """
                    # \(frameworkName.localizedCapitalized) Updates
                    
                    @Metadata { 
                        @PageColor(yellow)
                    }
                    
                    Learn about important changes to \(frameworkName.localizedCapitalized).
                    
                    ## Overview

                    Browse notable changes in \(frameworkName.localizedCapitalized).
                    
                    ## Diff between \(initialDocCArchiveVersion) and \(newerDocCArchiveVersion)

                    
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
            name: [.customLong("show-all", withSingleDash: false)],
            help: "Produces full symbol diff: including all properties, methods, and overrides"
        )
        var showAllSymbols: Bool = false
        
        // MARK: - Execution
        
        public mutating func run() throws {
            var initialDocCArchiveAPIs: [URL] = try findAllSymbolLinks(initialPath: initialDocCArchivePath)
            var newDocCArchiveAPIs: [URL] = try findAllSymbolLinks(initialPath: newerDocCArchivePath)
            
            if showAllSymbols {
                print("Showing ALL symbols")
                initialDocCArchiveAPIs = try findAllSymbolLinks_Full(initialPath: initialDocCArchivePath)
                newDocCArchiveAPIs = try findAllSymbolLinks_Full(initialPath: newerDocCArchivePath)
            } else {
                print("Showing ONLY modules, classes, protocols, and structs.")
            }
            
            let initialSet = Set(initialDocCArchiveAPIs.map { $0 })
            let newSet = Set(newDocCArchiveAPIs.map { $0 })
            
            // Compute additions and removals to both sets
            let additionsToNewSet = newSet.subtracting(initialSet)
            let removedFromOldSet = initialSet.subtracting(newSet)
            
            // The framework name is the path component after "/documentation/".
            var frameworkName: String = "No_Framework_Name"
            var potentialFrameworkName = try findFrameworkName(initialPath: initialDocCArchivePath)
            if potentialFrameworkName == nil {
                potentialFrameworkName = try findFrameworkName(initialPath: newerDocCArchivePath)
            }
            
            if potentialFrameworkName != nil {
                frameworkName = potentialFrameworkName ?? "No_Framework_Name"
            }
            
            let additionLinks = groupSymbols(symbolLinks: additionsToNewSet, frameworkName: frameworkName)
            let removalLinks = groupSymbols(symbolLinks: removedFromOldSet, frameworkName: frameworkName)
            
            // Create markdown file with changes in the newer DocC Archive that do not exist in the initial DocC Archive.
            for fileNameAndContent in Docc.GenerateChangelog.changeLogTemplateFileContent(frameworkName: frameworkName, initialDocCArchiveVersion: "RainbowF RC", newerDocCArchiveVersion: "Geode Beta 1", additionLinks: additionLinks, removalLinks: removalLinks) {
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
        
        func findClassName(symbolPath: URL) -> String {
            return symbolPath.lastPathComponent
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
        
        func addClassNames(allSymbolsString: String) -> String {
            // Split string into string array on a double newline
            return longestCommonPrefix(of: allSymbolsString)
        }
        
        func longestCommonPrefix(of string: String) -> String {
            
            let words = string.split(separator: " ")
            guard let first = words.first else {
                return ""
            }

            var (minWord, maxWord) = (first, first)
            for word in words.dropFirst() {
                if word < minWord {
                    print(word)
                    print(maxWord)
                    minWord = word
                } else if word > maxWord {
                    print(word)
                    print(maxWord)
                    maxWord = word
                }
            }

            return minWord.commonPrefix(with: maxWord)
        }
        
    }
}
