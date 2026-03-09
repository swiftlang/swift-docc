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

package import Markdown
package import DocCCommon

package extension MarkdownRenderer {
    /// Information about a task group that organizes other API into a hierarchy on this page.
    struct TaskGroupInfo {
        /// The title of this group of API
        package var title: String?
        /// Any additional free-form content that describes the group of API.
        package var content: [any Markup]
        /// A list of already resolved references that the renderer should display, in order, for this group.
        package var references: [URL]
        
        package init(title: String?, content: [any Markup], references: [URL]) {
            self.title = title
            self.content = content
            self.references = references
        }
    }
    
    /// Creates a grouped section with a given name, for example "topics" or "see also" that describes and organizes groups of related API.
    ///
    /// If each language representation of the API has its own task groups, pass the task groups for each language representation.
    ///
    /// If the API has the _same_ task groups in all language representations, only pass the task groups for one language.
    /// This produces a named section that doesn't hide any task groups for any of the languages (the same as if the symbol only had one language representation).
    func groupedSection(named sectionName: String, groups taskGroups: [SourceLanguage: [TaskGroupInfo]]) -> [XMLNode] {
        let taskGroups = RenderHelpers.sortedLanguageSpecificValues(taskGroups)
        
        let items: [XMLElement] = if taskGroups.count == 1 {
            taskGroups.first!.value.flatMap { taskGroup in
                _singleTaskGroupElements(for: taskGroup)
            }
        } else {
            // TODO: As a future improvement we could diff the references and only mark them as language-specific if the group and reference doesn't appear in all languages.
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
        // Don't return a title or abstract/discussion if this group has no links to display.
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
            
        case .languageSpecificSymbol(let fragmentsByLanguage):
            let fragmentsByLanguage = RenderHelpers.sortedLanguageSpecificValues(fragmentsByLanguage)
            items = if fragmentsByLanguage.count == 1 {
                [ _symbolSubheading(fragmentsByLanguage.first!.value, languageFilter: nil) ]
            } else if goal == .conciseness, let fragments = fragmentsByLanguage.first?.value {
                // On the rendered page, language specific symbol names _could_ be hidden through CSS but that wouldn't help the tool that reads the raw HTML.
                // So that tools don't need to filter out language specific names themselves, include only the primary language's subheading.
                [ _symbolSubheading(fragments, languageFilter: nil) ]
            } else {
                fragmentsByLanguage.map { language, fragments in
                    _symbolSubheading(fragments, languageFilter: language)
                }
            }
        }
        
        // Add the formatted abstract if the linked element has one.
        if let abstract = element.abstract {
            items.append(visit(abstract))
        }
        
        return .element(named: "li", children: [
            // Wrap both the name and the abstract in an anchor so that the entire item is a link to that page.
            .element(named: "a", children: items, attributes: ["href": path(to: element.path)])
        ])
    }
    
    /// Transforms the symbol name fragments into a `<code>` HTML element that represents a symbol's subheading.
    ///
    /// When the renderer has a ``RenderGoal/richness`` goal, it creates one `<span>` HTML element per fragment that could be styled differently through CSS:
    /// ```
    /// <code class="swift-only">
    ///   <span class="decorator">class </span>
    ///   <span class="identifier">Some<wbr/>Class</span>
    /// </code>
    /// ```
    ///
    /// When the renderer has a ``RenderGoal/conciseness`` goal, it joins the fragment's text into a single string:
    /// ```
    /// <code>class SomeClass</code>
    /// ```
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
