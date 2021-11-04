/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import XCTest
@testable import SwiftDocC

class LinkTitleResolverTests: XCTestCase {
    func testSymbolTitleResolving() throws {
        let (_, context) = try testBundleAndContext(named: "TestBundle")
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
}
