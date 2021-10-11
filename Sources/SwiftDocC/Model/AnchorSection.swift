/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown

/// Section of a document that can be linked to.
public struct AnchorSection {
    /// The unique reference to the section.
    public var reference: ResolvedTopicReference
    
    /// The title of the section.
    public var title: String
}
