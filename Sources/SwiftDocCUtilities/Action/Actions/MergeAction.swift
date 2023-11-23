/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
@_spi(FileManagerProtocol) import SwiftDocC

/// An action that merges a list of documentation archives into a combined archive.
struct MergeAction: Action {
    var archives: [URL]
    var landingPageCatalog: URL?
    var outputURL: URL
    var fileManager: FileManagerProtocol

    mutating func perform(logHandle: LogHandle) throws -> ActionResult {
        guard let firstArchive = archives.first else {
            // A validation warning should have already been raised in `Docc/Merge/InputAndOutputOptions/validate()`.
            return ActionResult(didEncounterError: true, outputs: [])
        }
        
        try? fileManager.removeItem(at: outputURL)
        try fileManager.copyItem(at: firstArchive, to: outputURL)
        
        // TODO: Merge the LMDB navigator index
        
        let jsonIndexURL = outputURL.appendingPathComponent("index/index.json")
        guard let jsonIndexData = fileManager.contents(atPath: jsonIndexURL.path) else {
            // TODO: Error
            return ActionResult(didEncounterError: true, outputs: [])
        }
        var combinedJSONIndex = try JSONDecoder().decode(RenderIndex.self, from: jsonIndexData)
        
        for archive in archives.dropFirst() {
            for directoryToCopy in ["data/documentation", "data/tutorials", "documentation", "tutorials", "images", "videos", "downloads"] {
                let fromDirectory = archive.appendingPathComponent(directoryToCopy, isDirectory: true)
                let toDirectory = outputURL.appendingPathComponent(directoryToCopy, isDirectory: true)
                
                for from in (try? fileManager.contentsOfDirectory(at: fromDirectory, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)) ?? [] {
                    try fileManager.copyItem(at: from, to: toDirectory.appendingPathComponent(from.lastPathComponent))
                }
            }
            guard let jsonIndexData = fileManager.contents(atPath: archive.appendingPathComponent("index/index.json").path) else {
                // TODO: Error
                return ActionResult(didEncounterError: true, outputs: [])
            }
            let renderIndex = try JSONDecoder().decode(RenderIndex.self, from: jsonIndexData)
            
            try combinedJSONIndex.merge(renderIndex)
        }
        
        try fileManager.createFile(at: jsonIndexURL, contents: RenderJSONEncoder.makeEncoder(emitVariantOverrides: false).encode(combinedJSONIndex))
        
        // TODO: Build landing page from input or synthesize default landing page
        
        // TODO: Inactivate external links outside the merged archives
        
        return ActionResult(didEncounterError: false, outputs: [outputURL])
    }
}
