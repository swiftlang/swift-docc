/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import SymbolKit

extension SymbolGraph.Symbol.KindIdentifier {
    /// The kinds of symbols that should not generate pages in the documentation hierarchy.
    static let noPageKinds: [SymbolGraph.Symbol.KindIdentifier] = [
        .module,
        .snippet,
        .snippetGroup
    ]

    /// Indicates whether this kind of symbol should generate a page.
    func symbolGeneratesPage() -> Bool {
        !Self.noPageKinds.contains(self)
    }
}
