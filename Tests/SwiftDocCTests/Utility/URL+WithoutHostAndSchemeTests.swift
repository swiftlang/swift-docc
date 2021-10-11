/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocC

class URL_withoutHostAndPortAndSchemeTests: XCTestCase {

    func test() {
        let url = URL(string: "http://host.name:8888/path/to/something#fragment")!

        let withoutHostAndPortAndScheme = url.withoutHostAndPortAndScheme()
        XCTAssertEqual(withoutHostAndPortAndScheme.absoluteString, "/path/to/something#fragment")
        
        // Removing the host and scheme from a URL without those shouldn't change anything.
        XCTAssertEqual(withoutHostAndPortAndScheme.withoutHostAndPortAndScheme().absoluteString, "/path/to/something#fragment")
    }
}
