/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2023 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SwiftDocC

protocol Catalog {
    var articles: [String:Article] { get }
    var title: String { get set }
}

struct CatalogTemplateFactory {
    
    enum Error: DescribedError {
        case missingCatalogTemplate
        var errorDescription: String {
            switch self {
                case .missingCatalogTemplate:
                return "Provided template name is not a valid catalog template."
            }
        }
    }
    
    let fileManager: FileManager = .default
    
    /// The different available templates
    enum initTemplateOptions: String {
        case initDefault = "init default template"
        
        public var description: String {
            return rawValue
        }
    }
    
    func createDocumentationCatalog(
        _ catalogTemplate: String,
        catalogTitle: String
    ) throws -> Catalog {
        switch catalogTemplate {
        case "init":
            InitTemplateCatalog(title: catalogTitle)
        default:
            throw Error.missingCatalogTemplate
        }
    }
    
    @discardableResult
    func constructCatalog(
        _ catalogTemplate: Catalog,
        outputPath: String
    ) throws -> URL {
        try catalogTemplate.articles.forEach {
            try fileManager.createDirectory(
                at: URL(fileURLWithPath: "/\(outputPath)/\($0.key)").deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            fileManager.createFile(
                atPath: "/\(outputPath)/\($0.key)",
                contents: Data($0.value.formattedArticleContent.utf8)
            )
        }
        return URL(fileURLWithPath: outputPath)
    }
    
}
