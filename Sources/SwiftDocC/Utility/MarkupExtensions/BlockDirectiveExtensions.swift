/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Markdown

extension BlockDirective {
    /// Names of directives expected to represent special types of Markdown documents.
    static let topLevelDirectiveNames: [String] = [
        Technology.directiveName,
        Tutorial.directiveName,
        TutorialArticle.directiveName,
    ]

    /// Names of known directives
    static let allKnownDirectiveNames: [String] = [
        Assessments.directiveName,
        Chapter.directiveName,
        Choice.directiveName,
        Code.directiveName,
        Comment.directiveName,
        ContentAndMedia.directiveName,
        DeprecationSummary.directiveName,
        DisplayName.directiveName,
        DocumentationExtension.directiveName,
        ImageMedia.directiveName,
        Intro.directiveName,
        Justification.directiveName,
        Metadata.directiveName,
        MultipleChoice.directiveName,
        Redirect.directiveName,
        Resources.directiveName,
        Snippet.directiveName,
        Stack.directiveName,
        Step.directiveName,
        Steps.directiveName,
        Technology.directiveName,
        TechnologyRoot.directiveName,
        TechnologyRoot.directiveName,
        Tile.directiveName,
        Tutorial.directiveName,
        TutorialArticle.directiveName,
        TutorialReference.directiveName,
        TutorialSection.directiveName,
        VideoMedia.directiveName,
        Volume.directiveName,
        XcodeRequirement.directiveName
    ]
}
