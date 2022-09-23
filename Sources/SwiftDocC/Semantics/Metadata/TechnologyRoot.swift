/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown

/// A directive to set this page as a documentation root-level node.
///
/// This directive is only valid within a top-level ``Metadata`` directive:
/// ```
/// @Metadata {
///    @TechnologyRoot
/// }
/// ```
public final class TechnologyRoot: Semantic, AutomaticDirectiveConvertible {
    public let originalMarkup: BlockDirective
    
    static var keyPaths: [String : AnyKeyPath] = [:]
    
    @available(*, deprecated, message: "Do not call directly. Required for 'AutomaticDirectiveConvertible'.")
    init(originalMarkup: BlockDirective) {
        self.originalMarkup = originalMarkup
    }
}
