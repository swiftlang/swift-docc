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

package extension MarkupRenderer {
    struct AvailabilityInfo {
        package var name: String
        package var introduced, deprecated: String?
        package var isBeta: Bool
        
        package init(name: String, introduced: String? = nil, deprecated: String? = nil, isBeta: Bool) {
            self.name = name
            self.introduced = introduced
            self.deprecated = deprecated
            self.isBeta = isBeta
        }
    }
    
    /// Creates an HTML element for the availability information.
    func availability(_ info: [AvailabilityInfo]) -> XMLNode {
        let items: [XMLNode] = info.map {
            var text = $0.name
            
            let description: String
            if let introduced = $0.introduced {
                if let deprecated  = $0.deprecated{
                    text += " \(introduced)–\(deprecated)"
                    description = "Introduced in \($0.name) \(introduced) and deprecated in \($0.name) \(deprecated)"
                } else {
                    text += " \(introduced)+"
                    description = "Available on \(introduced) and later"
                }
            } else {
                description = "Available on \($0.name)"
            }
            
            var attributes = [
                "role": "text",
                "aria-label": "\(text), \(description)",
                "title": description
            ]
            if $0.isBeta {
                attributes["class"] = "beta"
            } else if $0.deprecated != nil {
                attributes["class"] = "deprecated"
            }
            
            return .element(named: "li", children: [.text(text)], attributes: attributes)
        }
        
        return .element(
            named: "ul",
            children: items,
            attributes: ["id": "availability"]
        )
    }
}
