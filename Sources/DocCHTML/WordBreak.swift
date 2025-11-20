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

package enum RenderHelpers {
    /// Inserts `<wbr/>` elements into a symbol name so that it can wrap better on the rendered page.
    ///
    /// For example, a method call like this (below), inserts line break elements at the highlighted locations:
    ///
    ///     do Something< Generic>( with First: and Second:)
    ///       △          ▲         ▲    △      ▲   △
    ///       │          ╰─────────┴───╴│╶─────┴──╴│╶─── after syntax
    ///       ╰─────────────────────────┴──────────┴──── between words
    package static func wordBreak(symbolName: String) -> [XMLNode] {
        var result: [XMLNode] = []
        
        let utf8View = symbolName.utf8
        let indices = utf8View.indices
        
        var fromIndex = utf8View.startIndex
        for (index, previousIndex) in zip(indices.dropFirst(), indices) {
            let previous = utf8View[previousIndex]
            let current  = utf8View[index]
            
            guard previous.isSyntaxSeparator      && !current.isSyntaxSeparator
               || previous.isLowercaseASCIILetter && current.isUppercaseASCIILetter
            else {
                continue
            }
            
            result.append(.text(String(utf8View[fromIndex ..< index])!))
            if index < utf8View.endIndex {
                result.append(.element(named: "wbr"))
            }
            fromIndex = index
        }
        
        if fromIndex < utf8View.endIndex {
            result.append(.text(String(utf8View[fromIndex...])!))
        }
        
        return result
    }
    
    /// Returns the language specific symbol names sorted by the language.
    package static func sortedLanguageSpecificValues<Value>(_ valuesByLanguageID: [String /* language ID */: Value]) -> [(key: String, value: Value)] {
        valuesByLanguageID.sorted(by: { lhs, rhs in
            // Sort Swift before other languages.
            if lhs.key == "swift" {
                return true
            } else if rhs.key == "swift" {
                return false
            }
            // Otherwise, sort by ID for a stable order.
            return lhs.key < rhs.key
        })
    }
}

private extension UTF8.CodeUnit {
    // Because this is only for line breaks, limiting support to ASCII is probably acceptable
    var isUppercaseASCIILetter: Bool {
        UTF8.CodeUnit(ascii: "A") <= self && self <= UTF8.CodeUnit(ascii: "Z")
    }
    var isLowercaseASCIILetter: Bool {
        UTF8.CodeUnit(ascii: "a") <= self && self <= UTF8.CodeUnit(ascii: "z")
    }
    
    var isSyntaxSeparator: Bool {
        return self == UTF8.CodeUnit(ascii: ":")
            || self == UTF8.CodeUnit(ascii: "(")
            || self == UTF8.CodeUnit(ascii: ")")
            || self == UTF8.CodeUnit(ascii: "<")
            || self == UTF8.CodeUnit(ascii: ">")
    }
}
