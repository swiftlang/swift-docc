/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2026 Apple Inc. and the Swift project authors
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

/// Creates a new HTML from an XMLNode, or returns `nil` if the XMLNode doesn't represent an HTML element.
package extension HTMLNode {
    init?(from xmlNode: XMLNode) {
        if let element = xmlNode as? XMLElement {
            guard let name = xmlNode.name,
                  let tag = HTMLNode._Tag(rawValue: name.lowercased())
            else {
                return nil
            }
            
            let attributes = element.attributes?.compactMap {
                HTMLNode.Attribute($0)
            } ?? []
            
            if tag.isVoid {
                self = ._voidElement(tag, attributes: attributes)
            } else {
                let contents = xmlNode.children?.compactMap {
                    HTMLNode(from: $0)
                } ?? []
                self = ._element(tag, attributes: attributes, contents: contents)
            }
        } else if xmlNode.kind == .text, let text = xmlNode.stringValue {
            self = .text(text)
        } else {
            return nil
        }
    }
}

private extension HTMLNode.Attribute {
    init?(_ attribute: XMLNode) {
        assert(attribute.kind == .attribute)
        guard let name = attribute.name?.lowercased() else {
            return nil
        }
        
        self.name = name
        self.value = attribute.stringValue ?? ""
    }
}
