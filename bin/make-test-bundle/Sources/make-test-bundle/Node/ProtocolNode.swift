/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A protocol source node.
class ProtocolNode: TypeNode {
    var implementations = [String]()

    override class func keyword() -> String { return "protocol" }
    
    override func source() -> String {
        var result = ""
        result += Text.docs(for: name, bundle: bundle)
        result += "public \(Self.keyword()) \(name) {\n"
        
        // Properties
        if nested.contains(.property) {
            result += (0...5).reduce("") { result, _ -> String in
                let property = PropertyNode(kind: .interface, level: .public, bundle: bundle, isDynamic: false)
                defer { property.implementation.map { implementations.append($0) } }
                return result.appending(property.source())
            }
        }
        
        // Methods
        if nested.contains(.method) {
            result += (0...5).reduce("") { result, _ -> String in
                let method = MethodNode(kind: .interface, level: .public, bundle: bundle)
                defer { method.implementation.map { implementations.append($0) } }
                return result.appending(method.source())
            }
        }
        
        result += "}\n\n"
        return result
    }
    
    func `extension`() -> String {
        var result = ""
        result += Text.docs(for: name, bundle: bundle)
        result += "public extension \(name) {\n"
        
        // Default implementations for non-required methods
        if nested.contains(.method) {
            result += (0...5).reduce("") { result, _ -> String in
                let method = MethodNode(kind: .instance, level: .default, bundle: bundle)
                return result.appending(method.source())
            }
        }
        
        result += "}\n\n"
        return result
    }
}
