/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SymbolKit

extension DeclarationRenderSection.Token {
    /// Creates a new declaration token.
    /// - Parameters:
    ///   - fragment: The symbol-graph declaration fragment to render.
    ///   - identifier: An optional reference to a symbol.
    init(fragment: SymbolKit.SymbolGraph.Symbol.DeclarationFragments.Fragment, identifier: String?) {
        self.text = fragment.spelling
        self.kind = Kind(rawValue: fragment.kind.rawValue) ?? .text
        self.identifier = identifier
        self.preciseIdentifier = fragment.preciseIdentifier
    }
}
