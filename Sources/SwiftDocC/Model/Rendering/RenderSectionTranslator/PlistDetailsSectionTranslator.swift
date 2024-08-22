/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SymbolKit

/// Translates a symbol's details into a render nodes's details section.
struct PlistDetailsSectionTranslator: RenderSectionTranslator, Decodable {
    
    private func generatePlistDetailsRenderSection(_ symbol: Symbol, plistDetails: SymbolGraph.Symbol.PlistDetails) -> PlistDetailsRenderSection {
        PlistDetailsRenderSection(
            details: PlistDetailsRenderSection.Details(
                rawKey: plistDetails.rawKey,
                value: [TypeDetails(baseType: plistDetails.baseType, arrayMode: plistDetails.arrayMode)],
                platforms: [],
                displayName: plistDetails.customTitle,
                // If the symbol uses the raw key as its title, display its human-friendly name  in the details section.
                titleStyle: symbol.title == plistDetails.rawKey ? .useRawKey : .useDisplayName
            )
        )
    }
    
    func translateSection(for symbol: Symbol, renderNode: inout RenderNode, renderNodeTranslator: inout RenderNodeTranslator) -> VariantCollection<CodableContentSection?>? {
        guard let plistDetails = symbol.mixinsVariants.allValues.mapFirst(where: { mixin in
            mixin.variant[SymbolGraph.Symbol.PlistDetails.mixinKey] as? SymbolGraph.Symbol.PlistDetails
        }) else {
            return nil
        }
        let section = generatePlistDetailsRenderSection(symbol, plistDetails: plistDetails)
        return VariantCollection(defaultValue: CodableContentSection(section))
    }
    
}
