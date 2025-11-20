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

package extension MarkupRenderer {
    /// Creates an HTML element for the breadcrumbs leading up to the renderer's reference.
    func breadcrumbs(references: [URL]) -> XMLNode {
        // Breadcrumbs handle symbols differently than most elements, so there's no point in sharing _this_ code
        func names(for element: LinkedElement) -> [XMLNode] {
            switch element.names {
            // Breadcrumbs display both symbolic names and conceptual in a default style
            case .single(.conceptual(let name)), .single(.symbol(let name)):
                [.text(name)]
                
            case .languageSpecificSymbol(let namesByLanguageID):
                RenderHelpers.sortedLanguageSpecificValues(namesByLanguageID).map { languageID, name in
                    .element(named: "span", children: [
                        .text(name) // Breadcrumbs display symbol names in a default style (no "code voice")
                    ], attributes: ["class": "\(languageID)-only"])
                }
            }
        }
        
        var items: [XMLNode] = references.compactMap {
            linkProvider.element(for: $0).map { page in
                .element(named: "li", children: [
                    .element(named: "a", children: names(for: page), attributes: ["href": self.path(to: page.path)])
                ])
            }
        }
        
        // The current page doesn't display as a link
        items.append(
            .element(named: "li", children: names(for: linkProvider.element(for: self.path)! /* The current page is known to exist */))
        )
        
        return .element(
            named: "nav",
            children: [.element(named: "ul", children: items)],
            attributes: ["id": "breadcrumbs"]
        )
    }
}
