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

extension XMLNode {
    /// Creates a new XML element with the given name, child nodes, and attributes.
    package static func element(
        named name: String,
        children: [XMLNode]? = nil,
        attributes: [String: String]? = nil
    ) -> XMLElement {
        let attributeNodes: [XMLNode]?
        if let attributes, !attributes.isEmpty {
            attributeNodes = attributes.sorted(by: { $0.key < $1.key }).map {
                XMLNode.attribute(withName: $0.key, stringValue: $0.value) as! XMLNode
            }
        } else {
            attributeNodes = nil
        }
        
        return XMLNode.element(
            withName: name,
            children: children,
            attributes: attributeNodes
        ) as! XMLElement
    }
    
    /// Creates a new XML text node that wraps the given string.
    package static func text(_ value: some StringProtocol) -> XMLNode {
        XMLNode.text(withStringValue: String(value)) as! XMLNode
    }
}

extension XMLElement {
    /// Adds the given attributes to the element.
    func addAttributes(_ attributes: [String: String]) {
        let attributeNodes = attributes.sorted(by: { $0.key < $1.key }).map {
            XMLNode.attribute(withName: $0.key, stringValue: $0.value) as! XMLNode
        }
        for attributeNode in attributeNodes {
            self.addAttribute(attributeNode)
        }
    }
}
