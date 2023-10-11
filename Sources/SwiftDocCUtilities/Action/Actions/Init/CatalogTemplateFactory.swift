/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2023 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SwiftDocC

struct CatalogTemplateFactory {
    
    static func createDocumentationCatalog(
        _ catalogTemplate: CatalogTemplateKind,
        catalogTitle: String
    ) throws -> CatalogTemplate {
        return try catalogTemplate.generate(catalogTitle: catalogTitle)
    }
    
    @discardableResult
    static func constructCatalog(
        _ catalogTemplate: CatalogTemplate,
        outputURL: URL
    ) throws -> URL {
        let fileManager: FileManager = .default
        try catalogTemplate.articles.forEach { (articleURL, articleContent) in
            // Creates the directories for storing the files by
            // appending the article path to the output URL
            // and removing the name of the file.
            try fileManager.createDirectory(
                at: outputURL.appendingPathComponent(articleURL.path).deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            // Creates the template files on the given URL path.
            try fileManager.createFile(
                at: outputURL.appendingPathComponent(articleURL.path),
                contents: Data(articleContent.formattedArticleContent.utf8)
            )
        }
        // Writes additional directiories defined in the catalog.
        // Ex. `Resources`
        try catalogTemplate.additionalDirectories.forEach {
            try fileManager.createDirectory(
                at: outputURL.appendingPathComponent($0.path),
                withIntermediateDirectories: true
            )
        }
        return outputURL
    }
    
}
