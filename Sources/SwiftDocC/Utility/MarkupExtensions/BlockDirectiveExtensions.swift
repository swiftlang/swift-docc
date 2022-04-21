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
        ImageMedia.directiveName,
        VideoMedia.directiveName,
        Metadata.directiveName,
        TechnologyRoot.directiveName,
        Snippet.directiveName,
        DeprecationSummary.directiveName,
        TechnologyRoot.directiveName,
        Resources.directiveName,
        Chapter.directiveName,
        Tutorial.directiveName,
        TutorialReference.directiveName,
        Choice.directiveName,
        Code.directiveName,
        Technology.directiveName
    ]
}
