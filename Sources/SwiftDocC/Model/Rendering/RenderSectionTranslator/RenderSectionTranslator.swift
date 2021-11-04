/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A type that translates a piece of symbol data into a render node section.
protocol RenderSectionTranslator {
    /// Translates a piece of the given symbol into a render node section.
    func translateSection(
        for symbol: Symbol,
        renderNode: inout RenderNode,
        renderNodeTranslator: inout RenderNodeTranslator
    ) -> VariantCollection<CodableContentSection?>?
}

extension RenderSectionTranslator {
    /// Translates the variants of a piece of the given symbol into render node section variants.
    func translateSectionToVariantCollection<SymbolValue>(
        documentationDataVariants: DocumentationDataVariants<SymbolValue>,
        transform: (DocumentationDataVariantsTrait, SymbolValue) -> RenderSection?
    ) -> VariantCollection<CodableContentSection?>? {
        VariantCollection<CodableContentSection?>(
            from: documentationDataVariants,
            transform: { trait, value in
                transform(trait, value).map(CodableContentSection.init)
            }
        )
    }
}
