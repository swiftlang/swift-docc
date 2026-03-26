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

package import DocCCommon
package import SymbolKit

package extension MarkdownRenderer {
 
    typealias DeclarationFragment = SymbolGraph.Symbol.DeclarationFragments.Fragment
    
    /// Creates a`<pre><code>` HTML element hierarchy that represents the symbol's language-specific declarations.
    ///
    /// When the renderer has a ``RenderGoal/richness`` goal, it creates a `<span>` element for each declaration fragment so that to enable syntax highlighting.
    ///
    /// When the renderer has a ``RenderGoal/conciseness`` goal, it joins the different fragments into string.
    func declaration(_ fragmentsByLanguage: [SourceLanguage: [DeclarationFragment]]) -> XMLElement {
        let fragmentsByLanguage = RenderHelpers.sortedLanguageSpecificValues(fragmentsByLanguage)
        
        guard goal == .richness else {
            // On the rendered page, language specific content _could_ be hidden through CSS but that wouldn't help the tool that reads the raw HTML.
            // So that tools don't need to filter out language specific content themselves, include only the primary language's (plain text) declaration.
            let plainTextDeclaration: [XMLNode] = fragmentsByLanguage.first.map { _, fragments in
                // The main purpose of individual HTML elements per declaration fragment would be syntax highlighting on the rendered page.
                // That structure likely won't be beneficial (and could even be detrimental) to the tool's ability to consume the declaration information.
                [.element(named: "code", children: [.text(fragments.map(\.spelling).joined())])]
            } ?? []
            return .element(named: "pre", children: plainTextDeclaration)
        }
        
        let declarations: [XMLElement] = if fragmentsByLanguage.count == 1 {
            // If there's only a single language there's no need to mark anything as language specific.
            [XMLNode.element(named: "code", children: _declarationTokens(for: fragmentsByLanguage.first!.value))]
        } else {
            fragmentsByLanguage.map { language, fragments in
                XMLNode.element(named: "code", children: _declarationTokens(for: fragments), attributes: ["class": "\(language.id)-only"])
            }
        }
        return .element(named: "pre", children: declarations, attributes: ["id": "declaration"])
    }
    
    private func _declarationTokens(for fragments: [DeclarationFragment]) -> [XMLNode] {
        // TODO: Pretty print declarations for Swift and Objective-C by placing attributes and parameters on their own lines (rdar://165918402)
        fragments.map { fragment in
            let elementClass = "token-\(fragment.kind.rawValue)"
            
            if fragment.kind == .typeIdentifier,
               let symbolID = fragment.preciseIdentifier,
               let reference = linkProvider.pathForSymbolID(symbolID)
            {
                // If the token refers to a symbol that the `linkProvider` is aware of, make that fragment a link to that symbol.
                return .element(named: "a", children: [.text(fragment.spelling)], attributes: [
                    "href": path(to: reference),
                    "class": elementClass
                ])
            } else if fragment.kind == .text {
                // ???: Does text also need a <span> element or can that be avoided?
                return .text(fragment.spelling)
            } else {
                // The declaration element is expected to scroll, so individual fragments don't need to contain explicit word breaks.
                return .element(named: "span", children: [.text(fragment.spelling)], attributes: ["class": elementClass])
            }
        }
    }
}
