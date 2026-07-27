/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

package struct HTMLNode: Sendable {
    // This type should be though of as opaque with a file-private implementation.
    // However, to avoid needing to define the formatting and parsing of HTML all in this file,
    // it's implementation is accessible within this module.
    
    enum _Storage {
        case text(String)
        // We intentionally don't model comments because we don't want them to appear in the output.
        case element(    _Tag, attributes: [Attribute], contents: [HTMLNode])
        case voidElement(_Tag, attributes: [Attribute])
    }
    var _storage: _Storage
    
    /// Creates a new HTML text node.
    package static func text(_ text: consuming String) -> HTMLNode {
        .init(_storage: .text(text))
    }

    static func _element(_ tag: _Tag, attributes: [Attribute] = [], contents: [HTMLNode]) -> HTMLNode {
        assert(!tag.isVoid, "Cannot create an element using void tag '\(tag)'. Use `._voidElement(...)` instead.")
        assert(attributes.count == Set(attributes.map { $0.name.description.lowercased() }).count, {
            let duplicateAttributes = attributes.filter {
                let name = $0.name.description.lowercased()
                return attributes.count(where: { $0.name.description.lowercased() == name }) > 1
            }
            return "All attribute names has to be case insensitively unique. This wasn't true for \(duplicateAttributes)."
        }())
        return .init(_storage: .element(tag, attributes: attributes, contents: contents))
    }
    
    static func _voidElement(_ tag: _Tag, attributes: [Attribute] = []) -> HTMLNode {
        assert(tag.isVoid, "Cannot create a void element using non-void tag '\(tag)'. Use `._element(...)` instead.")
        return .init(_storage: .voidElement(tag, attributes: attributes))
    }
    
    var _tag: _Tag? {
        switch _storage {
            case .element(    let tag, _, _),
                 .voidElement(let tag, _): tag
            case .text:                    nil
        }
    }
    
    var _isText: Bool {
        switch _storage {
            case .text:                  true
            case .element, .voidElement: false
        }
    }
}

private extension HTMLNode._Tag {
    var isVoid: Bool {
        switch self {
            case .base, .link, .meta,                  // Metadata
                 .hr,                                  // Grouping
                 .br, .wbr,                            // Text-level semantics
                 .source, .img, .embed, .track, .area, // Embedded
                 .col,                                 // Tables
                 .input:                               // Forms
                     true
            default: false
        }
    }
}
