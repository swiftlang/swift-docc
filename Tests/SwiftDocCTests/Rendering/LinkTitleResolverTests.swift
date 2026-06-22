/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import XCTest
@testable import SwiftDocC
import DocCTestUtilities

class LinkTitleResolverTests: XCTestCase {
    func testSymbolTitleResolving() async throws {
        let catalog = Folder(name: "unit-test.docc") {
            JSONFile(symbolGraph: makeSymbolGraph(moduleName: "MyKit", symbols: [
                makeSymbol(id: "s:6MyKit10MyProtocolP", kind: .protocol, pathComponents: ["MyProtocol"]),
            ]))
        }
        let (_, context) = try await loadBundle(catalog: catalog)
        let resolver = LinkTitleResolver(context: context, source: nil)
        let reference = try XCTUnwrap(context.knownIdentifiers.first(where: { ref in
            ref.path.hasSuffix("MyProtocol")
        }), "Did not find MyProtocol in test catalog")
        let myProtocolNode = try context.entity(with: reference)
        
        // Tests title resolving for symbols
        let title = resolver.title(for: myProtocolNode)
        XCTAssertEqual("MyProtocol", title?.allValues.first?.variant)
    }
}
