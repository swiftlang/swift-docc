/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022-2023 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocC
import Markdown

class DirectiveIndexTests: XCTestCase {
    func testDirectiveIndexHasExpectedDirectives() {
        XCTAssertEqual(
            DirectiveIndex.shared.indexedDirectives.keys.sorted(),
            [
                "Assessments",
                "AutomaticArticleSubheading",
                "AutomaticSeeAlso",
                "AutomaticTitleHeading",
                "Available",
                "CallToAction",
                "Chapter",
                "Choice",
                "Column",
                "CustomMetadata",
                "DeprecationSummary",
                "DisplayName",
                "DocumentationExtension",
                "Image",
                "Intro",
                "Justification",
                "Links",
                "Metadata",
                "Options",
                "PageColor",
                "PageImage",
                "PageKind",
                "Redirected",
                "Row",
                "Small",
                "Snippet",
                "Stack",
                "SupportedLanguage",
                "Tab",
                "TabNavigator",
                "TechnologyRoot",
                "TitleHeading",
                "TopicsVisualStyle",
                "Tutorial",
                "TutorialReference",
                "Video",
                "XcodeRequirement",
            ]
        )
    }
    
    func testDirectiveIndexHasExpectedRenderableDirectives() {
        XCTAssertEqual(
            DirectiveIndex.shared.renderableDirectives.keys.sorted(),
            [
                "Image",
                "Links",
                "Row",
                "Small",
                "Snippet",
                "TabNavigator",
                "Video",
            ]
        )
    }
}
