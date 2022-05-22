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

enum StaticHostableTransformerError: DescribedError  {
    case dataProviderDoesNotReferenceValidInput(url: URL)
    
    var errorDescription: String {
        switch self {
        case .dataProviderDoesNotReferenceValidInput(let url):
            return """
            The content of `\(url.absoluteString)` is not in the format expected by the transformer.
            """
        }
    }
}

/// Navigates the contents of a FileSystemProvider pointing at the data folder of a `.doccarchive` to emit a static hostable website.
struct StaticHostableTransformer {
    
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
    ///   - dataProvider: Should point to the data folder in a docc archive.
    ///   - fileManager: The FileManager to use for file processes.
    ///   - outputURL: The folder where the output will be placed
    ///   - indexHTMLData: Data representing the index.html to be written in the transformed folder structure.
    init(dataProvider: FileSystemProvider, fileManager: FileManagerProtocol, outputURL: URL, indexHTMLData: Data) {
        self.dataProvider = dataProvider
        self.fileManager = fileManager
        self.outputURL = outputURL
        self.indexHTMLData = indexHTMLData
    }
    
    /// Creates a static hostable version of the documentation in the data folder of an archive pointed to by the `dataProvider`
    func transform() throws {

        let node = dataProvider.fileSystem
        
        // We should be starting at the data folder of a .doccarchive.
        switch node {
        case .directory(let dir):
            try transformDirectoryContents(directoryRoot: outputURL, relativeSubPath: "", directoryContents: dir.children)
        case .file(let file):
            throw StaticHostableTransformerError.dataProviderDoesNotReferenceValidInput(url: file.url)
        }
    }


    /// Create a directory at the provided URL
    ///
    private func createDirectory(url: URL) throws {
        if !fileManager.fileExists(atPath: url.path) {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true, attributes: [:])
        }
    }

    /// Transforms the contents of a given directory
    /// - Parameters:
    ///   - root: The root output URL
    ///   - directory: The relative path (to the root) of the directory for which then content will processed.
    ///   - nodes: The directory contents
    /// - Returns: An array of problems that may have occurred during processing
    private func transformDirectoryContents(directoryRoot: URL, relativeSubPath: String, directoryContents: [FSNode]) throws {

        for node in directoryContents {
            switch node {
            case .directory(let dir):
                try transformDirectory(directoryRoot: directoryRoot, currentDirectoryNode: dir, directorySubPath: relativeSubPath)
            case .file(let file):
                let outputURL = directoryRoot.appendingPathComponent(relativeSubPath)
                try transformFile(file: file, outputURL: outputURL)
            }
        }

    }

    /// Transform the  given directory
    /// - Parameters:
    ///   - root: The root output URL
    ///   - dir: The FSNode that represents the directory
    ///   - currentDirectory: The relative path (to the root) of the directory that will contain this directory
    private func transformDirectory(directoryRoot: URL, currentDirectoryNode: FSNode.Directory, directorySubPath: String) throws {

        // Create the path for the new directory
        var newDirectory = directorySubPath
        let newPathComponent = currentDirectoryNode.url.lastPathComponent
        
        // We need to ensure the new directory component, if not empty, ends with /
        if !newDirectory.isEmpty && !newDirectory.hasSuffix("/") {
            newDirectory += "/"
        }
        newDirectory += newPathComponent


        // Create the HTML output directory

        let htmlOutputURL = directoryRoot.appendingPathComponent(newDirectory)
        try createDirectory(url: htmlOutputURL)

        // Process the directory contents
        try transformDirectoryContents(directoryRoot: directoryRoot, relativeSubPath: newDirectory, directoryContents: currentDirectoryNode.children)

    }

    /// Transform the given File
    /// -   Parameters:
    ///     - file: The FSNode that represents the file
    ///     - outputURL: The directory the need to be placed in
    private func transformFile(file: FSNode.File, outputURL: URL) throws {

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

extension StaticHostableTransformer {
    
    /// Returns the data for the `index.html` file that should be used in the DocC archive
    /// produced by this conversion.
    ///
    /// Takes into account whether or not a custom hosting base path is provided and inserts
    /// that path into the returned data if necessary.
    ///
    /// - Parameters:
    ///   - htmlTemplateDirectory: The directory containing the `index.html` and `index-template.html`
    ///     file that should be used.
    ///   - hostingBasePath: The base path the produced DocC archive will be hosted at.
    ///   - fileManager: The file manager that should be used for all file operations.
    static func indexHTMLData(
        in htmlTemplateDirectory: URL,
        with hostingBasePath: String?,
        fileManager: FileManagerProtocol
    ) throws -> Data {
        let customHostingBasePathProvided = !(hostingBasePath?.isEmpty ?? true)
        
        let indexHTMLFileName: String
        if customHostingBasePathProvided {
            indexHTMLFileName = HTMLTemplate.templateFileName.rawValue
        } else {
            indexHTMLFileName = HTMLTemplate.indexFileName.rawValue
        }
        
        let indexHTMLUrl = htmlTemplateDirectory.appendingPathComponent(
            indexHTMLFileName,
            isDirectory: false
        )
        
        guard let indexHTMLData = fileManager.contents(atPath: indexHTMLUrl.path),
              var indexHTML = String(data: indexHTMLData, encoding: .utf8)
        else {
            throw TemplateOption.invalidHTMLTemplateError(
                path: indexHTMLUrl.path,
                expectedFile: indexHTMLFileName
            )
        }
        
        if customHostingBasePathProvided, var replacementString = hostingBasePath {
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
        
        return Data(indexHTML.utf8)
    }
}
