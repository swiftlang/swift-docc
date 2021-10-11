/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A type property source node.
class PropertyNode: TypeMemberNode {
    var isDynamic = false
    var type: String?
    var implementation: String?
    
    convenience init(kind: Kind, level: AccessLevel, bundle: OutputBundle, isDynamic: Bool, type: String? = nil) {
        self.init(kind: kind, level: level, bundle: bundle)
        self.isDynamic = isDynamic
        self.type = type
    }

    let typesAndValues: [(String, String)] = [
        ("String", "\"Test value\""),
        ("Int", "1024"),
        ("Bool", "true"),
        ("CGFloat", "108.34")
    ]

    override class func keyword() -> String { return "var" }

    override func source() -> String {
        var propertyType: String
        var propertyValue: String
        
        if let type = self.type {
            propertyType = "\(type)?"
            propertyValue = "nil"
        } else {
            let index = Self.counter % typesAndValues.count
            propertyType = typesAndValues[index].0
            propertyValue = typesAndValues[index].1
        }
        
        var result = ""
        
        let kindString = (kind == .instance || kind == .interface) ? "" : kind.rawValue
        let levelString = (level == .default) ? "" : level.rawValue
        
        result += Text.docs(for: name, bundle: bundle, sections: [.abstract])
        if isDynamic {
            result += "\(levelString) \(kindString) var \(name.lowercased()): \(propertyType) { return \(propertyType)(\(propertyValue)) }\n"
        } else {
            result += "\(levelString) \(kindString) var \(name.lowercased()): \(propertyType) = \(propertyValue)\n"
        }
        
        if kind == .interface {
            implementation = result
            result = "var \(name.lowercased()): \(propertyType) { get set }\n"
        }
        
        return result
    }
}
