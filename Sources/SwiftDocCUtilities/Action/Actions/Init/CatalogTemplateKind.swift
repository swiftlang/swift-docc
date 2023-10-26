/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2023 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SwiftDocC

/// Specifies the different template kinds available for
/// initializing the documentation catalog.
public enum CatalogTemplateKind: String {
    /// The default and most-basic form of catalog template.
    case articleOnly
    
    enum Error: DescribedError {
        case missingInformation
        var errorDescription: String {
            switch self {
                case .missingInformation: return "The required template is missing information."
            }
        }
    }
    
    /// Generates the requested catalog template.
    func generate(catalogTitle: String?) throws -> CatalogTemplate {
        switch self {
        case .articleOnly:
            guard let catalogTitle = catalogTitle else {
                throw Error.missingInformation
            }
            return try CatalogTemplate(
                title: catalogTitle,
                articles: [
                    "\(catalogTitle).md": ArticleTemplate(
                        title: catalogTitle,
                        content: """
                        
                        Add a single sentence or sentence fragment, which DocC uses as the page’s abstract or summary.
                        
                        Add one or more paragraphs that introduce your content overview.
                        
                        ## Usage Instructions
                        
                        To preview this documentation, use your terminal to navigate to the root of this DocC catalog and run:
                        ```
                        docc preview
                        ```
                        
                        To generate a doccarchive navigate to the root of this DocC catalog and run:
                        ```
                        docc convert \(catalogTitle).docc -o ./\(catalogTitle).doccarchive
                        ```
                        
                        ## Topics
                        
                        ### Essentials
                        
                        - <doc:getting-started>
                        - <doc:more-information>
                        """,
                        isTechnologyRoot: true
                    ),
                    "Essentials/getting-started.md": ArticleTemplate(
                        title: "Getting started",
                        content: """
                        
                        Provide a description of the concept at a high level.
                        
                        Write an article that engage the reader and communicate problems and solutions in a clear and concise manner.
                        """
                    ),
                    "Essentials/more-information.md": ArticleTemplate(
                        title: "More information",
                        content: """
                        
                        Show your readers more information on how to solve specific problems in an article.
                        
                        Make your documentation more useful by providing examples for the reader.
                        """
                    )
                ],
                additionalDirectories: ["Resources/", "Essentials/Resources/"]
            )
            
        }
    }
}
