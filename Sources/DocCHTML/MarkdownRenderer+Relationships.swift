/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2025-2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

package import Foundation

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
    func groupedListSection(named sectionName: String, groups lists: [SourceLanguage: [ListInfo]]) -> [HTMLNode] {
        let lists = RenderHelpers.sortedLanguageSpecificValues(lists)
        
        let items: [HTMLNode] = if lists.count == 1 {
            lists.first!.value.flatMap { list in
                _singleListGroupElements(for: list)
            }
        } else {
            // TODO: As a future improvement we could diff the references and only mark them as language-specific if the group and reference doesn't appear in all languages.
            lists.flatMap { language, taskGroups in
                let attributes = [language.filterAttribute]
                
                var elements = taskGroups.flatMap { _singleListGroupElements(for: $0) }
                for index in elements.indices {
                    elements[index]._addAttributes(attributes)
                }
                return elements
            }
        }
        
        return selfReferencingSection(named: sectionName, content: items)
    }
    
    private func _singleListGroupElements(for list: ListInfo) -> [HTMLNode] {
        let listItems = list.references.compactMap { reference in
            linkProvider.element(for: reference).map { _listItem(for: $0) }
        }
        // Don't return a title or abstract/discussion if this group has no links to display.
        guard !listItems.isEmpty else { return [] }
        
        var items: [HTMLNode] = []
        // Title
        if let title = list.title {
            items.append(selfReferencingHeading(level: 3, content: [.text(title)], plainTextTitle: title))
        }
        // Links
        items.append(ul(contents: listItems))
        
        return items
    }
    
    private func _listItem(for element: LinkedElement) -> HTMLNode {
        var items: [HTMLNode]
        switch element.names {
        case .single(.conceptual(let title)):
            items = [.text(title)]
            
        case .single(.symbol(let title)):
            items = [ code(contents: wordBreak(symbolName: title)) ]
            
        case .languageSpecificSymbol(let titlesByLanguage):
            let titlesByLanguage = RenderHelpers.sortedLanguageSpecificValues(titlesByLanguage)
            items = if titlesByLanguage.count == 1 {
                [ code(contents: wordBreak(symbolName: titlesByLanguage.first!.value)) ]
            } else {
                titlesByLanguage.map { language, title in
                    code(attributes: [language.filterAttribute], contents: wordBreak(symbolName: title))
                }
            }
        }
        
        return li(contents: [anchor(linkingTo: element, contents: items)])
    }
}
