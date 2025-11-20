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

package import SymbolKit

package extension MarkupRenderer {
 
    typealias DeclarationFragment = SymbolGraph.Symbol.DeclarationFragments.Fragment
    
    func declaration(_ fragmentsByLanguage: [String /* Language ID*/: [DeclarationFragment]]) -> XMLElement {
        let fragmentsByLanguage = RenderHelpers.sortedLanguageSpecificValues(fragmentsByLanguage)
        // Note: declarations scroll, so they don't need to word wrap within tokens
        
        let declarations: [XMLElement] = if fragmentsByLanguage.count == 1 {
            [XMLNode.element(named: "code", children: _declarationTokens(for: fragmentsByLanguage.first!.value))]
        } else {
            fragmentsByLanguage.map { languageID, fragments in
                XMLNode.element(named: "code", children: _declarationTokens(for: fragments), attributes: ["class": "\(languageID)-only"])
            }
        }
        return .element(named: "pre", children: declarations, attributes: ["id": "declaration"])
    }
    
    private func _declarationTokens(for fragments: [DeclarationFragment]) -> [XMLNode] {
        // FIXME: Pretty print declarations for Swift and Objective-C
        
        fragments.map { fragment in
            let elementClass = "token-\(fragment.kind.rawValue)"
            
            if fragment.kind == .typeIdentifier,
               let symbolID = fragment.preciseIdentifier,
               let reference = linkProvider.pathForSymbolID(symbolID)
            {
                // Make a link
                return .element(named: "a", children: [.text(fragment.spelling)], attributes: [
                    "href": path(to: reference),
                    "class": elementClass
                ])
            }
            else if fragment.kind == .text {
                // ???: Does text need a <span> element?
                return .text(fragment.spelling)
            } else {
                return .element(named: "span", children: [.text(fragment.spelling)], attributes: ["class": elementClass])
            }
        }
    }
}
