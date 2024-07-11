/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2023 Apple Inc. and the Swift project authors
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
        AutomaticArticleSubheading.directiveName,
        AutomaticSeeAlso.directiveName,
        AutomaticTitleHeading.directiveName,
        CallToAction.directiveName,
        Chapter.directiveName,
        Choice.directiveName,
        Code.directiveName,
        Comment.directiveName,
        ContentAndMedia.directiveName,
        CustomMetadata.directiveName,
        DeprecationSummary.directiveName,
        DisplayName.directiveName,
        DocumentationExtension.directiveName,
        ImageMedia.directiveName,
        Intro.directiveName,
        Justification.directiveName,
        Links.directiveName,
        Metadata.directiveName,
        Metadata.Availability.directiveName,
        Metadata.PageKind.directiveName,
        MultipleChoice.directiveName,
        Options.directiveName,
        PageColor.directiveName,
        PageImage.directiveName,
        Redirect.directiveName,
        Resources.directiveName,
        Row.directiveName,
        Small.directiveName,
        Snippet.directiveName,
        Stack.directiveName,
        Step.directiveName,
        Steps.directiveName,
        SupportedLanguage.directiveName,
        TabNavigator.directiveName,
        Technology.directiveName,
        TechnologyRoot.directiveName,
        TechnologyRoot.directiveName,
        Tile.directiveName,
        TitleHeading.directiveName,
        TopicsVisualStyle.directiveName,
        Tutorial.directiveName,
        TutorialArticle.directiveName,
        TutorialReference.directiveName,
        TutorialSection.directiveName,
        VideoMedia.directiveName,
        Volume.directiveName,
        XcodeRequirement.directiveName
    ]
    
    static let directivesRemovedFromContent: [String] = [
        Comment.directiveName,
        Metadata.directiveName,
        Options.directiveName,
        Redirect.directiveName,
    ]
}
