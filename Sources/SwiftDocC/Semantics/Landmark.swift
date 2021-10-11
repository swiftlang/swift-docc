/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Markdown

/// A linkable point on a page.
public protocol Landmark {
    /// The document cursor range that the landmark contains.
    var range: SourceRange? { get }
    
    /// The title of the landmark.
    var title: String { get }
    
    /// The content of the landmark.
    var markup: Markup { get }
}

extension Heading: Landmark {
    public var title: String {
        return plainText
    }
    public var markup: Markup {
        return self
    }
}
