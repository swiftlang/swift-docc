/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Markdown

/// Any kind of `Markdown.Markup` element that has a `destination` property.
public protocol AnyLink: Markup {
    var destination: String? { get }
}

extension Link: AnyLink {}
extension SymbolLink: AnyLink {}
