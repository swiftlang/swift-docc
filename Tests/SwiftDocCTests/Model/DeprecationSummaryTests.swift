/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Testing
@testable import SwiftDocC
import DocCTestUtilities
import SymbolKit

struct DeprecationSummaryTests {
    @Test(arguments: [
        makeInSourceAvailabilityInfo(domain: "FirstPlatform", deprecated: .init(major: 4, minor: 5, patch: 6)),
        makeInSourceAvailabilityInfo(domain: "FirstPlatform", deprecated: nil,                                isUnconditionallyDeprecated: true),
        makeInSourceAvailabilityInfo(domain: nil,     deprecated: .init(major: 4, minor: 5, patch: 6)),
        makeInSourceAvailabilityInfo(domain: nil,     deprecated: nil,                                isUnconditionallyDeprecated: true),
    ])
    func displaysDeprecationMessageFromInSourceAttribute(_ availabilityItem: SymbolGraph.Symbol.Availability.AvailabilityItem) async throws {
        let catalog = Folder(name: "unit-test.docc", content: [
            JSONFile(name: "SomeModule.symbols.json", content: makeSymbolGraph(moduleName: "SomeModule", symbols: [
                makeSymbol(id: "some-symbol-id", kind: .typealias, pathComponents: ["SomeTypeAlias"], docComment: """
                    Some in-source documentation with a deprecation summary for this type alias
                    """, availability: [availabilityItem])
            ]))
        ])
        
        let context = try await load(catalog: catalog)
        #expect(context.diagnostics.isEmpty, "Unexpected problems: \(context.diagnostics.map(\.summary))")
        let node = try #require(context.documentationCache["some-symbol-id"])
        
        let converter = DocumentationNodeConverter(context: context)
        let renderNode = converter.convert(node)
        
        #expect(renderNode.deprecationSummary?.firstParagraph == [.text("Some description, from the availability information, of why this protocol is deprecated")])
    }
    
    private static let deprecationSummaryDirective = """
    @DeprecationSummary {
      Some description, from the directive, of why this protocol is deprecated.
    }
    """
    
    @Test(arguments: [
        "", // No markup before
        "Only an abstract before the directive",
        """
        An abstract and another section before the directive 
        
        ## Overview
        """,
    ])
    func displaysDeprecationSummaryFromExtensionFile(markupBeforeDirective: String) async throws {
        let catalog = Folder(name: "unit-test.docc", content: [
            JSONFile(name: "SomeModule.symbols.json", content: makeSymbolGraph(moduleName: "SomeModule", symbols: [
                makeSymbol(id: "some-symbol-id", kind: .typealias, pathComponents: ["SomeTypeAlias"], docComment: """
                    Some in-source documentation with a deprecation summary for this type alias
                    """, availability: [
                        Self.makeInSourceAvailabilityInfo(domain: "FirstPlatform", deprecated: .init(major: 4, minor: 5, patch: 6)),
                    ])
            ])),
            
            TextFile(name: "SomeTypeAlias.md", utf8Content: """
            # ``SomeTypeAlias``
            \(markupBeforeDirective)
            \(Self.deprecationSummaryDirective)
            """)
        ])
        
        let context = try await load(catalog: catalog)
        #expect(context.diagnostics.isEmpty, "Unexpected problems: \(context.diagnostics.map(\.summary))")
        
        // Verify that DocC displays the deprecation text.
        let node = try #require(context.documentationCache["some-symbol-id"])
        let converter = DocumentationNodeConverter(context: context)
        let renderNode = converter.convert(node)
        
        #expect(renderNode.deprecationSummary?.firstParagraph == [.text("Some description, from the directive, of why this protocol is deprecated.")])
    }
    
    enum DirectiveLocation: CaseIterable {
        case extensionFile
        case inSourceComment
    }
    
    @Test(arguments: DirectiveLocation.allCases)
    func prefersDeprecationSummaryTextOverAvailabilityMessage(_ directiveLocation: DirectiveLocation) async throws {
        let catalog = Folder(name: "unit-test.docc", content: [
            JSONFile(name: "SomeModule.symbols.json", content: makeSymbolGraph(moduleName: "SomeModule", symbols: [
                makeSymbol(id: "some-symbol-id", kind: .typealias, pathComponents: ["SomeTypeAlias"], docComment: """
                    Some in-source documentation with a deprecation summary for this type alias
                    
                    \(directiveLocation == .inSourceComment ? Self.deprecationSummaryDirective : "")
                    """, availability: [
                        Self.makeInSourceAvailabilityInfo(domain: "FirstPlatform", deprecated: .init(major: 4, minor: 5, patch: 6))
                    ])
            ])),
            
            TextFile(name: "SomeTypeAlias.md", utf8Content: """
            # ``SomeTypeAlias``
            
            Some additional documentation for this type alias.
               
            \(directiveLocation == .extensionFile ? Self.deprecationSummaryDirective : "")
            """)
        ])
        
        let context = try await load(catalog: catalog)
        #expect(context.diagnostics.isEmpty, "Unexpected problems: \(context.diagnostics.map(\.summary))")
        let node = try #require(context.documentationCache["some-symbol-id"])
        
        let converter = DocumentationNodeConverter(context: context)
        let renderNode = converter.convert(node)
        
        #expect(renderNode.deprecationSummary?.firstParagraph == [.text("Some description, from the directive, of why this protocol is deprecated.")])
    }
    
    @Test(arguments: DirectiveLocation.allCases)
    func warnsAboutDeprecationSummaryIfSymbolIsNotDeprecated(_ directiveLocation: DirectiveLocation) async throws {
        let catalog = Folder(name: "unit-test.docc", content: [
            JSONFile(name: "SomeModule.symbols.json", content: makeSymbolGraph(moduleName: "SomeModule", symbols: [
                makeSymbol(id: "some-symbol-id", kind: .typealias, pathComponents: ["SomeTypeAlias"], docComment: """
                    Some in-source documentation with a deprecation summary for this type alias
                    
                    \(directiveLocation == .inSourceComment ? Self.deprecationSummaryDirective : "")
                    """, availability: []) // No availability attributes for this symbol
            ])),
            
            TextFile(name: "SomeTypeAlias.md", utf8Content: """
            # ``SomeTypeAlias``
            
            Some additional documentation for this type alias.
               
            \(directiveLocation == .extensionFile ? Self.deprecationSummaryDirective : "")
            """)
        ])
        
        let context = try await load(catalog: catalog)
        // Verify the warning
        #expect(context.diagnostics.map(\.identifier) == ["DeprecationSummaryForAvailableSymbol"],
                "Unexpected problems: \(context.diagnostics.map(\.summary))")
        
        let diagnostic = try #require(context.diagnostics.first)
        #expect(diagnostic.summary == "Type alias 'SomeTypeAlias' is unconditionally available")
        #expect(diagnostic.explanation == "A symbol without any availability annotations is considered available for all versions of the module (SomeModule) for all platforms.")
        
        // Verify that DocC still displays the deprecation text, despite the symbol being available.
        let node = try #require(context.documentationCache["some-symbol-id"])
        let converter = DocumentationNodeConverter(context: context)
        let renderNode = converter.convert(node)
        
        #expect(renderNode.deprecationSummary?.firstParagraph == [.text("Some description, from the directive, of why this protocol is deprecated.")])
    }
    
    @Test(arguments: DirectiveLocation.allCases)
    func warnsAboutDeprecationSummaryIfSymbolIsOnlyPartiallyDeprecated(_ directiveLocation: DirectiveLocation) async throws {
        let catalog = Folder(name: "unit-test.docc", content: [
            JSONFile(name: "SomeModule.symbols.json", content: makeSymbolGraph(moduleName: "SomeModule", symbols: [
                makeSymbol(id: "some-symbol-id", kind: .typealias, pathComponents: ["SomeTypeAlias"], docComment: """
                    Some in-source documentation with a deprecation summary for this type alias
                    
                    \(directiveLocation == .inSourceComment ? Self.deprecationSummaryDirective : "")
                    """, availability: [
                        Self.makeInSourceAvailabilityInfo(domain: "FirstPlatform",                                                   deprecated: .init(major: 4, minor: 5, patch: 6)),
                        Self.makeInSourceAvailabilityInfo(domain: "SecondPlatform", introduced: .init(major: 1, minor: 2, patch: 3), deprecated: nil),
                        Self.makeInSourceAvailabilityInfo(domain: "ThirdPlatform",  introduced: nil,                                 deprecated: nil),
                    ])
            ])),
            
            TextFile(name: "SomeTypeAlias.md", utf8Content: """
            # ``SomeTypeAlias``
            
            Some additional documentation for this type alias.
            
            \(directiveLocation == .extensionFile ? Self.deprecationSummaryDirective : "")
            """)
        ])
        
        let context = try await load(catalog: catalog)
        // Verify the warning
        #expect(context.diagnostics.map(\.identifier) == ["DeprecationSummaryForAvailableSymbol"],
                "Unexpected problems: \(context.diagnostics.map(\.summary))")
        
        let diagnostic = try #require(context.diagnostics.first)
        #expect(diagnostic.summary == "Type alias 'SomeTypeAlias' is available for SecondPlatform and ThirdPlatform")
        #expect(diagnostic.explanation == "This type alias has attributes that mark it as available for 'SecondPlatform' 1.2.3 onwards and all versions of 'ThirdPlatform'.")
        
        // Verify that DocC still displays the deprecation text, despite the symbol being available.
        let node = try #require(context.documentationCache["some-symbol-id"])
        let converter = DocumentationNodeConverter(context: context)
        let renderNode = converter.convert(node)
        
        #expect(renderNode.deprecationSummary?.firstParagraph == [.text("Some description, from the directive, of why this protocol is deprecated.")])
    }
    
    @Test(arguments: DirectiveLocation.allCases, [
        [], // No in-source availability attributes
        [Self.makeInSourceAvailabilityInfo(domain: "SecondPlatform", deprecated: nil)]
    ])
    func doesNotWarnAboutDeprecationSummaryIfVersionInfoIsProvidedInAvailabilityDirective(
        _ directiveLocation: DirectiveLocation,
        availability: [SymbolGraph.Symbol.Availability.AvailabilityItem]
    ) async throws {
        let directives = """
        \(Self.deprecationSummaryDirective)
        @Metadata {
          @Available(SecondPlatform, introduced: "2.3.4", deprecated: "5.6.7")
        }
        """
        
        let catalog = Folder(name: "unit-test.docc", content: [
            JSONFile(name: "SomeModule.symbols.json", content: makeSymbolGraph(moduleName: "SomeModule", symbols: [
                makeSymbol(id: "some-symbol-id", kind: .typealias, pathComponents: ["SomeTypeAlias"], docComment: """
                    Some in-source documentation with a deprecation summary for this type alias
                    
                    \(directiveLocation == .inSourceComment ? directives : "")
                    """, availability: availability)
            ])),
            
            TextFile(name: "SomeTypeAlias.md", utf8Content: """
            # ``SomeTypeAlias``
            
            Some additional documentation for this type alias.
               
            \(directiveLocation == .extensionFile ? directives : "")
            """)
        ])
        
        let context = try await load(catalog: catalog)
        #expect(context.diagnostics.map(\.identifier) == [],
                "Unexpected problems: \(context.diagnostics.map(\.summary))")
        
        // Verify that DocC displays the deprecation text.
        let node = try #require(context.documentationCache["some-symbol-id"])
        let converter = DocumentationNodeConverter(context: context)
        let renderNode = converter.convert(node)
        
        #expect(renderNode.deprecationSummary?.firstParagraph == [.text("Some description, from the directive, of why this protocol is deprecated.")])
    }
    
    @Test(arguments: DirectiveLocation.allCases, [SourceLanguage.swift, .objectiveC, .javaScript])
    func warningIncludesInformationFromBothAvailableDirectiveAndSourceAttributes(_ directiveLocation: DirectiveLocation, _ sourceLanguage: SourceLanguage) async throws {
        let directives = """
        \(Self.deprecationSummaryDirective)
        @Metadata {
          @Available(PlatformB, introduced: "2.3.4")
          @Available(PlatformD, introduced: "3.4.5")
        }
        """
        
        let catalog = Folder(name: "unit-test.docc", content: [
            JSONFile(name: "SomeModule.symbols.json", content: makeSymbolGraph(moduleName: "SomeModule", symbols: [
                makeSymbol(id: "some-symbol-id", language: sourceLanguage, kind: .typealias,  pathComponents: ["SomeTypeAlias"], docComment: """
                    Some in-source documentation with a deprecation summary for this type alias
                    
                    \(directiveLocation == .inSourceComment ? directives : "")
                    """, availability: [
                        Self.makeInSourceAvailabilityInfo(domain: "PlatformA",                                                  deprecated: .init(major: 4, minor: 5, patch: 6)),
                        Self.makeInSourceAvailabilityInfo(domain: "PlatformB", introduced: .init(major: 1, minor: 2, patch: 3), deprecated: nil),
                        Self.makeInSourceAvailabilityInfo(domain: "PlatformC", introduced: nil,                                 deprecated: nil),
                    ])
            ])),
            
            TextFile(name: "SomeTypeAlias.md", utf8Content: """
            # ``SomeTypeAlias``
            
            Some additional documentation for this type alias.
               
            \(directiveLocation == .extensionFile ? directives : "")
            """)
        ])
        
        let context = try await load(catalog: catalog)
        // Verify the warning
        #expect(context.diagnostics.map(\.identifier) == ["DeprecationSummaryForAvailableSymbol"],
                "Unexpected problems: \(context.diagnostics.map(\.summary))")
        
        let diagnostic = try #require(context.diagnostics.first)
        #expect(diagnostic.summary == "Type alias 'SomeTypeAlias' is available for PlatformB, PlatformC, and PlatformD")
        #expect(diagnostic.explanation == "This type alias has attributes that mark it as available for 'PlatformB' 2.3.4 onwards, all versions of 'PlatformC', and 'PlatformD' 3.4.5 onwards.")
        
        // Verify that the notes refer to the Available directives
        let expectedSource = switch directiveLocation {
            case .extensionFile:   "/unit-test.docc/SomeTypeAlias.md"
            case .inSourceComment: "/Users/username/path/to/SomeFile.swift"
        }
        #expect(diagnostic.notes.map(\.source.path) == [expectedSource, expectedSource])
        #expect(diagnostic.notes.map(\.message) == [
            "Marked available for 'PlatformB' here",
            "Marked available for 'PlatformD' here",
        ])
        
        // Verify that the solutions suggest marking the available platforms as deprecated using both attributes (preferred) and directives
        let expectedSourceAttribute: String? = switch sourceLanguage {
            case .swift:      "'@available()' attributes"
            case .objectiveC: "'API_AVAILABLE\' macros"
            default:          nil
        }
        #expect(diagnostic.solutions.count == (expectedSourceAttribute != nil ? 2 : 1))
        if let expectedSourceAttribute {
            #expect(diagnostic.solutions.first?.summary == "Add \(expectedSourceAttribute) marking 'PlatformB', 'PlatformC', and 'PlatformD' as deprecated API")
        }
        #expect(diagnostic.solutions.last?.summary == "Add Available directives marking 'PlatformB', 'PlatformC', and 'PlatformD' as deprecated only in documentation")
        // Verify that DocC still displays the deprecation text, despite the symbol being available.
        let node = try #require(context.documentationCache["some-symbol-id"])
        let converter = DocumentationNodeConverter(context: context)
        let renderNode = converter.convert(node)
        
        #expect(renderNode.deprecationSummary?.firstParagraph == [.text("Some description, from the directive, of why this protocol is deprecated.")])
    }
    
    @Test(arguments: DirectiveLocation.allCases)
    func warningListsDeprecatedPlatformWhenSymbolHasUnconditionalAvailability(_ directiveLocation: DirectiveLocation) async throws {
        let directives = """
        \(Self.deprecationSummaryDirective)
        @Metadata {
          @Available(PlatformB, introduced: "2.3.4", deprecated: "4.5.6")
        }
        """
        
        let catalog = Folder(name: "unit-test.docc", content: [
            JSONFile(name: "SomeModule.symbols.json", content: makeSymbolGraph(moduleName: "SomeModule", symbols: [
                makeSymbol(id: "some-symbol-id", kind: .typealias,  pathComponents: ["SomeTypeAlias"], docComment: """
                    Some in-source documentation with a deprecation summary for this type alias
                    
                    \(directiveLocation == .inSourceComment ? directives : "")
                    """, availability: [
                        Self.makeInSourceAvailabilityInfo(domain: nil,         introduced: nil, deprecated: nil), // Available on all platforms except where explicitly marked as deprecated
                        Self.makeInSourceAvailabilityInfo(domain: "PlatformA", introduced: nil, deprecated: .init(major: 3, minor: 4, patch: 5)),
                    ])
            ])),
            
            TextFile(name: "SomeTypeAlias.md", utf8Content: """
            # ``SomeTypeAlias``
            
            Some additional documentation for this type alias.
               
            \(directiveLocation == .extensionFile ? directives : "")
            """)
        ])
        
        let context = try await load(catalog: catalog)
        // Verify the warning
        #expect(context.diagnostics.map(\.identifier) == ["DeprecationSummaryForAvailableSymbol"],
                "Unexpected problems: \(context.diagnostics.map(\.summary))")
        
        let diagnostic = try #require(context.diagnostics.first)
        #expect(diagnostic.summary == "Type alias 'SomeTypeAlias' is available for all platforms, except PlatformA and PlatformB")
        #expect(diagnostic.explanation == "This type alias has attributes that mark it as available for all platforms, except PlatformA and PlatformB.")
        
        #expect(diagnostic.notes.map(\.message) == [], "Only deprecated platforms, not available ones, are defined in Available directives")
        
        // Verify that the solutions suggest modifying the wildcard availability attribute
        #expect(diagnostic.solutions.count == 1)
        let solution = try #require(diagnostic.solutions.first)
        #expect(solution.summary == "Update wildcard '@available()' attribute with a deprecated version or unconditional deprecation")
    }
    
    @Test
    func marksSymbolAsDeprecatedWithoutMessage() async throws {
        // Verify that a symbol with a single availability item that is unconditionally deprecated
        // on a custom domain is marked as deprecated in topic render references, even without a message.
        let catalog = Folder(name: "unit-test.docc", content: [
            JSONFile(name: "SomeModule.symbols.json", content: makeSymbolGraph(moduleName: "SomeModule", symbols: [
                makeSymbol(id: "parent-symbol-id", language: SourceLanguage(name: "Data", id: "data"), kind: .class, pathComponents: ["SomeClass"], docComment: "A class."),
                makeSymbol(id: "deprecated-symbol-id", language: SourceLanguage(name: "Data", id: "data"), kind: .typealias, pathComponents: ["SomeClass", "SomeTypeAlias"], docComment: "A deprecated type alias.", availability: [
                    .init(
                        domain: .init(rawValue: "MapKit JS"),
                        introducedVersion: .init(major: 5, minor: 0, patch: 0),
                        deprecatedVersion: .init(major: 5, minor: 9999, patch: 0),
                        obsoletedVersion: .init(major: 5, minor: 9999, patch: 0),
                        message: nil,
                        renamed: nil,
                        isUnconditionallyDeprecated: true,
                        isUnconditionallyUnavailable: false,
                        willEventuallyBeDeprecated: false
                    ),
                ]),
            ], relationships: [
                .init(source: "deprecated-symbol-id", target: "parent-symbol-id", kind: .memberOf, targetFallback: nil),
            ]))
        ])

        let context = try await load(catalog: catalog)

        // Render the parent and check the topic render reference for the deprecated child
        let parentNode = try #require(context.documentationCache["parent-symbol-id"])
        var translator = RenderNodeTranslator(context: context, identifier: parentNode.reference)
        let renderNode = translator.visit(parentNode.semantic) as! RenderNode

        let deprecatedRef = renderNode.references.values.compactMap { $0 as? TopicRenderReference }.first { $0.title == "SomeTypeAlias" }
        let topicRef = try #require(deprecatedRef, "Expected to find a topic render reference for SomeTypeAlias")
        #expect(topicRef.isDeprecated == true, "Symbol should be marked as deprecated even without a message")
    }

    @Test
    func marksSymbolAsDeprecatedWithMessage() async throws {
        // Verify that a symbol with a single availability item that is unconditionally deprecated
        // on a custom domain is marked as deprecated in topic render references when a message is present.
        let catalog = Folder(name: "unit-test.docc", content: [
            JSONFile(name: "SomeModule.symbols.json", content: makeSymbolGraph(moduleName: "SomeModule", symbols: [
                makeSymbol(id: "parent-symbol-id", language: SourceLanguage(name: "Data", id: "data"), kind: .class, pathComponents: ["SomeClass"], docComment: "A class."),
                makeSymbol(id: "deprecated-symbol-id", language: SourceLanguage(name: "Data", id: "data"), kind: .typealias, pathComponents: ["SomeClass", "SomeTypeAlias"], docComment: "A deprecated type alias.", availability: [
                    .init(
                        domain: .init(rawValue: "MapKit JS"),
                        introducedVersion: .init(major: 5, minor: 0, patch: 0),
                        deprecatedVersion: .init(major: 5, minor: 9999, patch: 0),
                        obsoletedVersion: .init(major: 5, minor: 9999, patch: 0),
                        message: "This property has been removed.",
                        renamed: nil,
                        isUnconditionallyDeprecated: true,
                        isUnconditionallyUnavailable: false,
                        willEventuallyBeDeprecated: false
                    ),
                ]),
            ], relationships: [
                .init(source: "deprecated-symbol-id", target: "parent-symbol-id", kind: .memberOf, targetFallback: nil),
            ]))
        ])

        let context = try await load(catalog: catalog)

        // Render the parent and check the topic render reference for the deprecated child
        let parentNode = try #require(context.documentationCache["parent-symbol-id"])
        var translator = RenderNodeTranslator(context: context, identifier: parentNode.reference)
        let renderNode = translator.visit(parentNode.semantic) as! RenderNode

        let deprecatedRef = renderNode.references.values.compactMap { $0 as? TopicRenderReference }.first { $0.title == "SomeTypeAlias" }
        let topicRef = try #require(deprecatedRef, "Expected to find a topic render reference for SomeTypeAlias")
        #expect(topicRef.isDeprecated == true, "Symbol should be marked as deprecated with a message")
    }

    private static func makeInSourceAvailabilityInfo(
        domain: String?,
        introduced: SymbolGraph.SemanticVersion? = .init(major: 1, minor: 2, patch: 3),
        deprecated: SymbolGraph.SemanticVersion?,
        isUnconditionallyDeprecated: Bool = false
    ) -> SymbolGraph.Symbol.Availability.AvailabilityItem {
        .init(
            domain: domain.map { .init(rawValue: $0) },
            introducedVersion: introduced,
            deprecatedVersion: deprecated,
            obsoletedVersion: nil,
            message: "Some description, from the availability information, of why this protocol is deprecated",
            renamed: nil,
            // These all default to false unless otherwise specified.
            isUnconditionallyDeprecated:  isUnconditionallyDeprecated,
            isUnconditionallyUnavailable: false,
            willEventuallyBeDeprecated:   false
        )
    }
}
