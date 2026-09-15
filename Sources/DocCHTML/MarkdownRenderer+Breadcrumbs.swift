/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2025-2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

package import struct Foundation.URL
private import DocCCommon

package extension MarkdownRenderer {
    /// Creates an HTML element for the breadcrumbs that lead to the renderer's current page.
    func breadcrumbs(references: [URL], currentPageNames: LinkedElement.Names) -> HTMLNode {
        // Breadcrumbs handle symbols differently than most elements in that everything uses a default style (no "code voice")
        func nameElements(for names: LinkedElement.Names) -> [HTMLNode] {
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
                            span(attributes: [language.filterAttribute], contents: [.text(name)])
                        }
                    }
                case .conciseness:
                    // If the goal is conciseness, only display the primary language's name
                    names.first.map { _, name in [.text(name)] } ?? []
                }
            }
        }
        
        // Create links for each of the breadcrumbs
        var items: [HTMLNode] = references.compactMap {
            linkProvider.element(for: $0).map { page in
                li(contents: [
                    anchor(linkingTo: page, contents: nameElements(for: page.names))
                ])
            }
        }
        
        // Add the name of the current page. It doesn't display as a link because it would refer to the current page.
        items.append(
            li(contents: nameElements(for: currentPageNames))
        )
        let list = ul(contents: items)
        
        return switch goal {
        case .conciseness: list // If the goal is conciseness, don't wrap the list in a `<nav>` HTML element with an "id".
        case .richness:    nav(attributes: [.id("breadcrumbs")], contents: [list])
        }
    }
}
