/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown

/// A type that can be initialized from markup.
public protocol MarkupConvertible {
    /// Initializes a new element with a given markup and source that's part of a given documentation bundle.
    ///
    /// - Parameters:
    ///   - markup: The markup that makes up this element's content.
    ///   - source: The location of the file that this element's content comes from.
    ///   - bundle: The documentation bundle that the source file belongs to.
    ///   - problems: A mutable collection of problems to update with any problem encountered while initializing the element.
    init?(from markup: Markup, source: URL?, for bundle: DocumentationBundle, problems: inout [Problem])
    
    @available(*, deprecated, renamed: "init(from:source:for:problems:)", message: "Use 'init(from:source:for:problems:)' instead. This deprecated API will be removed after 6.2 is released")
    init?(from markup: Markup, source: URL?, for bundle: DocumentationBundle, in context: DocumentationContext, problems: inout [Problem])
}

public extension MarkupConvertible {
    // Default implementation to avoid source breaking changes. Remove this after 6.2 is released.
    init?(from markup: Markup, source: URL?, for bundle: DocumentationBundle, problems: inout [Problem]) {
        fatalError("Markup convertible type doesn't implement either 'init(from:source:for:problems:)' or 'init(from:source:for:in:problems:)'")
    }
    
    // Default implementation to new types don't need to implement a deprecated initializer. Remove this after 6.2 is released.
    init?(from markup: Markup, source: URL?, for bundle: DocumentationBundle, in context: DocumentationContext, problems: inout [Problem]) {
        self.init(from: markup, source: source, for: bundle, problems: &problems)
    }
}
