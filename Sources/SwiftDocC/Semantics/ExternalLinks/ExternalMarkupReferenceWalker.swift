/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown

/// Walks a markup tree and collects any links external to a given bundle.
struct ExternalMarkupReferenceWalker: MarkupVisitor {
    /// The local bundle ID, used to identify and skip absolute fully qualified local links.
    var localBundleID: DocumentationBundle.Identifier
    
    /// After walking a markup tree, all encountered external links are collected grouped by the bundle ID.
    var collectedExternalLinks = [DocumentationBundle.Identifier: Set<ValidatedURL>]()

    /// Descends down the given elements' children.
    mutating func defaultVisit(_ markup: any Markup) {
        for child in markup.children {
            self.visit(child)
        }
    }

    /// Collects the link URL, if the link is not to a topic in the current bundle.
    mutating func visitLink(_ link: Link) {
        // Only process documentation links to external bundles
        guard let destination = link.destination,
              let url = ValidatedURL(parsingAuthoredLink: destination)?.requiring(scheme: ResolvedTopicReference.urlScheme),
              let bundleID = url.components.host.map({ DocumentationBundle.Identifier(rawValue: $0) }),
              bundleID != localBundleID
        else {
            return
        }
        
        // Collect the external link.
        collectedExternalLinks[bundleID, default: []].insert(url)
    }
}
