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
    /// A template designed for authoring conceptual documentation consisting of a catalog containing only articles.
    case articleOnly
    
    /// Generates the catalog template  using the provided template kind.
    static func generate(
        _ catalogTemplateKind: CatalogTemplateKind,
        catalogTitle: String
    ) throws -> CatalogTemplate {
        switch catalogTemplateKind {
        case .articleOnly:
            return try CatalogTemplate(
                title: catalogTitle,
                articles: articleOnlyTemplateArticles(catalogTitle),
                additionalDirectories: ["Resources/", "Essentials/Resources/"]
            )
        }
    }
}

/// Content of the different kinds of templates
extension CatalogTemplateKind {
    
    /// Content of the 'articleOnly' template
    static private let articleOnlyTemplateArticles = { (_ title: String) -> [String: CatalogFileTemplate] in
        return (
            [
                "\(title).md": CatalogFileTemplate(
                    title: title,
                    content: """
                    
                    Add a single sentence or sentence fragment, which DocC uses as the page’s abstract or summary.

                    Add one or more paragraphs that introduce your content overview.

                    ## Usage instructions

                    To preview this documentation, use your terminal to navigate to the root of this DocC catalog and run:
                    ```
                    docc preview
                    ```

                    To generate a DocC archive navigate to the root of this DocC catalog and run:
                    ```
                    docc convert -o ./\(title).doccarchive
                    ```

                    ## Learn more

                    To learn more about how to create engaging and beautiful conceptual documentation, refer to the official DocC documentation on the [DocC Swift.org website](https://www.swift.org/documentation/docc/).

                    ## Topics

                    ### Essentials

                    - <doc:getting-started>
                    - <doc:more-information>
                    """,
                    isTechnologyRoot: true
                ),
                "Essentials/getting-started.md": CatalogFileTemplate(
                    content: """
                    # Getting started
                    
                    Provide a description of the concept at a high level.

                    ## Overview

                    Write an article that engages the reader, and communicates problems and solutions in a clear and concise manner.


                    ## Format your documentation content

                    Use Markdown to provide structure and style to your documentation. DocC features a tailored variant of Markdown known as _documentation markup_, which expands upon Markdown's syntax by introducing features such enhanced image support, term lists, and asides. To maintain uniformity in both structure and style, it is recommended to employ DocC's documentation markup for all your written documentation.

                    To learn more about how to format your documentation please refer to [Formatting Your Documentation Content](https://www.swift.org/documentation/docc/formatting-your-documentation-content) in the DocC documentation.

                    ## Customizing the Appearance of Your Documentation Pages

                    By default, rendered documentation webpages produced by DocC come with a default visual styling. If you wish, you may make adjustments to this styling by adding an optional theme-settings.json file to the root of your documentation catalog with some configuration. This file is used to customize various things like colors and fonts. You can even make changes to the way that specific elements appear, like buttons, code listings, and asides. Additionally, some metadata for the website can be configured in this file, and it can also be used to opt in or opt out of certain default rendering behavior.

                    To learn more about this please visit [Customizing the Appearance of Your Documentation Pages](https://www.swift.org/documentation/docc/customizing-the-appearance-of-your-documentation-pages) in the DocC documentation.
                    """
                ),
                "Essentials/more-information.md": CatalogFileTemplate(
                    content: """
                    # More Information
                    
                    Show your readers more information on how to solve specific problems in an article.

                    ## Overview

                    Make your documentation more useful by providing examples for the reader.
                    """
                )
            ]
        )
    }
}
