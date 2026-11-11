/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

package import Markdown

/// A type that parses a BlockDirective and provides its relevant arguments back so it can be rendered.
///
/// This protocol is intended to be used for _renderable_ directives that represent on-page content.
package protocol RenderableDirectiveParser {
    /// Parses and provides information about the block directive, or throws if the block directive can't be parsed.
    func parse(blockDirective: BlockDirective) -> RenderableDirective?
}

/// Information about a block directive whose arguments and children the SwiftDocC module has already parsed and validated.
package enum RenderableDirective {
    case small
    case image(source: String, alt: String?, caption: [any Markup] /* TODO: Support device frames*/)
    case row(columns: [(size: Int, alignment: ColumnAlignment, content: [any Markup])])
}

package enum ColumnAlignment {
    case leading
    case center
    case trailing
}
