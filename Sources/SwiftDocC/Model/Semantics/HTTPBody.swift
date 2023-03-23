/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2023 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Markdown
import SymbolKit

/// Documentation about the payload body of an HTTP request.
public struct HTTPBody {
    /// The media type of the body.
    /// 
    /// Value might be undefined initially when first extracted from markdown.
    public var mediaType: String?
    /// The content that describe the body.
    public var contents: [Markup]
    /// The symbol graph symbol representing this body.
    public var symbol: SymbolGraph.Symbol?
    
    /// Initialize a value to describe documentation about a payload body for an HTTP request symbol.
    /// - Parameters:
    ///   - mediaType: The media type of the body.
    ///   - contents: The content that describe this body.
    ///   - symbol: The symbol data extracted from the symbol graph.
    public init(mediaType: String?, contents: [Markup], symbol: SymbolGraph.Symbol? = nil) {
        self.mediaType = mediaType
        self.contents = contents
        self.symbol = symbol
    }
}
