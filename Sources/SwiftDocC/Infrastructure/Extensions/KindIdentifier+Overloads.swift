/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2023 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import SymbolKit

extension SymbolGraph.Symbol.KindIdentifier {
    /// The kinds of symbols whose documentation pages should be grouped as overloads.
    static let overloadableKinds: Set<SymbolGraph.Symbol.KindIdentifier> = [
        .method,
        .typeMethod,
        .`func`,
        .`init`,
        .macro,
        .subscript,
        .`operator`
    ]
    
    /// Whether a string representing a symbol kind matches an overloadable symbol kind.
    static func isOverloadableKind(_ kind: String) -> Bool {
        return overloadableKinds.contains { $0.identifier == kind }
    }
}

