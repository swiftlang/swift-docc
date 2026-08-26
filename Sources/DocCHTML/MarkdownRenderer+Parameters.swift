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
    /// Information about a specific parameter for a piece of API.
    struct ParameterInfo {
        /// The name of the parameter.
        package var name: String
        /// The markdown content that describes the parameter.
        package var content: [any Markup]
        
        package init(name: String, content: [any Markup]) {
            self.name = name
            self.content = content
        }
    }
    
    /// Creates a "parameters" section that describes all the parameters for a symbol.
    ///
    /// If each language representation of the symbol has its own language-specific parameters, pass the parameter information for all language representations.
    ///
    /// If all language representations of the symbol have the _same_ parameters, only pass the parameter information for one language.
    /// This produces a "parameters" section that doesn't hide any parameters for any of the languages (same as if the symbol only had one language representation)
    func parameters(_ info: [SourceLanguage: [ParameterInfo]]) -> [HTMLNode] {
        let info = RenderHelpers.sortedLanguageSpecificValues(info)
        guard info.contains(where: { _, parameters in !parameters.isEmpty }) else {
            // Don't create a section if there are no parameters to describe.
            return []
        }
        
        let items: [HTMLNode] = switch info.count {
        case 1:
            [_singleLanguageParameters(info.first!.value)]
            
        case 2:
            [_dualLanguageParameters(primary: info.first!, secondary: info.last!)]
            
        default:
            // In practice DocC only encounters one or two different languages. If there would be a third one,
            // produce correct looking pages that may include duplicated markup by not trying to share parameters across languages.
            info.map { language, info in
                dl(attributes: [language.filterAttribute], contents: _singleLanguageParameterItems(info))
            }
        }
        
        return selfReferencingSection(named: "Parameters", content: items)
    }
    
    private func _singleLanguageParameters(_ parameterInfo: [ParameterInfo]) -> HTMLNode {
        dl(contents: _singleLanguageParameterItems(parameterInfo))
    }
    
    private func _singleLanguageParameterItems(_ parameterInfo: [ParameterInfo]) -> [HTMLNode] {
        // When there's only a single language representation, create a list of `<dt>` and `<dd>` HTML elements ("terms" and "definitions" in a "description list" (`<dl> HTML element`)
        var items: [HTMLNode] = []
        items.reserveCapacity(parameterInfo.count * 2)
        for parameter in parameterInfo {
            // name
            items.append(
                dt(contents: [.text(parameter.name)])
            )
            // description
            items.append(
                dd(contents: parameter.content.map { visit($0) })
            )
        }
        
        return items
    }
    
    private func _dualLanguageParameters(
        primary:   (key: SourceLanguage, value: [ParameterInfo]),
        secondary: (key: SourceLanguage, value: [ParameterInfo])
    ) -> HTMLNode {
        // "Shadow" the parameters with more descriptive tuple labels
        let primary   = (language: primary.key,   parameters: primary.value)
        let secondary = (language: secondary.key, parameters: secondary.value)
        
        // When there are exactly two language representations, which is very common,
        // avoid duplication and only create `<dt>` and `<dd>` HTML elements _once_ if the parameter exist in both language representations.
        
        // Start by rendering the primary language's parameter, then update that list with information about language-specific parameters.
        var items = _singleLanguageParameterItems(primary.parameters)
        
        // Find all the inserted and deleted parameters.
        // This assumes that parameters appear in the same _order_ in each language representation, which is true in practice.
        // If that assumption is wrong, it will produce correct looking results but some repeated markup.
        // TODO: Consider adding a debug assertion that verifies the order and a test that verifies the output of out-of-order parameter names.
        let differences = secondary.parameters.difference(from: primary.parameters, by: { $0.name == $1.name })
        
        // Track which parameters _only_ exist in the primary language in order to insert the secondary languages's _unique_ parameters in the right locations.
        var primaryOnlyIndices = Set<Int>()
        
        // Add a "class" attribute to the parameters that only exist in the secondary language representation.
        // Through CSS, the rendered page can show and hide HTML elements that only apply to a specific language representation.
        let primaryLanguageFilter = [primary.language.filterAttribute]
        for case let .remove(offset, _, _) in differences.removals {
            // This item only exists in the primary parameters
            primaryOnlyIndices.insert(offset)
            let index = offset * 2
            // Mark those items as only being applying to the first language
            items[index    ]._addAttributes(primaryLanguageFilter)
            items[index + 1]._addAttributes(primaryLanguageFilter)
        }
        
        // Insert parameter that only exists in the secondary language representation.
        let secondaryLanguageFilter = [secondary.language.filterAttribute]
        for case let .insert(offset, parameter, _) in differences.insertions {
            // Account for any primary-only parameters that appear before this (times 2 because each parameter has a `<dt>` and `<dd>` HTML element)
            let index = (offset + primaryOnlyIndices.count(where: { $0 < offset })) * 2
            items.insert(contentsOf: [
                // Name
                dt(attributes: secondaryLanguageFilter, contents: [.text(parameter.name)]),
                // Description
                dd(attributes: secondaryLanguageFilter, contents: parameter.content.map { visit($0) })
            ], at: index)
        }
        
        return dl(contents: items)
    }
}
