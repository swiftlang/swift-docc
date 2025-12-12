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

package import DocCCommon

package extension MarkdownRenderer {
    /// Information about a task group that organizes other API into a hierarchy on this page.
    struct ListInfo {
        /// The title of this group of API
        package var title: String?
        /// A list of already resolved references that the renderer should display, in order, for this group.
        package var references: [URL]
        
        package init(title: String?, references: [URL]) {
            self.title = title
            self.references = references
        }
    }
    
    /// Creates a grouped section with a given name, for example "relationships" or "mentioned in" lists groups of related pages without further description.
    ///
    /// If each language representation of the API has its own lists, pass the list for each language representation.
    ///
    /// If the API has the _same_ lists in all language representations, only pass the lists for one language.
    /// This produces a named section that doesn't hide any lists for any of the languages (the same as if the symbol only had one language representation).
    func groupedListSection(named sectionName: String, groups lists: [SourceLanguage: [ListInfo]]) -> [XMLNode] {
        let lists = RenderHelpers.sortedLanguageSpecificValues(lists)
        
        let items: [XMLElement] = if lists.count == 1 {
            lists.first!.value.flatMap { list in
                _singleListGroupElements(for: list)
            }
        } else {
            // TODO: As a future improvement we could diff the references and only mark them as language-specific if the group and reference doesn't appear in all languages.
            lists.flatMap { language, taskGroups in
                let attribute = XMLNode.attribute(withName: "class", stringValue: "\(language.id)-only") as! XMLNode
                
                let elements = taskGroups.flatMap { _singleListGroupElements(for: $0) }
                for element in elements {
                    element.addAttribute(attribute)
                }
                return elements
            }
        }
        
        return selfReferencingSection(named: sectionName, content: items)
    }
    
    private func _singleListGroupElements(for list: ListInfo) -> [XMLElement] {
        let listItems = list.references.compactMap { reference in
            linkProvider.element(for: reference).map { _listItem(for: $0) }
        }
        // Don't return a title or abstract/discussion if this group has no links to display.
        guard !listItems.isEmpty else { return [] }
        
        var items: [XMLElement] = []
        // Title
        if let title = list.title {
            items.append(selfReferencingHeading(level: 3, content: [.text(title)], plainTextTitle: title))
        }
        // Links
        items.append(.element(named: "ul", children: listItems))
        
        return items
    }
    
    private func _listItem(for element: LinkedElement) -> XMLElement {
        var items: [XMLNode]
        switch element.names {
        case .single(.conceptual(let title)):
            items = [.text(title)]
            
        case .single(.symbol(let title)):
            items = [ .element(named: "code", children: wordBreak(symbolName: title)) ]
            
        case .languageSpecificSymbol(let titlesByLanguage):
            let titlesByLanguage = RenderHelpers.sortedLanguageSpecificValues(titlesByLanguage)
            items = if titlesByLanguage.count == 1 {
                [ .element(named: "code", children: wordBreak(symbolName: titlesByLanguage.first!.value)) ]
            } else {
                titlesByLanguage.map { language, title in
                    .element(named: "code", children: wordBreak(symbolName: title), attributes: ["class": "\(language.id)-only"])
                }
            }
        }
        
        return .element(named: "li", children: [
            .element(named: "a", children: items, attributes: ["href": path(to: element.path)])
        ])
    }
}
