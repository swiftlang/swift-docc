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

package import Markdown
package import DocCCommon

package extension MarkdownRenderer {
    /// Creates a "returns" section that describes all return values of a symbol.
    ///
    /// If each language representation of the symbol has its own language-specific return values, pass the return value content for all language representations.
    ///
    /// If all language representations of the symbol have the _same_ return value, only pass the return value content for one language.
    /// This produces a "returns" section that doesn't hide the return value content for any of the languages (same as if the symbol only had one language representation)
    ///
    /// When the content is in outline form (a single ``UnorderedList`` with list items like `- name: description`), it is rendered as a definition list (like Parameters) for clarity.
    func returns(_ languageSpecificSections: [SourceLanguage: [any Markup]]) -> [XMLNode] {
        let info = RenderHelpers.sortedLanguageSpecificValues(languageSpecificSections)
        
        // When content is outline form (- Returns: \n  - name: ... \n  - name: ...), render as dl/dt/dd like Parameters.
        if info.count == 1, let paramInfos = _parseReturnsOutlineContent(info.first!.value), !paramInfos.isEmpty {
            return _returnValuesAsList([info.first!.key: paramInfos])
        }
        if info.count == 2,
           let primary = _parseReturnsOutlineContent(info.first!.value),
           let secondary = _parseReturnsOutlineContent(info.last!.value),
           !primary.isEmpty {
            return _returnValuesAsList([info.first!.key: primary, info.last!.key: secondary])
        }
        
        let items: [XMLNode] = if info.count == 1 {
            info.first!.value.map { visit($0) }
        } else {
            info.flatMap { language, content in
                let attributes = ["class": "\(language.id)-only"]
                // Most return sections only have 1 paragraph of content with 2 and 3 paragraphs being increasingly uncommon.
                // Avoid wrapping that content in a `<div>` or other container element and instead add the language specific class attribute to each paragraph.
                return content.map { markup in
                    let node = visit(markup)
                    if let element = node as? XMLElement {
                        element.addAttributes(attributes)
                        return element
                    } else {
                        // Any text _should_ already be contained in a markdown paragraph, but if the input is unexpected, wrap the raw text in a paragraph here.
                        return .element(named: "p", children: [node], attributes: attributes)
                    }
                }
            }
        }
        
        return selfReferencingSection(named: "Return Value", content: items)
    }
    
    /// Renders named return values as a definition list (same layout as Parameters), with section title "Return Value".
    private func _returnValuesAsList(_ info: [SourceLanguage: [ParameterInfo]]) -> [XMLNode] {
        let info = RenderHelpers.sortedLanguageSpecificValues(info)
        guard info.contains(where: { _, parameters in !parameters.isEmpty }) else {
            return []
        }
        let items: [XMLElement] = switch info.count {
        case 1:
            [_singleLanguageParameters(info.first!.value)]
        case 2:
            [_dualLanguageParameters(primary: info.first!, secondary: info.last!)]
        default:
            info.map { language, paramInfo in
                .element(
                    named: "dl",
                    children: _singleLanguageParameterItems(paramInfo),
                    attributes: ["class": "\(language.id)-only"]
                )
            }
        }
        return selfReferencingSection(named: "Return Value", content: items)
    }
    
    /// Parses return section content when it is in outline form: a single `UnorderedList` with items like `- name: description`.
    /// Returns `nil` if the content is not in that form.
    private func _parseReturnsOutlineContent(_ content: [any Markup]) -> [ParameterInfo]? {
        guard content.count == 1, let list = content.first as? UnorderedList else {
            return nil
        }
        var result: [ParameterInfo] = []
        for listChild in list.children {
            guard let listItem = listChild as? ListItem,
                  let firstBlock = listItem.child(at: 0) as? Paragraph,
                  let (name, contentAfterColon) = _splitParagraphNameAndContent(firstBlock) else {
                return nil
            }
            let restBlocks = (1..<listItem.childCount).compactMap { listItem.child(at: $0) }
            let fullContent = contentAfterColon + restBlocks
            result.append(ParameterInfo(name: name, content: fullContent))
        }
        return result.isEmpty ? nil : result
    }
    
    /// Splits a paragraph's inline content at the first colon to get "name" and "description" (for outline form list items).
    private func _splitParagraphNameAndContent(_ paragraph: Paragraph) -> (name: String, content: [any Markup])? {
        let inlines = paragraph.children
        for (i, inline) in inlines.enumerated() {
            guard let text = inline as? Text, let colonIndex = text.string.firstIndex(of: ":") else {
                continue
            }
            let name = String(text.string[..<colonIndex]).trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { return nil }
            let afterColon = text.string[text.string.index(after: colonIndex)...].drop(while: { $0 == " " })
            var remaining: [any InlineMarkup] = [Text(String(afterColon))]
            for node in inlines.dropFirst(i + 1) {
                if let inline = node as? (any InlineMarkup) {
                    remaining.append(inline)
                }
            }
            return (name, [Paragraph(remaining)])
        }
        return nil
    }
}
