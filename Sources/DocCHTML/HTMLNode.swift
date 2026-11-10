/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

private import DocCCommon

package struct HTMLNode: Sendable {
    // This type should be though of as opaque with a file-private implementation.
    // However, to avoid needing to define the formatting and parsing of HTML all in this file,
    // it's implementation is accessible within this module.
    
    enum _Storage {
        case text(String)
        // We intentionally don't model comments because we don't want them to appear in the output.
        case element(    _Tag, attributes: [Attribute], contents: [HTMLNode])
        case voidElement(_Tag, attributes: [Attribute])
        // Several sibling nodes without a containing element. See `_fragment(_:)`.
        case fragment([HTMLNode])
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
        return .init(_storage: .element(tag, attributes: attributes, contents: _flatteningFragments(contents)))
    }
    
    /// Creates a fragment of several sibling nodes.
    ///
    /// Creating an element replaces the fragment in its contents with these nodes.
    /// Don't put a fragment directly in the contents of `ul`, `ol`, `dl`, `tr`, or other helpers that assert which tags their contents have.
    /// Those helpers check the tags before the fragment is flattened.
    static func _fragment(_ nodes: [HTMLNode]) -> HTMLNode {
        .init(_storage: .fragment(_flatteningFragments(nodes)))
    }
    
    /// Returns the given nodes with each fragment replaced by the fragment's nodes.
    private static func _flatteningFragments(_ nodes: [HTMLNode]) -> [HTMLNode] {
        // Fragments are rare. Avoid allocating a new array when there are none.
        guard nodes.contains(where: \._isFragment) else {
            return nodes
        }
        var flattened: [HTMLNode] = []
        flattened.reserveCapacity(nodes.count)
        for node in nodes {
            if case .fragment(let children) = node._storage {
                flattened.append(contentsOf: children) // Already flattened when the fragment was created.
            } else {
                flattened.append(node)
            }
        }
        return flattened
    }
    
    static func _voidElement(_ tag: _Tag, attributes: [Attribute] = []) -> HTMLNode {
        assert(tag.isVoid, "Cannot create a void element using non-void tag '\(tag)'. Use `._element(...)` instead.")
        return .init(_storage: .voidElement(tag, attributes: attributes))
    }
    
    var _tag: _Tag? {
        switch _storage {
            case .element(    let tag, _, _),
                 .voidElement(let tag, _): tag
            case .text, .fragment:         nil
        }
    }
    
    var _isText: Bool {
        switch _storage {
            case .text:                             true
            case .element, .voidElement, .fragment: false
        }
    }
    
    var _isFragment: Bool {
        switch _storage {
            case .fragment:                     true
            case .text, .element, .voidElement: false
        }
    }
    
    mutating func _addAttributes(_ newAttributes: [Attribute]) {
        switch _storage {
        case .text:
            return
        case .element(let tag, let attributes, let contents):
            _storage = .element(tag, attributes: attributes + newAttributes, contents: contents)
        case .voidElement(let tag, let attributes):
            _storage = .voidElement(tag, attributes: attributes + newAttributes)
        case .fragment(var nodes):
            for index in nodes.indices {
                nodes[index]._addAttributes(newAttributes)
            }
            _storage = .fragment(nodes)
        }
    }
}

extension HTMLNode._Tag {
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

extension HTMLNode: TermListDetectableInline {
    var termListPlainText: String? {
        if case .text(let text) = _storage { text } else { nil }
    }
    
    init(termListPlainText: String) {
        self = .text(termListPlainText)
    }
}
