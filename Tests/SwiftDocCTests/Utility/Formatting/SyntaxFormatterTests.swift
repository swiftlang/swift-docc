/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import SwiftFormat
import XCTest
@testable import SwiftDocC

class SyntaxFormatterTests: XCTestCase {
    func testDefaultInitializerUsesDefaultConfig() {
        let formatter = SyntaxFormatter()
        XCTAssertEqual(formatter.configuration.tabWidth, 4)
    }

    func testCustomConfigurationInitializer() {
        var config = Configuration()
        config.tabWidth = 2
        let formatter = SyntaxFormatter(configuration: config)
        XCTAssertEqual(formatter.configuration.tabWidth, 2)
    }

    func testFormatWithComplexFunction() throws {
        XCTAssertEqual(
            try SyntaxFormatter().format(source: """
                @attached(peer) macro Test<C1, C2>(_ displayName: String? = nil, \
                _ traits: any TestTrait..., arguments zippedCollections: \
                Zip2Sequence<C1, C2>) where C1 : Collection, C1 : Sendable, C2 \
                : Collection, C2 : Sendable, C1.Element : Sendable, C2.Element \
                : Sendable
            """),
            """
            @attached(peer)
            macro Test<C1, C2>(
                _ displayName: String? = nil,
                _ traits: any TestTrait...,
                arguments zippedCollections: Zip2Sequence<C1, C2>
            )
            where
                C1: Collection,
                C1: Sendable,
                C2: Collection,
                C2: Sendable,
                C1.Element: Sendable,
                C2.Element: Sendable
            """
        )
    }
}
