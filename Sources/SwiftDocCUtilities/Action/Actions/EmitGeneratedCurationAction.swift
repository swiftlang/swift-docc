/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2023 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SwiftDocC

/// An action that emits documentation extension files that reflect the auto-generated curation.
struct EmitGeneratedCurationAction: Action {
    let catalogURL: URL?
    let additionalSymbolGraphDirectory: URL?
    let outputURL: URL
    let depthLimit: Int?
    let startingPointSymbolLink: String?
    
    let fileManager: FileManagerProtocol
    
    init(
        documentationCatalog: URL?,
        additionalSymbolGraphDirectory: URL?,
        outputURL: URL?,
        depthLimit: Int?,
        startingPointSymbolLink: String?,
        fileManager: FileManagerProtocol = FileManager.default
    ) throws {
        self.catalogURL = documentationCatalog
        if let outputURL = outputURL ?? documentationCatalog {
            self.outputURL = outputURL
        } else {
            self.outputURL = URL(fileURLWithPath: fileManager.currentDirectoryPath).appendingPathComponent("Generated.docc")
        }
        self.depthLimit = depthLimit
        self.startingPointSymbolLink = startingPointSymbolLink
        self.additionalSymbolGraphDirectory = additionalSymbolGraphDirectory
        self.fileManager = fileManager
    }
    
    mutating func perform(logHandle: LogHandle) throws -> ActionResult {
        let workspace = DocumentationWorkspace()
        let context = try DocumentationContext(dataProvider: workspace)

        let dataProvider: DocumentationWorkspaceDataProvider
        if let catalogURL = catalogURL {
            dataProvider = try LocalFileSystemDataProvider(rootURL: catalogURL)
        } else {
            dataProvider = GeneratedDataProvider(symbolGraphDataLoader: { [fileManager] url in
                fileManager.contents(atPath: url.path)
            })
        }
        let bundleDiscoveryOptions = BundleDiscoveryOptions(
            infoPlistFallbacks: [:],
            additionalSymbolGraphFiles: symbolGraphFiles(in: additionalSymbolGraphDirectory)
        )
        try workspace.registerProvider(dataProvider, options: bundleDiscoveryOptions)

        let writer = GeneratedCurationWriter(context: context, catalogURL: catalogURL, outputURL: outputURL)
        let curation = try writer.generateDefaultCurationContents(fromSymbol: startingPointSymbolLink, depthLimit: depthLimit)
        for (url, updatedContent) in curation {
            guard let data = updatedContent.data(using: .utf8) else { continue }
            try? fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
            try? fileManager.createFile(at: url, contents: data, options: .atomic)
        }
        
        return ActionResult(didEncounterError: false, outputs: [outputURL])
    }
}

private func symbolGraphFiles(in directory: URL?) -> [URL] {
    guard let directory = directory else { return [] }
    
    let subpaths = FileManager.default.subpaths(atPath: directory.path) ?? []
    return subpaths.map { directory.appendingPathComponent($0) }
        .filter { DocumentationBundleFileTypes.isSymbolGraphFile($0) }
}
