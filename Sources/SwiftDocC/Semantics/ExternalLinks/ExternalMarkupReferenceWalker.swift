/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown

/**
 Walks a markup tree and collects any links external to a given bundle.
 */
struct ExternalMarkupReferenceWalker: MarkupVisitor {
    var bundle: DocumentationBundle
    
    /// After walking a markup tree, all encountered external links are collected in this list.
    var collectedExternalLinks = [ValidatedURL]()
    
    /// Creates a new markup walker.
    /// - Parameter bundle: All links with a bundle ID different than this bundle's are considered external and collected.
    init(bundle: DocumentationBundle) {
        self.bundle = bundle
    }

    /// Descends down the given elements' children.
    public mutating func defaultVisit(_ markup: Markup) {
        for child in markup.children {
            self.visit(child)
        }
    }

    /// Collects the link URL, if the link is not to a topic in the current bundle.
    mutating func visitLink(_ link: Link) {
        // Only process documentation links to external bundles
        guard let destination = link.destination,
            let url = ValidatedURL(parsingExact: destination),
            url.components.scheme == ResolvedTopicReference.urlScheme,
            let bundleID = url.components.host,
            bundleID != bundle.identifier else {
            return
        }
        
        // Collect the external link.
        collectedExternalLinks.append(url)
    }
}
