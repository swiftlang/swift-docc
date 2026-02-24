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
        makeInSourceAvailabilityInfo(domain: "macOS", deprecated: .init(major: 4, minor: 5, patch: 6)),
        makeInSourceAvailabilityInfo(domain: "macOS", deprecated: nil,                                isUnconditionallyDeprecated: true),
        makeInSourceAvailabilityInfo(domain: nil,     deprecated: .init(major: 4, minor: 5, patch: 6)),
        makeInSourceAvailabilityInfo(domain: nil,     deprecated: nil,                                isUnconditionallyDeprecated: true),
    ])
    func displaysDeprecationMessageFromInSourceAttribute(_ availabilityItem: SymbolGraph.Symbol.Availability.AvailabilityItem) async throws {
        let catalog = Folder(name: "unit-test.docc", content: [
            JSONFile(name: "SomeModule.symbols.json", content: makeSymbolGraph(moduleName: "SomeModule", symbols: [
                makeSymbol(id: "some-symbol-id", kind: .protocol, pathComponents: ["SomeProtocol"], docComment: """
                    Some in-source documentation with a deprecation summary for this protocol.
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
                makeSymbol(id: "some-symbol-id", kind: .protocol, pathComponents: ["SomeProtocol"], docComment: """
                    Some in-source documentation with a deprecation summary for this protocol.
                    """, availability: [
                        Self.makeInSourceAvailabilityInfo(domain: "macOS", deprecated: .init(major: 4, minor: 5, patch: 6)),
                    ])
            ])),
            
            TextFile(name: "SomeProtocol.md", utf8Content: """
            # ``SomeProtocol``
            \(markupBeforeDirective)
            \(Self.deprecationSummaryDirective)
            """)
        ])
        
        let context = try await load(catalog: catalog)
        #expect(context.problems.isEmpty, "Unexpected problems: \(context.problems.map(\.diagnostic.summary))")
        
        // Verify that DocC still displays the deprecation text, despite the symbol being available.
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
                makeSymbol(id: "some-symbol-id", kind: .protocol, pathComponents: ["SomeProtocol"], docComment: """
                    Some in-source documentation with a deprecation summary for this protocol.
                    
                    \(directiveLocation == .inSourceComment ? Self.deprecationSummaryDirective : "")
                    """, availability: [
                        Self.makeInSourceAvailabilityInfo(domain: "macOS", deprecated: .init(major: 4, minor: 5, patch: 6))
                    ])
            ])),
            
            TextFile(name: "SomeProtocol.md", utf8Content: """
            # ``SomeProtocol``
            
            Some additional documentation for this protocol.
               
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
                makeSymbol(id: "some-symbol-id", kind: .protocol, pathComponents: ["SomeProtocol"], docComment: """
                    Some in-source documentation with a deprecation summary for this protocol.
                    
                    \(directiveLocation == .inSourceComment ? Self.deprecationSummaryDirective : "")
                    """, availability: []) // No availability attributes for this symbol
            ])),
            
            TextFile(name: "SomeProtocol.md", utf8Content: """
            # ``SomeProtocol``
            
            Some additional documentation for this protocol.
               
            \(directiveLocation == .extensionFile ? Self.deprecationSummaryDirective : "")
            """)
        ])
        
        let context = try await load(catalog: catalog)
        // Verify the warning
        #expect(context.problems.map(\.diagnostic.identifier) == ["org.swift.docc.DeprecationSummaryForAvailableSymbol"],
                "Unexpected problems: \(context.problems.map(\.diagnostic.summary))")
        
        let problem = try #require(context.problems.first)
        #expect(problem.diagnostic.summary == "'SomeProtocol' isn't unconditionally deprecated")
        
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
                makeSymbol(id: "some-symbol-id", kind: .protocol, pathComponents: ["SomeProtocol"], docComment: """
                    Some in-source documentation with a deprecation summary for this protocol.
                    
                    \(directiveLocation == .inSourceComment ? Self.deprecationSummaryDirective : "")
                    """, availability: [
                        Self.makeInSourceAvailabilityInfo(domain: "macOS", deprecated: .init(major: 4, minor: 5, patch: 6)),
                        Self.makeInSourceAvailabilityInfo(domain: "iOS", deprecated: nil),
                    ])
            ])),
            
            TextFile(name: "SomeProtocol.md", utf8Content: """
            # ``SomeProtocol``
            
            Some additional documentation for this protocol.
            
            \(directiveLocation == .extensionFile ? Self.deprecationSummaryDirective : "")
            """)
        ])
        
        let context = try await load(catalog: catalog)
        // Verify the warning
        #expect(context.problems.map(\.diagnostic.identifier) == ["org.swift.docc.DeprecationSummaryForAvailableSymbol"],
                "Unexpected problems: \(context.problems.map(\.diagnostic.summary))")
        
        let problem = try #require(context.problems.first)
        #expect(problem.diagnostic.summary == "'SomeProtocol' isn't unconditionally deprecated")
        
        // Verify that DocC still displays the deprecation text, despite the symbol being available.
        let node = try #require(context.documentationCache["some-symbol-id"])
        let converter = DocumentationNodeConverter(context: context)
        let renderNode = converter.convert(node)
        
        #expect(renderNode.deprecationSummary?.firstParagraph == [.text("Some description, from the directive, of why this protocol is deprecated.")])
    }
    
    @Test(.disabled("Available directive doesn't prevent this warning"), arguments: DirectiveLocation.allCases)
    func doesNotWarnAboutDeprecationSummaryIfVersionInfoIsProvidedInAvailabilityDirective(_ directiveLocation: DirectiveLocation) async throws {
        let directives = """
        \(Self.deprecationSummaryDirective)
        @Metadata {
          @Available(iOS, introduced: "2.3.4", deprecated: "5.6.7")
        }
        """
        
        let catalog = Folder(name: "unit-test.docc", content: [
            JSONFile(name: "SomeModule.symbols.json", content: makeSymbolGraph(moduleName: "SomeModule", symbols: [
                makeSymbol(id: "some-symbol-id", kind: .protocol, pathComponents: ["SomeProtocol"], docComment: """
                    Some in-source documentation with a deprecation summary for this protocol.
                    
                    \(directiveLocation == .inSourceComment ? directives : "")
                    """, availability: [
                        Self.makeInSourceAvailabilityInfo(domain: "iOS", deprecated: nil),
                    ])
            ])),
            
            TextFile(name: "SomeProtocol.md", utf8Content: """
            # ``SomeProtocol``
            
            Some additional documentation for this protocol.
               
            \(directiveLocation == .extensionFile ? directives : "")
            """)
        ])
        
        let context = try await load(catalog: catalog)
        #expect(context.problems.map(\.diagnostic.identifier) == [],
                "Unexpected problems: \(context.problems.map(\.diagnostic.summary))")
        
        // Verify that DocC still displays the deprecation text, despite the symbol being available.
        let node = try #require(context.documentationCache["some-symbol-id"])
        let converter = DocumentationNodeConverter(context: context)
        let renderNode = converter.convert(node)
        
        #expect(renderNode.deprecationSummary?.firstParagraph == [.text("Some description, from the directive, of why this protocol is deprecated.")])
    }
    
    private static func makeInSourceAvailabilityInfo(
        domain: String?,
        deprecated: SymbolGraph.SemanticVersion?,
        isUnconditionallyDeprecated: Bool = false
    ) -> SymbolGraph.Symbol.Availability.AvailabilityItem {
        .init(
            domain: domain.map { .init(rawValue: $0) },
            introducedVersion: .init(major: 1, minor: 2, patch: 3),
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
