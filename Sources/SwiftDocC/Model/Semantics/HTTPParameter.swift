/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2023 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Markdown
import SymbolKit

/// Documentation about a parameter for an HTTP request.
public struct HTTPParameter {
    /// The name of the parameter.
    public var name: String
    /// The source of the parameter, such as "query" or "path".
    /// 
    /// Value might be undefined initially when first extracted from markdown.
    public var source: String?
    /// The content that describe the parameter.
    public var contents: [Markup]
    /// The symbol graph symbol representing this parameter.
    public var symbol: SymbolGraph.Symbol?
    /// The required status of the parameter.
    public var required: Bool
    
    /// Initialize a value to describe documentation about a parameter for an HTTP request symbol.
    /// - Parameters:
    ///   - name: The name of this parameter.
    ///   - source: The source of this parameter, such as "query" or "path".
    ///   - contents: The content that describe this parameter.
    ///   - symbol: The symbol data extracted from the symbol graph.
    ///   - required: Flag indicating whether the parameter is required to be present in the request.
    public init(name: String, source: String?, contents: [Markup], symbol: SymbolGraph.Symbol? = nil, required: Bool = false) {
        self.name = name
        self.source = source
        self.contents = contents
        self.symbol = symbol
        self.required = required
    }
}
