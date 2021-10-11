/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown

/// A type that can be initialized from markup.
public protocol MarkupConvertible {
    /// Initializes a new element with a given markup and source for a given documentation bundle and documentation context.
    ///
    /// - Parameters:
    ///   - markup: The markup that makes up this element's content.
    ///   - source: The location of the file that this element's content comes from.
    ///   - bundle: The documentation bundle that the element belongs to.
    ///   - context: The documentation context that the element belongs to.
    ///   - problems: A mutable collection of problems to update with any problem encountered while initializing the element.
    init?(from markup: Markup, source: URL?, for bundle: DocumentationBundle, in context: DocumentationContext, problems: inout [Problem])
}
