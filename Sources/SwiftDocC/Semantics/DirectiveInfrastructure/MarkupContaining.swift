/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Markdown

/// A directive convertible that contains markup.
protocol MarkupContaining: DirectiveConvertible {
    /// The markup contained by this directive.
    ///
    /// This property does not necessarily return the markup contained only by this directive, it may
    /// be the concatenated markup contained by all of this directive's directive children.
    var childMarkup: [Markup] { get }
}
