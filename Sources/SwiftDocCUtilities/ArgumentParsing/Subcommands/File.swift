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
        
        // MARK: - Configuration
        
        static var configuration = CommandConfiguration(
            commandName: "diff-docc-archive",
            abstract: "Produce a list of symbols added in the newer DocC Archive that did not exist in the initial DocC Archive.",
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
        
        // MARK: - Execution
        
        public mutating func run() throws {
            
            // Process arguments to start from the /data/ subdirectory.
            // This is where all the relevant renderJSON are contained.
            let initialProcessedArchivePath = initialDocCArchivePath.appendingPathComponent("data")
            let newerProcessedArchivePath = newerDocCArchivePath.appendingPathComponent("data")
            
            let initialDocCArchiveAPIs: [URL] = try findAllSymbolLinks(initialPath: initialProcessedArchivePath)
            let newDocCArchiveAPIs: [URL] = try findAllSymbolLinks(initialPath: newerProcessedArchivePath)
            
            print("\ninitialDocCArchiveAPIs: ")
            print(initialDocCArchiveAPIs)
            
            print("\nnewDocCArchiveAPIs: ")
            print(newDocCArchiveAPIs)
            
            let initialSet = Set(initialDocCArchiveAPIs.map { $0 })
            let newSet = Set(newDocCArchiveAPIs.map { $0 })
            let difference = newSet.subtracting(initialSet)
            print("\nDifference:\n\(difference)")
        }
        
        // Given a URL, return each of the symbols by their unique identifying links
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
                    returnSymbolLinks.append(symbolLink)
                }
            }
            
            return returnSymbolLinks
        }
        
        func findAllSymbols(initialPath: URL) throws -> [String] {
            guard let enumerator = FileManager.default.enumerator(
                at: initialPath,
                includingPropertiesForKeys: [],
                options: .skipsHiddenFiles,
                errorHandler: nil
            ) else {
                return []
            }
            
            var returnSymbols: [String] = []
            for case let filePath as URL in enumerator {
                if filePath.lastPathComponent.hasSuffix(".json") {
                    returnSymbols.append(filePath.lastPathComponent)
                }
            }
            
            return returnSymbols
        }
        
        // Given a file path to a renderJSON, return that symbol's url from its identifier.
        func findSymbolLink(symbolPath: URL) throws -> URL {
            let renderJSONData = try Data(contentsOf: symbolPath)
            let decoder = RenderJSONDecoder.makeDecoder()
            let renderNode = try decoder.decode(RenderNode.self, from: renderJSONData)
            
            return renderNode.identifier.url
        }
                    
    }
}
