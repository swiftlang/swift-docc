/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Testing
import SymbolKit
@testable import SwiftDocC
import DocCTestUtilities

struct AvailabilityTests {
    
    enum DirectiveLocation: CaseIterable {
        case extensionFile
        case inSourceComment
    }
    
    // MARK: Fallback availability
    
    @Test(arguments: ["8.0", nil])
    func fillsInFallbackAvailabilityFromDefaultAvailability(defaultIntroducedVersion: String?) async throws {
        let catalog = Folder(name: "unit-test.docc") {
            // This symbol graph file is not for iOS and the symbol doesn't have iOS availability. This means that the iOS availability has to come from the Info.plist
            JSONFile(symbolGraph: makeSymbolGraph(moduleName: "ModuleName", platform: .init(operatingSystem: .init(name: "tvos")), symbols: [
                makeSymbol(id: "some-symbol-id", kind: .class, pathComponents: ["SomeClass"]) // No in-source availability attributes.
            ]))
            
            TextFile(name: "SomeArticle.md", utf8Content: """
            # Some article
            """)
            
            InfoPlist(defaultAvailability: ["ModuleName": [
                .init(platformName: .iOS, platformVersion: defaultIntroducedVersion)
            ]])
        }
        let context = try await load(catalog: catalog)
        #expect(context.problems.isEmpty, "Unexpected problems: \(context.problems.map(\.diagnostic.summary))")
        
        // Verify that the symbol has filled in iPadOS and Mac Catalyst from the iOS default availability.
        do {
            let node = try #require(context.documentationCache["some-symbol-id"])
            let converter = DocumentationContextConverter(context: context, renderContext: .init(documentationContext: context))
            let renderNode = try #require(converter.renderNode(for: node))
            
            let renderPlatforms = try #require(renderNode.metadata.platforms)
            if defaultIntroducedVersion != nil {
                #expect(renderPlatforms.compactMap(\.name) == ["iOS", "iPadOS", "Mac Catalyst", "tvOS"])
            } else {
                // ???: Why do we not want fallback platforms in when there's no introduced version? (rdar://171807245)
                #expect(renderPlatforms.compactMap(\.name) == ["iOS", "tvOS"])
            }
            #expect(renderPlatforms.first(where: { $0.name == "iOS"          })?.introduced == defaultIntroducedVersion)
            #expect(renderPlatforms.first(where: { $0.name == "iPadOS"       })?.introduced == defaultIntroducedVersion)
            #expect(renderPlatforms.first(where: { $0.name == "Mac Catalyst" })?.introduced == defaultIntroducedVersion)
            #expect(renderPlatforms.first(where: { $0.name == "tvOS"         })?.introduced == nil)
        }
        
        // Verify that the article has filled in iPadOS and Mac Catalyst from the iOS default availability.
        do {
            withKnownIssue("Articles don't display default availability (rdar://173688303)") {
                let articleReference = try #require(context.knownPages.first(where: { $0.lastPathComponent == "SomeArticle" }))
                let node = try #require(context.documentationCache[articleReference])
                let converter = DocumentationContextConverter(context: context, renderContext: .init(documentationContext: context))
                let renderNode = try #require(converter.renderNode(for: node))
                
                let renderPlatforms = try #require(renderNode.metadata.platforms)
                if defaultIntroducedVersion != nil {
                    #expect(renderPlatforms.compactMap(\.name) == ["iOS", "iPadOS", "Mac Catalyst"])
                } else {
                    // ???: Why do we not want fallback platforms in when there's no introduced version? (rdar://171807245)
                    #expect(renderPlatforms.compactMap(\.name) == ["iOS"])
                }
                #expect(renderPlatforms.first(where: { $0.name == "iOS"          })?.introduced == defaultIntroducedVersion)
                #expect(renderPlatforms.first(where: { $0.name == "iPadOS"       })?.introduced == defaultIntroducedVersion)
                #expect(renderPlatforms.first(where: { $0.name == "Mac Catalyst" })?.introduced == defaultIntroducedVersion)
            }
        }
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
        #expect(context.problems.isEmpty, "Unexpected problems: \(context.problems.map(\.diagnostic.summary))")
        let node = try #require(context.documentationCache["some-symbol-id"])
        let converter = DocumentationContextConverter(context: context, renderContext: .init(documentationContext: context))
        let renderNode = try #require(converter.renderNode(for: node))
        
        let renderPlatforms = try #require(renderNode.metadata.platforms)
        #expect(renderPlatforms.compactMap(\.name) == ["iOS", "iPadOS", "Mac Catalyst"])
        
        #expect(renderPlatforms.first(where: { $0.name == "iOS"          })?.introduced == "12.0")
        #expect(renderPlatforms.first(where: { $0.name == "iPadOS"       })?.introduced == "12.0")
        #expect(renderPlatforms.first(where: { $0.name == "Mac Catalyst" })?.introduced == "12.0")
    }
    
    @Test(arguments: DirectiveLocation.allCases)
    func fillsInFallbackAvailabilityFromDirectiveAnnotations(_ directiveLocation: DirectiveLocation) async throws {
        let availableDirective = """
        @Metadata {
          @Available(iOS, introduced: "9.2")
        }
        """
        
        let catalog = Folder(name: "unit-test.docc") {
            JSONFile(symbolGraph: makeSymbolGraph(moduleName: "ModuleName", symbols: [
                makeSymbol(id: "some-symbol-id", kind: .class, pathComponents: ["SomeClass"], docComment: """
                    Some in-source documentation for this class.
                    
                    \(directiveLocation == .inSourceComment ? availableDirective : "")
                    """, availability: []) // No availability _attributes_ for this symbol
            ]))
            
            TextFile(name: "SomeClass.md", utf8Content: """
            # ``SomeClass``
            
            Some additional documentation for this class.
            \(directiveLocation == .extensionFile ? availableDirective : "")
            """)
        }
        let context = try await load(catalog: catalog)
        #expect(context.problems.isEmpty, "Unexpected problems: \(context.problems.map(\.diagnostic.summary))")
        let node = try #require(context.documentationCache["some-symbol-id"])
        #expect(node.metadata?.availability.count == 1)
        let directiveAvailability = node.metadata?.availability.first
        #expect(directiveAvailability?.platform.rawValue      == "iOS")
        #expect(directiveAvailability?.introduced.description == "9.2.0")
        
        let converter = DocumentationContextConverter(context: context, renderContext: .init(documentationContext: context))
        let renderNode = try #require(converter.renderNode(for: node))
        
        let renderPlatforms = try #require(renderNode.metadata.platforms)
        #expect(renderPlatforms.compactMap(\.name) == ["iOS", "iPadOS", "Mac Catalyst"])
        
        #expect(renderPlatforms.first(where: { $0.name == "iOS"          })?.introduced == "9.2")
        #expect(renderPlatforms.first(where: { $0.name == "iPadOS"       })?.introduced == "9.2")
        #expect(renderPlatforms.first(where: { $0.name == "Mac Catalyst" })?.introduced == "9.2")
    }
    
    enum UnavailableDefaultPlatform: Equatable, CaseIterable {
        case iPadOS, catalyst
        
        var platformName: PlatformName {
            switch self {
                case .iPadOS:   .iPadOS
                case .catalyst: .catalyst
            }
        }
        
        var availablePlatformsDisplayName: String {
            switch self {
                case .iPadOS:   "Mac Catalyst"
                case .catalyst: "iPadOS"
            }
        }
    }
    
    @Test(arguments: UnavailableDefaultPlatform.allCases)
    func doesNotFillInFallbackAvailabilityForPlatformsMarkedUnavailableFromDefaultAvailability(_ unavailableDefaultPlatform: UnavailableDefaultPlatform) async throws {
        let catalog = Folder(name: "unit-test.docc") {
            // This symbol graph file is not for iOS and the symbol doesn't have iOS availability. This means that the iOS availability has to come from the Info.plist
            JSONFile(symbolGraph: makeSymbolGraph(moduleName: "ModuleName", platform: .init(operatingSystem: .init(name: "tvos")), symbols: [
                makeSymbol(id: "some-symbol-id", kind: .class, pathComponents: ["SomeClass"]) // No in-source availability attributes.
            ]))
            
            InfoPlist(defaultAvailability: ["ModuleName": [
                .init(platformName: .iOS, platformVersion: "8.0"),
                // One of the two fallback platforms, but not both, is marked unavailable here so its fallback availability won't be added.
                .init(unavailablePlatformName: unavailableDefaultPlatform.platformName),
            ]])
        }
        let context = try await load(catalog: catalog)
        #expect(context.problems.isEmpty, "Unexpected problems: \(context.problems.map(\.diagnostic.summary))")
        let node = try #require(context.documentationCache["some-symbol-id"])
        let converter = DocumentationContextConverter(context: context, renderContext: .init(documentationContext: context))
        let renderNode = try #require(converter.renderNode(for: node))
        
        let renderPlatforms = try #require(renderNode.metadata.platforms)
        #expect(renderPlatforms.compactMap(\.name) == ["iOS", unavailableDefaultPlatform.availablePlatformsDisplayName, "tvOS"])
        #expect(renderPlatforms.first(where: { $0.name == "iOS"          })?.introduced == "8.0")
        switch unavailableDefaultPlatform {
        case .iPadOS:
            #expect(renderPlatforms.first(where: { $0.name == "iPadOS"       }) == nil)
            #expect(renderPlatforms.first(where: { $0.name == "Mac Catalyst" })?.introduced == "8.0")
        case .catalyst:
            #expect(renderPlatforms.first(where: { $0.name == "iPadOS"       })?.introduced == "8.0")
            #expect(renderPlatforms.first(where: { $0.name == "Mac Catalyst" }) == nil)
        }
        #expect(renderPlatforms.first(where: { $0.name == "tvOS"         })?.introduced == nil)
    }
    
    @Test(arguments: UnavailableDefaultPlatform.allCases)
    func doesNotFillInFallbackAvailabilityForPlatformsMarkedUnavailableFromInSourceAvailability(_ unavailableDefaultPlatform: UnavailableDefaultPlatform) async throws {
        let catalog = Folder(name: "unit-test.docc") {
            JSONFile(symbolGraph: makeSymbolGraph(moduleName: "ModuleName", platform: .init(operatingSystem: .init(name: "ios")), symbols: [
                makeSymbol(id: "some-symbol-id", kind: .class, pathComponents: ["SomeClass"], availability: [
                    .init(domainName: "iOS", introduced: .init(major: 11, minor: 2, patch: 0), deprecated: nil)
                ])
            ]))
            
            InfoPlist(defaultAvailability: ["ModuleName": [
                // One of the two fallback platforms, but not both, is marked unavailable here so its fallback availability won't be added.
                .init(unavailablePlatformName: unavailableDefaultPlatform.platformName),
            ]])
        }
        let context = try await load(catalog: catalog)
        #expect(context.problems.isEmpty, "Unexpected problems: \(context.problems.map(\.diagnostic.summary))")
        let node = try #require(context.documentationCache["some-symbol-id"])
        let converter = DocumentationContextConverter(context: context, renderContext: .init(documentationContext: context))
        let renderNode = try #require(converter.renderNode(for: node))
        
        let renderPlatforms = try #require(renderNode.metadata.platforms)
        #expect(renderPlatforms.compactMap(\.name) == ["iOS", unavailableDefaultPlatform.availablePlatformsDisplayName])
        #expect(renderPlatforms.first(where: { $0.name == "iOS"          })?.introduced == "11.2")
        switch unavailableDefaultPlatform {
        case .iPadOS:
            #expect(renderPlatforms.first(where: { $0.name == "iPadOS"       }) == nil)
            #expect(renderPlatforms.first(where: { $0.name == "Mac Catalyst" })?.introduced == "11.2")
        case .catalyst:
            #expect(renderPlatforms.first(where: { $0.name == "iPadOS"       })?.introduced == "11.2")
            #expect(renderPlatforms.first(where: { $0.name == "Mac Catalyst" }) == nil)
        }
    }
    
    @Test(arguments: DirectiveLocation.allCases, UnavailableDefaultPlatform.allCases)
    func doesNotFillInFallbackAvailabilityForPlatformsMarkedUnavailableFromDirectiveAvailability(_ directiveLocation: DirectiveLocation, _ unavailableDefaultPlatform: UnavailableDefaultPlatform) async throws {
        let availableDirective = """
        @Metadata {
          @Available(iOS, introduced: "9.3")
        }
        """
        
        let catalog = Folder(name: "unit-test.docc") {
            JSONFile(symbolGraph: makeSymbolGraph(moduleName: "ModuleName", symbols: [
                makeSymbol(id: "some-symbol-id", kind: .class, pathComponents: ["SomeClass"], docComment: """
                    Some in-source documentation for this class.
                    
                    \(directiveLocation == .inSourceComment ? availableDirective : "")
                    """, availability: []) // No availability _attributes_ for this symbol
            ]))
            
            TextFile(name: "SomeClass.md", utf8Content: """
            # ``SomeClass``
            
            Some additional documentation for this class.
            \(directiveLocation == .extensionFile ? availableDirective : "")
            """)
            
            InfoPlist(defaultAvailability: ["ModuleName": [
                // One of the two fallback platforms, but not both, is marked unavailable here so its fallback availability won't be added.
                .init(unavailablePlatformName: unavailableDefaultPlatform.platformName),
            ]])
        }
        let context = try await load(catalog: catalog)
        #expect(context.problems.isEmpty, "Unexpected problems: \(context.problems.map(\.diagnostic.summary))")
        let node = try #require(context.documentationCache["some-symbol-id"])
        #expect(node.metadata?.availability.count == 1)
        let directiveAvailability = node.metadata?.availability.first
        #expect(directiveAvailability?.platform.rawValue      == "iOS")
        #expect(directiveAvailability?.introduced.description == "9.3.0")
        
        let converter = DocumentationContextConverter(context: context, renderContext: .init(documentationContext: context))
        let renderNode = try #require(converter.renderNode(for: node))
        
        let renderPlatforms = try #require(renderNode.metadata.platforms)
        #expect(renderPlatforms.compactMap(\.name) == ["iOS", unavailableDefaultPlatform.availablePlatformsDisplayName])
        #expect(renderPlatforms.first(where: { $0.name == "iOS"          })?.introduced == "9.3")
        switch unavailableDefaultPlatform {
        case .iPadOS:
            #expect(renderPlatforms.first(where: { $0.name == "iPadOS"       }) == nil)
            #expect(renderPlatforms.first(where: { $0.name == "Mac Catalyst" })?.introduced == "9.3")
        case .catalyst:
            #expect(renderPlatforms.first(where: { $0.name == "iPadOS"       })?.introduced == "9.3")
            #expect(renderPlatforms.first(where: { $0.name == "Mac Catalyst" }) == nil)
        }
    }
    
    @Test
    func fallbackAvailabilityDoesNotOverrideInSourceAvailability() async throws {
        let catalog = Folder(name: "unit-test.docc") {
            // This catalog contains two symbol graph files. One with iOS availability and one with Mac Catalyst availability for the same symbol.
            for (domainName, environment, introducedVersion) in [
                ("iOS",         nil,      SymbolGraph.SemanticVersion(major: 12, minor: 0, patch: 0)),
                ("macCatalyst", "macabi", SymbolGraph.SemanticVersion(major:  6, minor: 5, patch: 0)), // This explicit Mac Catalyst annotation takes precedence over the "fallback" information derived from the iOS availability.
            ] {
                JSONFile(name: "ModuleName-\(domainName).symbols.json", content: makeSymbolGraph(moduleName: "ModuleName", platform: .init(operatingSystem: .init(name: "ios"), environment: environment), symbols: [
                    makeSymbol(id: "some-symbol-id", kind: .class, pathComponents: ["SomeClass"], availability: [
                        .init(domainName: domainName, introduced: introducedVersion, deprecated: nil)
                    ])
                ]))
            }
        }
        let context = try await load(catalog: catalog)
        #expect(context.problems.isEmpty, "Unexpected problems: \(context.problems.map(\.diagnostic.summary))")
        let node = try #require(context.documentationCache["some-symbol-id"])
        let converter = DocumentationContextConverter(context: context, renderContext: .init(documentationContext: context))
        let renderNode = try #require(converter.renderNode(for: node))
        
        let renderPlatforms = try #require(renderNode.metadata.platforms)
        #expect(renderPlatforms.compactMap(\.name) == ["iOS", "iPadOS", "Mac Catalyst"])
        
        #expect(renderPlatforms.first(where: { $0.name == "iOS"          })?.introduced == "12.0")
        #expect(renderPlatforms.first(where: { $0.name == "iPadOS"       })?.introduced == "12.0")
        #expect(renderPlatforms.first(where: { $0.name == "Mac Catalyst" })?.introduced ==  "6.5")
    }
    
    @Test
    func defaultAvailabilityDoesNotOverrideInSourceAvailability() async throws {
        let catalog = Folder(name: "unit-test.docc") {
            // This catalog contains two symbol graph files. One with iOS availability and one with Mac Catalyst availability for the same symbol.
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
        #expect(context.problems.isEmpty, "Unexpected problems: \(context.problems.map(\.diagnostic.summary))")
        let node = try #require(context.documentationCache["some-symbol-id"])
        let converter = DocumentationContextConverter(context: context, renderContext: .init(documentationContext: context))
        let renderNode = try #require(converter.renderNode(for: node))
        
        let renderPlatforms = try #require(renderNode.metadata.platforms)
        #expect(renderPlatforms.compactMap(\.name) == ["iOS", "iPadOS", "Mac Catalyst"])
        
        #expect(renderPlatforms.first(where: { $0.name == "iOS"          })?.introduced == "12.0")
        #expect(renderPlatforms.first(where: { $0.name == "iPadOS"       })?.introduced == "12.0")
        #expect(renderPlatforms.first(where: { $0.name == "Mac Catalyst" })?.introduced ==  "6.5")
    }
    
    // MARK: Default Availability
    
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
        #expect(context.problems.isEmpty, "Unexpected problems: \(context.problems.map(\.diagnostic.summary))")
        let node = try #require(context.documentationCache["some-symbol-id"])
        let converter = DocumentationContextConverter(context: context, renderContext: .init(documentationContext: context))
        let renderNode = try #require(converter.renderNode(for: node))
        
        let renderPlatforms = try #require(renderNode.metadata.platforms)
        #expect(renderPlatforms.compactMap(\.name) == ["iOS", "iPadOS", "Mac Catalyst", "tvOS"])
        
        #expect(renderPlatforms.first(where: { $0.name == "iOS"          })?.introduced ==  "8.0")
        #expect(renderPlatforms.first(where: { $0.name == "Mac Catalyst" })?.introduced ==  "7.0")
        #expect(renderPlatforms.first(where: { $0.name == "iPadOS"       })?.introduced ==  "6.0")
        #expect(renderPlatforms.first(where: { $0.name == "tvOS"         })?.introduced == "10.0")
    }
    
    @Test
    func unavailableDefaultPlatformsDoNotRemovePlatformsWithSourceAvailability() async throws {
        let catalog = Folder(name: "unit-test.docc") {
            // This catalog contains two symbol graph files. One with iOS availability and one with Mac Catalyst availability for the same symbol.
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
                .init(unavailablePlatformName: .iOS),      // This configuration doesn't remove the in-source "iOS" availability from above
                .init(unavailablePlatformName: .iPadOS),
                .init(unavailablePlatformName: .catalyst), // This configuration doesn't remove the in-source "macCatalyst" availability from above
            ]])
        }
        let context = try await load(catalog: catalog)
        #expect(context.problems.isEmpty, "Unexpected problems: \(context.problems.map(\.diagnostic.summary))")
        let node = try #require(context.documentationCache["some-symbol-id"])
        let converter = DocumentationContextConverter(context: context, renderContext: .init(documentationContext: context))
        let renderNode = try #require(converter.renderNode(for: node))
        
        let renderPlatforms = try #require(renderNode.metadata.platforms)
        #expect(renderPlatforms.compactMap(\.name) == ["iOS", "Mac Catalyst"])
        
        #expect(renderPlatforms.first(where: { $0.name == "iOS"          })?.introduced == "10.0")
        #expect(renderPlatforms.first(where: { $0.name == "iPadOS"       }) == nil)
        #expect(renderPlatforms.first(where: { $0.name == "Mac Catalyst" })?.introduced == "12.0")
    }
    
    @Test
    func platformSpecificSymbolWithoutInSourceAvailabilityDoesNotDisplayDefaultAvailabilityForOtherPlatforms() async throws {
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
        #expect(context.problems.isEmpty, "Unexpected problems: \(context.problems.map(\.diagnostic.summary))")
        let firstNode  = try #require(context.documentationCache["first-symbol-id"])
        let secondNode = try #require(context.documentationCache["second-symbol-id"])
        let converter = DocumentationContextConverter(context: context, renderContext: .init(documentationContext: context))
        
        let firstRenderPlatforms  = try #require(converter.renderNode(for: firstNode )?.metadata.platforms)
        let secondRenderPlatforms = try #require(converter.renderNode(for: secondNode)?.metadata.platforms)
        #expect(firstRenderPlatforms.compactMap(\.name)  == ["iOS", "Mac Catalyst", "tvOS"])
        #expect(secondRenderPlatforms.compactMap(\.name) == ["iOS", "Mac Catalyst"],
                "The 'Second' symbol is not present in the tvOS symbol graph, so it shouldn't have any tvOS availability")
    }
    
    @Test
    func platformSpecificSymbolWithInSourceAvailabilityDoesNotDisplayDefaultAvailabilityForOtherPlatforms() async throws {
        let macOSOnlySymbol = makeSymbol(id: "macOS-only-symbol", kind: .class, pathComponents: ["MacOSOnlyClass"], availability: [
            makeAvailabilityItem(domainName: "macOS", introduced: .init(major: 14, minor: 0, patch: 0))
        ])

        let catalog = Folder(name: "unit-test.docc") {
            for (platformName, symbols) in [
                ("macos",   [macOSOnlySymbol]),
                ("ios",     []),
                ("watchos", [])
            ] {
                JSONFile(name: "ModuleName-\(platformName).symbols.json", content: makeSymbolGraph(
                    moduleName: "ModuleName",
                    platform: .init(operatingSystem: .init(name: platformName)),
                    symbols: symbols
                ))
            }
            
            InfoPlist(defaultAvailability: ["ModuleName": [
                .init(platformName: .macOS,   platformVersion: "10.0"),
                .init(platformName: .iOS,     platformVersion: "10.0"),
                .init(platformName: .watchOS, platformVersion: "10.0"),
            ]])
        }

        let context = try await load(catalog: catalog)
        #expect(context.problems.isEmpty, "Unexpected problems: \(context.problems.map(\.diagnostic.summary))")
        let node = try #require(context.documentationCache["macOS-only-symbol"])
        let converter = DocumentationContextConverter(context: context, renderContext: .init(documentationContext: context))
        let renderNode = try #require(converter.renderNode(for: node))
        let renderPlatforms = try #require(renderNode.metadata.platforms)
        #expect(renderPlatforms.map(\.name) == ["macOS"])
        #expect(renderPlatforms.map(\.introduced) == ["14.0"])
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
        let node = try #require(context.documentationCache["some-symbol-id"])
        let converter = DocumentationContextConverter(context: context, renderContext: .init(documentationContext: context))
        let renderNode = try #require(converter.renderNode(for: node))
        
        let renderPlatforms = try #require(renderNode.metadata.platforms)
        #expect(renderPlatforms.compactMap(\.name) == ["macOS"])
        #expect(renderPlatforms.first(where: { $0.name == "macOS" })?.introduced == "10.0")
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
        #expect(context.problems.isEmpty, "Unexpected problems: \(context.problems.map(\.diagnostic.summary))")
        let node = try #require(context.documentationCache["some-symbol-id"])
        let converter = DocumentationContextConverter(context: context, renderContext: .init(documentationContext: context))
        let renderNode = try #require(converter.renderNode(for: node))
        
        let renderPlatforms = try #require(renderNode.metadata.platforms)
        #expect(renderPlatforms.compactMap(\.name) == ["iOS", "iPadOS", "Mac Catalyst"])
        #expect(renderPlatforms.first(where: { $0.name == "iOS"          })?.introduced == "2.3")
        #expect(renderPlatforms.first(where: { $0.name == "iPadOS"       })?.introduced == "2.3")
        #expect(renderPlatforms.first(where: { $0.name == "Mac Catalyst" })?.introduced == "4.5",
                "The Mac Catalyst 'default' availability from the Info.plist is more specific than the 'fallback' from the 'default' iOS availability (also from the Info.plist)")
    }
    
    // MARK: In-Source Availability
    
    @Test(arguments: Self.allMainPlatforms)
    func displaysInSourceAvailabilityForAllPlatformsWhenThereIsOnlyOneSymbolGraph(_ platform: SymbolGraph.Platform) async throws {
        let catalog = Folder(name: "unit-test.docc") {
            JSONFile(symbolGraph: makeSymbolGraph(moduleName: "ModuleName", platform: platform, symbols: [
                makeSymbol(id: "some-symbol-id", kind: .class, pathComponents: ["SomeClass"], availability: [
                    // In-source availability attributes for many platforms
                    .init(domainName: "iOS",         introduced: .init(major: 1, minor: 1, patch: 0), deprecated: nil),
                    .init(domainName: "macCatalyst", introduced: .init(major: 2, minor: 2, patch: 0), deprecated: nil),
                    .init(domainName: "macOS",       introduced: .init(major: 3, minor: 3, patch: 0), deprecated: nil),
                    .init(domainName: "tvOS",        introduced: .init(major: 4, minor: 4, patch: 0), deprecated: nil),
                    .init(domainName: "visionOS",    introduced: .init(major: 5, minor: 5, patch: 0), deprecated: nil),
                    .init(domainName: "watchOS",     introduced: .init(major: 6, minor: 6, patch: 0), deprecated: nil),
                ])
            ]))
        }
        let context = try await load(catalog: catalog)
        #expect(context.problems.isEmpty, "Unexpected problems: \(context.problems.map(\.diagnostic.summary))")
        let node = try #require(context.documentationCache["some-symbol-id"])
        let converter = DocumentationContextConverter(context: context, renderContext: .init(documentationContext: context))
        let renderNode = try #require(converter.renderNode(for: node))
        
        let renderPlatforms = try #require(renderNode.metadata.platforms)
        #expect(renderPlatforms.compactMap(\.name) == ["iOS", "iPadOS", "Mac Catalyst", "macOS", "tvOS", "visionOS", "watchOS"])
        
        #expect(renderPlatforms.first(where: { $0.name == "iOS"          })?.introduced == "1.1")
        #expect(renderPlatforms.first(where: { $0.name == "iPadOS"       })?.introduced == "1.1")
        #expect(renderPlatforms.first(where: { $0.name == "Mac Catalyst" })?.introduced == "2.2")
        #expect(renderPlatforms.first(where: { $0.name == "macOS"        })?.introduced == "3.3")
        #expect(renderPlatforms.first(where: { $0.name == "tvOS"         })?.introduced == "4.4")
        #expect(renderPlatforms.first(where: { $0.name == "visionOS"     })?.introduced == "5.5")
        #expect(renderPlatforms.first(where: { $0.name == "watchOS"      })?.introduced == "6.6")
    }
    
    @Test(arguments: [
        SymbolGraph.Platform(operatingSystem: .init(name: "ios")),
        SymbolGraph.Platform(operatingSystem: .init(name: "ios"), environment: "macabi"), // Mac Catalyst
        SymbolGraph.Platform(operatingSystem: .init(name: "macosx")),
        SymbolGraph.Platform(operatingSystem: .init(name: "macos")),
        SymbolGraph.Platform(operatingSystem: .init(name: "watchos")),
        // tvOS and visionOS have custom symbol graphs in this test
    ])
    func symbolsMissingFromSpecificPlatformsDoNotDisplayInSourceAvailabilityForThosePlatforms(_ platform: SymbolGraph.Platform) async throws {
        let catalog = Folder(name: "unit-test.docc") {
            JSONFile(name: "ModuleName-\(platform.operatingSystem!.name).symbols.json", content: makeSymbolGraph(moduleName: "ModuleName", platform: platform, symbols: [
                makeSymbol(id: "some-symbol-id", kind: .class, pathComponents: ["SomeClass"], availability: [
                    // In-source availability attributes for many platforms
                    .init(domainName: "iOS",         introduced: .init(major: 1, minor: 1, patch: 0), deprecated: nil),
                    .init(domainName: "macCatalyst", introduced: .init(major: 2, minor: 2, patch: 0), deprecated: nil),
                    .init(domainName: "macOS",       introduced: .init(major: 3, minor: 3, patch: 0), deprecated: nil),
                    .init(domainName: "tvOS",        introduced: .init(major: 4, minor: 4, patch: 0), deprecated: nil),
                    .init(domainName: "visionOS",    introduced: .init(major: 5, minor: 5, patch: 0), deprecated: nil),
                    .init(domainName: "watchOS",     introduced: .init(major: 6, minor: 6, patch: 0), deprecated: nil),
                ])
            ]))
            
            // The symbol from above doesn't exist in the symbol graphs for tvOS and visionOS.
            for name in ["tvos", "visionos"] {
                JSONFile(name: "ModuleName-\(name).symbols.json", content: makeSymbolGraph(moduleName: "ModuleName", platform: .init(operatingSystem: .init(name: name)), symbols: [
                    // no symbols
                ]))
            }
        }
        let context = try await load(catalog: catalog)
        #expect(context.problems.isEmpty, "Unexpected problems: \(context.problems.map(\.diagnostic.summary))")
        #expect(context.inputs.symbolGraphURLs.count == 3)
        let node = try #require(context.documentationCache["some-symbol-id"])
        let converter = DocumentationContextConverter(context: context, renderContext: .init(documentationContext: context))
        let renderNode = try #require(converter.renderNode(for: node))
        
        let renderPlatforms = try #require(renderNode.metadata.platforms)
        withKnownIssue("Platform specific symbols shouldn't display 'default' availability for other platforms (rdar://173691006)") {
            #expect(renderPlatforms.compactMap(\.name) == ["iOS", "iPadOS", "Mac Catalyst", "macOS", "watchOS"])
        }
        
        #expect(renderPlatforms.first(where: { $0.name == "iOS"          })?.introduced == "1.1")
        #expect(renderPlatforms.first(where: { $0.name == "iPadOS"       })?.introduced == "1.1")
        #expect(renderPlatforms.first(where: { $0.name == "Mac Catalyst" })?.introduced == "2.2")
        #expect(renderPlatforms.first(where: { $0.name == "macOS"        })?.introduced == "3.3")
        withKnownIssue("Platform specific symbols shouldn't display 'default' availability for other platforms (rdar://173691006)") {
            #expect(renderPlatforms.first(where: { $0.name == "tvOS"         }) == nil)
            #expect(renderPlatforms.first(where: { $0.name == "visionOS"     }) == nil)
        }
        #expect(renderPlatforms.first(where: { $0.name == "watchOS"      })?.introduced == "6.6")
    }
    
    @Test(arguments: [true, false])
    func platformSpecificSymbolOnlyDisplaysItsOwnAvailability(withUnavailablePlatformsInInfoPlist: Bool) async throws {
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
        #expect(context.problems.isEmpty, "Unexpected problems: \(context.problems.map(\.diagnostic.summary))")
        let firstNode  = try #require(context.documentationCache["first-symbol-id"])
        let secondNode = try #require(context.documentationCache["second-symbol-id"])
        
        let converter = DocumentationContextConverter(context: context, renderContext: .init(documentationContext: context))
        let firstRenderNode  = try #require(converter.renderNode(for: firstNode))
        let secondRenderNode = try #require(converter.renderNode(for: secondNode))
        
        let firstRenderPlatforms  = try #require(firstRenderNode.metadata.platforms)
        let secondRenderPlatforms = try #require(secondRenderNode.metadata.platforms)
        
        if withUnavailablePlatformsInInfoPlist {
            #expect(firstRenderPlatforms.compactMap(\.name) == ["iOS", "Mac Catalyst"])
            
            #expect(firstRenderPlatforms.first(where: { $0.name == "iOS"          })?.introduced == "10.0")
            #expect(firstRenderPlatforms.first(where: { $0.name == "iPadOS"       }) == nil)
            #expect(firstRenderPlatforms.first(where: { $0.name == "Mac Catalyst" })?.introduced == "12.0")
            
        } else {
            #expect(firstRenderPlatforms.compactMap(\.name) == ["iOS", "iPadOS", "Mac Catalyst"])
            
            #expect(firstRenderPlatforms.first(where: { $0.name == "iOS"          })?.introduced == "10.0")
            #expect(firstRenderPlatforms.first(where: { $0.name == "iPadOS"       })?.introduced == "10.0")
            #expect(firstRenderPlatforms.first(where: { $0.name == "Mac Catalyst" })?.introduced == "12.0")
        }
        #expect(secondRenderPlatforms.compactMap(\.name) == ["Mac Catalyst"])
        #expect(secondRenderPlatforms.first(where: { $0.name == "Mac Catalyst" })?.introduced == "12.0")
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
        #expect(context.problems.isEmpty, "Unexpected problems: \(context.problems.map(\.diagnostic.summary))")
        let node = try #require(context.documentationCache["some-symbol-id"])
        let converter = DocumentationContextConverter(context: context, renderContext: .init(documentationContext: context))
        let renderNode = try #require(converter.renderNode(for: node))
        let renderPlatforms = try #require(renderNode.metadata.platforms)
        
        #expect(renderPlatforms.compactMap(\.name) == ["Mac Catalyst", "tvOS"])
        
        #expect(renderPlatforms.first(where: { $0.name == "tvOS"         })?.introduced == "12.0")
        #expect(renderPlatforms.first(where: { $0.name == "Mac Catalyst" })?.introduced == "15.2")
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
        #expect(context.problems.isEmpty, "Unexpected problems: \(context.problems.map(\.diagnostic.summary))")
        let node = try #require(context.documentationCache["some-symbol-id"])
        let converter = DocumentationContextConverter(context: context, renderContext: .init(documentationContext: context))
        let renderNode = try #require(converter.renderNode(for: node))
        let renderPlatforms = try #require(renderNode.metadata.platforms)
        
        #expect(renderPlatforms.compactMap(\.name) == ["iOS", "iPadOS", "Mac Catalyst"])
        
        #expect(renderPlatforms.first(where: { $0.name == "iOS"          })?.introduced == "12.0")
        #expect(renderPlatforms.first(where: { $0.name == "iPadOS"       })?.introduced == "12.0")
        #expect(renderPlatforms.first(where: { $0.name == "Mac Catalyst" })?.introduced == "12.0")
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
        #expect(context.problems.isEmpty, "Unexpected problems: \(context.problems.map(\.diagnostic.summary))")
        let node = try #require(context.documentationCache["some-symbol-id"])
        let converter = DocumentationContextConverter(context: context, renderContext: .init(documentationContext: context))
        let renderNode = try #require(converter.renderNode(for: node))
        let renderPlatforms = try #require(renderNode.metadata.platforms)
        
        #expect(renderPlatforms.compactMap(\.name) == ["iOS", "iPadOS", "Mac Catalyst", "macOS", "tvOS", "watchOS"])
        
        #expect(renderPlatforms.first(where: { $0.name == "iOS"    })?.introduced == nil)
        #expect(renderPlatforms.first(where: { $0.name == "iOS"    })?.deprecated == "13.0")
        withKnownIssue("iPadOS availability should follow iOS availability (rdar://173704351)", {
            #expect(renderPlatforms.first(where: { $0.name == "iPadOS" })?.introduced == nil)
            #expect(renderPlatforms.first(where: { $0.name == "iPadOS" })?.deprecated == "13.0")
        }, when: { fakeExtensionGraph == .iOS })
        
        #expect(renderPlatforms.first(where: { $0.name == "macOS"        })?.introduced == "10.15")
        #expect(renderPlatforms.first(where: { $0.name == "Mac Catalyst" })?.introduced ==  "1.0")
        #expect(renderPlatforms.first(where: { $0.name == "tvOS"         })?.introduced == "13.0")
        #expect(renderPlatforms.first(where: { $0.name == "watchOS"      })?.introduced ==  "6.0")
    }
    
    // MARK: Deprecations
    
    @Test(arguments: Self.allMainPlatforms)
    func symbolIsConsideredDeprecatedWhenAllPlatformsHaveDeprecatedVersion(_ platform: SymbolGraph.Platform) async throws {
        let catalog = Folder(name: "unit-test.docc") {
            JSONFile(symbolGraph: makeSymbolGraph(moduleName: "ModuleName", platform: platform, symbols: [
                makeSymbol(id: "some-symbol-id", kind: .class, pathComponents: ["SomeClass"], availability: [
                    // In-source availability attributes for many platforms
                    .init(domainName: "iOS",         introduced: nil, deprecated: .init(major: 1, minor: 1, patch: 0)),
                    .init(domainName: "macCatalyst", introduced: nil, deprecated: .init(major: 2, minor: 2, patch: 0)),
                    .init(domainName: "macOS",       introduced: nil, deprecated: .init(major: 3, minor: 3, patch: 0)),
                    .init(domainName: "tvOS",        introduced: nil, deprecated: .init(major: 4, minor: 4, patch: 0)),
                    .init(domainName: "visionOS",    introduced: nil, deprecated: .init(major: 5, minor: 5, patch: 0)),
                    .init(domainName: "watchOS",     introduced: nil, deprecated: .init(major: 6, minor: 6, patch: 0)),
                ])
            ]))
        }
        let context = try await load(catalog: catalog)
        #expect(context.problems.isEmpty, "Unexpected problems: \(context.problems.map(\.diagnostic.summary))")
        let node = try #require(context.documentationCache["some-symbol-id"])
        let converter = DocumentationContextConverter(context: context, renderContext: .init(documentationContext: context))
        let renderNode = try #require(converter.renderNode(for: node))
        
        let renderPlatforms = try #require(renderNode.metadata.platforms)
        if platform == .init(operatingSystem: .init(name: "ios")) {
            #expect(renderPlatforms.compactMap(\.name) == ["iOS", "iPadOS", "Mac Catalyst", "macOS", "tvOS", "visionOS", "watchOS"])
        } else {
            // ???: Why do we only fill "iPadOS" availability from the iOS symbol graph? (rdar://172280267)
            #expect(renderPlatforms.compactMap(\.name) == ["iOS", "Mac Catalyst", "macOS", "tvOS", "visionOS", "watchOS"])
        }
        
        #expect(renderPlatforms.first(where: { $0.name == "iOS"          })?.deprecated == "1.1")
        if platform == .init(operatingSystem: .init(name: "ios")) {
            #expect(renderPlatforms.first(where: { $0.name == "iPadOS"   })?.deprecated == "1.1")
        } else {
            #expect(renderPlatforms.first(where: { $0.name == "iPadOS"   }) == nil)
        }
        #expect(renderPlatforms.first(where: { $0.name == "Mac Catalyst" })?.deprecated == "2.2")
        #expect(renderPlatforms.first(where: { $0.name == "macOS"        })?.deprecated == "3.3")
        #expect(renderPlatforms.first(where: { $0.name == "tvOS"         })?.deprecated == "4.4")
        #expect(renderPlatforms.first(where: { $0.name == "visionOS"     })?.deprecated == "5.5")
        #expect(renderPlatforms.first(where: { $0.name == "watchOS"      })?.deprecated == "6.6")
        
        let renderReference = try #require(converter.renderContext.store.content(for: node.reference)?.renderReference as? TopicRenderReference)
        #expect(renderReference.isDeprecated)
    }
    
    @Test
    func symbolAvailableOnOnePlatformIsNotConsideredDeprecated() async throws {
        let catalog = Folder(name: "unit-test.docc") {
            JSONFile(symbolGraph: makeSymbolGraph(moduleName: "ModuleName", symbols: [
                makeSymbol(id: "some-symbol-id", kind: .class, pathComponents: ["SomeClass"], availability: [
                    .init(domainName: "iOS",   introduced: .init(major:  9, minor: 2, patch: 0), deprecated: nil),
                    .init(domainName: "macOS", introduced: .init(major: 10, minor: 7, patch: 0), deprecated: .init(major: 10, minor: 9, patch: 2)),
                ]),
            ]))
        }
        let context = try await load(catalog: catalog)
        #expect(context.problems.isEmpty, "Unexpected problems: \(context.problems.map(\.diagnostic.summary))")
        let node = try #require(context.documentationCache["some-symbol-id"])
        let converter = DocumentationContextConverter(context: context, renderContext: .init(documentationContext: context))
        let renderNode = try #require(converter.renderNode(for: node))
        let renderPlatforms = try #require(renderNode.metadata.platforms)
        
        #expect(renderPlatforms.compactMap(\.name) == ["iOS", "iPadOS", "Mac Catalyst", "macOS"])
        
        #expect(renderPlatforms.first(where: { $0.name == "iOS"          })?.introduced ==  "9.2")
        #expect(renderPlatforms.first(where: { $0.name == "iPadOS"       })?.introduced ==  "9.2")
        #expect(renderPlatforms.first(where: { $0.name == "Mac Catalyst" })?.introduced ==  "9.2")
        #expect(renderPlatforms.first(where: { $0.name == "macOS"        })?.introduced == "10.7")
        #expect(renderPlatforms.first(where: { $0.name == "macOS"        })?.deprecated == "10.9.2")
        
        let renderReference = try #require(converter.renderContext.store.content(for: node.reference)?.renderReference as? TopicRenderReference)
        #expect(renderReference.isDeprecated == false)
    }
    
    @Test(arguments: ["9.2", nil])
    func symbolAvailableOnOnePlatformIsNotConsideredDeprecatedWhenDefaultAvailable(defaultIntroducedVersion: String?) async throws {
        let catalog = Folder(name: "unit-test.docc") {
            JSONFile(symbolGraph: makeSymbolGraph(moduleName: "ModuleName", symbols: [
                makeSymbol(id: "some-symbol-id", kind: .class, pathComponents: ["SomeClass"], availability: [
                    .init(domainName: "macOS", introduced: .init(major: 10, minor: 7, patch: 0), deprecated: .init(major: 10, minor: 9, patch: 2)),
                ]),
            ]))
            
            InfoPlist(defaultAvailability: ["ModuleName": [
                .init(platformName: .iOS, platformVersion: defaultIntroducedVersion)
            ]])
        }
        let context = try await load(catalog: catalog)
        #expect(context.problems.isEmpty, "Unexpected problems: \(context.problems.map(\.diagnostic.summary))")
        let node = try #require(context.documentationCache["some-symbol-id"])
        let converter = DocumentationContextConverter(context: context, renderContext: .init(documentationContext: context))
        let renderNode = try #require(converter.renderNode(for: node))
        let renderPlatforms = try #require(renderNode.metadata.platforms)
        
        if defaultIntroducedVersion != nil {
            #expect(renderPlatforms.compactMap(\.name) == ["iOS", "iPadOS", "Mac Catalyst", "macOS"])
        } else {
            // ???: Why do we not want fallback platforms in when there's no introduced version? (rdar://171807245)
            #expect(renderPlatforms.compactMap(\.name) == ["iOS", "macOS"])
        }
        
        #expect(renderPlatforms.first(where: { $0.name == "iOS"          })?.introduced == defaultIntroducedVersion)
        #expect(renderPlatforms.first(where: { $0.name == "iPadOS"       })?.introduced == defaultIntroducedVersion)
        #expect(renderPlatforms.first(where: { $0.name == "Mac Catalyst" })?.introduced == defaultIntroducedVersion)
        #expect(renderPlatforms.first(where: { $0.name == "macOS"        })?.introduced == "10.7")
        #expect(renderPlatforms.first(where: { $0.name == "macOS"        })?.deprecated == "10.9.2")
        
        let renderReference = try #require(converter.renderContext.store.content(for: node.reference)?.renderReference as? TopicRenderReference)
        #expect(renderReference.isDeprecated == false)
    }

    @Test(arguments: DirectiveLocation.allCases)
    func symbolIsConsideredDeprecatedWhenOnlyAvailableDirectiveHasDeprecatedVersion(_ directiveLocation: DirectiveLocation) async throws {
        let availableDirective = """
        @Metadata {
          @Available(iOS, introduced: "9.2", deprecated: "13.0")
        }
        """
        
        let catalog = Folder(name: "unit-test.docc") {
            JSONFile(symbolGraph: makeSymbolGraph(moduleName: "ModuleName", symbols: [
                makeSymbol(id: "some-symbol-id", kind: .class, pathComponents: ["SomeClass"], docComment: """
                    Some in-source documentation for this class.
                    
                    \(directiveLocation == .inSourceComment ? availableDirective : "")
                    """, availability: []) // No availability _attributes_ for this symbol
            ]))
            
            TextFile(name: "SomeClass.md", utf8Content: """
            # ``SomeClass``
            
            Some additional documentation for this class.
            \(directiveLocation == .extensionFile ? availableDirective : "")
            """)
        }
        let context = try await load(catalog: catalog)
        #expect(context.problems.isEmpty, "Unexpected problems: \(context.problems.map(\.diagnostic.summary))")
        let node = try #require(context.documentationCache["some-symbol-id"])
        #expect(node.metadata?.availability.count == 1)
        let directiveAvailability = node.metadata?.availability.first
        #expect(directiveAvailability?.platform.rawValue       == "iOS")
        #expect(directiveAvailability?.introduced.description  ==  "9.2.0")
        #expect(directiveAvailability?.deprecated?.description == "13.0.0")
        
        let converter = DocumentationContextConverter(context: context, renderContext: .init(documentationContext: context))
        let renderNode = try #require(converter.renderNode(for: node))
        let renderPlatforms = try #require(renderNode.metadata.platforms)
        
        #expect(renderPlatforms.compactMap(\.name) == ["iOS", "iPadOS", "Mac Catalyst"])
        #expect(renderPlatforms.first(where: { $0.name == "iOS"          })?.introduced ==  "9.2")
        #expect(renderPlatforms.first(where: { $0.name == "iPadOS"       })?.introduced ==  "9.2")
        #expect(renderPlatforms.first(where: { $0.name == "Mac Catalyst" })?.introduced ==  "9.2")
        
        #expect(renderPlatforms.first(where: { $0.name == "iOS"          })?.deprecated == "13.0")
        #expect(renderPlatforms.first(where: { $0.name == "iPadOS"       })?.deprecated == "13.0")
        #expect(renderPlatforms.first(where: { $0.name == "Mac Catalyst" })?.deprecated == "13.0")
        
        withKnownIssue("Available directive isn't considered for TopicRenderReference deprecation (rdar://173761647)") {
            let renderReference = try #require(converter.renderContext.store.content(for: node.reference)?.renderReference as? TopicRenderReference)
            #expect(renderReference.isDeprecated)
        }
    }
    
    @Test
    func articleIsConsideredDeprecatedWhenOnlyAvailableDirectiveHasDeprecatedVersion() async throws {
        let catalog = Folder(name: "unit-test.docc") {
            JSONFile(symbolGraph: makeSymbolGraph(moduleName: "ModuleName", symbols: []))
            
            TextFile(name: "SomeArticle.md", utf8Content: """
            # Some article 
            
            @Metadata {
              @Available(iOS, introduced: "9.2", deprecated: "13.0")
            }
            """)
        }
        let context = try await load(catalog: catalog)
        #expect(context.problems.isEmpty, "Unexpected problems: \(context.problems.map(\.diagnostic.summary))")
        let reference = try #require(context.knownPages.first(where: { $0.lastPathComponent == "SomeArticle" }))
        let node = try #require(context.documentationCache[reference])
        #expect(node.metadata?.availability.count == 1)
        let directiveAvailability = node.metadata?.availability.first
        #expect(directiveAvailability?.platform.rawValue       == "iOS")
        #expect(directiveAvailability?.introduced.description  ==  "9.2.0")
        #expect(directiveAvailability?.deprecated?.description == "13.0.0")
        
        let converter = DocumentationContextConverter(context: context, renderContext: .init(documentationContext: context))
        let renderNode = try #require(converter.renderNode(for: node))
        let renderPlatforms = try #require(renderNode.metadata.platforms)
        
        #expect(renderPlatforms.compactMap(\.name) == ["iOS", "iPadOS", "Mac Catalyst"])
        #expect(renderPlatforms.first(where: { $0.name == "iOS"          })?.introduced ==  "9.2")
        #expect(renderPlatforms.first(where: { $0.name == "iPadOS"       })?.introduced ==  "9.2")
        #expect(renderPlatforms.first(where: { $0.name == "Mac Catalyst" })?.introduced ==  "9.2")
        
        #expect(renderPlatforms.first(where: { $0.name == "iOS"          })?.deprecated == "13.0")
        #expect(renderPlatforms.first(where: { $0.name == "iPadOS"       })?.deprecated == "13.0")
        #expect(renderPlatforms.first(where: { $0.name == "Mac Catalyst" })?.deprecated == "13.0")
        
        withKnownIssue("Available directive isn't considered for TopicRenderReference deprecation (rdar://173761647)") {
            let renderReference = try #require(converter.renderContext.store.content(for: node.reference)?.renderReference as? TopicRenderReference)
            #expect(renderReference.isDeprecated)
        }
    }
    
    @Test(arguments: DirectiveLocation.allCases)
    func symbolIsNotConsideredDeprecatedWhenOnlySomeAvailableDirectivesHaveDeprecatedVersion(_ directiveLocation: DirectiveLocation) async throws {
        let availableDirective = """
        @Metadata {
          @Available(iOS,   introduced: "9.2",  deprecated: "13.0")
          @Available(macOS, introduced: "10.14")
        }
        """
        
        let catalog = Folder(name: "unit-test.docc") {
            JSONFile(symbolGraph: makeSymbolGraph(moduleName: "ModuleName", symbols: [
                makeSymbol(id: "some-symbol-id", kind: .class, pathComponents: ["SomeClass"], docComment: """
                    Some in-source documentation for this class.
                    
                    \(directiveLocation == .inSourceComment ? availableDirective : "")
                    """, availability: []) // No availability _attributes_ for this symbol
            ]))
            
            TextFile(name: "SomeClass.md", utf8Content: """
            # ``SomeClass``
            
            Some additional documentation for this class.
            \(directiveLocation == .extensionFile ? availableDirective : "")
            """)
        }
        let context = try await load(catalog: catalog)
        #expect(context.problems.isEmpty, "Unexpected problems: \(context.problems.map(\.diagnostic.summary))")
        let node = try #require(context.documentationCache["some-symbol-id"])
        #expect(node.metadata?.availability.count == 2)
        let iOSDirectiveAvailability = node.metadata?.availability.first
        #expect(iOSDirectiveAvailability?.platform.rawValue       == "iOS")
        #expect(iOSDirectiveAvailability?.introduced.description  ==  "9.2.0")
        #expect(iOSDirectiveAvailability?.deprecated?.description == "13.0.0")
        
        let macOSDirectiveAvailability = node.metadata?.availability.last
        #expect(macOSDirectiveAvailability?.platform.rawValue      == "macOS")
        #expect(macOSDirectiveAvailability?.introduced.description == "10.14.0")
        #expect(macOSDirectiveAvailability?.deprecated             == nil)
        
        let converter = DocumentationContextConverter(context: context, renderContext: .init(documentationContext: context))
        let renderNode = try #require(converter.renderNode(for: node))
        let renderPlatforms = try #require(renderNode.metadata.platforms)
        
        #expect(renderPlatforms.compactMap(\.name) == ["iOS", "iPadOS", "Mac Catalyst", "macOS"])
        #expect(renderPlatforms.first(where: { $0.name == "iOS"          })?.introduced ==  "9.2")
        #expect(renderPlatforms.first(where: { $0.name == "iPadOS"       })?.introduced ==  "9.2")
        #expect(renderPlatforms.first(where: { $0.name == "Mac Catalyst" })?.introduced ==  "9.2")
        
        #expect(renderPlatforms.first(where: { $0.name == "iOS"          })?.deprecated == "13.0")
        #expect(renderPlatforms.first(where: { $0.name == "iPadOS"       })?.deprecated == "13.0")
        #expect(renderPlatforms.first(where: { $0.name == "Mac Catalyst" })?.deprecated == "13.0")
        
        #expect(renderPlatforms.first(where: { $0.name == "macOS" })?.introduced == "10.14")
        #expect(renderPlatforms.first(where: { $0.name == "macOS" })?.deprecated == nil)
        
        let renderReference = try #require(converter.renderContext.store.content(for: node.reference)?.renderReference as? TopicRenderReference)
        #expect(renderReference.isDeprecated == false)
    }
    
    @Test
    func articleIsNotConsideredDeprecatedWhenOnlySomeAvailableDirectivesHaveDeprecatedVersion() async throws {
        let catalog = Folder(name: "unit-test.docc") {
            JSONFile(symbolGraph: makeSymbolGraph(moduleName: "ModuleName", symbols: []))
            
            TextFile(name: "SomeArticle.md", utf8Content: """
            # Some article 
               
            @Metadata {
              @Available(iOS,   introduced: "9.2",  deprecated: "13.0")
              @Available(macOS, introduced: "10.14")
            }    
            """)
        }
        let context = try await load(catalog: catalog)
        #expect(context.problems.isEmpty, "Unexpected problems: \(context.problems.map(\.diagnostic.summary))")
        let reference = try #require(context.knownPages.first(where: { $0.lastPathComponent == "SomeArticle" }))
        let node = try #require(context.documentationCache[reference])
        #expect(node.metadata?.availability.count == 2)
        let iOSDirectiveAvailability = node.metadata?.availability.first
        #expect(iOSDirectiveAvailability?.platform.rawValue       == "iOS")
        #expect(iOSDirectiveAvailability?.introduced.description  ==  "9.2.0")
        #expect(iOSDirectiveAvailability?.deprecated?.description == "13.0.0")
        
        let macOSDirectiveAvailability = node.metadata?.availability.last
        #expect(macOSDirectiveAvailability?.platform.rawValue      == "macOS")
        #expect(macOSDirectiveAvailability?.introduced.description == "10.14.0")
        #expect(macOSDirectiveAvailability?.deprecated             == nil)
        
        let converter = DocumentationContextConverter(context: context, renderContext: .init(documentationContext: context))
        let renderNode = try #require(converter.renderNode(for: node))
        let renderPlatforms = try #require(renderNode.metadata.platforms)
        
        #expect(renderPlatforms.compactMap(\.name) == ["iOS", "iPadOS", "Mac Catalyst", "macOS"])
        #expect(renderPlatforms.first(where: { $0.name == "iOS"          })?.introduced ==  "9.2")
        #expect(renderPlatforms.first(where: { $0.name == "iPadOS"       })?.introduced ==  "9.2")
        #expect(renderPlatforms.first(where: { $0.name == "Mac Catalyst" })?.introduced ==  "9.2")
        
        #expect(renderPlatforms.first(where: { $0.name == "iOS"          })?.deprecated == "13.0")
        #expect(renderPlatforms.first(where: { $0.name == "iPadOS"       })?.deprecated == "13.0")
        #expect(renderPlatforms.first(where: { $0.name == "Mac Catalyst" })?.deprecated == "13.0")
        #expect(renderPlatforms.first(where: { $0.name == "macOS" })?.introduced == "10.14")
        #expect(renderPlatforms.first(where: { $0.name == "macOS" })?.deprecated == nil)
        
        let renderReference = try #require(converter.renderContext.store.content(for: node.reference)?.renderReference as? TopicRenderReference)
        #expect(renderReference.isDeprecated == false)
    }
    
    enum AvailabilitySource: Equatable, CaseIterable {
        case infoPlist
        case inSourceAttribute
        case directiveInDocComment
        case directiveInExtensionFile
    }
    
    @Test(arguments: DirectiveLocation.allCases, AvailabilitySource.allCases)
    func symbolIsConsideredDeprecatedWithWarningWhenAvailableWithDeprecationSummaryDirective(_ deprecationSummaryLocation: DirectiveLocation, _ availabilitySource: AvailabilitySource) async throws {
        let availableDirective = """
        @Metadata {
          @Available(macOS, introduced: "10.14")
        }
        """
        
        let deprecationSummaryDirective = """
        @DeprecationSummary {
          Some message that describes why this symbol is deprecated
        }
        """
        
        let catalog = Folder(name: "unit-test.docc") {
            JSONFile(symbolGraph: makeSymbolGraph(moduleName: "ModuleName", symbols: [
                makeSymbol(
                    id: "some-symbol-id", kind: .class, pathComponents: ["SomeClass"],
                    docComment: """
                    Some in-source documentation for this class.
                    
                    \(availabilitySource == .directiveInDocComment ? availableDirective : "")
                    \(deprecationSummaryLocation == .inSourceComment ? deprecationSummaryDirective : "")
                    """,
                    availability: availabilitySource == .inSourceAttribute ? [
                        .init(domainName: "macOS", introduced: .init(major: 10, minor: 14, patch: 0), deprecated: nil)
                    ] : [])
            ]))
            
            TextFile(name: "SomeClass.md", utf8Content: """
            # ``SomeClass``
            
            Some additional documentation for this class.
            \(availabilitySource == .directiveInExtensionFile ? availableDirective : "")
            \(deprecationSummaryLocation == .extensionFile ? deprecationSummaryDirective : "")
            """)
            
            if availabilitySource == .infoPlist {
                InfoPlist(defaultAvailability: ["ModuleName": [
                    .init(platformName: .macOS, platformVersion: "10.14")
                ]])
            }
        }
        let context = try await load(catalog: catalog)
        #expect(context.problems.map(\.diagnostic.identifier) == ["DeprecationSummaryForAvailableSymbol"], "Unexpected problems: \(context.problems.map(\.diagnostic.summary))")
        let node = try #require(context.documentationCache["some-symbol-id"])
        let converter = DocumentationContextConverter(context: context, renderContext: .init(documentationContext: context))
        let renderNode = try #require(converter.renderNode(for: node))
        
        #expect(renderNode.deprecationSummary == [.paragraph(.init(inlineContent: [
            .text("Some message that describes why this symbol is deprecated")
        ]))])
        
        let renderPlatforms = try #require(renderNode.metadata.platforms)
        
        #expect(renderPlatforms.compactMap(\.name) == ["macOS"])
        #expect(renderPlatforms.first(where: { $0.name == "macOS" })?.introduced == "10.14")
        #expect(renderPlatforms.first(where: { $0.name == "macOS" })?.deprecated == nil)
        
        let renderReference = try #require(converter.renderContext.store.content(for: node.reference)?.renderReference as? TopicRenderReference)
        #expect(renderReference.isDeprecated)
    }
    
    @Test
    func symbolDisplaysInSourceDeprecationMessage() async throws {
        let catalog = Folder(name: "unit-test.docc") {
            JSONFile(symbolGraph: makeSymbolGraph(moduleName: "ModuleName", symbols: [
                makeSymbol(id: "some-symbol-id", kind: .class, pathComponents: ["SomeClass"], availability: [
                    .init(domainName: "macOS", introduced: nil, deprecated: .init(major: 10, minor: 14, patch: 0), message: "Some message that describes why this symbol is deprecated")
                ])
            ]))
        }
        let context = try await load(catalog: catalog)
        #expect(context.problems.isEmpty, "Unexpected problems: \(context.problems.map(\.diagnostic.summary))")
        let node = try #require(context.documentationCache["some-symbol-id"])
        let converter = DocumentationContextConverter(context: context, renderContext: .init(documentationContext: context))
        let renderNode = try #require(converter.renderNode(for: node))
        
        #expect(renderNode.deprecationSummary == [.paragraph(.init(inlineContent: [
            .text("Some message that describes why this symbol is deprecated")
        ]))])
        
        let renderPlatforms = try #require(renderNode.metadata.platforms)
        
        #expect(renderPlatforms.compactMap(\.name) == ["macOS"])
        #expect(renderPlatforms.first(where: { $0.name == "macOS" })?.introduced == nil)
        #expect(renderPlatforms.first(where: { $0.name == "macOS" })?.deprecated == "10.14")
        
        let renderReference = try #require(converter.renderContext.store.content(for: node.reference)?.renderReference as? TopicRenderReference)
        #expect(renderReference.isDeprecated)
    }
    
    // FIXME: Articles don't display or consider DeprecationSummary information (rdar://173688303)
    @Test(.bug("rdar://173688303"), arguments: [AvailabilitySource.directiveInExtensionFile])
    func articleIsConsideredDeprecatedWhenAvailableWithDeprecationSummaryDirective(_ availabilitySource: AvailabilitySource) async throws {
        let availableDirective = """
        @Metadata {
          @Available(macOS, introduced: "10.14")
        }
        """
        
        let catalog = Folder(name: "unit-test.docc") {
            JSONFile(symbolGraph: makeSymbolGraph(moduleName: "ModuleName", symbols: []))
            
            TextFile(name: "SomeArticle.md", utf8Content: """
            # Some Article
            
            This is a deprecated article that's also still available one one platform.
            
            \(availabilitySource == .directiveInExtensionFile ? availableDirective : "")
            
            @DeprecationSummary {
              Some message that describes why this article is deprecated
            }
            """)
            
            if availabilitySource == .infoPlist {
                InfoPlist(defaultAvailability: ["ModuleName": [
                    .init(platformName: .macOS, platformVersion: "10.14")
                ]])
            }
        }
        let context = try await load(catalog: catalog)
        withKnownIssue("Articles don't display or consider DeprecationSummary information (rdar://173688303)") {
            #expect(context.problems.map(\.diagnostic.identifier) == ["DeprecationSummaryForAvailableSymbol"], "Unexpected problems: \(context.problems.map(\.diagnostic.summary))")
        }
        let reference = try #require(context.knownPages.first(where: { $0.lastPathComponent == "SomeArticle" }))
        let node = try #require(context.documentationCache[reference])
        let converter = DocumentationContextConverter(context: context, renderContext: .init(documentationContext: context))
        let renderNode = try #require(converter.renderNode(for: node))
        
        withKnownIssue("Articles don't display or consider DeprecationSummary information (rdar://173688303)") {
            #expect(renderNode.deprecationSummary == [.paragraph(.init(inlineContent: [
                .text("Some message that describes why this article is deprecated")
            ]))])
        }
        
        let renderPlatforms = try #require(renderNode.metadata.platforms)
        
        #expect(renderPlatforms.compactMap(\.name) == ["macOS"])
        #expect(renderPlatforms.first(where: { $0.name == "macOS" })?.introduced == "10.14")
        #expect(renderPlatforms.first(where: { $0.name == "macOS" })?.deprecated == nil)
        
        withKnownIssue("Articles don't display or consider DeprecationSummary information (rdar://173688303)") {
            let renderReference = try #require(converter.renderContext.store.content(for: node.reference)?.renderReference as? TopicRenderReference)
            #expect(renderReference.isDeprecated)
        }
    }
    // MARK: Beta
    
    @Test(arguments: AvailabilitySource.allCases)
    func symbolIsConsideredInBetaWhenOnlyPlatformIsCurrentlyInBeta(_ availabilitySource: AvailabilitySource) async throws {
        let availableDirective = """
        @Metadata {
          @Available(macOS, introduced: "10.14")
        }
        """
        
        let catalog = Folder(name: "unit-test.docc") {
            JSONFile(symbolGraph: makeSymbolGraph(moduleName: "ModuleName", symbols: [
                makeSymbol(
                    id: "some-symbol-id", kind: .class, pathComponents: ["SomeClass"],
                    docComment: """
                    Some in-source documentation for this class.
                    
                    \(availabilitySource == .directiveInDocComment ? availableDirective : "")
                    """,
                    availability: availabilitySource == .inSourceAttribute ? [
                        .init(domainName: "macOS", introduced: .init(major: 10, minor: 14, patch: 0), deprecated: nil)
                    ] : [])
            ]))
            
            TextFile(name: "SomeClass.md", utf8Content: """
            # ``SomeClass``
            
            Some additional documentation for this class.
            \(availabilitySource == .directiveInExtensionFile ? availableDirective : "")
            """)
            
            if availabilitySource == .infoPlist {
                InfoPlist(defaultAvailability: ["ModuleName": [
                    .init(platformName: .macOS, platformVersion: "10.14")
                ]])
            }
        }
        
        var configuration = DocumentationContext.Configuration()
        configuration.externalMetadata.currentPlatforms = [
            "macOS": .init(.init(10, 14, 0), beta: true),
        ]
        let context = try await load(catalog: catalog, configuration: configuration)
        #expect(context.problems.isEmpty, "Unexpected problems: \(context.problems.map(\.diagnostic.summary))")
        let node = try #require(context.documentationCache["some-symbol-id"])
        let converter = DocumentationContextConverter(context: context, renderContext: .init(documentationContext: context))
        let renderNode = try #require(converter.renderNode(for: node))

        let renderPlatforms = try #require(renderNode.metadata.platforms)
        
        #expect(renderPlatforms.compactMap(\.name) == ["macOS"])
        #expect(renderPlatforms.first?.introduced == "10.14")
        #expect(renderPlatforms.first?.isBeta     == true)
        
        #expect(renderNode.metadata.isBeta)
        
        try withKnownIssue("Symbols are only considered in-beta when the introduced version is from in-source attributes (rdar://173773442)", {
            let renderReference = try #require(converter.renderContext.store.content(for: node.reference)?.renderReference as? TopicRenderReference)
            #expect(renderReference.isBeta)
        }, when: { availabilitySource != .inSourceAttribute })
    }
    
    // FIXME: Articles don't display default availability (rdar://173688303)
    // FIXME: Articles are not considered in-beta for any source of availability (rdar://173773442)
    @Test(.bug("rdar://173773442&173688303"), arguments: [AvailabilitySource.infoPlist, .directiveInExtensionFile])
    func articleIsConsideredInBetaWhenOnlyPlatformIsCurrentlyInBeta(_ availabilitySource: AvailabilitySource) async throws {
        let availableDirective = """
        @Metadata {
          @Available(macOS, introduced: "10.14")
        }
        """
        
        let catalog = Folder(name: "unit-test.docc") {
            JSONFile(symbolGraph: makeSymbolGraph(moduleName: "ModuleName", symbols: []))
            
            TextFile(name: "SomeArticle.md", utf8Content: """
            # Some Article
            
            Some additional documentation for this class.
            \(availabilitySource == .directiveInExtensionFile ? availableDirective : "")
            """)
            
            if availabilitySource == .infoPlist {
                InfoPlist(defaultAvailability: ["ModuleName": [
                    .init(platformName: .macOS, platformVersion: "10.14")
                ]])
            }
        }
        
        var configuration = DocumentationContext.Configuration()
        configuration.externalMetadata.currentPlatforms = [
            "macOS": .init(.init(10, 14, 0), beta: true),
        ]
        let context = try await load(catalog: catalog, configuration: configuration)
        #expect(context.problems.isEmpty, "Unexpected problems: \(context.problems.map(\.diagnostic.summary))")
        let reference = try #require(context.knownPages.first(where: { $0.lastPathComponent == "SomeArticle" }))
        let node = try #require(context.documentationCache[reference])
        let converter = DocumentationContextConverter(context: context, renderContext: .init(documentationContext: context))
        let renderNode = try #require(converter.renderNode(for: node))
        
        withKnownIssue("Articles don't display default availability (rdar://173688303) and don't consider in-beta from any source of availability (rdar://173773442)") {
            let renderPlatforms = try #require(renderNode.metadata.platforms)
            
            #expect(renderPlatforms.compactMap(\.name) == ["macOS"])
            #expect(renderPlatforms.first?.introduced == "10.14")
            #expect(renderPlatforms.first?.isBeta     == true)
            
            #expect(renderNode.metadata.isBeta)
            
            let renderReference = try #require(converter.renderContext.store.content(for: node.reference)?.renderReference as? TopicRenderReference)
            #expect(renderReference.isBeta)
        }
    }
    
    @Test(arguments: AvailabilitySource.allCases)
    func symbolIsNotConsideredInBetaWhenIntroducedBeforeCurrentVersion(_ availabilitySource: AvailabilitySource) async throws {
        let availableDirective = """
        @Metadata {
          @Available(macOS, introduced: "10.14")
        }
        """
        
        let catalog = Folder(name: "unit-test.docc") {
            JSONFile(symbolGraph: makeSymbolGraph(moduleName: "ModuleName", symbols: [
                makeSymbol(
                    id: "some-symbol-id", kind: .class, pathComponents: ["SomeClass"],
                    docComment: """
                    Some in-source documentation for this class.
                    
                    \(availabilitySource == .directiveInDocComment ? availableDirective : "")
                    """,
                    availability: availabilitySource == .inSourceAttribute ? [
                        .init(domainName: "macOS", introduced: .init(major: 10, minor: 14, patch: 0), deprecated: nil)
                    ] : [])
            ]))
            
            TextFile(name: "SomeClass.md", utf8Content: """
            # ``SomeClass``
            
            Some additional documentation for this class.
            \(availabilitySource == .directiveInExtensionFile ? availableDirective : "")
            """)
            
            if availabilitySource == .infoPlist {
                InfoPlist(defaultAvailability: ["ModuleName": [
                    .init(platformName: .macOS, platformVersion: "10.14")
                ]])
            }
        }
        
        var configuration = DocumentationContext.Configuration()
        configuration.externalMetadata.currentPlatforms = [
            "macOS": .init(.init(11, 2, 0), beta: true),
        ]
        let context = try await load(catalog: catalog, configuration: configuration)
        #expect(context.problems.isEmpty, "Unexpected problems: \(context.problems.map(\.diagnostic.summary))")
        let node = try #require(context.documentationCache["some-symbol-id"])
        let converter = DocumentationContextConverter(context: context, renderContext: .init(documentationContext: context))
        let renderNode = try #require(converter.renderNode(for: node))

        let renderPlatforms = try #require(renderNode.metadata.platforms)
        
        #expect(renderPlatforms.compactMap(\.name) == ["macOS"])
        #expect(renderPlatforms.first?.introduced == "10.14")
        #expect(renderPlatforms.first?.isBeta     == false)
        
        #expect(renderNode.metadata.isBeta == false)
        
        let renderReference = try #require(converter.renderContext.store.content(for: node.reference)?.renderReference as? TopicRenderReference)
        #expect(renderReference.isBeta == false)
    }
    
    // FIXME: Articles don't display default availability (rdar://173688303)
    @Test(.bug("rdar://173688303"), arguments: [AvailabilitySource.infoPlist, .directiveInExtensionFile])
    func articleIsConsideredInBetaWhenIntroducedBeforeCurrentVersion(_ availabilitySource: AvailabilitySource) async throws {
        let availableDirective = """
        @Metadata {
          @Available(macOS, introduced: "10.14")
        }
        """
        
        let catalog = Folder(name: "unit-test.docc") {
            JSONFile(symbolGraph: makeSymbolGraph(moduleName: "ModuleName", symbols: []))
            
            TextFile(name: "SomeArticle.md", utf8Content: """
            # Some Article
            
            Some additional documentation for this class.
            \(availabilitySource == .directiveInExtensionFile ? availableDirective : "")
            """)
            
            if availabilitySource == .infoPlist {
                InfoPlist(defaultAvailability: ["ModuleName": [
                    .init(platformName: .macOS, platformVersion: "10.14")
                ]])
            }
        }
        
        var configuration = DocumentationContext.Configuration()
        configuration.externalMetadata.currentPlatforms = [
            "macOS": .init(.init(11, 2, 0), beta: true),
        ]
        let context = try await load(catalog: catalog, configuration: configuration)
        #expect(context.problems.isEmpty, "Unexpected problems: \(context.problems.map(\.diagnostic.summary))")
        let reference = try #require(context.knownPages.first(where: { $0.lastPathComponent == "SomeArticle" }))
        let node = try #require(context.documentationCache[reference])
        let converter = DocumentationContextConverter(context: context, renderContext: .init(documentationContext: context))
        let renderNode = try #require(converter.renderNode(for: node))
        
        try withKnownIssue("Articles don't display default availability (rdar://173688303)", {
            let renderPlatforms = try #require(renderNode.metadata.platforms)
            
            #expect(renderPlatforms.compactMap(\.name) == ["macOS"])
            #expect(renderPlatforms.first?.introduced == "10.14")
            #expect(renderPlatforms.first?.isBeta     == false)
            
            #expect(renderNode.metadata.isBeta == false)
            
            let renderReference = try #require(converter.renderContext.store.content(for: node.reference)?.renderReference as? TopicRenderReference)
            #expect(renderReference.isBeta == false)
        }, when: { availabilitySource == .infoPlist })
    }
    
    @Test(arguments: AvailabilitySource.allCases)
    func symbolIsNotConsideredInBetaWhenOnlySomePlatformsAreCurrentlyInBeta(_ availabilitySource: AvailabilitySource) async throws {
        let availableDirective = """
        @Metadata {
          @Available(macOS, introduced: "10.14")
          @Available(iOS,   introduced: "9.2")
        }
        """
        
        let catalog = Folder(name: "unit-test.docc") {
            JSONFile(symbolGraph: makeSymbolGraph(moduleName: "ModuleName", symbols: [
                makeSymbol(
                    id: "some-symbol-id", kind: .class, pathComponents: ["SomeClass"],
                    docComment: """
                    Some in-source documentation for this class.
                    
                    \(availabilitySource == .directiveInDocComment ? availableDirective : "")
                    """,
                    availability: availabilitySource == .inSourceAttribute ? [
                        .init(domainName: "macOS", introduced: .init(major: 10, minor: 14, patch: 0), deprecated: nil),
                        .init(domainName: "iOS",   introduced: .init(major:  9, minor:  2, patch: 0), deprecated: nil),
                    ] : [])
            ]))
            
            TextFile(name: "SomeClass.md", utf8Content: """
            # ``SomeClass``
            
            Some additional documentation for this class.
            \(availabilitySource == .directiveInExtensionFile ? availableDirective : "")
            """)
            
            if availabilitySource == .infoPlist {
                InfoPlist(defaultAvailability: ["ModuleName": [
                    .init(platformName: .macOS, platformVersion: "10.14"),
                    .init(platformName: .iOS,   platformVersion:  "9.2"),
                ]])
            }
        }
        
        var configuration = DocumentationContext.Configuration()
        configuration.externalMetadata.currentPlatforms = [
            "macOS": .init(.init(10, 14, 0), beta: true),
        ]
        let context = try await load(catalog: catalog, configuration: configuration)
        #expect(context.problems.isEmpty, "Unexpected problems: \(context.problems.map(\.diagnostic.summary))")
        let node = try #require(context.documentationCache["some-symbol-id"])
        let converter = DocumentationContextConverter(context: context, renderContext: .init(documentationContext: context))
        let renderNode = try #require(converter.renderNode(for: node))

        let renderPlatforms = try #require(renderNode.metadata.platforms)
        
        #expect(renderPlatforms.compactMap(\.name) == ["iOS", "iPadOS", "Mac Catalyst", "macOS"])
        #expect(renderPlatforms.first(where: { $0.name == "iOS"          })?.introduced == "9.2")
        #expect(renderPlatforms.first(where: { $0.name == "iPadOS"       })?.introduced == "9.2")
        #expect(renderPlatforms.first(where: { $0.name == "Mac Catalyst" })?.introduced == "9.2")
        #expect(renderPlatforms.first(where: { $0.name == "iOS"          })?.isBeta     == false)
        #expect(renderPlatforms.first(where: { $0.name == "iPadOS"       })?.isBeta     == false)
        #expect(renderPlatforms.first(where: { $0.name == "Mac Catalyst" })?.isBeta     == false)
        
        #expect(renderPlatforms.first(where: { $0.name == "macOS"        })?.introduced == "10.14")
        #expect(renderPlatforms.first(where: { $0.name == "macOS"        })?.isBeta     == true)
        
        #expect(renderNode.metadata.isBeta == false)
        
        let renderReference = try #require(converter.renderContext.store.content(for: node.reference)?.renderReference as? TopicRenderReference)
        #expect(renderReference.isBeta == false)
    }
    
    // MARK: Custom platforms
    
    @Test(arguments: [true, false])
    func symbolDisplaysCustomDefaultPlatformAfterKnownPlatforms(customPlatformIsBeta: Bool) async throws {
        let catalog = Folder(name: "unit-test.docc") {
            JSONFile(symbolGraph: makeSymbolGraph(moduleName: "ModuleName", symbols: [
                makeSymbol(id: "some-symbol-id", kind: .class, pathComponents: ["SomeClass"], docComment: """
                    Some in-source documentation for this class.
                    
                    """, availability: [
                        .init(domainName: "iOS", introduced: .init(major: 9, minor: 2, patch: 0), deprecated: nil)
                    ])
            ]))
            
            InfoPlist(defaultAvailability: ["ModuleName": [
                .init(platformName: .init(rawValue: "Something"), platformVersion: "1.2.3"),
                .init(platformName: .iOS, platformVersion: "9.2"),
            ]])
        }
        
        var configuration = DocumentationContext.Configuration()
        configuration.externalMetadata.currentPlatforms = [
            "Something": .init(.init(1, 2, 3), beta: customPlatformIsBeta),
        ]
        let context = try await load(catalog: catalog, configuration: configuration)
        #expect(context.problems.isEmpty, "Unexpected problems: \(context.problems.map(\.diagnostic.summary))")
        let node = try #require(context.documentationCache["some-symbol-id"])
        let converter = DocumentationContextConverter(context: context, renderContext: .init(documentationContext: context))
        let renderNode = try #require(converter.renderNode(for: node))
        let renderPlatforms = try #require(renderNode.metadata.platforms)
        
        #expect(renderPlatforms.compactMap(\.name) == ["iOS", "iPadOS", "Mac Catalyst", "Something"])
        #expect(renderPlatforms.first(where: { $0.name == "iOS"          })?.introduced == "9.2")
        #expect(renderPlatforms.first(where: { $0.name == "iPadOS"       })?.introduced == "9.2")
        #expect(renderPlatforms.first(where: { $0.name == "Mac Catalyst" })?.introduced == "9.2")
        #expect(renderPlatforms.first(where: { $0.name == "Something"    })?.introduced == "1.2.3")
        
        #expect(renderPlatforms.first(where: { $0.name == "Something"    })?.isBeta == customPlatformIsBeta)
        
        #expect(renderNode.metadata.isBeta == false)
    }
    
    @Test(arguments: DirectiveLocation.allCases, [true, false])
    func symbolDisplaysCustomDirectivePlatformAfterKnownPlatforms(_ directiveLocation: DirectiveLocation, customPlatformIsBeta: Bool) async throws {
        let availableDirective = """
        @Metadata {
          @Available("Something", introduced: "1.2.3")
          @Available(iOS, introduced: "9.2")
        }
        """
        
        let catalog = Folder(name: "unit-test.docc") {
            JSONFile(symbolGraph: makeSymbolGraph(moduleName: "ModuleName", symbols: [
                makeSymbol(id: "some-symbol-id", kind: .class, pathComponents: ["SomeClass"], docComment: """
                    Some in-source documentation for this class.
                    
                    \(directiveLocation == .inSourceComment ? availableDirective : "")
                    """, availability: [
                        .init(domainName: "iOS", introduced: .init(major: 9, minor: 2, patch: 0), deprecated: nil)
                    ])
            ]))
            
            TextFile(name: "SomeClass.md", utf8Content: """
            # ``SomeClass``
            
            Some additional documentation for this class.
            \(directiveLocation == .extensionFile ? availableDirective : "")
            """)
        }
        
        var configuration = DocumentationContext.Configuration()
        configuration.externalMetadata.currentPlatforms = [
            "Something": .init(.init(1, 2, 3), beta: customPlatformIsBeta),
        ]
        let context = try await load(catalog: catalog, configuration: configuration)
        #expect(context.problems.isEmpty, "Unexpected problems: \(context.problems.map(\.diagnostic.summary))")
        let node = try #require(context.documentationCache["some-symbol-id"])
        #expect(node.metadata?.availability.count == 2)
        do {
            let directiveAvailability = node.metadata?.availability.first
            #expect(directiveAvailability?.platform.rawValue      == "Something")
            #expect(directiveAvailability?.introduced.description ==  "1.2.3")
        }
        do {
            let directiveAvailability = node.metadata?.availability.last
            #expect(directiveAvailability?.platform.rawValue       == "iOS")
            #expect(directiveAvailability?.introduced.description  == "9.2.0")
        }
        
        let converter = DocumentationContextConverter(context: context, renderContext: .init(documentationContext: context))
        let renderNode = try #require(converter.renderNode(for: node))
        let renderPlatforms = try #require(renderNode.metadata.platforms)
        
        #expect(renderPlatforms.compactMap(\.name) == ["iOS", "iPadOS", "Mac Catalyst", "Something"])
        #expect(renderPlatforms.first(where: { $0.name == "iOS"          })?.introduced == "9.2")
        #expect(renderPlatforms.first(where: { $0.name == "iPadOS"       })?.introduced == "9.2")
        #expect(renderPlatforms.first(where: { $0.name == "Mac Catalyst" })?.introduced == "9.2")
        #expect(renderPlatforms.first(where: { $0.name == "Something"    })?.introduced == "1.2.3")
        
        #expect(renderPlatforms.first(where: { $0.name == "Something"    })?.isBeta == customPlatformIsBeta)
        
        #expect(renderNode.metadata.isBeta == false)
    }
    
    // FIXME: Articles don't display default availability (rdar://173688303)
    @Test(.bug("rdar://173688303"), arguments: [true, false])
    func articleDisplaysCustomDefaultPlatformAfterKnownPlatforms(customPlatformIsBeta: Bool) async throws {
        let catalog = Folder(name: "unit-test.docc") {
            JSONFile(symbolGraph: makeSymbolGraph(moduleName: "ModuleName", symbols: []))
            
            TextFile(name: "SomeArticle.md", utf8Content: """
            # Some article    
            """)
            
            InfoPlist(defaultAvailability: ["ModuleName": [
                .init(platformName: .init(rawValue: "Something"), platformVersion: "1.2.3"),
                .init(platformName: .iOS, platformVersion: "9.2"),
            ]])
        }
        
        var configuration = DocumentationContext.Configuration()
        configuration.externalMetadata.currentPlatforms = [
            "Something": .init(.init(1, 2, 3), beta: customPlatformIsBeta),
        ]
        let context = try await load(catalog: catalog, configuration: configuration)
        #expect(context.problems.isEmpty, "Unexpected problems: \(context.problems.map(\.diagnostic.summary))")
        let reference = try #require(context.knownPages.first(where: { $0.lastPathComponent == "SomeArticle" }))
        let node = try #require(context.documentationCache[reference])
        let converter = DocumentationContextConverter(context: context, renderContext: .init(documentationContext: context))
        let renderNode = try #require(converter.renderNode(for: node))
        
        withKnownIssue("Articles don't display default availability (rdar://173688303)") {
            let renderPlatforms = try #require(renderNode.metadata.platforms)
            
            #expect(renderPlatforms.compactMap(\.name) == ["iOS", "iPadOS", "Mac Catalyst", "Something"])
            #expect(renderPlatforms.first(where: { $0.name == "iOS"          })?.introduced == "9.2")
            #expect(renderPlatforms.first(where: { $0.name == "iPadOS"       })?.introduced == "9.2")
            #expect(renderPlatforms.first(where: { $0.name == "Mac Catalyst" })?.introduced == "9.2")
            #expect(renderPlatforms.first(where: { $0.name == "Something"    })?.introduced == "1.2.3")
            
            #expect(renderPlatforms.first(where: { $0.name == "Something"    })?.isBeta == customPlatformIsBeta)
            
            #expect(renderNode.metadata.isBeta == false)
        }
    }
    
    @Test(arguments: [true, false])
    func articleDisplaysCustomDirectivePlatformAfterKnownPlatforms(customPlatformIsBeta: Bool) async throws {
        let catalog = Folder(name: "unit-test.docc") {
            JSONFile(symbolGraph: makeSymbolGraph(moduleName: "ModuleName", symbols: []))
            
            TextFile(name: "SomeArticle.md", utf8Content: """
            # Some article   
            
            @Metadata {
              @Available("Something", introduced: "1.2.3")
              @Available(iOS, introduced: "9.2")
            }
            """)
            
            InfoPlist(defaultAvailability: ["ModuleName": [
                .init(platformName: .init(rawValue: "Something"), platformVersion: "1.2.3"),
                .init(platformName: .iOS, platformVersion: "9.2"),
            ]])
        }
        
        var configuration = DocumentationContext.Configuration()
        configuration.externalMetadata.currentPlatforms = [
            "Something": .init(.init(1, 2, 3), beta: customPlatformIsBeta),
        ]
        let context = try await load(catalog: catalog, configuration: configuration)
        #expect(context.problems.isEmpty, "Unexpected problems: \(context.problems.map(\.diagnostic.summary))")
        let reference = try #require(context.knownPages.first(where: { $0.lastPathComponent == "SomeArticle" }))
        let node = try #require(context.documentationCache[reference])
        let converter = DocumentationContextConverter(context: context, renderContext: .init(documentationContext: context))
        let renderNode = try #require(converter.renderNode(for: node))
        let renderPlatforms = try #require(renderNode.metadata.platforms)
        
        #expect(renderPlatforms.compactMap(\.name) == ["iOS", "iPadOS", "Mac Catalyst", "Something"])
        #expect(renderPlatforms.first(where: { $0.name == "iOS"          })?.introduced == "9.2")
        #expect(renderPlatforms.first(where: { $0.name == "iPadOS"       })?.introduced == "9.2")
        #expect(renderPlatforms.first(where: { $0.name == "Mac Catalyst" })?.introduced == "9.2")
        #expect(renderPlatforms.first(where: { $0.name == "Something"    })?.introduced == "1.2.3")
        
        #expect(renderPlatforms.first(where: { $0.name == "Something"    })?.isBeta == customPlatformIsBeta)
        
        #expect(renderNode.metadata.isBeta == false)
    }
    
    // MARK: Multiple language representations
    
    @Test(arguments: ["7.3", nil])
    func symbolVariantDisplaysTheirOwnInSourceAvailability(defaultIntroducedVersion: String?) async throws {
        let catalog = Folder(name: "unit-test.docc") {
            Folder(name: "swift") {
                JSONFile(symbolGraph: makeSymbolGraph(moduleName: "ModuleName", platform: .init(operatingSystem: .init(name: "ios")), symbols: [
                    makeSymbol(id: "some-symbol-id", language: .swift, kind: .class, pathComponents: ["SomeClass"], availability: [
                        .init(domainName: "iOS",   introduced: .init(major:  9, minor: 2, patch: 0), deprecated: nil),
                        .init(domainName: "macOS", introduced: .init(major: 10, minor: 7, patch: 0), deprecated: nil),
                    ])
                ]))
            }
            Folder(name: "clang") {
                JSONFile(symbolGraph: makeSymbolGraph(moduleName: "ModuleName", platform: .init(operatingSystem: .init(name: "macosx")), symbols: [
                    makeSymbol(id: "some-symbol-id", language: .objectiveC, kind: .class, pathComponents: ["SomeClass"], availability: [
                        .init(domainName: "macOS", introduced: .init(major: 12, minor: 1, patch: 0), deprecated: nil)
                    ])
                ]))
            }
            
            InfoPlist(defaultAvailability: ["ModuleName": [
                .init(platformName: .iOS, platformVersion: defaultIntroducedVersion),
            ]])
        }
        
        let context = try await load(catalog: catalog)
        #expect(context.problems.isEmpty, "Unexpected problems: \(context.problems.map(\.diagnostic.summary))")
        let node = try #require(context.documentationCache["some-symbol-id"])
        let converter = DocumentationContextConverter(context: context, renderContext: .init(documentationContext: context))
        let renderNode = try #require(converter.renderNode(for: node))
        let swiftRenderPlatforms = try #require(renderNode.metadata.platformsVariants.value(for: .swift))
        
        #expect(swiftRenderPlatforms.compactMap(\.name) == ["iOS", "iPadOS", "Mac Catalyst", "macOS"])
        #expect(swiftRenderPlatforms.first(where: { $0.name == "iOS"          })?.introduced ==  "9.2")
        #expect(swiftRenderPlatforms.first(where: { $0.name == "iPadOS"       })?.introduced ==  "9.2")
        #expect(swiftRenderPlatforms.first(where: { $0.name == "Mac Catalyst" })?.introduced ==  "9.2")
        #expect(swiftRenderPlatforms.first(where: { $0.name == "macOS"        })?.introduced == "10.7")
        
        withKnownIssue("Language specific availability isn't reflected on the rendered page (rdar://174818876)") {
            #expect(!renderNode.metadata.platformsVariants.variants.isEmpty)
            let objcRenderPlatforms = try #require(renderNode.metadata.platformsVariants.value(for: .objectiveC))
            
            if defaultIntroducedVersion != nil {
                #expect(objcRenderPlatforms.compactMap(\.name) == ["iOS", "iPadOS", "Mac Catalyst", "macOS"])
            } else {
                // ???: Why do we not want fallback platforms in when there's no introduced version? (rdar://171807245)
                #expect(objcRenderPlatforms.compactMap(\.name) == ["iOS", "macOS"])
            }
            #expect(objcRenderPlatforms.first(where: { $0.name == "iOS"          })?.introduced == defaultIntroducedVersion)
            #expect(objcRenderPlatforms.first(where: { $0.name == "iPadOS"       })?.introduced == defaultIntroducedVersion)
            #expect(objcRenderPlatforms.first(where: { $0.name == "Mac Catalyst" })?.introduced == defaultIntroducedVersion)
            #expect(objcRenderPlatforms.first(where: { $0.name == "macOS"        })?.introduced == "12.1")
        }
    }
    
    // MARK: Mixed sources
    
    @Test(arguments: DirectiveLocation.allCases)
    func combinesAvailabilityFromMultipleSources(_ directiveLocation: DirectiveLocation) async throws {
        // This symbol has macOS availability for different platforms from all 3 sources; Info.plist, in-source attributes, @Available directives.
        let availableDirective = """
        @Metadata {
          @Available(tvOS, introduced: "7.1")
        }
        """
        
        let catalog = Folder(name: "unit-test.docc") {
            JSONFile(symbolGraph: makeSymbolGraph(moduleName: "ModuleName", symbols: [
                makeSymbol(
                    id: "some-symbol-id", kind: .class, pathComponents: ["SomeClass"],
                    docComment: """
                    Some in-source documentation for this class.
                    
                    \(directiveLocation == .inSourceComment ? availableDirective : "")
                    """,
                    availability: [
                        .init(domainName: "macOS", introduced: .init(major: 10, minor: 14, patch: 0), deprecated: nil),
                    ]
                )
            ]))
            
            TextFile(name: "SomeClass.md", utf8Content: """
            # ``SomeClass``
            
            Some additional documentation for this class.
            \(directiveLocation == .extensionFile ? availableDirective : "")
            """)
            
            InfoPlist(defaultAvailability: ["ModuleName": [
                .init(platformName: .iOS, platformVersion:  "9.2"),
            ]])
        }
        let context = try await load(catalog: catalog)
        #expect(context.problems.isEmpty, "Unexpected problems: \(context.problems.map(\.diagnostic.summary))")
        let node = try #require(context.documentationCache["some-symbol-id"])
        let converter = DocumentationContextConverter(context: context, renderContext: .init(documentationContext: context))
        let renderNode = try #require(converter.renderNode(for: node))

        let renderPlatforms = try #require(renderNode.metadata.platforms)
        
        withKnownIssue("Available directives remove all in-source availability information (rdar://171807245)") {
            #expect(renderPlatforms.compactMap(\.name) == ["iOS", "iPadOS", "Mac Catalyst", "macOS", "tvOS"])
            #expect(renderPlatforms.first(where: { $0.name == "macOS"        })?.introduced == "10.14")
        }
        #expect(renderPlatforms.compactMap(\.name) == ["iOS", "iPadOS", "Mac Catalyst", "tvOS"])
        #expect(renderPlatforms.first(where: { $0.name == "iOS"          })?.introduced ==  "9.2")
        #expect(renderPlatforms.first(where: { $0.name == "iPadOS"       })?.introduced ==  "9.2")
        #expect(renderPlatforms.first(where: { $0.name == "Mac Catalyst" })?.introduced ==  "9.2")
        #expect(renderPlatforms.first(where: { $0.name == "tvOS"         })?.introduced ==  "7.1")
    }
    
    private static let allMainPlatforms: [SymbolGraph.Platform] = [
        .init(operatingSystem: .init(name: "ios")),
        .init(operatingSystem: .init(name: "ios"), environment: "macabi"), // Mac Catalyst
        .init(operatingSystem: .init(name: "macosx")),
        .init(operatingSystem: .init(name: "macos")),
        .init(operatingSystem: .init(name: "watchos")),
        .init(operatingSystem: .init(name: "tvos")),
        .init(operatingSystem: .init(name: "visionos")),
    ]
}
