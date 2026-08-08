/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
public import Markdown

/// A section that contains deprecation information.
public struct DeprecatedSection: Section {
    public static let title: String? = "Deprecated"
    public var content: [any Markup]
    
    /// Creates a new deprecation section with the given markup content.
    public init(content: [any Markup]) {
        self.content = content
    }
    
    /// Creates a new deprecation section with the given plain text.
    public init(text: String) {
        self.content = [Paragraph(Text(text))]
    }
}
