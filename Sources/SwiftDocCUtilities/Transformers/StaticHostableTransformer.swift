/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SwiftDocC

enum HTMLTemplate: String  {
    case templateFileName = "index-template.html"
    case indexFileName = "index.html"
    case tag = "{{BASE_PATH}}"
}

enum StaticHostableTransformerError: Error  {
    case dataProviderDoesNotReferenceValidInput
}

/// Navigates the contents of a FileSystemProvider pointing at the data folder of  a .doccarchive to emit a static hostable website.
class StaticHostableTransformer {
    
    /// The internal `FileSystemProvider` reference.
    /// This should be the data folder of an archive.
    private let dataProvider: FileSystemProvider
    
    /// Where the output will be written.
    private let outputURL: URL
    
    /// The index.html file to be used.
    private let indexHTMLData: Data

    private let fileManager: FileManagerProtocol
    
    /// Initialise with a dataProvider to the source doccarchive.
    /// - Parameters:
    ///   - dataProvider:  Should point to the data folder in a docc archive.
    ///   - fileManager: The FileManager to use for file processes.
    ///   - outputURL: The folder where the output will be placed
    ///   - indexHTML: The HTML to be used in the generated index.html file.
    init(dataProvider: FileSystemProvider, fileManager: FileManagerProtocol, outputURL: URL, htmlTemplate: URL, staticHostingBasePath: String?) throws {
        self.dataProvider = dataProvider
        self.fileManager = fileManager
        self.outputURL = outputURL

        let indexFileName = staticHostingBasePath != nil ? HTMLTemplate.templateFileName.rawValue : HTMLTemplate.indexFileName.rawValue
        let indexFileURL = htmlTemplate.appendingPathComponent(indexFileName)
        var indexHTML = try String(contentsOfFile: indexFileURL.path)


        if let staticHostingBasePath = staticHostingBasePath {

            var replacementString = staticHostingBasePath

            // We need to ensure that the base path has a leading /
            if !replacementString.hasPrefix("/") {
                replacementString = "/" + replacementString
            }

            // Trailing /'s are not required so will be removed if provided.
            if replacementString.hasSuffix("/") {
                replacementString = String(replacementString.dropLast(1))
            }

            indexHTML = indexHTML.replacingOccurrences(of: HTMLTemplate.tag.rawValue, with: replacementString)
        }
        self.indexHTMLData = Data(indexHTML.utf8)
    }
    
    /// Creates a static hostable version of the documention in the data folder of an archive pointed to by the `dataProvider`
    /// - Parameters:
    ///   - outputURL: The folder where the output will be placed
    ///   - basePath: The path to be prefix to all href and src parameters in generated html
    /// - Returns: An array if problems encounter during the archive.
    func transform() throws {

        let node = dataProvider.fileSystem
        
        // We should be starting at the data folder of a .doccarchive.
        switch node {
        case .directory(let dir):
            try processDirectoryContents(directoryRoot: outputURL, relativeSubPath: "", directoryContents: dir.children)
        case .file(_):
            throw StaticHostableTransformerError.dataProviderDoesNotReferenceValidInput
        }
    }


    /// Create a directory at the provided URL
    ///
    private func createDirectory(url: URL) throws {
        if !fileManager.fileExists(atPath: url.path) {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true, attributes: [:])
        }
    }

    /// Processes the contents of a given directory
    /// - Parameters:
    ///   - root: The root output URL
    ///   - directory: The relative path (to the root) of the directory for which then content will processed.
    ///   - nodes: The directory contents
    /// - Returns: An array of problems that may have occured during processing
    private func processDirectoryContents(directoryRoot: URL, relativeSubPath: String, directoryContents: [FSNode]) throws {

        for node in directoryContents {
            switch node {
            case .directory(let dir):
                try processDirectory(directoryRoot: directoryRoot, currentDirectoryNode: dir, directorySubPath: relativeSubPath)
            case .file(let file):
                let outputURL = directoryRoot.appendingPathComponent(relativeSubPath)
                try processFile(file: file, outputURL: outputURL)
            }
        }

    }

    /// Processes the  given directory
    /// - Parameters:
    ///   - root: The root output URL
    ///   - dir: The FSNode that represents the directory
    ///   - currentDirectory: The relative path (to the root) of the directory that will contain this directory
    /// - Returns: An array of problems that may have occured during processing
    private func processDirectory(directoryRoot: URL, currentDirectoryNode: FSNode.Directory, directorySubPath: String) throws {

        // Create the path for the new directory
        var newDirectory = directorySubPath
        let newPathComponent = currentDirectoryNode.url.lastPathComponent
        if !newDirectory.isEmpty {
            newDirectory += "/"
        }
        newDirectory += newPathComponent


        // Create the HTML output directory

        let htmlOutputURL = directoryRoot.appendingPathComponent(newDirectory)
        try createDirectory(url: htmlOutputURL)

        // Process the direcorty contents
        try processDirectoryContents(directoryRoot: directoryRoot, relativeSubPath: newDirectory, directoryContents: currentDirectoryNode.children)

    }

    /// Processes the given File
    /// -   Parameters:
    ///     - file: The FSNode that represents the file
    ///     - outputURL: The directory the need to be placed in
    /// -  Returns: An array of problems that may have occured during processing
    private func processFile(file: FSNode.File, outputURL: URL) throws {

        // For JSON files we need to create an associated index.html in a sub-folder of the same name.
        guard file.url.pathExtension.lowercased() == "json" else { return }

        let dirURL = file.url.deletingPathExtension()
        let newDir = dirURL.lastPathComponent
        let newDirURL = outputURL.appendingPathComponent(newDir)

        if !fileManager.fileExists(atPath: newDirURL.path) {
            try fileManager.createDirectory(at: newDirURL, withIntermediateDirectories: true, attributes: [:])
        }

        let fileURL = newDirURL.appendingPathComponent("index.html")
        try self.indexHTMLData.write(to: fileURL)
    }
}
