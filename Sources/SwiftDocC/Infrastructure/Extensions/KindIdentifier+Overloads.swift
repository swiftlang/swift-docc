/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2023-2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import SymbolKit

extension SymbolGraph.Symbol.KindIdentifier {
    /// Whether the kind supports grouping as overloads.
    var isOverloadableKind: Bool {
        switch self {
        case .method,
             .typeMethod,
             .`func`,
             .`init`,
             .macro,
             .subscript,
             .`operator`:
            return true
        default:
            return false
        }
    }
}

