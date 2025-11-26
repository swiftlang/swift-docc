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

package import Markdown
package import DocCCommon

package extension MarkdownRenderer {
    func returns(_ languageSpecificSections: [SourceLanguage: [any Markup]]) -> XMLElement {
        let info = RenderHelpers.sortedLanguageSpecificValues(languageSpecificSections)
        let items: [XMLNode] = if info.count == 1 {
            info.first!.value.map { visit($0) } // Verified to exist above
        } else {
            info.flatMap { language, content in
                let attributes = ["class": "\(language.id)-only"]
                // Most return sections only have 1 paragraph of content with 2 and 3 paragraphs being increasingly uncommon.
                // Avoid wrapping that content in a div and instead add the language specific class attribute to each paragraph.
                return content.map { markup in
                    let node = visit(markup)
                    if let element = node as? XMLElement {
                        element.addAttributes(attributes)
                        return element
                    } else {
                        // Any text _should_ already be contained in a markdown paragraph, but if the input is unexpected, wrap it here.
                        return .element(named: "p", children: [node], attributes: attributes)
                    }
                }
            }
        }
        
        return selfReferencingSection(named: "Return Value", content: items)
    }
    
    func selfReferencingSection(named sectionName: String, content: [XMLNode]) -> XMLElement {
        let headingContent: XMLNode
        let sectionAttributes: [String: String]
        
        switch goal {
        case .quality:
            let id = urlReadableFragment(sectionName.lowercased())
            headingContent = .element(named: "a", children: [.text(sectionName)], attributes: ["href": "#\(id)"])
            sectionAttributes = ["id": id]
        case .conciseness:
            headingContent = .text(sectionName)
            sectionAttributes = [:]
        }
        
        return .element(
            named: "section",
            children: [.element(named: "h2", children: [headingContent])] + content,
            attributes: sectionAttributes
        )
    }
}

private extension CharacterSet {
    // For fragments
    static let fragmentCharactersToRemove = CharacterSet.punctuationCharacters // Remove punctuation from fragments
        .union(CharacterSet(charactersIn: "`"))       // Also consider back-ticks as punctuation. They are used as quotes around symbols or other code.
        .subtracting(CharacterSet(charactersIn: "-")) // Don't remove hyphens. They are used as a whitespace replacement.
    static let whitespaceAndDashes = CharacterSet.whitespaces
        .union(CharacterSet(charactersIn: "-–—")) // hyphen, en dash, em dash
}

/// Creates a more readable version of a fragment by replacing characters that are not allowed in the fragment of a URL with hyphens.
///
/// If this step is not performed, the disallowed characters are instead percent escape encoded, which is less readable.
/// For example, a fragment like `"#hello world"` is converted to `"#hello-world"` instead of `"#hello%20world"`.
private func urlReadableFragment(_ fragment: some StringProtocol) -> String {
    var fragment = fragment
        // Trim leading/trailing whitespace
        .trimmingCharacters(in: .whitespaces)
    
        // Replace continuous whitespace and dashes
        .components(separatedBy: .whitespaceAndDashes)
        .filter({ !$0.isEmpty })
        .joined(separator: "-")
    
    // Remove invalid characters
    fragment.unicodeScalars.removeAll(where: CharacterSet.fragmentCharactersToRemove.contains)
    
    return fragment
}

