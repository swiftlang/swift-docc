/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

// https://forums.swift.org/t/challenge-finding-base-type-of-nested-optionals/25096/8
protocol OptionallyWrapped {
    static func baseType() -> Any.Type
    func baseType() -> Any.Type
}

extension Optional: OptionallyWrapped {
    static func baseType() -> Any.Type {
        switch Wrapped.self {
        case let wrapper as OptionallyWrapped.Type:
            return wrapper.baseType()
        default:
            return Wrapped.self
        }
    }

    func baseType() -> Any.Type {
        switch self {
        case .some(let wrapper as OptionallyWrapped):
            return wrapper.baseType()
        case .some(let wrapped):
            return type(of: wrapped)
        case .none:
            return Optional.baseType()
        }
    }
}
