/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// An enum source node.
class EnumNode: TypeNode {
    override class func keyword() -> String { return "enum" }
    
    override func source() -> String {
        var result = super.source()
        let closingBracket = result.index(before: result.lastIndex(of: "}")!)
        result.replaceSubrange(closingBracket..<result.endIndex, with: "\n\n")
        for caseName in ["one", "two", "three"] {
            result.append(Text.docs(for: caseName, bundle: bundle, sections: [.abstract]))
            result.append("case \(caseName)\n")
        }
        result.append("}\n\n")
        return result
    }
}
