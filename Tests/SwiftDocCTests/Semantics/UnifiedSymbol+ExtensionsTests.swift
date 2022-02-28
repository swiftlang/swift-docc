/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

@testable import SwiftDocC
import SymbolKit
import XCTest

class UnifiedSymbol_ExtensionsTests: XCTestCase {
    func testDefaultSelectorReturnsSwiftIfAvailable() throws {
        assertDefaultSelectorForSymbol(
            infos: [
                (language: "swift", platform: "macos", isMainGraph: true),
                (language: "occ", platform: "macos", isMainGraph: true),
            ],
            expectedDefaultSelector: .init(interfaceLanguage: "swift", platform: "macOS")
        )
    }
    
    func testDefaultSelectorReturnsSwiftWithAlphabeticallySmallestPlatform() throws {
        assertDefaultSelectorForSymbol(
            infos: [
                (language: "swift", platform: "macos", isMainGraph: true),
                (language: "swift", platform: "ios", isMainGraph: true),
            ],
            expectedDefaultSelector: .init(interfaceLanguage: "swift", platform: "iOS")
        )
    }
    
    func testDefaultSelectorReturnsSwiftWithNilPlatform() throws {
        assertDefaultSelectorForSymbol(
            infos: [
                (language: "swift", platform: nil, isMainGraph: true),
                (language: "swift", platform: "ios", isMainGraph: true),
            ],
            expectedDefaultSelector: .init(interfaceLanguage: "swift", platform: nil)
        )
    }
    
    func testDefaultSelectorReturnsObjectiveCIfThereIsNoSwift() throws {
        assertDefaultSelectorForSymbol(
            infos: [
                (language: "occ", platform: "macos", isMainGraph: true),
            ],
            expectedDefaultSelector: .init(interfaceLanguage: "occ", platform: "macOS")
        )
    }
    
    func testDefaultSelectorReturnsSwiftSelectorWithTheMostCommonPlatforms() throws {
        assertDefaultSelectorForSymbol(
            infos: [
                (language: "swift", platform: "ios", isMainGraph: true),
                (language: "swift", platform: "macos", isMainGraph: true),
                (language: "occ", platform: "macos", isMainGraph: true),
            ],
            expectedDefaultSelector: .init(interfaceLanguage: "swift", platform: "macOS")
        )
    }
    
    func testDefaultSelectorReturnsSwiftSelectorWithAlphabeticallySmallestPlatformIfTheyHaveTheSameNumberOfCommonPlatforms() throws {
        assertDefaultSelectorForSymbol(
            infos: [
                (language: "swift", platform: nil, isMainGraph: true),
                (language: "swift", platform: "macos", isMainGraph: true),
                (language: "occ", platform: nil, isMainGraph: true),
                (language: "occ", platform: "macos", isMainGraph: true),
            ],
            expectedDefaultSelector: .init(interfaceLanguage: "swift", platform: nil)
        )
    }
    
    func testDefaultSelectorIsMainGraphSelectorIfOneExists() throws {
        assertDefaultSelectorForSymbol(
            infos: [
                (language: "occ", platform: nil, isMainGraph: true),
                (language: "swift", platform: "macos", isMainGraph: false),
            ],
            expectedDefaultSelector: .init(interfaceLanguage: "occ", platform: nil)
        )
    }
    
    func testDefaultSelectorIsExtensionSelectorIfOneExists() throws {
        assertDefaultSelectorForSymbol(
            infos: [
                (language: "occ", platform: nil, isMainGraph: false),
                (language: "swift", platform: "macos", isMainGraph: false),
            ],
            expectedDefaultSelector: .init(interfaceLanguage: "swift", platform: "macOS")
        )
    }
    
    /// Creates a unified symbol with the given modules and returns its default selector's.
    func assertDefaultSelectorForSymbol(
        infos: [(language: String, platform: String?, isMainGraph: Bool)],
        expectedDefaultSelector: UnifiedSymbolGraph.Selector
    ) {
        func createSymbol(language: String) -> SymbolGraph.Symbol {
            SymbolGraph.Symbol(
                identifier: .init(precise: "Symbol", interfaceLanguage: language),
                names: SymbolGraph.Symbol.Names(title: "Symbol", navigator: [], subHeading: [], prose: nil),
                pathComponents: [],
                docComment: nil,
                accessLevel: .init(rawValue: "public"),
                kind: .init(rawIdentifier: "", displayName: ""),
                mixins: [:]
            )
        }
        
        guard let firstInfo = infos.first else {
            preconditionFailure("Argument 'info' must contain at least 1 element.")
        }
        
        let unifiedSymbol = UnifiedSymbolGraph.Symbol(
            fromSingleSymbol: createSymbol(language: firstInfo.language),
            module: SymbolGraph.Module(
                name: "",
                platform: SymbolGraph.Platform(
                    operatingSystem: firstInfo.platform.map { SymbolGraph.OperatingSystem.init(name: $0) }
                )
            ),
            isMainGraph: firstInfo.isMainGraph
        )
        
        let defaultSelector = infos.dropFirst().reduce(into: unifiedSymbol) { unifiedSymbol, info in
            unifiedSymbol.mergeSymbol(
                symbol: createSymbol(language: info.language),
                module: SymbolGraph.Module(
                    name: "",
                    platform: SymbolGraph.Platform(
                        operatingSystem: info.platform.map { SymbolGraph.OperatingSystem.init(name: $0) }
                    )
                ),
                isMainGraph: info.isMainGraph
            )
        }.defaultSelector
        
        XCTAssertEqual(defaultSelector, expectedDefaultSelector)
    }
}
