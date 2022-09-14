/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown

/// A directive that can be directly rendered within markup content.
///
/// This protocol is used by the `RenderContentCompiler` to render arbitrary directives
/// that conform to renderable.
protocol RenderableDirectiveConvertible: AutomaticDirectiveConvertible {
    func render(with contentCompiler: inout RenderContentCompiler) -> [RenderContent]
}

extension RenderableDirectiveConvertible {
    static func render(
        _ blockDirective: BlockDirective,
        with contentCompiler: inout RenderContentCompiler
    ) -> [RenderContent] {
        guard let directive = Self.init(
            from: blockDirective,
            for: contentCompiler.bundle,
            in: contentCompiler.context
        ) else {
            return []
        }
        
        return directive.render(with: &contentCompiler)
    }
}

struct AnyRenderableDirectiveConvertibleType {
    var underlyingType: RenderableDirectiveConvertible.Type
    
    func render(
        _ blockDirective: BlockDirective,
        with contentCompiler: inout RenderContentCompiler
    ) -> [RenderContent] {
        return underlyingType.render(blockDirective, with: &contentCompiler)
    }
    
    var directiveName: String {
        return underlyingType.directiveName
    }
}
