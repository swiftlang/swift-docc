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
package import FoundationEssentials
#else
package import Foundation
#endif

package extension MarkdownRenderer {
    /// Creates an HTML element for the breadcrumbs that lead to the renderer's current page.
    func breadcrumbs(references: [URL], currentPageNames: LinkedElement.Names) -> XMLNode {
        // Breadcrumbs handle symbols differently than most elements in that everything uses a default style (no "code voice")
        func nameElements(for names: LinkedElement.Names) -> [XMLNode] {
            switch names {
            case .single(.conceptual(let name)), .single(.symbol(let name)):
                return [.text(name)]
                
            case .languageSpecificSymbol(let namesByLanguageID):
                let names = RenderHelpers.sortedLanguageSpecificValues(namesByLanguageID)
                return switch goal {
                case .richness:
                    if names.count == 1 {
                        [.text(names.first!.value)]
                    } else {
                        names.map { language, name in
                            // Wrap the name in a span so that it can be given a language specific "class" attribute.
                            .element(named: "span", children: [.text(name)], attributes: ["class": "\(language.id)-only"])
                        }
                    }
                case .conciseness:
                    // If the goal is conciseness, only display the primary language's name
                    names.first.map { _, name in [.text(name)] } ?? []
                }
            }
        }
        
        // Create links for each of the breadcrumbs
        var items: [XMLNode] = references.compactMap {
            linkProvider.element(for: $0).map { page in
                .element(named: "li", children: [
                    .element(named: "a", children: nameElements(for: page.names), attributes: ["href": self.path(to: page.path)])
                ])
            }
        }
        
        // Add the name of the current page. It doesn't display as a link because it would refer to the current page.
        items.append(
            .element(named: "li", children: nameElements(for: currentPageNames))
        )
        let list = XMLNode.element(named: "ul", children: items)
        
        return switch goal {
        case .conciseness: list // If the goal is conciseness, don't wrap the list in a `<nav>` HTML element with an "id".
        case .richness:    .element(named: "nav", children: [list], attributes: ["id": "breadcrumbs"])
        }
    }
}
