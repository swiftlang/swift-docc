/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Markdown

/// Documentation about a parameter for a symbol.
public struct Parameter {
    /// The name of the parameter.
    public var name: String
    /// The content that describe the parameter.
    public var contents: [Markup]
    
    /// Initialize a value to describe documentation about a parameter for a symbol.
    /// - Parameters:
    ///   - name: The name of this parameter.
    ///   - contents: The content that describe this parameter.
    public init(name: String, contents: [Markup]) {
        self.name = name
        self.contents = contents
    }
}
