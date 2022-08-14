/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

struct DirectiveIndex {
    var indexedDirectives = Synchronized<[String : DirectiveMirror.ReflectedDirective]>([:])
    
    static var shared = DirectiveIndex()
    
    mutating func reflection(
        of directiveConvertible: AutomaticDirectiveConvertible.Type
    ) -> DirectiveMirror.ReflectedDirective {
        if let indexedDirective = indexedDirectives.sync({ $0[directiveConvertible.directiveName] }) {
            return indexedDirective
        } else {
            let reflectedDirective = DirectiveMirror(reflecting: directiveConvertible).reflectedDirective
            indexedDirectives.sync {
                $0[directiveConvertible.directiveName] = reflectedDirective
            }
            return reflectedDirective
        }
    }
}
