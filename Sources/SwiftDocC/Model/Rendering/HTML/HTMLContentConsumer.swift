/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

package import Foundation
#if canImport(FoundationXML)
// FIXME: See if we can avoid depending on XMLNode/XMLParser to avoid needing to import FoundationXML
package import FoundationXML
#endif

/// A consumer for HTML content produced during documentation conversion.
package protocol HTMLContentConsumer {
    /// Consumes the HTML content and metadata for a given page.
    ///
    /// The content and metadata doesn't make up a full valid HTML page.
    /// It's the consumers responsibility to insert the information into a template or skeletal structure to produce a valid HTML file for each page.
    ///
    /// - Parameters:
    ///   - mainContent: The contents for this page as an XHTML node.
    ///   - metadata: Metadata information (title and description) about this page.
    ///   - reference: The resolved topic reference that identifies this page.
    func consume(
        mainContent: XMLNode,
        metadata: (
            title: String,
            description: String?
        ),
        forPage reference: ResolvedTopicReference
    ) throws
}
