/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2023 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SwiftDocC

struct CatalogTemplate {
  
    enum Error: DescribedError, Equatable {
        case malformedCatalogFileURL(_: String)
        case malformedCatalogDirectoryURL(_: String)
        var errorDescription: String {
            switch self {
            case .malformedCatalogFileURL(let URL): return "Invalid structure of the catalog file with URL \(URL)."
            case .malformedCatalogDirectoryURL(let URL): return "Invalid structure of the catalog directory with URL \(URL)."
            }
        }
    }
    
    let files: [URL: CatalogFileTemplate]
    let additionalDirectories: [URL]
    let title: String
    
    /// Creates a catalog from the given articles and additional directories validating
    /// that the paths conforms to valid URLs.
    init(
        title: String,
        files: [String: CatalogFileTemplate],
        additionalDirectories: [String] = []
    ) throws {
        self.title = title
        // Converts every key of the articles dictionary into
        // a valid URL.
        self.files = Dictionary(uniqueKeysWithValues:
            try files.map { (rawURL, article) in
                guard
                    let articleURL = URL(string: rawURL),
                    !articleURL.hasDirectoryPath
                else {
                    throw Error.malformedCatalogFileURL(rawURL)
                }
                return (articleURL, article)
            }
        )
        // Creates the additional directories URLs.
        self.additionalDirectories = try additionalDirectories.map {
            guard
                let directoryURL = URL(string: $0),
                directoryURL.hasDirectoryPath
            else {
                throw Error.malformedCatalogDirectoryURL($0)
            }
            return directoryURL
        }
    }
    
    /// Writes the catalog template to the specified output URL location on disk.
    @discardableResult
    func write(
        to outputURL: URL
    ) throws -> URL {
        let fileManager: FileManager = .default
        // We begin by creating the directory for each article in the template,
        // where it should be stored, and then proceed to create the file.
        try self.files.forEach { (articleURL, articleContent) in
            // Generate the directories for file storage
            // by adding the article path to the output URL and
            // excluding the file name.
            try fileManager.createDirectory(
                at: outputURL.appendingPathComponent(articleURL.path).deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            // Generate the article file at the specified URL path.
            try fileManager.createFile(
                at: outputURL.appendingPathComponent(articleURL.path),
                contents: Data(articleContent.content.utf8)
            )
        }
        // Writes additional directiories defined in the catalog.
        // Ex. `Resources`
        try self.additionalDirectories.forEach {
            try fileManager.createDirectory(
                at: outputURL.appendingPathComponent($0.path),
                withIntermediateDirectories: true
            )
        }
        return outputURL
    }
}
