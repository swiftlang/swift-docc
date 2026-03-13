/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Testing
@testable import SymbolKit
@testable import SwiftDocC
import DocCTestUtilities

struct SymbolGraphLoaderTests {
    @Test
    func loadingDifferentMainSymbolGraphFiles() throws {
        var loader = try makeLoader {
            for moduleName in ["One", "Two", "Three"] {
                JSONFile(symbolGraph: makeSymbolGraph(moduleName: moduleName))
            }
        }
        #expect(loader.unifiedGraphs.isEmpty, "Has not loaded anything yet")
        
        try loader.loadAll()
        #expect(loader.unifiedGraphs.count == 3, "Loaded all 3 symbol graphs")
        
        var moduleNameFrequency = [String: Int]()
        for graph in loader.unifiedGraphs.values {
            moduleNameFrequency[graph.moduleName, default: 0] += 1
        }
        
        #expect(moduleNameFrequency == ["One": 1, "Two": 1, "Three": 1])
    }
    
    @Test
    func loadingDifferentExtensionSymbolGraphFiles() throws {
        var loader = try makeLoader {
            for moduleName in ["One", "Two", "Three"] {
                JSONFile(name: "Something@\(moduleName).symbols.json", content: makeSymbolGraph(moduleName: moduleName))
            }
        }
        #expect(loader.unifiedGraphs.isEmpty, "Has not loaded anything yet")
        
        try loader.loadAll()
        #expect(loader.unifiedGraphs.count == 3, "Loaded all 3 symbol graphs")
        
        var moduleNameFrequency = [String: Int]()
        for graph in loader.unifiedGraphs.values {
            moduleNameFrequency[graph.moduleName, default: 0] += 1
        }
        
        #expect(moduleNameFrequency == ["One": 1, "Two": 1, "Three": 1])
    }
    
    @Test
    func doesNotUnifyExtendedModulesWithTheExtendingModule() throws {
        var loader = try makeLoader {
            JSONFile(symbolGraph: makeSymbolGraph(moduleName: "Main")) // This is the extend_ing_ module.
            
            for moduleName in ["One", "Two", "Three"] { // These are all extend_ed_ modules.
                JSONFile(name: "Main@\(moduleName).symbols.json", content: makeSymbolGraph(moduleName: moduleName))
            }
        }
        #expect(loader.unifiedGraphs.isEmpty, "Has not loaded anything yet")
        
        try loader.loadAll()
        #expect(loader.unifiedGraphs.count == 4, "Loaded all 4 symbol graphs")
        
        var moduleNameFrequency = [String: Int]()
        for graph in loader.unifiedGraphs.values {
            moduleNameFrequency[graph.moduleName, default: 0] += 1
        }
        
        #expect(moduleNameFrequency == ["Main": 1, "One": 1, "Two": 1, "Three": 1])
    }
    
    // This test calls ``SymbolGraph.relationships`` which is deprecated.
    // Deprecating the test silences the deprecation warning when running the tests. It doesn't skip the test.
    @available(*, deprecated) // `SymbolGraph.relationships` doesn't specify when it will be removed
    @Test
    func loadingHighNumberOfSymbolGraphFilesConcurrently() throws {
        let symbols = (0..<20).map { id in
            makeSymbol(id: "symbol-\(id)", kind: .class, pathComponents: ["SomeClass\(id)"])
        }
        let symbolGraph = makeSymbolGraph(moduleName: "Something", symbols: symbols)
        
        var loader = try makeLoader {
            for number in 0 ..< 100 {
                JSONFile(symbolGraph: makeSymbolGraph(moduleName: "Something\(number)", symbols: symbols))
            }
        }
        #expect(loader.unifiedGraphs.isEmpty, "Has not loaded anything yet")
        
        try loader.loadAll()
        #expect(loader.unifiedGraphs.count == 100, "Loaded all 100 symbol graphs")
        
        var loadedGraphs = 0
        for graph in loader.unifiedGraphs.values {
            loadedGraphs += 1
            #expect(graph.symbols.count       == symbolGraph.symbols.count)
            #expect(graph.relationships.count == symbolGraph.relationships.count)
        }
        #expect(loadedGraphs == 100)
    }
    
    enum FakeExtensionGraph: Equatable, CaseIterable {
        case iOS, catalyst
    }
    
    @Test(arguments: FakeExtensionGraph.allCases)
    func mergingAvailabilityInformationFromDifferentPlatforms(_ fakeExtensionGraph: FakeExtensionGraph) async throws {
        // This test (which is rewritten based on a rather old test) tries to enforce a loading order by pretending that a main symbol graph file is an extension symbol graph file.
        // There could be unforeseen side effects and consequences of this behavior and future loading correctness changes _could_ break this test.
        // If this test break because of an intentional loading correctness change (but all other tests are fine) then we should likely remove this specific test.
        let catalog = Folder(name: "unit-test.docc") {
            JSONFile(name: "\(fakeExtensionGraph == .iOS ? "FakeExtension@" : "")ModuleName.symbols.json", content: makeSymbolGraph(moduleName: "ModuleName", platform: .init(operatingSystem: .init(name: "ios"), environment: nil), symbols: [
                makeSymbol(id: "some-symbol-id", kind: .class, pathComponents: ["SomeClass"], availability: [
                    .init(domainName: "iOS",     introduced: nil,                                   deprecated: .init(major: 13, minor:  0, patch: 0)),
                    .init(domainName: "macOS",   introduced: .init(major: 10, minor: 15, patch: 0), deprecated: nil),
                    .init(domainName: "tvOS",    introduced: .init(major: 13, minor:  0, patch: 0), deprecated: nil),
                    .init(domainName: "watchOS", introduced: .init(major:  6, minor:  0, patch: 0), deprecated: nil),
                ], declaration: [
                    // FIXME: Some availability logic only happens when symbols have declarations (rdar://172280267)
                    .init(kind: .keyword,    spelling: "class",     preciseIdentifier: nil),
                    .init(kind: .text,       spelling: " ",         preciseIdentifier: nil),
                    .init(kind: .identifier, spelling: "SomeClass", preciseIdentifier: nil),
                ]),
            ]))
            
            JSONFile(name: "\(fakeExtensionGraph == .catalyst ? "FakeExtension@" : "")ModuleName.symbols.json", content: makeSymbolGraph(moduleName: "ModuleName", platform: .init(operatingSystem: .init(name: "ios"), environment: "macabi"), symbols: [
                makeSymbol(id: "some-symbol-id", kind: .class, pathComponents: ["SomeClass"], availability: [
                    // Change the symbol's availability to have some differing data to verify
                    .init(domainName: "iOS",         introduced: .init(major: 7, minor: 0, patch: 0), deprecated: nil),
                    .init(domainName: "macCatalyst", introduced: .init(major: 1, minor: 0, patch: 0), deprecated: nil),
                ], declaration: [
                    // FIXME: Some availability logic only happens when symbols have declarations (rdar://172280267)
                    .init(kind: .keyword,    spelling: "class",     preciseIdentifier: nil),
                    .init(kind: .text,       spelling: " ",         preciseIdentifier: nil),
                    .init(kind: .identifier, spelling: "SomeClass", preciseIdentifier: nil),
                ]),
            ]))
        }
        let context = try await load(catalog: catalog)
        let availability = try #require((context.documentationCache["some-symbol-id"]?.semantic as? Symbol)?.availability?.availability)
        
        // FIXME: It might make more sense to move this information elsewhere (rdar://172280267)
        #expect(availability.compactMap(\.domain?.rawValue).sorted() == ["iOS", "iPadOS", "macCatalyst", "macOS", "tvOS", "watchOS"])
        
        #expect(availability.first(where: { $0.domain?.rawValue == "iOS"         })?.introducedVersion?.description ==  nil)
        #expect(availability.first(where: { $0.domain?.rawValue == "iOS"         })?.deprecatedVersion?.description == "13.0.0")
        #expect(availability.first(where: { $0.domain?.rawValue == "macOS"       })?.introducedVersion?.description == "10.15.0")
        #expect(availability.first(where: { $0.domain?.rawValue == "macCatalyst" })?.introducedVersion?.description ==  "1.0.0")
        #expect(availability.first(where: { $0.domain?.rawValue == "tvOS"        })?.introducedVersion?.description == "13.0.0")
        #expect(availability.first(where: { $0.domain?.rawValue == "watchOS"     })?.introducedVersion?.description ==  "6.0.0")
    }
    
    @Test
    func bystanderExtensionsAreCombinedWithTheExtendedModule() async throws {
        var loader = try makeLoader {
            JSONFile(symbolGraph: makeSymbolGraph(moduleName: "Main"))
            
            JSONFile(name: "Main@Extending@_Main_Extending.symbols.json", content: SymbolGraph(
                metadata: makeMetadata(),
                module: .init(name: "Main", platform: .init(), bystanders: ["Extending"]),
                symbols: [],
                relationships: []
            ))
        }
        #expect(loader.unifiedGraphs.isEmpty, "Has not loaded anything yet")
        
        try loader.loadAll()
        #expect(loader.unifiedGraphs.count == 1, "The extension symbol graph is combined with the extended module")
        
        let graph = try #require(loader.unifiedGraphs.values.first)
        #expect(graph.moduleName == "Main")
        
        #expect(graph.moduleData.values.contains(where: { $0.bystanders == ["Extending"] }))
    }
    
    @Test(arguments: [
        "WithCompletionHandler": false,
        "WithAsyncKeyword": true,
        "DuplicateSymbolAsyncVariants": false,
        "DuplicateSymbolAsyncVariantsReverseOrder": false,
    ])
    func loadingAsyncSymbolsAsOnlySymbolGraphFile(symbolGraphFileName: String, shouldContainAsyncVariant: Bool) throws {
        let symbolGraphURL = try #require(Bundle.module.url(forResource: "\(symbolGraphFileName).symbols", withExtension: "json", subdirectory: "Test Resources"))
        var loader = try makeLoader {
            CopyOfFile(original: symbolGraphURL)
        }
        try loader.loadAll()
        
        let symbolGraph = try #require(loader.unifiedGraphs.values.first)
        
        #expect(symbolGraph.moduleName == "AsyncMethods")
        
        #expect(symbolGraph.symbols.count == 1, "Only one of the symbols should be decoded")
        let symbol = try #require(symbolGraph.symbols.values.first)
        let declaration = try #require(symbol.mixins.values.first?[SymbolGraph.Symbol.DeclarationFragments.mixinKey] as? SymbolGraph.Symbol.DeclarationFragments)
        
        #expect(shouldContainAsyncVariant == declaration.declarationFragments.contains(where: { fragment in
            fragment.kind == .keyword && fragment.spelling == "async"
        }), "\(symbolGraphFileName).symbols.json should\(shouldContainAsyncVariant ? "" : " not") contain an async keyword declaration fragment")
        
        #expect(!shouldContainAsyncVariant == declaration.declarationFragments.contains(where: { fragment in
            fragment.kind == .externalParameter && fragment.spelling == "completionHandler"
        }), "\(symbolGraphFileName).symbols.json should\(!shouldContainAsyncVariant ? "" : " not") contain a completionHandler parameter declaration fragment")
    }
    
    @Test(arguments: [
        "WithCompletionHandler": false,
        "WithAsyncKeyword": true,
        "DuplicateSymbolAsyncVariants": false,
        "DuplicateSymbolAsyncVariantsReverseOrder": false,
    ])
    func loadingAsyncSymbolsAlongsideAnotherSymbolGraphFile(symbolGraphFileName: String, shouldContainAsyncVariant: Bool) throws {
        // This tests the decoding behavior when the symbol graph loader is decoding more than one file
        
        let extraSymbolGraphFile = try #require(Bundle.module.url(forResource: "Asides.symbols", withExtension: "json", subdirectory: "Test Resources"))
        let symbolGraphURL       = try #require(Bundle.module.url(forResource: "\(symbolGraphFileName).symbols", withExtension: "json", subdirectory: "Test Resources"))
        var loader = try makeLoader {
            CopyOfFile(original: extraSymbolGraphFile)
            CopyOfFile(original: symbolGraphURL)
        }
        try loader.loadAll()
        
        #expect(loader.unifiedGraphs.values.contains(where: { $0.moduleName == "AsyncMethods" }))
        for symbolGraph in loader.unifiedGraphs.values where symbolGraph.moduleName == "AsyncMethods" {
            #expect(symbolGraph.symbols.count ==  1, "Only one of the symbols should be decoded")
            let symbol = try #require(symbolGraph.symbols.values.first)
            let declaration = try #require(symbol.mixins.values.first?[SymbolGraph.Symbol.DeclarationFragments.mixinKey] as? SymbolGraph.Symbol.DeclarationFragments)
            
            #expect(shouldContainAsyncVariant == declaration.declarationFragments.contains(where: { fragment in
                fragment.kind == .keyword && fragment.spelling == "async"
            }), "\(symbolGraphFileName).symbols.json should\(shouldContainAsyncVariant ? "" : " not") contain an async keyword declaration fragment")
            
            #expect(!shouldContainAsyncVariant == declaration.declarationFragments.contains(where: { fragment in
                fragment.kind == .externalParameter && fragment.spelling == "completionHandler"
            }), "\(symbolGraphFileName).symbols.json should\(!shouldContainAsyncVariant ? "" : " not") contain a completionHandler parameter declaration fragment")
        }
    }
    
    @Test
    func appliesTransformationToLoadedSymbolGraph() throws {
        // This test manually creates the loader so that it can pass the transformation parameter to the initializer
        let (fileSystem, folderURL) = try makeTestFileSystemWith {
            JSONFile(symbolGraph: makeSymbolGraph(moduleName: "ModuleName"))
        }
        
        let (inputs, dataProvider) = try DocumentationContext.InputsProvider(fileManager: fileSystem)
            .inputsAndDataProvider(startingPoint: folderURL, allowArbitraryCatalogDirectories: true, options: .init())
        
        var loader = SymbolGraphLoader(bundle: inputs, dataProvider: dataProvider) { symbolGraph in
            // Make any verifiable change to the symbol graph
            symbolGraph.metadata.formatVersion = .init(major: 9, minor: 9, patch: 9)
        }
        try loader.loadAll()
        
        #expect(loader.unifiedGraphs.first?.value.metadata.first?.value.formatVersion.description == "9.9.9")
    }
    
    @Test(arguments: ["8.0.0", nil])
    func fillsInFallbackAvailabilityFromDefaultAvailability(defaultIntroducedVersion: String?) async throws {
        let catalog = Folder(name: "unit-test.docc") {
            // This symbol graph file is not for iOS and the symbol doesn't have iOS availability. This means that the iOS availability has to come from the Info.plist
            JSONFile(symbolGraph: makeSymbolGraph(moduleName: "ModuleName", platform: .init(operatingSystem: .init(name: "tvos")), symbols: [
                makeSymbol(id: "some-symbol-id", kind: .class, pathComponents: ["SomeClass"]) // No in-source availability attributes.
            ]))
            
            InfoPlist(defaultAvailability: ["ModuleName": [
                .init(platformName: .iOS, platformVersion: defaultIntroducedVersion)
            ]])
        }
        let context = try await load(catalog: catalog)
        let availability = try #require((context.documentationCache["some-symbol-id"]?.semantic as? Symbol)?.availability?.availability)
        
        // FIXME: It might make more sense to move this information elsewhere (rdar://172280267)
        if defaultIntroducedVersion != nil {
            #expect(availability.compactMap(\.domain?.rawValue).sorted() == ["iOS", "iPadOS", "macCatalyst", "tvOS"])
        } else {
            // ???: Why do we not want fallback platforms in when there's no introduced version? (rdar://171807245)
            #expect(availability.compactMap(\.domain?.rawValue).sorted() == ["iOS", "tvOS"])
        }
        #expect(availability.first(where: { $0.domain?.rawValue == "iOS"         })?.introducedVersion?.description == defaultIntroducedVersion)
        #expect(availability.first(where: { $0.domain?.rawValue == "iPadOS"      })?.introducedVersion?.description == defaultIntroducedVersion)
        #expect(availability.first(where: { $0.domain?.rawValue == "macCatalyst" })?.introducedVersion?.description == defaultIntroducedVersion)
        #expect(availability.first(where: { $0.domain?.rawValue == "tvOS"        })?.introducedVersion?.description == nil)
    }
     
    @Test
    func doesNotFillInFallbackAvailabilityForPlatformsMarkedUnavailable() async throws {
        let catalog = Folder(name: "unit-test.docc") {
            // This symbol graph file is not for iOS and the symbol doesn't have iOS availability. This means that the iOS availability has to come from the Info.plist
            JSONFile(symbolGraph: makeSymbolGraph(moduleName: "ModuleName", platform: .init(operatingSystem: .init(name: "tvos")), symbols: [
                makeSymbol(id: "some-symbol-id", kind: .class, pathComponents: ["SomeClass"]) // No in-source availability attributes.
            ]))
            
            InfoPlist(defaultAvailability: ["ModuleName": [
                .init(platformName: .iOS, platformVersion: "8.0"),
                .init(unavailablePlatformName: .catalyst), // Mac Catalyst is marked unavailable here so its fallback availability won't be added
            ]])
        }
        let context = try await load(catalog: catalog)
        let availability = try #require((context.documentationCache["some-symbol-id"]?.semantic as? Symbol)?.availability?.availability)
        
        // FIXME: It might make more sense to move this information elsewhere (rdar://172280267)
        #expect(availability.compactMap(\.domain?.rawValue).sorted() == ["iOS", "iPadOS", "tvOS"])
        
        #expect(availability.first(where: { $0.domain?.rawValue == "iOS"         })?.introducedVersion?.description == "8.0.0")
        #expect(availability.first(where: { $0.domain?.rawValue == "iPadOS"      })?.introducedVersion?.description == "8.0.0")
        #expect(availability.first(where: { $0.domain?.rawValue == "macCatalyst" }) == nil)
        #expect(availability.first(where: { $0.domain?.rawValue == "tvOS"        })?.introducedVersion?.description == nil)
    }
    
    @Test
    func fillsInFallbackAvailabilityFromInSourceAnnotations() async throws {
        let catalog = Folder(name: "unit-test.docc") {
            JSONFile(symbolGraph: makeSymbolGraph(moduleName: "ModuleName", platform: .init(operatingSystem: .init(name: "ios")), symbols: [
                makeSymbol(id: "some-symbol-id", kind: .class, pathComponents: ["SomeClass"], availability: [
                    .init(domainName: "iOS", introduced: .init(major: 12, minor: 0, patch: 0), deprecated: nil)
                ])
            ]))
        }
        let context = try await load(catalog: catalog)
        let availability = try #require((context.documentationCache["some-symbol-id"]?.semantic as? Symbol)?.availability?.availability)
        
        // FIXME: It might make more sense to move this information elsewhere (rdar://172280267)
        #expect(availability.compactMap(\.domain?.rawValue).sorted() == ["iOS", "iPadOS", "macCatalyst"])
        
        #expect(availability.first(where: { $0.domain?.rawValue == "iOS"         })?.introducedVersion?.description == "12.0.0")
        #expect(availability.first(where: { $0.domain?.rawValue == "iPadOS"      })?.introducedVersion?.description == "12.0.0")
        #expect(availability.first(where: { $0.domain?.rawValue == "macCatalyst" })?.introducedVersion?.description == "12.0.0")
    }
    
    @Test
    func fallbackAvailabilityDoesNotOverrideInSourceAvailability() async throws {
        let catalog = Folder(name: "unit-test.docc") {
            for (domainName, environment, introducedVersion) in [
                ("iOS",         nil,      SymbolGraph.SemanticVersion(major: 12, minor: 0, patch: 0)),
                ("macCatalyst", "macabi", SymbolGraph.SemanticVersion(major:  6, minor: 5, patch: 0))
            ] {
                JSONFile(name: "ModuleName-\(domainName).symbols.json", content: makeSymbolGraph(moduleName: "ModuleName", platform: .init(operatingSystem: .init(name: "ios"), environment: environment), symbols: [
                    makeSymbol(id: "some-symbol-id", kind: .class, pathComponents: ["SomeClass"], availability: [
                        .init(domainName: domainName, introduced: introducedVersion, deprecated: nil)
                    ])
                ]))
            }
        }
        let context = try await load(catalog: catalog)
        let availability = try #require((context.documentationCache["some-symbol-id"]?.semantic as? Symbol)?.availability?.availability)
        
        // FIXME: It might make more sense to move this information elsewhere (rdar://172280267)
        #expect(availability.compactMap(\.domain?.rawValue).sorted() == ["iOS", "iPadOS", "macCatalyst"])
        
        #expect(availability.first(where: { $0.domain?.rawValue == "iOS"         })?.introducedVersion?.description == "12.0.0")
        #expect(availability.first(where: { $0.domain?.rawValue == "iPadOS"      })?.introducedVersion?.description == "12.0.0")
        #expect(availability.first(where: { $0.domain?.rawValue == "macCatalyst" })?.introducedVersion?.description ==  "6.5.0")
    }
    
    @Test
    func defaultAvailabilityDoesNotOverrideInSourceAvailability() async throws {
        let catalog = Folder(name: "unit-test.docc") {
            for (domainName, environment, introducedVersion) in [
                ("iOS",         nil,      SymbolGraph.SemanticVersion(major: 12, minor: 0, patch: 0)),
                ("macCatalyst", "macabi", SymbolGraph.SemanticVersion(major:  6, minor: 5, patch: 0))
            ] {
                JSONFile(name: "ModuleName-\(domainName).symbols.json", content: makeSymbolGraph(moduleName: "ModuleName", platform: .init(operatingSystem: .init(name: "ios"), environment: environment), symbols: [
                    makeSymbol(id: "some-symbol-id", kind: .class, pathComponents: ["SomeClass"], availability: [
                        .init(domainName: domainName, introduced: introducedVersion, deprecated: nil)
                    ])
                ]))
            }
            
            InfoPlist(defaultAvailability: ["ModuleName": [
                .init(platformName: .iOS,      platformVersion: "8.0"),
                .init(platformName: .iPadOS,   platformVersion: "8.0"),
                .init(platformName: .catalyst, platformVersion: "8.0"),
            ]])
        }
        let context = try await load(catalog: catalog)
        let availability = try #require((context.documentationCache["some-symbol-id"]?.semantic as? Symbol)?.availability?.availability)
        
        // FIXME: It might make more sense to move this information elsewhere (rdar://172280267)
        #expect(availability.compactMap(\.domain?.rawValue).sorted() == ["iOS", "iPadOS", "macCatalyst"])
        
        #expect(availability.first(where: { $0.domain?.rawValue == "iOS"         })?.introducedVersion?.description == "12.0.0")
        #expect(availability.first(where: { $0.domain?.rawValue == "iPadOS"      })?.introducedVersion?.description == "12.0.0")
        #expect(availability.first(where: { $0.domain?.rawValue == "macCatalyst" })?.introducedVersion?.description ==  "6.5.0")
    }
    
    @Test
    func defaultAvailabilityFillMissingSourceAvailability() async throws {
        let catalog = Folder(name: "unit-test.docc") {
            // This symbol graph file is not for iOS and the symbol doesn't have iOS availability. This means that the iOS availability has to come from the Info.plist
            JSONFile(symbolGraph: makeSymbolGraph(moduleName: "ModuleName", platform: .init(operatingSystem: .init(name: "tvos")), symbols: [
                makeSymbol(id: "some-symbol-id", kind: .class, pathComponents: ["SomeClass"], availability: [
                    .init(domainName: "tvOS", introduced: .init(major: 10, minor: 0, patch: 0), deprecated: nil),
                ])
            ]))
            
            InfoPlist(defaultAvailability: ["ModuleName": [
                .init(platformName: .iOS,      platformVersion: "8.0"),
                .init(platformName: .catalyst, platformVersion: "7.0"),
                .init(platformName: .iPadOS,   platformVersion: "6.0"),
            ]])
        }
        let context = try await load(catalog: catalog)
        let availability = try #require((context.documentationCache["some-symbol-id"]?.semantic as? Symbol)?.availability?.availability)
        
        // FIXME: It might make more sense to move this information elsewhere (rdar://172280267)
        #expect(availability.compactMap(\.domain?.rawValue).sorted() == ["iOS", "iPadOS", "macCatalyst", "tvOS"])
        
        #expect(availability.first(where: { $0.domain?.rawValue == "iOS"         })?.introducedVersion?.description ==  "8.0.0")
        #expect(availability.first(where: { $0.domain?.rawValue == "macCatalyst" })?.introducedVersion?.description ==  "7.0.0")
        #expect(availability.first(where: { $0.domain?.rawValue == "iPadOS"      })?.introducedVersion?.description ==  "6.0.0")
        #expect(availability.first(where: { $0.domain?.rawValue == "tvOS"        })?.introducedVersion?.description == "10.0.0")
    }
    
    @Test
    func unavailableDefaultPlatformsDoNotRemovePlatformsWithSourceAvailability() async throws {
        let catalog = Folder(name: "unit-test.docc") {
            for (domainName, environment, introducedVersion) in [
                ("iOS",         nil,      SymbolGraph.SemanticVersion(major: 10, minor: 0, patch: 0)),
                ("macCatalyst", "macabi", SymbolGraph.SemanticVersion(major: 12, minor: 0, patch: 0))
            ] {
                JSONFile(name: "ModuleName-\(domainName).symbols.json", content: makeSymbolGraph(moduleName: "ModuleName", platform: .init(operatingSystem: .init(name: "ios"), environment: environment), symbols: [
                    makeSymbol(id: "some-symbol-id", kind: .class, pathComponents: ["SomeClass"], availability: [
                        .init(domainName: domainName, introduced: introducedVersion, deprecated: nil)
                    ])
                ]))
            }
            
            InfoPlist(defaultAvailability: ["ModuleName": [
                .init(unavailablePlatformName: .iOS),
                .init(unavailablePlatformName: .iPadOS),
                .init(unavailablePlatformName: .catalyst),
            ]])
        }
        let context = try await load(catalog: catalog)
        let availability = try #require((context.documentationCache["some-symbol-id"]?.semantic as? Symbol)?.availability?.availability)
        
        // FIXME: It might make more sense to move this information elsewhere (rdar://172280267)
        #expect(availability.compactMap(\.domain?.rawValue).sorted() == ["iOS", "macCatalyst"])
        
        #expect(availability.first(where: { $0.domain?.rawValue == "iOS"         })?.introducedVersion?.description == "10.0.0")
        #expect(availability.first(where: { $0.domain?.rawValue == "iPadOS"      }) == nil)
        #expect(availability.first(where: { $0.domain?.rawValue == "macCatalyst" })?.introducedVersion?.description == "12.0.0")
    }
    
    @Test(arguments: [true, false])
    func testSymbolUnavailablePerPlatform(withUnavailablePlatformsInInfoPlist: Bool) async throws {
        let catalog = Folder(name: "unit-test.docc") {
            JSONFile(name: "ModuleName-ios.symbols.json", content: makeSymbolGraph(moduleName: "ModuleName", platform: .init(operatingSystem: .init(name: "ios"), environment: nil), symbols: [
                makeSymbol(id: "first-symbol-id", kind: .class, pathComponents: ["First"], availability: [
                    .init(domainName: "iOS", introduced: .init(major: 10, minor: 0, patch: 0), deprecated: nil)
                ])
            ]))
            
            JSONFile(name: "ModuleName-catalyst.symbols.json", content: makeSymbolGraph(moduleName: "ModuleName", platform: .init(operatingSystem: .init(name: "ios"), environment: "macabi"), symbols: [
                makeSymbol(id: "first-symbol-id", kind: .class, pathComponents: ["First"], availability: [
                    .init(domainName: "macCatalyst", introduced: .init(major: 12, minor: 0, patch: 0), deprecated: nil)
                ]),
                makeSymbol(id: "second-symbol-id", kind: .class, pathComponents: ["Second"], availability: [
                    .init(domainName: "macCatalyst", introduced: .init(major: 12, minor: 0, patch: 0), deprecated: nil)
                ]),
            ]))
            
            if withUnavailablePlatformsInInfoPlist {
                InfoPlist(defaultAvailability: ["ModuleName": [
                    .init(unavailablePlatformName: .iOS),
                    .init(unavailablePlatformName: .iPadOS),
                    .init(unavailablePlatformName: .catalyst),
                ]])
            }
        }
        let context = try await load(catalog: catalog)
        let firstAvailability  = try #require((context.documentationCache["first-symbol-id"]?.semantic  as? Symbol)?.availability?.availability)
        let secondAvailability = try #require((context.documentationCache["second-symbol-id"]?.semantic as? Symbol)?.availability?.availability)
        
        // FIXME: It might make more sense to move this information elsewhere (rdar://172280267)
        if withUnavailablePlatformsInInfoPlist {
            #expect(firstAvailability.compactMap(\.domain?.rawValue).sorted() == ["iOS", "macCatalyst"])
            
            #expect(firstAvailability.first(where: { $0.domain?.rawValue == "iOS"         })?.introducedVersion?.description == "10.0.0")
            #expect(firstAvailability.first(where: { $0.domain?.rawValue == "iPadOS"      }) == nil)
            #expect(firstAvailability.first(where: { $0.domain?.rawValue == "macCatalyst" })?.introducedVersion?.description == "12.0.0")
            
            #expect(secondAvailability.compactMap(\.domain?.rawValue).sorted() == ["macCatalyst"])
            #expect(secondAvailability.first(where: { $0.domain?.rawValue == "macCatalyst" })?.introducedVersion?.description == "12.0.0")
        } else {
            #expect(firstAvailability.compactMap(\.domain?.rawValue).sorted() == ["iOS", "iPadOS", "macCatalyst"])
            
            #expect(firstAvailability.first(where: { $0.domain?.rawValue == "iOS"         })?.introducedVersion?.description == "10.0.0")
            #expect(firstAvailability.first(where: { $0.domain?.rawValue == "iPadOS"      })?.introducedVersion?.description == "10.0.0")
            #expect(firstAvailability.first(where: { $0.domain?.rawValue == "macCatalyst" })?.introducedVersion?.description == "12.0.0")
            
            #expect(secondAvailability.compactMap(\.domain?.rawValue).sorted() == ["macCatalyst"])
            #expect(secondAvailability.first(where: { $0.domain?.rawValue == "macCatalyst" })?.introducedVersion?.description == "12.0.0")
        }
    }
    
    @Test
    func fillsVersionFromDefaultAvailability() async throws {
        let catalog = Folder(name: "unit-test.docc") {
            JSONFile(symbolGraph: makeSymbolGraph(moduleName: "ModuleName", platform: .init(operatingSystem: .init(name: "macosx")), symbols: [
                makeSymbol(id: "some-symbol-id", kind: .class, pathComponents: ["SomeClass"]) // No explicit availability
            ]))
            
            InfoPlist(defaultAvailability: ["ModuleName": [
                .init(platformName: .macOS, platformVersion: "10.0")
            ]])
        }
        let context = try await load(catalog: catalog)
        let availability = try #require((context.documentationCache["some-symbol-id"]?.semantic as? Symbol)?.availability?.availability)
        
        // FIXME: It might make more sense to move this information elsewhere (rdar://172280267)
        #expect(availability.compactMap(\.domain?.rawValue).sorted() == ["macOS"])
        #expect(availability.first(where: { $0.domain?.rawValue == "macOS" })?.introducedVersion?.description == "10.0.0")
    }
    
    @Test
    func unifiesCatalystAvailabilityWithDifferentSpellingFromDifferentSources() async throws {
        let catalog = Folder(name: "unit-test.docc") {
            JSONFile(name: "ModuleName-tvos.symbols.json", content: makeSymbolGraph(moduleName: "ModuleName", platform: .init(operatingSystem: .init(name: "tvos"), environment: nil), symbols: [
                makeSymbol(id: "some-symbol-id", kind: .class, pathComponents: ["SomeClass"], availability: [
                    .init(domainName: "tvOS", introduced: .init(major: 12, minor: 0, patch: 0), deprecated: nil)
                ])
            ]))
            
            JSONFile(name: "ModuleName-catalyst.symbols.json", content: makeSymbolGraph(moduleName: "ModuleName", platform: .init(operatingSystem: .init(name: "ios"), environment: "macabi"), symbols: [
                makeSymbol(id: "some-symbol-id", kind: .class, pathComponents: ["SomeClass"], availability: [
                    // Even when the domain name is lowercased in the in-source availability attribute, DocC should unify it with the Info.plist information
                    .init(domainName: "maccatalyst", introduced: .init(major: 15, minor: 2, patch: 0), deprecated: nil)
                ]),
            ]))
            
            InfoPlist(defaultAvailability: ["ModuleName": [
                .init(platformName: .catalyst, platformVersion: "1.0")
            ]])
        }
        let context = try await load(catalog: catalog)
        let availability = try #require((context.documentationCache["some-symbol-id"]?.semantic as? Symbol)?.availability?.availability)
        
        // FIXME: It might make more sense to move this information elsewhere (rdar://172280267)
        #expect(availability.compactMap(\.domain?.rawValue).sorted() == ["macCatalyst", "tvOS"])
        
        #expect(availability.first(where: { $0.domain?.rawValue == "tvOS"        })?.introducedVersion?.description == "12.0.0")
        #expect(availability.first(where: { $0.domain?.rawValue == "macCatalyst" })?.introducedVersion?.description == "15.2.0")
    }
    
    @Test
    func fallbackFromSourceAvailabilityTakesPrecedenceOverDefaultAvailability() async throws {
        let catalog = Folder(name: "unit-test.docc") {
            JSONFile(name: "ModuleName-catalyst.symbols.json", content: makeSymbolGraph(moduleName: "ModuleName", platform: .init(operatingSystem: .init(name: "ios"), environment: "macabi"), symbols: [
                makeSymbol(id: "some-symbol-id", kind: .class, pathComponents: ["SomeClass"], availability: [
                    // In the Mac Catalyst symbol graph file, the symbol only has iOS availability
                    .init(domainName: "iOS", introduced: .init(major: 12, minor: 0, patch: 0), deprecated: nil)
                ]),
            ]))
            
            InfoPlist(defaultAvailability: ["ModuleName": [
                .init(platformName: .catalyst, platformVersion: "5.5")
            ]])
        }
        let context = try await load(catalog: catalog)
        let availability = try #require((context.documentationCache["some-symbol-id"]?.semantic as? Symbol)?.availability?.availability)
        
        // FIXME: It might make more sense to move this information elsewhere (rdar://172280267)
        #expect(availability.compactMap(\.domain?.rawValue).sorted() == ["iOS", "macCatalyst"])
        
        #expect(availability.first(where: { $0.domain?.rawValue == "iOS"         })?.introducedVersion?.description == "12.0.0")
        #expect(availability.first(where: { $0.domain?.rawValue == "macCatalyst" })?.introducedVersion?.description == "12.0.0",
                "The Mac Catalyst 'fallback' from the per-symbol iOS availability is more specific than the Info.plist information that applies to all symbols")
    }
    
    @Test
    func prefersMoreSpecificDefaultAvailabilityWhenThereIsNoSourceAvailability() async throws {
        let catalog = Folder(name: "unit-test.docc") {
            JSONFile(name: "ModuleName-catalyst.symbols.json", content: makeSymbolGraph(moduleName: "ModuleName", platform: .init(operatingSystem: .init(name: "ios"), environment: "macabi"), symbols: [
                makeSymbol(id: "some-symbol-id", kind: .class, pathComponents: ["SomeClass"]) // No in-source availability attributes.
            ]))
            
            InfoPlist(defaultAvailability: ["ModuleName": [
                .init(platformName: .iOS,      platformVersion: "2.3"),
                .init(platformName: .catalyst, platformVersion: "4.5"),
            ]])
        }
        let context = try await load(catalog: catalog)
        let availability = try #require((context.documentationCache["some-symbol-id"]?.semantic as? Symbol)?.availability?.availability)
        
        // FIXME: It might make more sense to move this information elsewhere (rdar://172280267)
        #expect(availability.compactMap(\.domain?.rawValue).sorted() == ["iOS", "iPadOS", "macCatalyst"])
        
        #expect(availability.first(where: { $0.domain?.rawValue == "iOS"         })?.introducedVersion?.description == "2.3.0")
        #expect(availability.first(where: { $0.domain?.rawValue == "iPadOS"      })?.introducedVersion?.description == "2.3.0")
        #expect(availability.first(where: { $0.domain?.rawValue == "macCatalyst" })?.introducedVersion?.description == "4.5.0",
                "The Mac Catalyst 'default' availability from the Info.plist is more specific than the 'fallback' from the 'default' iOS availability (also from the Info.plist)")
    }
    
    @Test
    func testDefaultAvailabilityWhenSymbolIsNotAvailableForThatPlatform() async throws {
        let catalog = Folder(name: "unit-test.docc") {
            JSONFile(name: "ModuleName-ios.symbols.json", content: makeSymbolGraph(moduleName: "ModuleName", platform: .init(operatingSystem: .init(name: "tvos"), environment: nil), symbols: [
                makeSymbol(id: "first-symbol-id", kind: .class, pathComponents: ["First"]) // No in-source availability attributes.
            ]))
            
            JSONFile(name: "ModuleName-catalyst.symbols.json", content: makeSymbolGraph(moduleName: "ModuleName", platform: .init(operatingSystem: .init(name: "ios"), environment: "macabi"), symbols: [
                makeSymbol(id: "first-symbol-id",  kind: .class, pathComponents: ["First"]),  // No in-source availability attributes.
                makeSymbol(id: "second-symbol-id", kind: .class, pathComponents: ["Second"]), // No in-source availability attributes.
            ]))
            
            InfoPlist(defaultAvailability: ["ModuleName": [
                .init(platformName: .tvOS, platformVersion: nil),
                .init(platformName: .iOS,  platformVersion: nil),
            ]])
        }
        let context = try await load(catalog: catalog)
        let firstAvailability  = try #require((context.documentationCache["first-symbol-id"]?.semantic  as? Symbol)?.availability?.availability)
        let secondAvailability = try #require((context.documentationCache["second-symbol-id"]?.semantic as? Symbol)?.availability?.availability)
        
        // FIXME: It might make more sense to move this information elsewhere (rdar://172280267)
        #expect(firstAvailability.compactMap(\.domain?.rawValue).sorted()  == ["iOS", "macCatalyst", "tvOS"])
        #expect(secondAvailability.compactMap(\.domain?.rawValue).sorted() == ["iOS", "macCatalyst"],
                "The 'Second' symbol is not present in the tvOS symbol graph, so it shouldn't have any tvOS availability")
    }
    
    private func makeLoader(@FileBuilder content: () -> [any File]) throws -> SymbolGraphLoader {
        let (fileSystem, folderURL) = try makeTestFileSystemWith(content: content)
        
        let (inputs, dataProvider) = try DocumentationContext.InputsProvider(fileManager: fileSystem)
            .inputsAndDataProvider(startingPoint: folderURL, allowArbitraryCatalogDirectories: true, options: .init())
        
        return SymbolGraphLoader(bundle: inputs, dataProvider: dataProvider)
    }
}

private extension SymbolGraph.Symbol.Availability.AvailabilityItem {
    init(
        domainName: String,
        introduced: SymbolGraph.SemanticVersion?,
        deprecated: SymbolGraph.SemanticVersion?,
        obsoleted: SymbolGraph.SemanticVersion? = nil,
        message: String? = nil,
        renamed: String? = nil,
        isUnconditionallyDeprecated:  Bool = false,
        isUnconditionallyUnavailable: Bool = false,
        willEventuallyBeDeprecated:   Bool = false
    ) {
        self.init(
            domain: .init(rawValue: domainName),
            introducedVersion: introduced,
            deprecatedVersion: deprecated,
            obsoletedVersion: obsoleted,
            message: message,
            renamed: renamed,
            isUnconditionallyDeprecated: isUnconditionallyDeprecated,
            isUnconditionallyUnavailable: isUnconditionallyUnavailable,
            willEventuallyBeDeprecated: willEventuallyBeDeprecated
        )
    }
}
