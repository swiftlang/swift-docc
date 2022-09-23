/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

// On non-Darwin platforms, Foundation's XML support is vended as a separate module:
// https://github.com/apple/swift-corelibs-foundation/blob/main/Docs/ReleaseNotes_Swift5.md#dependency-management
#if canImport(FoundationXML)
import FoundationXML
#endif

/// A basic XML parser that extracts the first `id` attribute found in the given SVG.
///
/// This is a single-purpose tool and should not be used for general-purpose SVG parsing.
enum SVGIDExtractor {
    /// Extracts an SVG ID from the given data.
    ///
    /// Exposed for testing. The sibling `extractID(from: URL)` method is intended to be
    /// used within SwiftDocC.
    static func _extractID(from data: Data) -> String? {
        let delegate = SVGIDParserDelegate()
        let svgParser = XMLParser(data: data)
        svgParser.delegate = delegate
        svgParser.parse()
        
        return delegate.id
    }
    
    /// Returns the first `id` attribute found in the given SVG, if any.
    ///
    /// Returns nil if any errors are encountered or if an `id` attribute is
    /// not found in the given SVG.
    static func extractID(from svg: URL) -> String? {
        guard let data = try? Data(contentsOf: svg) else {
            return nil
        }
        
        return _extractID(from: data)
    }
}

private class SVGIDParserDelegate: NSObject, XMLParserDelegate {
    var id: String?
    
    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String : String] = [:]
    ) {
        guard let id = attributeDict["id"] ?? attributeDict["ID"] ?? attributeDict["iD"] ?? attributeDict["Id"] else {
            return
        }
        
        self.id = id
        parser.abortParsing()
    }
}
