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
    
    let files: [URL: String]
    let additionalDirectories: [URL]
    let title: String
    
    /// Creates a catalog from the given articles and additional directories validating
    /// that the paths conforms to valid URLs.
    init(
        title: String,
        files: [String: String],
        additionalDirectories: [String] = []
    ) throws {
        self.title = title
        // Converts every key of the articles dictionary into
        // a valid URL.
        self.files = Dictionary(uniqueKeysWithValues:
            files.map { (rawURL, article) in
                assert(URL(string: rawURL) != nil, "Invalid structure of the catalog file with URL \(rawURL).")
                return (URL(string: rawURL)!, article)
            }
        )
        // Creates the additional directories URLs.
        self.additionalDirectories = additionalDirectories.map {
            assert(URL(string:  $0) != nil, "Invalid structure of the catalog directory with URL \($0).")
            return URL(string:  $0)!
        }
    }
    
    /// Creates a Catalog Template using one of the provided template kinds.
    init(_ templateKind: CatalogTemplateKind, title: String) throws {
        switch templateKind {
        case .articleOnly:
            try self.init(
                title: title,
                files: CatalogTemplateKind.articleOnlyTemplateFiles(title),
                additionalDirectories: ["Resources"]
            )
        case .tutorial:
            try self.init(
                title: title,
                files: CatalogTemplateKind.tutorialTemplateFiles,
                additionalDirectories: ["Resources", "Chapter01/Resources"]
            )
        }
    }
}
