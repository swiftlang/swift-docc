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
    struct ParameterInfo {
        package var name: String
        package var content: [any Markup]
        
        package init(name: String, content: [any Markup]) {
            self.name = name
            self.content = content
        }
    }
    
    func parameters(_ info: [SourceLanguage: [ParameterInfo]]) -> XMLElement {
        let info = RenderHelpers.sortedLanguageSpecificValues(info)
        let items: [XMLElement] = switch info.count {
        case 1:
            [_singleLanguageParameters(info.first!.value)] // Verified to exist above
            
        case 2:
            [_dualLanguageParameters(primary: info.first!, secondary: info.last!)] // Both verified to exist above
            
        default:
            // In practice DocC only encounters one or two different languages. If there would be a third one,
            // produce correct looking pages that may include duplicated markup by not trying to share parameters across languages.
            info.map { language, info in
                .element(
                    named: "dl",
                    children: _singleLanguageParameterItems(info),
                    attributes: ["class": "\(language.id)-only"]
                )
            }
        }
        
        return selfReferencingSection(named: "Parameters", content: items)
    }
    
    private func _singleLanguageParameters(_ parameterInfo: [ParameterInfo]) -> XMLElement {
        .element(named: "dl", children: _singleLanguageParameterItems(parameterInfo))
    }
    
    private func _singleLanguageParameterItems(_ parameterInfo: [ParameterInfo]) -> [XMLElement] {
        var items: [XMLElement] = []
        items.reserveCapacity(parameterInfo.count * 2)
        for parameter in parameterInfo {
            // name
            items.append(
                .element(named: "dt", children: [
                    .element(named: "code", children: [.text(parameter.name)])
                ])
            )
            // description
            items.append(
                .element(named: "dd", children: parameter.content.map { visit($0) })
            )
        }
        
        return items
    }
    
    private func _dualLanguageParameters(
        primary:   (key: SourceLanguage, value: [ParameterInfo]),
        secondary: (key: SourceLanguage, value: [ParameterInfo])
    ) -> XMLElement {
        // Shadow the parameters with more descriptive tuple labels
        let primary   = (language: primary.key,   parameters: primary.value)
        let secondary = (language: secondary.key, parameters: secondary.value)
        
        var items = _singleLanguageParameterItems(primary.parameters)
        
        let differences = secondary.parameters.difference(from: primary.parameters, by: { $0.name == $1.name })
        
        var primaryOnlyIndices = Set<Int>()
        
        for case let .remove(offset, _, _) in differences.removals {
            // This item only exists in the primary parameters
            primaryOnlyIndices.insert(offset)
            let index = offset * 2
            // Mark those items as only being applying to the first language
            items[index    ].addAttributes(["class": "\(primary.language.id)-only"])
            items[index + 1].addAttributes(["class": "\(primary.language.id)-only"])
        }
        
        for case let .insert(offset, parameter, _) in differences.insertions {
            // This parameter only exist in the secondary parameters.
            let index = (offset + primaryOnlyIndices.count(where: { $0 < offset })) * 2
            // Description first because we're appending twice
            items.insert(contentsOf: [
                // Name
                .element(named: "dt", children: [
                    .element(named: "code", children: [.text(parameter.name)])
                ], attributes: ["class": "\(secondary.language.id)-only"]),
                // Description
                .element(named: "dd", children: parameter.content.map { visit($0) }, attributes: ["class": "\(secondary.language.id)-only"])
            ], at: index)
        }
        
        return .element(named: "dl", children: items)
    }
}
