/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2025-2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

package import Markdown
package import DocCCommon

package extension MarkdownRenderer {
    /// Creates a "returns" section that describes all return values of a symbol.
    ///
    /// If each language representation of the symbol has its own language-specific return values, pass the return value content for all language representations.
    ///
    /// If all language representations of the symbol have the _same_ return value, only pass the return value content for one language.
    /// This produces a "returns" section that doesn't hide the return value content for any of the languages (same as if the symbol only had one language representation)
    func returns(_ languageSpecificSections: [SourceLanguage: [any Markup]]) -> [HTMLNode] {
        let info = RenderHelpers.sortedLanguageSpecificValues(languageSpecificSections)
        let items: [HTMLNode] = if info.count == 1 {
            info.first!.value.map { visit($0) }
        } else {
            info.flatMap { language, content in
                let attributes = [language.filterAttribute]
                // Most return sections only have 1 paragraph of content with 2 and 3 paragraphs being increasingly uncommon.
                // Avoid wrapping that content in a `<div>` or other container element and instead add the language specific class attribute to each paragraph.
                return content.map { markup in
                    var node = visit(markup)
                    
                    guard !node._isText else {
                        // Any text _should_ already be contained in a markdown paragraph, but if the input is unexpected, wrap the raw text in a paragraph here.
                        return p(attributes: attributes, contents: [node])
                    }
                    node._addAttributes(attributes)
                    return node
                }
            }
        }
        
        return selfReferencingSection(named: "Return Value", content: items)
    }
}
