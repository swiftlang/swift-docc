/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022-2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A basic XML parser that extracts the first `id` attribute found in the given SVG.
///
/// This is a single-purpose tool and should not be used for general-purpose SVG parsing.
enum SVGIDExtractor {
    /// Extracts an SVG ID from the given data.
    ///
    /// Exposed for testing. The sibling `extractID(from: URL)` method is intended to be
    /// used within SwiftDocC.
    static func _extractID(from data: Data) -> String? {
        // FIXME: Revert this and resume using XMLParser when rdar://138726860 is integrated into a Swift toolchain.
        for capitalization in ["id", "ID", "Id", "iD"] {
            guard let idAttributeRange = data.firstRange(of: Data(" \(capitalization)=\"".utf8), in: data.indices) else {
                continue
            }
            
            guard let endQuote = data.firstRange(of: Data("\"".utf8), in: idAttributeRange.upperBound...) else {
                continue
            }
            
            return String(data: data[idAttributeRange.endIndex ..< endQuote.lowerBound], encoding: .utf8)
        }
        return nil
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
