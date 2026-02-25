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
        #expect(context.problems.isEmpty, "Unexpected problems: \(context.problems.map(\.diagnostic.summary))")
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
        #expect(context.problems.isEmpty, "Unexpected problems: \(context.problems.map(\.diagnostic.summary))")
        
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
        #expect(context.problems.isEmpty, "Unexpected problems: \(context.problems.map(\.diagnostic.summary))")
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
        #expect(context.problems.map(\.diagnostic.identifier) == ["DeprecationSummaryForAvailableSymbol"],
                "Unexpected problems: \(context.problems.map(\.diagnostic.summary))")
        
        let problem = try #require(context.problems.first)
        #expect(problem.diagnostic.summary == "Type alias 'SomeTypeAlias' is unconditionally available")
        #expect(problem.diagnostic.explanation == "A symbol without any availability annotations is considered available for all versions of the module (SomeModule) for all platforms.")
        
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
        #expect(context.problems.map(\.diagnostic.identifier) == ["DeprecationSummaryForAvailableSymbol"],
                "Unexpected problems: \(context.problems.map(\.diagnostic.summary))")
        
        let problem = try #require(context.problems.first)
        #expect(problem.diagnostic.summary == "Type alias 'SomeTypeAlias' is available for SecondPlatform and ThirdPlatform")
        #expect(problem.diagnostic.explanation == "This type alias has attributes that mark it as available for 'SecondPlatform' 1.2.3 onwards and all versions of 'ThirdPlatform'.")
        
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
        #expect(context.problems.map(\.diagnostic.identifier) == [],
                "Unexpected problems: \(context.problems.map(\.diagnostic.summary))")
        
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
        #expect(context.problems.map(\.diagnostic.identifier) == ["DeprecationSummaryForAvailableSymbol"],
                "Unexpected problems: \(context.problems.map(\.diagnostic.summary))")
        
        let problem = try #require(context.problems.first)
        #expect(problem.diagnostic.summary == "Type alias 'SomeTypeAlias' is available for PlatformB, PlatformC, and PlatformD")
        #expect(problem.diagnostic.explanation == "This type alias has attributes that mark it as available for 'PlatformB' 2.3.4 onwards, all versions of 'PlatformC', and 'PlatformD' 3.4.5 onwards.")
        
        // Verify that the notes refer to the Available directives
        let expectedSource = switch directiveLocation {
            case .extensionFile:   "/unit-test.docc/SomeTypeAlias.md"
            case .inSourceComment: "/Users/username/path/to/SomeFile.swift"
        }
        #expect(problem.diagnostic.notes.map(\.source.path) == [expectedSource, expectedSource])
        #expect(problem.diagnostic.notes.map(\.message) == [
            "Marked available for 'PlatformB' here",
            "Marked available for 'PlatformD' here",
        ])
        
        // Verify that the solutions suggest marking the available platforms as deprecated using both attributes (preferred) and directives
        let expectedSourceAttribute: String? = switch sourceLanguage {
            case .swift:      "'@available()' attributes"
            case .objectiveC: "'API_AVAILABLE\' macros"
            default:          nil
        }
        #expect(problem.possibleSolutions.count == (expectedSourceAttribute != nil ? 2 : 1))
        if let expectedSourceAttribute {
            #expect(problem.possibleSolutions.first?.summary == "Add \(expectedSourceAttribute) marking 'PlatformB', 'PlatformC', and 'PlatformD' as deprecated API")
        }
        #expect(problem.possibleSolutions.last?.summary == "Add Available directives marking 'PlatformB', 'PlatformC', and 'PlatformD' as deprecated only in documentation")
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
        #expect(context.problems.map(\.diagnostic.identifier) == ["DeprecationSummaryForAvailableSymbol"],
                "Unexpected problems: \(context.problems.map(\.diagnostic.summary))")
        
        let problem = try #require(context.problems.first)
        #expect(problem.diagnostic.summary == "Type alias 'SomeTypeAlias' is available for all platforms, except PlatformA and PlatformB")
        #expect(problem.diagnostic.explanation == "This type alias has attributes that mark it as available for all platforms, except PlatformA and PlatformB.")
        
        #expect(problem.diagnostic.notes.map(\.message) == [], "Only deprecated platforms, not available ones, are defined in Available directives")
        
        // Verify that the solutions suggest modifying the wildcard availability attribute
        #expect(problem.possibleSolutions.count == 1)
        let solution = try #require(problem.possibleSolutions.first)
        #expect(solution.summary == "Update wildcard '@available()' attribute with a deprecated version or unconditional deprecation")
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
