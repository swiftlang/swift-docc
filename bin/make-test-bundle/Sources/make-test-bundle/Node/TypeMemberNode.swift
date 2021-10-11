/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A type member source node.
class TypeMemberNode {
    enum Kind: String {
        case instance, `static`, `class`, `interface`
    }
    
    enum AccessLevel: String {
        case `public`, `open`
        case `default` = ""
    }
    
    class func keyword() -> String { fatalError() }
    
    static var counter = 0
    let name: String
    let bundle: OutputBundle
    let kind: Kind
    let level: AccessLevel
    
    init(kind: Kind, level: AccessLevel, bundle: OutputBundle) {
        Self.counter += 1
        let word = words.next()
        self.name = word.titleCase.appending("\(Self.counter)")
        self.kind = kind
        self.level = level
        self.bundle = bundle
    }
    
    func source() -> String { fatalError() }
}
