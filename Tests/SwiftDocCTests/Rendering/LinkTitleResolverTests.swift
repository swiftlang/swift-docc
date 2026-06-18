/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import XCTest
import SymbolKit
import Markdown
@testable import SwiftDocC

class LinkTitleResolverTests: XCTestCase {
    func testSymbolTitleResolving() async throws {
        let (_, context) = try await testBundleAndContext(named: "LegacyBundle_DoNotUseInNewTests")
        let resolver = LinkTitleResolver(context: context, source: nil)
        guard let reference = context.knownIdentifiers.filter({ ref -> Bool in
            return ref.path.hasSuffix("MyProtocol")
        }).first else {
            XCTFail("Did not find MyProtocol in Test Bundle")
            return
        }
        let myProtocolNode = try context.entity(with: reference)

        // Tests title resolving for symbols
        let title = resolver.title(for: myProtocolNode)
        XCTAssertEqual("MyProtocol", title?.allValues.first?.variant)
    }

    func testSymbolProseTitleResolving() async throws {
        let (_, context) = try await testBundleAndContext(named: "LegacyBundle_DoNotUseInNewTests")
        let resolver = LinkTitleResolver(context: context, source: nil)

        let reference = ResolvedTopicReference(bundleID: "test", path: "/test", sourceLanguage: .swift)
        var node = DocumentationNode(
            reference: reference,
            kind: .class,
            sourceLanguage: .swift,
            name: .symbol(name: "init(arg:)"),
            markup: Document(parsing: ""),
            semantic: nil
        )

        let makeSymbol: (String?) -> Symbol = { prose in
            Symbol(
                kindVariants: .init(swiftVariant: .init(parsedIdentifier: .class, displayName: "Class")),
                titleVariants: .init(swiftVariant: "init(arg:)"),
                proseVariants: .init(swiftVariant: prose),
                subHeadingVariants: .init(swiftVariant: nil),
                navigatorVariants: .init(swiftVariant: nil),
                roleHeadingVariants: .init(swiftVariant: "Class"),
                platformNameVariants: .init(swiftVariant: nil),
                moduleReference: reference,
                externalIDVariants: .init(swiftVariant: nil),
                accessLevelVariants: .init(swiftVariant: nil),
                availabilityVariants: .init(swiftVariant: .init(availability: [])),
                deprecatedSummaryVariants: .init(swiftVariant: nil),
                mixinsVariants: .init(swiftVariant: nil),
                abstractSectionVariants: .init(swiftVariant: nil),
                discussionVariants: .init(swiftVariant: nil),
                topicsVariants: .init(swiftVariant: nil),
                seeAlsoVariants: .init(swiftVariant: nil),
                returnsSectionVariants: .init(swiftVariant: nil),
                parametersSectionVariants: .init(swiftVariant: nil),
                dictionaryKeysSection: nil,
                possibleValuesSection: nil,
                httpEndpointSection: nil,
                httpBodySection: nil,
                httpParametersSection: nil,
                httpResponsesSection: nil,
                redirects: nil
            )
        }

        // When prose is set, the resolver returns it instead of the title.
        node.semantic = makeSymbol("MyClass")
        let proseTitle = resolver.title(for: node)
        XCTAssertEqual("MyClass", proseTitle?.allValues.first?.variant)

        // When prose is nil, proseVariants is empty and the resolver falls back to titleVariants.
        node.semantic = makeSymbol(nil)
        let fallbackTitle = resolver.title(for: node)
        XCTAssertEqual("init(arg:)", fallbackTitle?.allValues.first?.variant)
    }
}
