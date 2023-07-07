/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2023 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Markdown
import SymbolKit

/// Documentation about a dictionary key for a symbol.
public struct DictionaryKey {
    /// The name of the dictionary key.
    public var name: String
    /// The content that describe the dictionary key.
    public var contents: [Markup]
    /// The symbol graph symbol representing this dictionary key.
    public var symbol: SymbolGraph.Symbol?
    /// The required status of the dictionary key.
    public var required: Bool
    
    /// Initialize a value to describe documentation about a dictionary key for a symbol.
    /// - Parameters:
    ///   - name: The name of this dictionary key.
    ///   - contents: The content that describe this dictionary key.
    ///   - symbol: The symbol data extracted from the symbol graph.
    ///   - required: Flag indicating whether the key is required to be present in the dictionary.
    public init(name: String, contents: [Markup], symbol: SymbolGraph.Symbol? = nil, required: Bool = false) {
        self.name = name
        self.contents = contents
        self.symbol = symbol
        self.required = required
    }
}
