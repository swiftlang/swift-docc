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
    
    /// A template designed for authoring article-only reference documentation, consisting of a catalog that contains only one markdown file.
    case articleOnly
    
    /// A template designed for authoring tutorials, consisting of a catalog that contains a table of contents and a chapter.
    case tutorial
    
    /// Generates the catalog template using the provided template kind.
    static func generate(
        _ catalogTemplateKind: CatalogTemplateKind,
        catalogTitle: String
    ) throws -> CatalogTemplate {
        switch catalogTemplateKind {
        case .articleOnly:
            return try CatalogTemplate(
                title: catalogTitle,
                files: minimalTemplateArticles(catalogTitle),
                additionalDirectories: ["Resources/"]
            )
        case .tutorial:
            return try CatalogTemplate(
                title: catalogTitle,
                files: tutorialTemplateFiles,
                additionalDirectories: ["Resources/", "Chapter01/Resources/"]
            )
        }
    }
}

/// Content of the different templates
extension CatalogTemplateKind {
    
    /// Content of the 'articleOnly' template
    static private let minimalTemplateArticles = { (_ title: String) -> [String: CatalogFileTemplate] in
        return (
            [
                "\(title).md": CatalogFileTemplate(
                    title: title,
                    content: """
                    
                    Add a single sentence or sentence fragment, which DocC uses as the page’s abstract or summary.
                    
                    ## Overview

                    Add one or more paragraphs that introduce your content overview.
                    """,
                    isTechnologyRoot: true
                )
            ]
        )
    }
    
    /// Content of the 'tutorial' template
    static let tutorialTemplateFiles: [String: CatalogFileTemplate] = [
        "table-of-contents.tutorial": CatalogFileTemplate(
            content: """
            @Tutorials(name: "Tutorial Name") {
                @Intro(title: "Tutorial Introduction") {
                    Add one or more paragraphs that introduce your tutorial.
                }
                @Chapter(name: "Chapter Name") {
                    @Image(source: "add-your-chapter-image-filename-here.jpg", alt: "Add an accessible description for your image here.")
                    @TutorialReference(tutorial: "doc:page-01")
                }
            }
            """
        ),
        "Chapter01/page-01.tutorial": CatalogFileTemplate(
            content: """
            @Tutorial() {
                @Intro(title: "Tutorial Page Title") {
                    Add one paragraph that introduce your tutorial.
                }
                @Section(title: "Section Name") {
                    @ContentAndMedia {
                        Add text that introduces the tasks that the reader needs to follow.
                        @Image(source: "add-your-section-image-filename-here.jpg", alt: "Add an accessible description for your image here.")
                    }
                    @Steps {
                        @Step {
                            This is a step with code.
                            @Code(name: "", file: "")
                        }
                        @Step {
                            This is a step with an image.
                            @Image(source: "", alt: "")
                        }
                    }
                }
            }
            """
        )
    ]
}
