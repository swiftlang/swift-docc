/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A function source node.
class MethodNode: TypeMemberNode {
    var implementation: String?
    
    override class func keyword() -> String { return "func" }
    
    override func source() -> String {
        var result = ""
        result += Text.docs(for: name, bundle: bundle, sections: [.abstract, .discussion])

        let kindString = (kind == .instance || kind == .interface) ? "" : kind.rawValue
        let levelString = level == .default ? "" : level.rawValue
        
        result += "\(levelString) \(kindString) func \(name.lowercased())() { /* code */ }\n\n"
        
        if kind == .interface {
            implementation = result
            result = "func \(name.lowercased())()\n\n"
        }
        
        return result
    }
}
