/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SwiftDocC

/// An object that writes render nodes, as JSON files, into a target folder.
///
/// The render node writer writes the JSON files into a hierarchy of folders and subfolders based on the relative URL for each node.
class JSONEncodingRenderNodeWriter {
    /// Errors that may occur while writing render node JSON files.
    enum Error: DescribedError {
        /// A file already exist at this path.
        case fileExists(String)
        /// The absolute path to the file is too long.
        public var errorDescription: String {
            switch self {
            case .fileExists(let path): return "File already exists at: '\(path)'"
            }
        }
    }
    
    private let renderNodeURLGenerator: NodeURLGenerator
    private let targetFolder: URL
    private let transformForStaticHostingIndexHTML: URL?
    private let fileManager: FileManagerProtocol
    private let renderReferenceCache = RenderReferenceCache([:])
    
    /// Creates a writer object that write render node JSON into a given folder.
    ///
    /// - Parameters:
    ///   - targetFolder: The folder to which the writer object writes the files.
    ///   - fileManager: The file manager with which the writer object writes data to files.
    init(targetFolder: URL, fileManager: FileManagerProtocol, transformForStaticHostingIndexHTML: URL?) {
        self.renderNodeURLGenerator = NodeURLGenerator(
            baseURL: targetFolder.appendingPathComponent("data", isDirectory: true)
        )
        self.targetFolder = targetFolder
        self.transformForStaticHostingIndexHTML = transformForStaticHostingIndexHTML
        self.fileManager = fileManager
    }
    
    // The already created directories on disk
    let directoryIndex = Synchronized(Set<URL>())
    
    /// Writes a render node to a JSON file at a location based on the node's relative URL.
    ///
    /// If the target path to the JSON file includes intermediate folders that don't exist, the writer object will ask the file manager, with which it was created, to
    /// create those intermediate folders before writing the JSON file.
    ///
    /// - Parameter renderNode: The node which the writer object writes to a JSON file.
    /// - Throws: A ``Error/fileExists`` error if a file already exists at the location for this node's JSON file.
    func write(_ renderNode: RenderNode) throws {
        let fileSafePath = NodeURLGenerator.fileSafeReferencePath(
            renderNode.identifier,
            lowercased: true
        )
        
        // The path on disk to write the render node JSON file at.
        let renderNodeTargetFileURL = renderNodeURLGenerator
            .urlForReference(
                renderNode.identifier,
                fileSafePath: fileSafePath
            )
            .appendingPathExtension("json")
        
        let renderNodeTargetFolderURL = renderNodeTargetFileURL.deletingLastPathComponent()
        
        // On Linux sometimes it takes a moment for the directory to be created and that leads to
        // errors when trying to write files concurrently in the same target location.
        // We keep an index in `directoryIndex` and create new sub-directories as needed.
        // When the symbol's directory already exists no code is executed during the lock below
        // besides the set lookup.
        try directoryIndex.sync { directoryIndex in
            let (insertedRenderNodeTargetFolderURL, _) = directoryIndex.insert(renderNodeTargetFolderURL)
            if insertedRenderNodeTargetFolderURL {
                try fileManager.createDirectory(
                    at: renderNodeTargetFolderURL,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
            }
        }
        
        let encoder = RenderJSONEncoder.makeEncoder()
        
        let data = try renderNode.encodeToJSON(with: encoder, renderReferenceCache: renderReferenceCache)
        try fileManager.createFile(at: renderNodeTargetFileURL, contents: data, options: nil)
        
        guard let indexHTML = transformForStaticHostingIndexHTML else {
            return
        }
        
        let htmlTargetFolderURL = targetFolder.appendingPathComponent(
            fileSafePath,
            isDirectory: true
        )
        let htmlTargetFileURL = htmlTargetFolderURL.appendingPathComponent(
            HTMLTemplate.indexFileName.rawValue,
            isDirectory: false
        )
        
        // Note that it doesn't make sense to use the above-described `directoryIndex` for this use
        // case since we expect every 'index.html' file to require the creation of
        // its own unique parent directory.
        try fileManager.createDirectory(
            at: htmlTargetFolderURL,
            withIntermediateDirectories: true,
            attributes: nil
        )
        
        do {
            try fileManager.copyItem(at: indexHTML, to: htmlTargetFileURL)
        } catch let error as NSError where error.code == NSFileWriteFileExistsError {
            // We already have an 'index.html' file at this path. This could be because
            // we're writing to an output directory that already contains built documentation
            // or because we we're given bad input such that multiple documentation pages
            // have the same path on the filesystem. Either way, we don't want this to error out
            // so just remove the destination item and try the copy operation again.
            try fileManager.removeItem(at: htmlTargetFileURL)
            try fileManager.copyItem(at: indexHTML, to: htmlTargetFileURL)
        }
    }
}
