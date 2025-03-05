/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocC
import Markdown
import SwiftDocCTestUtilities
import SymbolKit

class ArticleSymbolMentionsTests: XCTestCase {
    /// Test that the recording abstraction for ``ArticleSymbolMentions`` works as expected.
    func testArticlesMentioningSymbol() throws {
        let article = ResolvedTopicReference(
            bundleID: "org.swift.anything",
            path: "/article",
            sourceLanguage: .swift
        )
        let symbol = ResolvedTopicReference(bundleID: "org.swift.anything", path: "/Thing", sourceLanguage: .swift)
        var mentions = ArticleSymbolMentions()

        XCTAssertTrue(mentions.articlesMentioning(symbol).isEmpty)

        let weight = 99
        mentions.article(article, didMention: symbol, weight: weight)
        
        let gottenArticles = mentions.articlesMentioning(symbol)
        XCTAssertEqual(1, gottenArticles.count)
        let gottenArticle = try XCTUnwrap(gottenArticles.first)
        XCTAssertEqual(gottenArticle, article)
    }

    func testSymbolLinkCollectorEnabled() throws {
        let (bundle, context) = try createMentionedInTestBundle()

        // The test bundle currently only has one article with symbol mentions
        // in the abstract/discussion.
        XCTAssertEqual(1, context.articleSymbolMentions.mentions.count)

        let mentioningArticle = ResolvedTopicReference(
            bundleID: bundle.id,
            path: "/documentation/MentionedIn/ArticleMentioningSymbol",
            sourceLanguage: .swift)
        let mentionedSymbol = ResolvedTopicReference(
            bundleID: bundle.id,
            path: "/documentation/MentionedIn/MyClass",
            sourceLanguage: .swift)
        
        let mentions = context.articleSymbolMentions.articlesMentioning(mentionedSymbol)
        XCTAssertEqual(1, mentions.count)
        let gottenArticle = try XCTUnwrap(mentions.first)
        XCTAssertEqual(mentioningArticle, gottenArticle)
    }

    func testSymbolLinkCollectorDisabled() throws {
        let currentFeatureFlags = FeatureFlags.current
        addTeardownBlock {
            FeatureFlags.current = currentFeatureFlags
        }
        FeatureFlags.current.isMentionedInEnabled = false
        
        
        let (bundle, context) = try createMentionedInTestBundle()
        XCTAssertTrue(context.articleSymbolMentions.mentions.isEmpty)

        let mentionedSymbol = ResolvedTopicReference(
            bundleID: bundle.id,
            path: "/documentation/MentionedIn/MyClass",
            sourceLanguage: .swift)

        XCTAssertTrue(context.articleSymbolMentions.articlesMentioning(mentionedSymbol).isEmpty)
    }
}
