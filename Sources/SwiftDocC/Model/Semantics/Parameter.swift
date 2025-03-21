/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

public import Markdown

/// Documentation about a parameter for a symbol.
public struct Parameter {
    /// The name of the parameter.
    public var name: String
    /// The content that describe the parameter.
    public var contents: [Markup]
    /// The text range where the parameter name was parsed.
    var nameRange: SourceRange?
    /// The text range where this parameter was parsed.
    var range: SourceRange?
    /// Whether the parameter is documented standalone or as a member of a parameters outline.
    var isStandalone: Bool
    
    /// Initialize a value to describe documentation about a parameter for a symbol.
    /// - Parameters:
    ///   - name: The name of this parameter.
    ///   - contents: The content that describe this parameter.
    ///   - nameRange: The text range where the parameter name was parsed.
    ///   - range: The text range where this parameter was parsed.
    ///   - isStandalone: Whether the parameter is documented standalone or as a member of a parameters outline.
    public init(name: String, nameRange: SourceRange? = nil, contents: [Markup], range: SourceRange? = nil, isStandalone: Bool = false) {
        self.name = name
        self.nameRange = nameRange
        self.contents = contents
        self.range = range
        self.isStandalone = isStandalone
    }

    /// Initialize a value to describe documentation about a symbol's parameter via a Doxygen `\param` command.
    ///
    /// - Parameter doxygenParameter: A parsed Doxygen `\param` command.
    public init(_ doxygenParameter: DoxygenParameter) {
        self.name = doxygenParameter.name
        self.nameRange = nil
        self.contents = Array(doxygenParameter.children)
        self.range = doxygenParameter.range
        self.isStandalone = true // Each Doxygen parameter has a `\param` command.
    }
}
