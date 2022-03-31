/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SymbolKit

extension DocumentationDataVariants {
    init<V>(
        symbolData: [UnifiedSymbolGraph.Selector: V],
        platformName: String?,
        transform: ((V) -> Variant)
    ) {
        self.init(
            values: Dictionary(
                uniqueKeysWithValues: symbolData.compactMap { selector, value in
                    guard selector.platform == platformName else { return nil }
                    
                    return (
                        DocumentationDataVariantsTrait(for: selector),
                        transform(value)
                    )
                }
            )
        )
    }
    
    init<V>(
        symbolData: [UnifiedSymbolGraph.Selector: V],
        platformName: String?,
        transform: ((V) -> Variant?)
    ) {
        self.init(
            values: Dictionary(
                uniqueKeysWithValues: symbolData.compactMap { selector, value in
                    guard selector.platform == platformName,
                          let value = transform(value)
                    else { return nil }
                    
                    return (
                        DocumentationDataVariantsTrait(for: selector),
                        value
                    )
                }
            )
        )
    }
    
    init<V>(
        symbolData: [UnifiedSymbolGraph.Selector: V],
        platformName: String?,
        keyPath: KeyPath<V, Variant>
    ) {
        self.init(symbolData: symbolData, platformName: platformName, transform: { $0[keyPath: keyPath] })
    }
    
    init<V>(
        symbolData: [UnifiedSymbolGraph.Selector: V],
        platformName: String?,
        keyPath: KeyPath<V, Variant?>
    ) {
        self.init(symbolData: symbolData, platformName: platformName, transform: { $0[keyPath: keyPath] })
    }
    
    init(symbolData: [UnifiedSymbolGraph.Selector: Variant], platformName: String?) {
        self.init(symbolData: symbolData, platformName: platformName, transform: { $0 })
    }
}
