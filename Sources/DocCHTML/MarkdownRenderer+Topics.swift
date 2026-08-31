/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2025-2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

package import struct Foundation.URL
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
    func groupedSection(named sectionName: String, groups taskGroups: [SourceLanguage: [TaskGroupInfo]]) -> [HTMLNode] {
        let taskGroups = RenderHelpers.sortedLanguageSpecificValues(taskGroups)
        
        let items: [HTMLNode] = if taskGroups.count == 1 {
            taskGroups.first!.value.flatMap { taskGroup in
                _singleTaskGroupElements(for: taskGroup)
            }
        } else {
            // TODO: As a future improvement we could diff the references and only mark them as language-specific if the group and reference doesn't appear in all languages.
            taskGroups.flatMap { language, taskGroups in
                let attributes = [language.filterAttribute]
                
                var elements = taskGroups.flatMap { _singleTaskGroupElements(for: $0) }
                for index in elements.indices {
                    elements[index]._addAttributes(attributes)
                }
                return elements
            }
        }
        
        return selfReferencingSection(named: sectionName, content: items)
    }
    
    private func _singleTaskGroupElements(for taskGroup: TaskGroupInfo) -> [HTMLNode] {
        let listItems = taskGroup.references.compactMap { reference in
            linkProvider.element(for: reference).map { _taskGroupItem(for: $0) }
        }
        // Don't return a title or abstract/discussion if this group has no links to display.
        guard !listItems.isEmpty else { return [] }
        
        var items: [HTMLNode] = []
        // Title
        if let title = taskGroup.title {
            items.append(selfReferencingHeading(level: 3, content: [.text(title)], plainTextTitle: title))
        }
        // Abstract/Discussion
        for markup in taskGroup.content {
            let rendered = visit(markup)
            if rendered._isText {
                // Wrap any inline content in an element. This is not expected to happen in practice
                items.append(p(contents: [rendered]))
            } else {
                items.append(rendered)
            }
        }
        // Links
        items.append(ul(contents: listItems))
        
        return items
    }
    
    private func _taskGroupItem(for element: LinkedElement) -> HTMLNode {
        let items: [HTMLNode]
        switch element.subheadings {
        case .single(.conceptual(let title)):
            // TODO: Pass information about the type of icon that the conceptual element should display.
            let item = p(attributes: goal == .richness ? [.class("api-collection")] : [], contents: [.text(title)])
            items = [item]
            
        case .single(.symbol(let fragments)):
            items = switch goal {
            case .conciseness:
                [ code(contents: [.text(fragments.map(\.text).joined())]) ]
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
        
        var content = [
            // DocC-Render only makes the item's name an anchor, not its abstract
            anchor(linkingTo: element, contents: items)
        ]
        
        // Add the formatted abstract if the linked element has one.
        if let abstract = element.abstract {
            content.append(visit(abstract))
        }
        
        return li(contents: content)
    }
    
    /// Transforms the symbol name fragments into a `<code>` HTML element that represents a symbol's subheading.
    ///
    /// When the renderer has a ``RenderGoal/richness`` goal, it creates one `<span>` HTML element per fragment that could be styled differently through CSS:
    /// ```
    /// <code class="swift-only">
    ///   <span class="decorator">class </span>
    ///   <span class="identifier">Some<wbr>Class</span>
    /// </code>
    /// ```
    ///
    /// When the renderer has a ``RenderGoal/conciseness`` goal, it joins the fragment's text into a single string:
    /// ```
    /// <code>class SomeClass</code>
    /// ```
    private func _symbolSubheading(_ fragments: [LinkedElement.SymbolNameFragment], languageFilter: SourceLanguage?) -> HTMLNode {
        let attributes = languageFilter.map { [$0.filterAttribute] } ?? []
        return switch goal {
        case .richness:
            code(attributes: attributes, contents: fragments.map {
                span(attributes: [.class($0.kind.rawValue)], contents: wordBreak(symbolName: $0.text))
            })
        case .conciseness:
            code(attributes: attributes, contents: [.text(fragments.map(\.text).joined())])
        }
    }
}
