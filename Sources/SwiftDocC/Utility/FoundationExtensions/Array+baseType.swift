/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

protocol CollectionWrapped {
    static func baseType() -> Any.Type
}

extension Array: CollectionWrapped {
    static func baseType() -> Any.Type {
        return Element.self
    }
}
