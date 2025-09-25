/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

public import Foundation
public import Markdown

/// A type that can be initialized from markup.
public protocol MarkupConvertible {
    /// Initializes a new element with a given markup and source that's part of a given documentation catalog.
    ///
    /// - Parameters:
    ///   - markup: The markup that makes up this element's content.
    ///   - source: The location of the file that this element's content comes from.
    ///   - inputs: The collection of input files that the source file belongs to.
    ///   - problems: A mutable collection of problems to update with any problem encountered while initializing the element.
    init?(from markup: any Markup, source: URL?, for inputs: DocumentationContext.Inputs, problems: inout [Problem])
}
