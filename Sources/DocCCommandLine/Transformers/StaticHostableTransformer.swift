/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SwiftDocC

enum HTMLTemplate: String {
    case templateFileName = "index-template.html"
    case indexFileName = "index.html"
    case tag = "{{BASE_PATH}}"
}

enum StaticHostableTransformerError: DescribedError {
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
    /// The data directory to create static hostable files for.
    private let dataDirectory: URL
    /// The directory to write the static hostable files in.
    private let outputURL: URL
    /// The index.html contents to write for each static hostable file.
    private let indexHTMLData: Data
    /// The file manager used to create directories and files.
    private let fileManager: any FileManagerProtocol
    
    /// Initialize with a dataProvider to the source doccarchive.
    /// - Parameters:
    ///   - dataDirectory: The data directory to create static hostable files for.
    ///   - fileManager: The file manager used to create directories and files.
    ///   - outputURL: The output directory where the transformer will write the static hostable files in.
    ///   - indexHTMLData: Data representing the index.html content that the static
    init(dataDirectory: URL, fileManager: any FileManagerProtocol, outputURL: URL, indexHTMLData: Data) {
        self.dataDirectory = dataDirectory.standardizedFileURL
        self.fileManager = fileManager
        self.outputURL = outputURL.standardizedFileURL
        self.indexHTMLData = indexHTMLData
    }
    
    /// Creates a static hostable version of the documentation in the data folder of an archive pointed to by the `dataProvider`
    func transform() throws {
        for file in fileManager.recursiveFiles(startingPoint: dataDirectory) where file.pathExtension.lowercased() == "json" {
            // For each "/relative/something.json" file, create a "/relative/something/index.html" file.
            
            guard let relativeFileURL = file.relative(to: dataDirectory) else {
                // Our `URL.relative(to:)` extension only return `nil` if the URLComponents aren't valid.
                continue
            }
            
            let outputDirectoryURL = outputURL.appendingPathComponent(
                relativeFileURL.deletingPathExtension().path, // A directory with the same base name as the file
                isDirectory: true
            )

            // Ensure that the intermediate directories exist
            if !fileManager.fileExists(atPath: outputDirectoryURL.path) {
                try fileManager.createDirectory(at: outputDirectoryURL, withIntermediateDirectories: true, attributes: [:])
            }
            
            try fileManager.createFile(at: outputDirectoryURL.appendingPathComponent("index.html"), contents: indexHTMLData)
        }
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
        fileManager: any FileManagerProtocol
    ) throws -> Data {
        let customHostingBasePathProvided = !(hostingBasePath?.isEmpty ?? true)
        
        let indexHTMLFileName = if customHostingBasePathProvided {
            HTMLTemplate.templateFileName.rawValue
        } else {
            HTMLTemplate.indexFileName.rawValue
        }
        
        let indexHTMLFile = htmlTemplateDirectory.appendingPathComponent(indexHTMLFileName, isDirectory: false)
        
        guard let indexHTMLData = try? fileManager.contents(of: indexHTMLFile),
              var indexHTML = String(data: indexHTMLData, encoding: .utf8)
        else {
            throw TemplateOption.missingRequiredFile(fileName: indexHTMLFileName, inHTMLTemplateAt: htmlTemplateDirectory)
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
