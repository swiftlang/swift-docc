/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2025-2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Testing
import Foundation
import SymbolKit
import DocCCommon
import SwiftDocC

struct FastSymbolGraphJSONDecoderTests {
    
    @Test(arguments: [
        "Asides",
        "Availability",
        "BaseKit",
        "Collisions-iOS",
        "Collisions-macOS",
        "ConformanceOverloads",
        "DeckKit-Objective-C",
        "DeeplyNestedSymbolWithUnresolvableDocLink",
        "Deprecated",
        "DuplicateSymbolAsyncVariants",
        "DuplicateSymbolAsyncVariantsReverseOrder",
        "FancyOverloads",
        "FancyProtocol",
        "Inheritance",
        "InheritedDefaultImplementations",
        "InheritedDefaultImplementations@Swift",
        "InheritedDefaultImplementationsFromExternalModule",
        "InheritedDocs-RelativeLinks",
        "MissingDocs",
        "mykit-one-symbol",
        "MyKit@Foundation@_MyKit_Foundation",
        "one-symbol-top-level",
        "SameShapeConstraint",
        "SingleSymbolWithUnresolvableDocLink",
        "SingleSymbolWithUnresolvableSymbolLink",
        "SPI",
        "TopLevelCuration",
        "TypeSubscript",
        "Whatsit-Objective-C",
        "WithAsyncKeyword",
        "WithCompletionHandler",
        "_OverlayTest_BaseKit@BaseKit",
    ])
    func decodingTestResourceSymbolGraph(symbolGraphBaseName: String) throws {
        let url = try #require(Bundle.module.url(forResource: "\(symbolGraphBaseName).symbols", withExtension: "json", subdirectory: "Test Resources"))
        let data = try Data(contentsOf: url)
        
        try expectSymbolGraphToDecodeTheSame(data: data)
    }
    
    @Test(arguments: [
        "AlternateDeclarations",
        "AnonymousTopicGroups",
        "AvailabilityBetaBundle",
        "AvailabilityBundle",
        "AvailabilityOverrideBundle",
        "BookLikeContent",
        "BundleWithArticlesNoCurated",
        "BundleWithCollisionBasedOnNestedTypeExtension",
        "BundleWithExecutableModuleKind",
        "BundleWithLonelyDeprecationDirective",
        "BundleWithRelativePathAmbiguity",
        "BundleWithSameNameForSymbolAndContainer",
        "BundleWithSingleArticle",
        "BundleWithTechnologyRoot",
        "BundleWithoutAvailability",
        "CxxOperators",
        "CxxSymbols",
        "DefaultImplementations",
        "DefaultImplementationsWithExportedImport",
        "DeprecatedInOneLanguageOnly",
        "DictionaryData",
        "ErrorParameters",
        "ExtensionArticleBundle",
        "GeometricalShapes",
        "HTTPRequests",
        "InheritedOperators",
        "InheritedUnderCollision",
        "LegacyBundle_DoNotUseInNewTests",
        "MixedLanguageFramework",
        "MixedLanguageFrameworkComplexLinks",
        "MixedLanguageFrameworkSingleLanguageCuration",
        "MixedLanguageFrameworkSingleLanguageParent",
        "MixedLanguageFrameworkWithArticlesUsingSupportedLanguages",
        "MixedLanguageFrameworkWithLanguageRefinements",
        "MixedLanguageFrameworkWithLanguageSpecificRelationships",
        "MixedManualAutomaticCuration",
        "ModuleWithConformanceAndExtension",
        "ModuleWithEmptyDeclarationFragments",
        "ModuleWithProtocolExtensions",
        "ModuleWithSingleExtension",
        "MultiCuratedSubtree",
        "MultiPlatformModuleWithExtension",
        "ObjCFrameworkWithInvalidLink",
        "OverloadedSymbols",
        "SampleBundle",
        "ShadowExtendedModuleWithLocalSymbol",
        "Snippets",
        "SourceLocations",
        "SymbolsWithSameNameAsModule",
    ])
    func decodingSymbolGraphsInTestsCatalog(catalogBaseName: String) throws {
        let catalogURL = try #require(Bundle.module.url(forResource: catalogBaseName, withExtension: "docc", subdirectory: "Test Bundles"))
        
        // Discover all symbol graph files in the catalog.
        let (inputs, dataProvider) = try DocumentationContext.InputsProvider().inputsAndDataProvider(startingPoint: catalogURL, options: .init())
        
        // Verify that each symbol graph file decodes the same, regardless of decoder
        for url in inputs.symbolGraphURLs {
            let data = try dataProvider.contents(of: url)
            
            try expectSymbolGraphToDecodeTheSame(data: data)
        }
    }
    
    private func expectSymbolGraphToDecodeTheSame(data: Data) throws {
        let real = try JSONDecoder().decode(SymbolGraph.self, from: data)
        let fast = try FastSymbolGraphJSONDecoder.decode(SymbolGraph.self, from: data)
        
        // Verify that the fast decoder can scan and ignore the entire JSON structure without issues
        _ = try FastSymbolGraphJSONDecoder.decode(IgnoreEverything.self, from: data)
        
        // SymbolGraph.Metadata isn't equatable but only has two properties
        #expect(real.metadata.formatVersion == fast.metadata.formatVersion)
        #expect(real.metadata.generator     == fast.metadata.generator)
        
        // SymbolGraph.Module
        #expect(real.module == fast.module)
        
        // SymbolGraph.Relationship
        #expect(real.relationships == fast.relationships)
        for (real, fast) in zip(real.relationships, fast.relationships) {
            #expect(real.genericConstraints == fast.genericConstraints)
            #expect(real.referenceLocation  == fast.referenceLocation)
            #expect(real.sourceOrigin       == fast.sourceOrigin)
        }
        
        // SymbolGraph.Symbol
        // Much of the symbol data isn't equatable so this test various nested properties directly.
        // This makes it easier to pinpoint where there are differences compared to making Symbol equatable and doing a single `==` check.
        #expect(real.symbols.keys == fast.symbols.keys)
        
        for key in real.symbols.keys {
            let realSymbol = try #require(real.symbols[key])
            let fastSymbol = try #require(fast.symbols[key])
            
            // Dedicated properties
            #expect(realSymbol.identifier     == fastSymbol.identifier)
            #expect(realSymbol.kind           == fastSymbol.kind)
            #expect(realSymbol.pathComponents == fastSymbol.pathComponents)
            #expect(realSymbol.type           == fastSymbol.type)
            #expect(realSymbol.names          == fastSymbol.names)
            #expect(realSymbol.docComment     == fastSymbol.docComment)
            #expect(realSymbol.isVirtual      == fastSymbol.isVirtual)
            #expect(realSymbol.accessLevel    == fastSymbol.accessLevel)
            
            // Mixins
            #expect(realSymbol.availability          == fastSymbol.availability)
            #expect(realSymbol.declarationFragments  == fastSymbol.declarationFragments)
            #expect(realSymbol.functionSignature     == fastSymbol.functionSignature)
            #expect(realSymbol.httpEndpoint          == fastSymbol.httpEndpoint)
            #expect(realSymbol.httpParameterSource   == fastSymbol.httpParameterSource)
            #expect(realSymbol.httpMediaType         == fastSymbol.httpMediaType)
            #expect(realSymbol.extension             == fastSymbol.extension)
            #expect(realSymbol.generics              == fastSymbol.generics)
            #expect(realSymbol.alternateDeclarations == fastSymbol.alternateDeclarations)
            #expect(realSymbol.alternateSymbols      == fastSymbol.alternateSymbols)
            #expect(realSymbol.location              == fastSymbol.location)
            #expect(realSymbol.mutability            == fastSymbol.mutability)
            #expect(realSymbol.overloadData          == fastSymbol.overloadData)
            #expect(realSymbol.plistDetails          == fastSymbol.plistDetails)
            #expect(realSymbol.snippet               == fastSymbol.snippet)
            #expect(realSymbol.spi                   == fastSymbol.spi)
        }
    }
    
    @Test
    func decodingNestedDictionariesWithArbitraryStringKeys() throws {
        let json = #"""
        {
          "simple": 
          {
            "": 1,
            "escaped\\slashes\\": 2
          }, 
          "escaped\"quote": 
          {
            "\u1234": 3
          }
        }
        """#
        
        let decoded = try FastSymbolGraphJSONDecoder.decode([String: [String: Int]].self, from: Data(json.utf8))
        #expect(Set(decoded.keys) == ["simple", "escaped\"quote"])
        
        let first = try #require(decoded["simple"])
        #expect(Set(first.keys) == ["", "escaped\\slashes\\"])
        #expect(first[""] == 1)
        #expect(first["escaped\\slashes\\"] == 2)
        
        let second = try #require(decoded["escaped\"quote"])
        #expect(Set(second.keys) == ["\u{1234}"])
        #expect(second["\u{1234}"] == 3)
    }
}

private struct IgnoreEverything: FastJSONDecodable {
    init(using decoder: inout DocCCommon.FastSymbolGraphJSONDecoder) throws(DecodingError) {
        try decoder.descendIntoObject()
        while try decoder.advanceToNextKey() {
            try decoder.ignoreValue()
        }
    }
}

private extension SymbolGraph.Relationship {
    var genericConstraints: Swift.GenericConstraints? {
        mixins[Swift.GenericConstraints.mixinKey] as? Swift.GenericConstraints
    }
    var referenceLocation: ReferenceLocation? {
        mixins[ReferenceLocation.mixinKey] as? ReferenceLocation
    }
    var sourceOrigin: SourceOrigin? {
        mixins[SourceOrigin.mixinKey] as? SourceOrigin
    }
}

private extension SymbolGraph.Symbol {
    var `extension`: Swift.Extension? {
        self[mixin: Swift.Extension.self]
    }
    var generics: Swift.Generics? {
        self[mixin: Swift.Generics.self]
    }
    var location: Location? {
        self[mixin: Location.self]
    }
    var mutability: Mutability? {
        self[mixin: Mutability.self]
    }
    var snippet: Snippet? {
        self[mixin: Snippet.self]
    }
    var spi: SPI? {
        self[mixin: SPI.self]
    }
}

extension SymbolGraph.Symbol.Availability.AvailabilityItem: @retroactive Equatable {
    static func == (lhs: SymbolKit.SymbolGraph.Symbol.Availability.AvailabilityItem, rhs: SymbolKit.SymbolGraph.Symbol.Availability.AvailabilityItem) -> Bool {
        return lhs.isUnconditionallyUnavailable == rhs.isUnconditionallyUnavailable
            && lhs.isUnconditionallyDeprecated  == rhs.isUnconditionallyDeprecated
            && lhs.domain?.rawValue             == rhs.domain?.rawValue
            && lhs.introducedVersion            == rhs.introducedVersion
            && lhs.deprecatedVersion            == rhs.deprecatedVersion
            && lhs.obsoletedVersion             == rhs.obsoletedVersion
            && lhs.message                      == rhs.message
            && lhs.willEventuallyBeDeprecated   == rhs.willEventuallyBeDeprecated
    }
}

extension SymbolGraph.Symbol.Swift.Generics: @retroactive Equatable{
    static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.parameters  == rhs.parameters
            && lhs.constraints == rhs.constraints
    }
}

extension SymbolGraph.Symbol.Swift.GenericParameter: @retroactive Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.name  == rhs.name
            && lhs.depth == rhs.depth
            && lhs.index == rhs.index
    }
}

extension SymbolGraph.Symbol.HTTP.Endpoint: @retroactive Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.baseURL    == rhs.baseURL
            && lhs.method     == rhs.method
            && lhs.path       == rhs.path
            && lhs.sandboxURL == rhs.sandboxURL
    }
}

extension SymbolGraph.Symbol.Swift.Extension: @retroactive Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.extendedModule == rhs.extendedModule
            && lhs.typeKind       == rhs.typeKind
            && lhs.constraints    == rhs.constraints
    }
}

extension SymbolGraph.Symbol.AlternateSymbols: @retroactive Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.alternateSymbols == rhs.alternateSymbols
    }
}

extension SymbolGraph.Symbol.AlternateSymbols.AlternateSymbol: @retroactive Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.docComment           == rhs.docComment
            && lhs.functionSignature    == rhs.functionSignature
            && lhs.declarationFragments == rhs.declarationFragments
    }
}

extension SymbolGraph.Symbol.Location: @retroactive Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.uri      == lhs.uri
            && lhs.position == rhs.position
    }
}

extension SymbolGraph.Symbol.OverloadData: @retroactive Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.overloadGroupIdentifier == rhs.overloadGroupIdentifier
            && lhs.overloadGroupIndex      == rhs.overloadGroupIndex
    }
}

extension SymbolGraph.Symbol.PlistDetails: @retroactive Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.customTitle == rhs.customTitle
            && lhs.rawKey      == rhs.rawKey
            && lhs.arrayMode   == rhs.arrayMode
            && lhs.baseType    == rhs.baseType
    }
}

extension SymbolGraph.Symbol.Snippet: @retroactive Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.slices   == rhs.slices
            && lhs.language == rhs.language
            && lhs.lines    == rhs.lines
    }
}

extension SymbolGraph.Symbol.SPI: @retroactive Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.isSPI == rhs.isSPI
    }
}
