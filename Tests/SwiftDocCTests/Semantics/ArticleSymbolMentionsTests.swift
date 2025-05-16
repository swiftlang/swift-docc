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

    // Test the sorting of articles mentioning a given symbol
    func testArticlesMentioningSorting() throws {
        let bundleID: DocumentationBundle.Identifier = "org.swift.test"
        let articles = ["a", "b", "c", "d", "e", "f"].map { letter in
            ResolvedTopicReference(
                bundleID: bundleID,
                path: "/\(letter)",
                sourceLanguage: .swift
            )
        }
        let symbol = ResolvedTopicReference(
            bundleID: bundleID,
            path: "/z",
            sourceLanguage: .swift
        )

        var mentions = ArticleSymbolMentions()
        XCTAssertTrue(mentions.articlesMentioning(symbol).isEmpty)

        // test that mentioning articles are sorted by weight
        mentions.article(articles[0], didMention: symbol, weight: 10)
        mentions.article(articles[1], didMention: symbol, weight: 42)
        mentions.article(articles[2], didMention: symbol, weight: 1)
        mentions.article(articles[3], didMention: symbol, weight: 14)
        mentions.article(articles[4], didMention: symbol, weight: 2)
        mentions.article(articles[5], didMention: symbol, weight: 6)
        XCTAssertEqual(mentions.articlesMentioning(symbol), [
            articles[1],
            articles[3],
            articles[0],
            articles[5],
            articles[4],
            articles[2],
        ])

        // test that mentioning articles w/ same weights are sorted alphabetically
        //
        // note: this test is done multiple times with a shuffled list to ensure
        // that it isn't just passing by pure chance due to the unpredictable
        // order of Swift dictionaries
        for _ in 1...10 {
            mentions = ArticleSymbolMentions()
            XCTAssertTrue(mentions.articlesMentioning(symbol).isEmpty)
            for article in articles.shuffled() {
                mentions.article(article, didMention: symbol, weight: 1)
            }
            XCTAssertEqual(mentions.articlesMentioning(symbol), articles)
        }
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
