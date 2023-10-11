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
    case base
    
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
        case .base:
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
                        
                        ## Overview
                        
                        Add one or more paragraphs that introduce your content overview.
                        
                        ## Usage Instructions
                        
                        To preview this documentation, use your terminal to navigate to the root of this
                        DocC catalog and run:
                        ```
                        docc preview
                        ```
                        
                        To generate a doccarchive navigate to the root of this
                        DocC catalog and run:
                        ```
                        docc convert \(catalogTitle).docc -o \(catalogTitle).doccarchive
                        ```
                        
                        ## Topics
                        
                        ### Essentials
                        
                        - <doc:getting_started>
                        - <doc:more_information>
                        """,
                        isTechnologyRoot: true
                    ),
                    "Essentials/getting_started.md": ArticleTemplate(
                        title: "Getting Started",
                        content: """
                        
                        Summary
                        
                        Overview
                        """
                    ),
                    "Essentials/more_information.md": ArticleTemplate(
                        title: "More Information",
                        content: """
                        
                        Summary
                        
                        Overview
                        """
                    )
                ],
                additionalDirectories: ["Resources/", "Essentials/Resources/"]
            )
            
        }
    }
}
