/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024 Apple Inc. and the Swift project authors
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

}

/// Content of the different templates
extension CatalogTemplateKind {
    
    /// Content of the 'articleOnly' template
    static func articleOnlyTemplateFiles(_ title: String) -> [String: String] {
        [
            "\(title).md": """
                # \(title)
                
                <!--- Metadata configuration to make appear this documentation page as a top-level page -->
                
                @Metadata {
                  @TechnologyRoot
                }
                
                Add a single sentence or sentence fragment, which DocC uses as the page’s abstract or summary.
                
                ## Overview

                Add one or more paragraphs that introduce your content overview.
                """
        ]
    }
    
    /// Content of the 'tutorial' template
    static var tutorialTopLevelFilename: String { "table-of-contents.tutorial" }
    static func tutorialTemplateFiles(_ title: String) -> [String: String] {
        [
            tutorialTopLevelFilename: """
            @Tutorials(name: "\(title)") {
                @Intro(title: "Tutorial Introduction") {
                    Add one or more paragraphs that introduce your tutorial.
                }
                @Chapter(name: "Chapter Name") {
                    @Image(source: "add-your-chapter-image-filename-here.jpg", alt: "Add an accessible description for your image here.")
                    @TutorialReference(tutorial: "doc:page-01")
                }
            }
            """,
                "Chapter01/page-01.tutorial": """
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
        ]
    }
    
    /// Content of the 'changeLog' template
    static func changeLogTemplateFileContent(
        frameworkName: String,
        initialDocCArchiveVersion: String,
        newerDocCArchiveVersion: String,
        additionLinks: String,
        removalLinks: String
    ) -> [String : String] {
        [
            "\(frameworkName.localizedCapitalized)_Changelog.md": """
                # \(frameworkName.localizedCapitalized) Updates
                
                @Metadata {
                    @PageColor(yellow)
                }
                
                Learn about important changes to \(frameworkName.localizedCapitalized).
                
                ## Overview

                Browse notable changes in \(frameworkName.localizedCapitalized).
                
                ## Diff between \(initialDocCArchiveVersion) and \(newerDocCArchiveVersion)

                
                ### Change Log
                
                #### Additions
                _New symbols added in \(newerDocCArchiveVersion) that did not previously exist in \(initialDocCArchiveVersion)._
                                    
                \(additionLinks)
                
                
                #### Removals
                _Old symbols that existed in \(initialDocCArchiveVersion) that no longer exist in \(newerDocCArchiveVersion)._
                                    
                \(removalLinks)
                
                """
        ]
    }
}
