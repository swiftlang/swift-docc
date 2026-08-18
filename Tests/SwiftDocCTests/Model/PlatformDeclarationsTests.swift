/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Testing
import SymbolKit
@testable import SwiftDocC

struct PlatformDeclarationsTests {
    private func declaration(_ spelling: String) -> SymbolGraph.Symbol.DeclarationFragments {
        .init(declarationFragments: [.init(kind: .identifier, spelling: spelling, preciseIdentifier: nil)])
    }

    @Test
    func picksHighestPriorityPlatformDeclaration() {
        let variants: [[PlatformName?]: SymbolGraph.Symbol.DeclarationFragments] = [
            [.macOS]: declaration("macOS"),
            [.iOS]:   declaration("iOS"),
            [.tvOS]:  declaration("tvOS"),
        ]
        // iOS is higher priority than macOS and tvOS
        #expect(variants.mainRenderFragments()?.declarationFragments == declaration("iOS").declarationFragments)
    }

    @Test
    func picksHighestPriorityPlatformWithinMergedGroup() {
        for mergedKey: [PlatformName?] in [[.iOS, .tvOS], [.tvOS, .iOS]] {
            let variants: [[PlatformName?]: SymbolGraph.Symbol.DeclarationFragments] = [
                mergedKey: declaration("shared"),
                [.macOS]:  declaration("macOS"),
            ]
            // iOS in the merged key for the shared declaration is higher priority than macOS
            #expect(variants.mainRenderFragments()?.declarationFragments == declaration("shared").declarationFragments)
        }
    }
}
