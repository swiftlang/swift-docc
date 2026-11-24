/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Markdown
import DocCHTML

/// A parsed directive provider for HTML rendering.
///
/// This provides `DocCHTML.MarkdownRenderer` with the capability to parse BlockDirectives.
///
/// > Important: If you create a new block directive that represents visual content on the page, make sure it's supported in the static HTML version of the page. To do so:
///     - Add a new case to the switch statement in `parse(blockDirective:)`
///     - Add a corresponding new case to `ParsedDirective` in `DocCHTML`, containing any properties that you may need to render this directive in HTML.
///     - Switch over the new case in DocCHTML's `MarkdownRenderer.visit(_ directive:)` and return your directive's custom HTML.
struct ContextDirectiveParser: RenderableDirectiveParser {
    private let context: DocumentationContext
    
    init(context: DocumentationContext) {
        self.context = context
    }
    
    func parse(blockDirective: Markdown.BlockDirective) -> DocCHTML.RenderableDirective? {
        // Diagnostics were already emitted during semantic analysis, so discard them here.
        var diagnostics = [Diagnostic]()
        
        func parse<D: DirectiveConvertible>(_: D.Type) -> D? {
            D(from: blockDirective, source: nil, for: context.inputs, featureFlags: context.configuration.featureFlags, diagnostics: &diagnostics)
        }
        
        switch blockDirective.name {
        case ImageMedia.directiveName:
            guard let image = parse(ImageMedia.self) else { return nil }
            return .image(source: image.source.path, alt: image.altText, caption: image.caption.elements)
        case Small.directiveName:
            return .small
        case Row.directiveName:
            guard let row = parse(Row.self) else { return nil }
            let columns = row.columns.map { column in
                let alignment: ColumnAlignment = switch column.alignment {
                case .leading: .leading
                case .center: .center
                case .trailing: .trailing
                }
                return (size: column.size, alignment: alignment, content: column.content.elements)
            }
            return .row(columns: columns)
        case TabNavigator.directiveName:
            guard let tabNavigator = parse(TabNavigator.self) else { return nil }
            return .tabNavigator(tabs: tabNavigator.tabs.map { tab in (
                title: tab.title,
                content: tab.childMarkup
            ) })
        default:
            return nil
        }
    }
}
