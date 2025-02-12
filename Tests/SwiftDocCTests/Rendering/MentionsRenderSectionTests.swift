/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import XCTest
@testable import SwiftDocC

class MentionsRenderSectionTests: XCTestCase {
    /// Verify that the Mentioned In section is present when a symbol is mentioned,
    /// pointing to the correct article.
    func testMentionedInSectionFull() throws {
        enableFeatureFlag(\.isMentionedInEnabled)
        let (bundle, context) = try createMentionedInTestBundle()
        let identifier = ResolvedTopicReference(
            bundleID: bundle.id,
            path: "/documentation/MentionedIn/MyClass",
            sourceLanguage: .swift
        )
        let mentioningArticle = ResolvedTopicReference(
            bundleID: bundle.id,
            path: "/documentation/MentionedIn/ArticleMentioningSymbol",
            sourceLanguage: .swift
        )
        let node = try context.entity(with: identifier)
        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference)
        let renderNode = translator.visit(node.semantic) as! RenderNode
        let mentionsSection = try XCTUnwrap(renderNode.primaryContentSections.mapFirst { $0 as? MentionsRenderSection })
        XCTAssertEqual(1, mentionsSection.mentions.count)
        let soleMention = try XCTUnwrap(mentionsSection.mentions.first)
        XCTAssertEqual(mentioningArticle.url, soleMention)
    }

    /// If there are no qualifying mentions of a symbol, the Mentioned In section should not appear.
    func testMentionedInSectionEmpty() throws {
        enableFeatureFlag(\.isMentionedInEnabled)
        let (bundle, context) = try createMentionedInTestBundle()
        let identifier = ResolvedTopicReference(
            bundleID: bundle.id,
            path: "/documentation/MentionedIn/MyClass/myFunction()",
            sourceLanguage: .swift
        )
        let node = try context.entity(with: identifier)
        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference)
        let renderNode = translator.visit(node.semantic) as! RenderNode
        let mentionsSection = renderNode.primaryContentSections.mapFirst { $0 as? MentionsRenderSection }
        XCTAssertNil(mentionsSection)
    }
}
