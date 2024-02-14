/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Markdown

/// An index that describes which articles mention symbols.
///
/// When an article mentions a symbol from a module registered with the
/// documentation context, the mention is recorded in this data structure.
/// This is ultimately used to render a "mentioned in" section in symbol documentation.
///
/// This type should only record article -> symbol links, as the "mentioned in" section
/// is for directing readers to explanatory articles from the API reference.
struct ArticleSymbolMentions {
    /// A count of symbol mentions.
    var mentions: [ResolvedTopicReference: [ResolvedTopicReference: Int]] = [:]

    /// Record a symbol mention within an article.
    mutating func article(_ article: ResolvedTopicReference, didMention symbol: ResolvedTopicReference, weight: Int) {
        mentions[symbol, default: [:]][article, default: 0] += 1 * weight
    }

    /// The list of articles mentioning a symbol, from most frequent to least frequent.
    func articlesMentioning(_ symbol: ResolvedTopicReference) -> [ResolvedTopicReference] {
        // Mentions are sorted on demand based on the number of mentions.
        // This could change in the future.
        return mentions[symbol, default: [:]].sorted {
            $0.value > $1.value
        }
        .map { $0.key }
    }
}

struct SymbolLinkCollector: MarkupWalker {
    var context: DocumentationContext
    var article: ResolvedTopicReference
    var baseWeight: Int

    func visitSymbolLink(_ symbolLink: SymbolLink) {
        if let destination = symbolLink.destination,
           let symbol = context.referenceIndex[destination] {
            context.articleSymbolMentions.article(article, didMention: symbol, weight: baseWeight)
        }
    }
}
