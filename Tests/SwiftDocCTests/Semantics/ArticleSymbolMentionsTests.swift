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
            bundleIdentifier: "org.swift.anything",
            path: "/article",
            sourceLanguage: .swift
        )
        let symbol = ResolvedTopicReference(bundleIdentifier: "org.swift.anything", path: "/Thing", sourceLanguage: .swift)
        var mentions = ArticleSymbolMentions()

        XCTAssertTrue(mentions.articlesMentioning(symbol).isEmpty)

        let weight = 99
        mentions.article(article, didMention: symbol, weight: weight)
        
        let gottenArticles = mentions.articlesMentioning(symbol)
        XCTAssertEqual(1, gottenArticles.count)
        let gottenArticle = try XCTUnwrap(gottenArticles.first)
        XCTAssertEqual(gottenArticle, article)
    }

    /// If the `--enable-mentioned-in` flag is passed, symbol mentions in the test bundle's
    /// articles should be recorded.
    func testSymbolLinkCollectorEnabled() throws {
        enableFeatureFlag(\.isExperimentalMentionedInEnabled)
        let (bundle, context) = try createMentionedInTestBundle()

        // The test bundle currently only has one article with symbol mentions
        // in the abstract/discussion.
        XCTAssertEqual(1, context.articleSymbolMentions.mentions.count)

        let mentioningArticle = ResolvedTopicReference(
            bundleIdentifier: bundle.identifier,
            path: "/documentation/MentionedIn/ArticleMentioningSymbol",
            sourceLanguage: .swift)
        let mentionedSymbol = ResolvedTopicReference(
            bundleIdentifier: bundle.identifier,
            path: "/documentation/MentionedIn/MyClass",
            sourceLanguage: .swift)
        
        let mentions = context.articleSymbolMentions.articlesMentioning(mentionedSymbol)
        XCTAssertEqual(1, mentions.count)
        let gottenArticle = try XCTUnwrap(mentions.first)
        XCTAssertEqual(mentioningArticle, gottenArticle)
    }

    /// If the `--enable-experimental-mentioned-in` flag is not passed, symbol mentions in the test bundle's
    /// articles should not be recorded.
    func testSymbolLinkCollectorDisabled() throws {
        let (bundle, context) = try createMentionedInTestBundle()
        XCTAssertTrue(context.articleSymbolMentions.mentions.isEmpty)

        let mentionedSymbol = ResolvedTopicReference(
            bundleIdentifier: bundle.identifier,
            path: "/documentation/MentionedIn/MyClass",
            sourceLanguage: .swift)

        XCTAssertTrue(context.articleSymbolMentions.articlesMentioning(mentionedSymbol).isEmpty)
    }
}
