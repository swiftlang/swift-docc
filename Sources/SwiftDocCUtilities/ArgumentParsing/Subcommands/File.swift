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
            
            let initialDocCArchiveAPIs: [String] = try findAllSymbols(initialPath: initialDocCArchivePath)
            let newDocCArchiveAPIs: [String] = try findAllSymbols(initialPath: newerDocCArchivePath)
            
            print("\ninitialDocCArchiveAPIs: ")
            print(initialDocCArchiveAPIs)
            
            print("\nnewDocCArchiveAPIs: ")
            print(newDocCArchiveAPIs)
            
            let initialSet = Set(initialDocCArchiveAPIs.map { $0.plainText })
            let newSet = Set(newDocCArchiveAPIs.map { $0.plainText })
            let difference = newSet.subtracting(initialSet)
            print("\nDifference:\n\(difference)")
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
                    
    }
}
