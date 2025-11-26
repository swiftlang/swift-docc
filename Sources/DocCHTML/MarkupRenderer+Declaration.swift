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

package import DocCCommon
package import SymbolKit

package extension MarkdownRenderer {
 
    typealias DeclarationFragment = SymbolGraph.Symbol.DeclarationFragments.Fragment
    
    func declaration(_ fragmentsByLanguage: [SourceLanguage: [DeclarationFragment]]) -> XMLElement {
        let fragmentsByLanguage = RenderHelpers.sortedLanguageSpecificValues(fragmentsByLanguage)
        
        guard goal == .quality else {
            // If the goal is conciseness, display only the primary language's plain text declaration in a <code> block
            let plainTextDeclaration: [XMLNode] = fragmentsByLanguage.first.map { _, fragments in
                [.element(named: "code", children: [.text(fragments.map(\.spelling).joined())])]
            } ?? []
            return .element(named: "pre", children: plainTextDeclaration, attributes: ["id": "declaration"])
        }
        
        // Note: declarations scroll, so they don't need to word wrap within tokens
        
        let declarations: [XMLElement] = if fragmentsByLanguage.count == 1 {
            [XMLNode.element(named: "code", children: _declarationTokens(for: fragmentsByLanguage.first!.value))]
        } else {
            fragmentsByLanguage.map { language, fragments in
                XMLNode.element(named: "code", children: _declarationTokens(for: fragments), attributes: ["class": "\(language.id)-only"])
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
