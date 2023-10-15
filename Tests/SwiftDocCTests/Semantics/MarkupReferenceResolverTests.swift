/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022-2023 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocC
import Markdown

class MarkupReferenceResolverTests: XCTestCase {
    func testArbitraryReferenceInComment() throws {
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        let source = """
        @Comment {
            ``hello`` and ``world`` are 2 arbitrary symbol links.
            <doc:NOT-EXISTS-DESTINATION#UNKNOWN>
            But since they are under a comment block, no reference resolve problem should be emitted.
        }
        """
        let document = Document(parsing: source, options: [.parseBlockDirectives, .parseSymbolLinks])
        var resolver = MarkupReferenceResolver(context: context, bundle: bundle, source: nil, rootReference: context.rootModules[0])
        _ = resolver.visit(document)
        XCTAssertEqual(0, resolver.problems.count)
    }

    func testDuplicatedDiagnosticForExtensionFile() throws {
        let (_, context) = try testBundleAndContext(named: "ExtensionArticleBundle")
        // Before #733's change, there will be 2 duplicated problems.
        // And we'll trigger a index out of range crash in DefaultDiagnosticConsoleFormatter
        XCTAssertEqual(1, context.problems.count)
    }
}
