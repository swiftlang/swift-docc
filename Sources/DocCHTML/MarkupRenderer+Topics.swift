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
    struct TaskGroupInfo {
        package var title: String?
        package var content: [any Markup]
        package var references: [URL]
        
        package init(title: String?, content: [any Markup], references: [URL]) {
            self.title = title
            self.content = content
            self.references = references
        }
    }
    
    func groupedSection(named sectionName: String, groups taskGroups: [SourceLanguage: [TaskGroupInfo]]) -> XMLElement {
        let taskGroups = RenderHelpers.sortedLanguageSpecificValues(taskGroups)
        
        let items: [XMLElement] = if taskGroups.count == 1 {
            taskGroups.first!.value.flatMap { taskGroup in
                _singleTaskGroupElements(for: taskGroup)
            }
        } else {
            // TODO: As a future improvement we could diff the links and only mark add "class" attributes to the unique ones
            taskGroups.flatMap { language, taskGroups in
                let attribute = XMLNode.attribute(withName: "class", stringValue: "\(language.id)-only") as! XMLNode
                
                let elements = taskGroups.flatMap { _singleTaskGroupElements(for: $0) }
                for element in elements {
                    element.addAttribute(attribute)
                }
                return elements
            }
        }
        
        return selfReferencingSection(named: sectionName, content: items)
    }
    
    private func _singleTaskGroupElements(for taskGroup: TaskGroupInfo) -> [XMLElement] {
        let listItems = taskGroup.references.compactMap { reference in
            linkProvider.element(for: reference).map { _taskGroupItem(for: $0) }
        }
        // Don't return a title and abstract/discussion if this group has no links
        guard !listItems.isEmpty else { return [] }
        
        var items: [XMLElement] = []
        // Title
        if let title = taskGroup.title {
            items.append(selfReferencingHeading(level: 3, content: [.text(title)], plainTextTitle: title))
        }
        // Abstract/Discussion
        for markup in taskGroup.content {
            let rendered = visit(markup)
            if let element = rendered as? XMLElement {
                items.append(element)
            } else {
                // Wrap any inline content in an element. This is not expected to happen in practice
                items.append(.element(named: "p", children: [rendered]))
            }
        }
        // Links
        items.append(.element(named: "ul", children: listItems))
        
        return items
    }
    
    private func _taskGroupItem(for element: LinkedElement) -> XMLElement {
        var items: [XMLNode]
        switch element.subheadings {
        case .single(.conceptual(let title)):
            items = [.element(named: "p", children: [.text(title)])]
            
        case .single(.symbol(let fragments)):
            items = switch goal {
            case .conciseness:
                [ .element(named: "code", children: [.text(fragments.map(\.text).joined())]) ]
            case .richness:
                [ _symbolSubheading(fragments, languageFilter: nil) ]
            }
            break
            
        case .languageSpecificSymbol(let fragmentsByLanguage):
            let fragmentsByLanguage = RenderHelpers.sortedLanguageSpecificValues(fragmentsByLanguage)
            items = if fragmentsByLanguage.count == 1 {
                [ _symbolSubheading(fragmentsByLanguage.first!.value, languageFilter: nil) ]
            } else if goal == .conciseness, let fragments = fragmentsByLanguage.first?.value {
                [ _symbolSubheading(fragments, languageFilter: nil) ]
            } else {
                fragmentsByLanguage.map { language, fragments in
                    _symbolSubheading(fragments, languageFilter: language)
                }
            }
        }
        
        // Add the formatted abstract if the
        if let abstract = element.abstract {
            items.append(visit(abstract))
        }
        
        return .element(named: "li", children: [
            .element(named: "a", children: items, attributes: ["href": path(to: element.path)])
        ])
    }
    
    private func _symbolSubheading(_ fragments: [LinkedElement.SymbolNameFragment], languageFilter: SourceLanguage?) -> XMLElement {
        switch goal {
        case .richness:
            .element(
                named: "code",
                children: fragments.map {
                    .element(named: "span", children: wordBreak(symbolName: $0.text), attributes: ["class": $0.kind.rawValue])
                },
                attributes: languageFilter.map { ["class": "\($0.id)-only"] }
            )
        case .conciseness:
            .element(
                named: "code",
                children: [.text(fragments.map(\.text).joined())],
                attributes: languageFilter.map { ["class": "\($0.id)-only"] }
            )
        }
    }
}
