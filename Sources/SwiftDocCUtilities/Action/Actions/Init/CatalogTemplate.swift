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
  
    enum Error: DescribedError {
        case malformedCatalogTemplate
        var errorDescription: String {
            switch self {
                case .malformedCatalogTemplate: return "Unable to generate the catalog template."
            }
        }
    }
    
    let articles: [URL:ArticleTemplate]
    let additionalDirectories: [URL]
    let title: String
    
    /// Creates a catalog from the given articles and additional directories validating
    /// that the paths are conforms to valid URLs.
    init(title: String, articles: [String:ArticleTemplate], additionalDirectories: [String] = []) throws {
        self.title = title
        // Converts every key of the articles dictionary into
        // a valid URL.
        self.articles = Dictionary(uniqueKeysWithValues:
            try articles.map { (rawURL, article) in
                guard
                    let articleURL = URL(string: rawURL),
                    !articleURL.hasDirectoryPath
                else {
                    throw Error.malformedCatalogTemplate
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
                throw Error.malformedCatalogTemplate
            }
            return directoryURL
        }
    }
}
