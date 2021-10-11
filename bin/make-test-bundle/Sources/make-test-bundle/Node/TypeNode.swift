/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A type source node.
class TypeNode {
    let childMultiplier = 10
    
    enum NestedMembers: String {
        case `protocol`, `struct`, `enum`, `property`, `method`
    }
    
    static var counter = 0
    static var index = [String: TypeNode]()
    
    let name: String
    let bundle: OutputBundle
    let nested: [NestedMembers]
    let implements: [ProtocolNode]
    let parentPath: String
    var childNames = [String]()
    
    var collectedExtensions = [MarkupFile]()
    
    init(nested: [NestedMembers], implements: [ProtocolNode] = [], parentPath: String, bundle: OutputBundle) {
        Self.counter += 1
        let word = words.next()
        self.name = word.titleCase.appending("\(Self.counter)")
        self.nested = nested
        self.bundle = bundle
        self.implements = implements
        self.parentPath = parentPath
        Self.index["\(parentPath)/\(name)"] = self
    }

    class func keyword() -> String { fatalError() }

    func source() -> String {
        let implementsString = implements.isEmpty ? "" : ": ".appending(implements.map({ $0.name }).joined(separator: ","))
        
        var result = ""
        result += Text.docs(for: name, bundle: bundle)
        result += "public \(Self.keyword()) \(name) \(implementsString) {\n"
        
        // Nested Types
        
        var nestedTypeNames = [String]()
        for _ in 0...3 {
            // Add nested structs
            if nested.contains(.struct) {
                let structNode = StructNode(nested: [.property, .method], parentPath: "\(parentPath)/\(name)", bundle: bundle)
                nestedTypeNames.append(structNode.name)
                result.append(structNode.source())
                
                let ext = MarkupFile(kind: .docExt("\(structNode.parentPath)/\(structNode.name)"), bundle: bundle)
                collectedExtensions.append(ext)
            }
            
            // Add nested enums
            if nested.contains(.enum) {
                let enumNode = EnumNode(nested: [.property, .method], parentPath: "\(parentPath)/\(name)", bundle: bundle)
                nestedTypeNames.append(enumNode.name)
                result.append(enumNode.source())

                let ext = MarkupFile(kind: .docExt("\(enumNode.parentPath)/\(enumNode.name)"), bundle: bundle)
                collectedExtensions.append(ext)
            }
        }
        
        // Properties
        if nested.contains(.property) {
            result += (0...childMultiplier).reduce("") { result, _ -> String in
                let property = PropertyNode(kind: .static, level: .public, bundle: bundle, isDynamic: false)
                childNames.append(property.name.lowercased())
                return result.appending(property.source())
            }
            result += (0...childMultiplier).reduce("") { result, _ -> String in
                let property = PropertyNode(kind: .instance, level: .public, bundle: bundle, isDynamic: true)
                childNames.append(property.name.lowercased())
                return result.appending(property.source())
            }

            result += nestedTypeNames.reduce("", { result, name -> String in
                let property = PropertyNode(kind: .instance, level: .public, bundle: bundle, isDynamic: false, type: name)
                childNames.append(property.name.lowercased())
                return result.appending(property.source())
            })

        }
        
        // Methods
        if nested.contains(.method) {
            result += (0...childMultiplier).reduce("") { result, _ -> String in
                let method = MethodNode(kind: .static, level: .public, bundle: bundle)
                childNames.append("\(method.name.lowercased())()")
                return result.appending(method.source())
            }
            result += (0...childMultiplier).reduce("") { result, _ -> String in
                let method = MethodNode(kind: .instance, level: .public, bundle: bundle)
                childNames.append("\(method.name.lowercased())()")
                return result.appending(method.source())
            }
        }
        
        // Protocol implementations
        for proto in implements {
            result += "// \(proto.name) implementations\n"
            result += proto.implementations.joined(separator: "\n").appending("\n")
        }
        
        result += "}\n\n"
        return result
    }
}
