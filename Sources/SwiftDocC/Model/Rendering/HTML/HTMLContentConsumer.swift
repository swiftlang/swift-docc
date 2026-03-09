/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

#if canImport(FoundationXML)
// TODO: Consider other HTML rendering options as a future improvement (rdar://165755530)
package import FoundationXML
#else
package import Foundation
#endif

/// A consumer for HTML content produced during documentation conversion.
package protocol HTMLContentConsumer {
    // One reason that this is its own protocol, rather than an extension of ConvertOutputConsumer, is so that we can avoid exposing `XMLNode` in any public API.
    // That way, we are completely free to replace the entire internal HTML rendering implementation with something else in the future, without breaking API.
    
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
