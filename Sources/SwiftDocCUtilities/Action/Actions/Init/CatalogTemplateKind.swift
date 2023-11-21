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
    /// This template contains an expanded structure and content with guidelines on how to author content using DocC.
    case expanded
    
    /// A template designed for authoring conceptual documentation consisting of a catalog containing only one markdown file.
    /// This template contains minimal content to let the user start writing content right away.
    case minimal
    
    /// A template with the necessary structure and directives to get started on authoring tutorials.
    case tutorial
    
    /// Generates the catalog template using the provided template kind.
    static func generate(
        _ catalogTemplateKind: CatalogTemplateKind,
        catalogTitle: String
    ) throws -> CatalogTemplate {
        switch catalogTemplateKind {
        case .expanded:
            return try CatalogTemplate(
                title: catalogTitle,
                files: expandedTemplateArticles(catalogTitle),
                additionalDirectories: ["Resources/", "Essentials/Resources/"]
            )
        case .minimal:
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
    
    /// Content of the 'expanded' template
    static private let expandedTemplateArticles = { (_ title: String) -> [String: CatalogFileTemplate] in
        return (
            [
                "\(title).md": CatalogFileTemplate(
                    title: title,
                    content: """
                    
                    Add a single sentence or sentence fragment, which DocC uses as the page’s abstract or summary.
                    
                    ## Overview

                    Add one or more paragraphs that introduce your content overview.

                    ## Usage Instructions

                    To preview this documentation, use your terminal to navigate to the root of this DocC catalog and run:
                    ```
                    docc preview
                    ```

                    To generate a DocC archive navigate to the root of this DocC catalog and run:
                    ```
                    docc convert -o ./\(title).doccarchive
                    ```

                    ## Learn More

                    Learn more about how to create engaging and beautiful documentation, refer to the official DocC documentation on the [DocC Swift.org website](https://www.swift.org/documentation/docc/).

                    ## Topics

                    ### Essentials

                    - <doc:getting-started>
                    - <doc:more-information>
                    """,
                    isTechnologyRoot: true
                ),
                "Essentials/getting-started.md": CatalogFileTemplate(
                    content: """
                    # Getting Started
                    
                    Provide a description of the concept at a high level.

                    ## Overview

                    Write an article that engages the reader, and communicates problems and solutions in a clear and concise manner.

                    ## Format your Documentation Content

                    Use Markdown to provide structure and style to your documentation. DocC features a tailored variant of Markdown known as _documentation markup_, which expands upon Markdown's syntax by introducing features such enhanced image support, term lists, and asides.

                    Learn more about how to format your documentation, please refer to [Formatting Your Documentation Content](https://www.swift.org/documentation/docc/formatting-your-documentation-content) in the DocC documentation.
                    
                    ## Integrate your Documentation with your Source Code
                    
                    Integrate the conceptual content of this catalog with your Swift project and connect them using powerful organizational and linking capabilities. This allows you to create comprehensive and engaging documentation for developers.
                    
                    Learn how to integrate your project with your documentation catalog by referring to  [Documenting a Swift Framework or Package](https://www.swift.org/documentation/docc/documenting-a-swift-framework-or-package).
                    """
                ),
                "Essentials/more-information.md": CatalogFileTemplate(
                    content: """
                    # More Information
                    
                    Enhance your documentation catalog with directives.

                    ## Overview

                    Customize how your documentation looks and behaves using DocC directives, from adjusting behaviors when rendering a page to arranging custom content in tab-based and grid-based row and column layouts.

                    Learn how to do this by referring to [API Documentation](https://www.swift.org/documentation/docc/api-reference-syntax#creating-custom-page-layouts).
                    """
                )
            ]
        )
    }
    
    /// Content of the 'minimal' template
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
    
    static let tutorialTemplateFiles: [String: CatalogFileTemplate] = [
        "table-of-contents.tutorial": CatalogFileTemplate(
            content: """
            @Tutorials(name: "Start with") {
                @Intro(title: "Creating a Tutorial") {
                    Provide a step-by-step learning experience in tutorial format
                }
                @Volume(name: "Getting Started") {
                    Organize related chapters into volume groupings.
                    @Chapter(name: "Crafting the Tutorial") {
                        @Image(source: "your-image-name.png", alt: "Add an accessible description for your image here.")
                        Establish your tutorial's boundaries and get your code project ready.
                        @TutorialReference(tutorial: "doc:page-01")
                        @TutorialReference(tutorial: "doc:page-02")
                    }
                }
                @Resources {
                   Explore more resources for learning how to build tutorials.
                   @Documentation(destination: "https://forums.swift.org/c/development/swift-docc/80") {
                       Browse and search tutorial-related documentation.

                       - [Interactive Tutorials API](https://www.swift.org/documentation/docc/tutorial-syntax)
                       - [DocC](https://www.swift.org/documentation/docc/)
                   }
               }
            }
            """
        ),
        "Chapter01/page-01.tutorial": CatalogFileTemplate(
            content: """
            @Article(time: 10) {
                @Intro(title: "Scope Your Tutorial") {
                    Establish your tutorial’s boundaries and get your code project ready.
                }
                @Stack {
                    @ContentAndMedia {
                        # Deciding what your tutorial covers
                        @Image(source: "add-your-section-image-filename-here.jpg", alt: "Add an accessible description for your image here.")
                    }
                }
                @Stack {
                    @ContentAndMedia {
                        **Define Your Audience.**
                        @Image(source: "add-your-section-image-filename-here.jpg", alt: "Add an accessible description for your image here.")
                        
                    }
                    @ContentAndMedia {
                        **Define Teaching Goals.**
                        @Image(source: "add-your-section-image-filename-here.jpg", alt: "Add an accessible description for your image here.")
                    }
                    @ContentAndMedia {
                        **Define the Scope.**
                        @Image(source: "add-your-section-image-filename-here.jpg", alt: "Add an accessible description for your image here.")
                    }
                }
            }
            """
        ),
        "Chapter01/page-02.tutorial": CatalogFileTemplate(
            content: """
            @Tutorial(time: 10) {
                @Intro(title: "Add Content to the Tutorial") {
                    Start by carefully structuring your narrative to ensure clarity and engagement.
                }
                @Section(title: "Create the Tutorial Structure") {
                    @ContentAndMedia {
                        A table of contents page sets context and introduces the reader to your tutorial.
                        @Image(source: "add-your-section-image-filename-here.jpg", alt: "Add an accessible description for your image here.")
                    }
                    @Steps {
                        @Step {
                            A table of contents page sets context and introduces the reader to your tutorial.
                            
                            Incorporate the initial chapter of your tutorial, refering to the pages that comprise it.
                            @Code(name: "table-of-contents.tutorial", file: "page-02-1.swift")
                        }
                        @Step {
                            Add Step-By-Step Instructions using the `@Steps` directives.
                            @Code(name: "page01.tutorial", file: "page-02-2.swift")
                        }
                        @Step {
                            Optionally use an Assessments directive to test the reader’s knowledge.
                            @Code(name: "page01.tutorial", file: "page-02-3.swift")
                        }
                    }
                }
                @Assessments {
                    @MultipleChoice {
                        What directive do you use to define an individual task the reader performs within a set of steps on a tutorial page?
                        @Choice(isCorrect: false) {
                            `@Section`
                            @Justification(reaction: "Try again!") {
                                Remember, `@Section` displays a grouping of text, images, and tasks on a tutorial page.
                            }
                        }
                        @Choice(isCorrect: true) {
                            `@Step`
                            @Justification(reaction: "That's right!") {
                                The `@Step` adds an individual step to the tutorial.
                            }
                        }
                    }
                }
            }
            """
        ),
        "Chapter01/Resources/page-02-1.swift": CatalogFileTemplate(
            content: """
            @Tutorials(name: "Add the name of your tutorial here. This usually matches your framework name.") {
                @Intro(title: "Add a title for your introduction here.") {
                    Describe what your reader will learn from this tutorial.
                    @Image(source: "toc-introduction-image-filename.png", alt: "Add an accessible description for your image here.")
                }
                @Chapter(name: "Add a chapter title here.") {
                    Add chapter text here.
                    @Image(source: "chapter-image-filename-here.png", alt: "Add an accessible description for your image here.")
                    @TutorialReference(tutorial: "doc:tutorial-page-file-name-here")
                }
            }
            """
        ),
        "Chapter01/Resources/page-02-2.swift": CatalogFileTemplate(
            content: """
            @Tutorial(time: number) {
                @Intro(title: "Add the name of your title here.") {
                    Add engaging introduction text here.
                    
                    @Image(source: "intro-image-filename-here.jpg", alt: "Add an accessible description for your image here.")
                }
                @Section(title: "Add the name of your section here.") {
                    @ContentAndMedia {
                        Describe what your reader will do when they follow the steps in this section.
                        @Image(source: "section-image-filename-here.jpg", alt: "Add an accessible description for your image here.")
                    }
                    @Steps {
                        @Step {
                            Add engaging step 1 text here.
                            @Image(source: "step-1-image-filename-here.jpg", alt: "Add an accessible description for your step here.")
                        }
                        @Step {
                            Add code for step 1 here.
                            @Code(name: "code-display-name-here", file: "step-1-code-image-filename-here.jpg")
                        }
                    }
                }
            }
            """
        ),
        "Chapter01/Resources/page-02-3.swift": CatalogFileTemplate(
            content: """
            @Tutorial(time: number) {
                @Intro(title: "Add the name of your title here.") {
                    Add engaging introduction text here.
                    
                    @Image(source: "intro-image-filename-here.jpg", alt: "Add an accessible description for your image here.")
                }
                @Section(title: "Add the name of your section here.") {
                    @ContentAndMedia {
                        Describe what your reader will do when they follow the steps in this section.
                        @Image(source: "section-image-filename-here.jpg", alt: "Add an accessible description for your image here.")
                    }
                    @Steps {
                        @Step {
                            Add engaging step 1 text here.
                            @Image(source: "step-1-image-filename-here.jpg", alt: "Add an accessible description for your step here.")
                        }
                        @Step {
                            Add code for step 1 here.
                            @Code(name: "code-display-name-here", file: "step-1-code-image-filename-here.jpg")
                        }
                    }
                }
                @Assessments {
                    @MultipleChoice {
                        Add a question to test the reader's knowledge here.
                        @Choice(isCorrect: false) {
                            Add an incorrect answer here.
                            @Justification(reaction: "Try again!") {
                                Add a hint that helps direct the reader to the right answer.
                            }
                        }
                        @Choice(isCorrect: true) {
                            Add the correct answer here.
                            @Justification(reaction: "That's right!") {
                                Add some text that reinforces the right answer.
                            }
                        }
                    }
                }
            }
            """
        )
    ]
}
