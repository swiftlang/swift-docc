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

package extension MarkdownRenderer {
    /// Creates an HTML element for the breadcrumbs leading up to the renderer's reference.
    func breadcrumbs(references: [URL], currentPageNames: LinkedElement.Names) -> XMLNode {
        // Breadcrumbs handle symbols differently than most elements, so there's no point in sharing _this_ code
        func nameElements(for names: LinkedElement.Names) -> [XMLNode] {
            switch names {
            // Breadcrumbs display both symbolic names and conceptual in a default style
            case .single(.conceptual(let name)), .single(.symbol(let name)):
                return [.text(name)]
                
            case .languageSpecificSymbol(let namesByLanguageID):
                let names = RenderHelpers.sortedLanguageSpecificValues(namesByLanguageID)
                return switch goal {
                case .quality:
                    names.map { language, name in
                        .element(named: "span", children: [
                            .text(name) // Breadcrumbs display symbol names in a default style (no "code voice")
                        ], attributes: ["class": "\(language.id)-only"])
                    }
                case .conciseness:
                    // If the goal is conciseness, only display the primary language's name
                    names.first.map { _, name in
                        [.text(name)]
                    } ?? []
                }
            }
        }
        
        var items: [XMLNode] = references.compactMap {
            linkProvider.element(for: $0).map { page in
                .element(named: "li", children: [
                    .element(named: "a", children: nameElements(for: page.names), attributes: ["href": self.path(to: page.path)])
                ])
            }
        }
        
        // The current page doesn't display as a link
        items.append(
            .element(named: "li", children: nameElements(for: currentPageNames))
        )
        let list = XMLNode.element(named: "ul", children: items)
        
        return switch goal {
        case .conciseness:
            list
        case .quality:
            .element(named: "nav", children: [list], attributes: ["id": "breadcrumbs"])
        }
    }
}
