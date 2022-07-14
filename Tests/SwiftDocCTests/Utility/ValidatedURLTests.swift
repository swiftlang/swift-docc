/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocC

class ValidatedURLTests: XCTestCase {
    
    func testValidURLs() {
        let validURLs = [
            URL(string: "http://domain")!,
            URL(string: "http://www.domain.com")!,
            URL(string: "http://www.domain.com/path")!,
            URL(string: "https://www.domain.com/path")!,
            URL(string: "ftp://www.domain.com/path/file.ext")!,
        ]
        
        // Test ValidatedURL.init(String)
        validURLs.forEach { url in
            let validated = ValidatedURL(parsingExact: url.absoluteString)
            XCTAssertEqual(url.absoluteString, validated?.absoluteString)
        }

        // Test ValidatedURL.init(URL)
        validURLs.forEach { url in
            let validated = ValidatedURL(url)
            XCTAssertEqual(url.absoluteString, validated?.absoluteString)
        }
    }

    func testInvalidURLs() {
        let invalidURLs = [
            URL(string: "http://:domain")!,
        ]
        
        // Test ValidatedURL.init(String)
        invalidURLs.forEach { url in
            XCTAssertNil(ValidatedURL(parsingExact: url.absoluteString))
        }

        // Test ValidatedURL.init(URL)
        invalidURLs.forEach { url in
            XCTAssertNil(ValidatedURL(url))
        }
    }

    func testRequiringScheme() {
        let validURLs = [
            URL(string: "http://domain")!,
            URL(string: "https://www.domain.com")!,
            URL(string: "ftp://www.domain.com/path")!,
        ]
        
        // Test successful requiring
        validURLs
            .filter { $0.scheme == "ftp" }
            .forEach { url in
                XCTAssertEqual(url.absoluteString, ValidatedURL(url)?.requiring(scheme: "ftp")?.absoluteString)
            }

        // Test unsuccessful requiring
        validURLs
            .filter { $0.scheme != "ftp" }
            .forEach { url in
                XCTAssertNil(ValidatedURL(url)?.requiring(scheme: "ftp"))
            }
    }
    
    // We need to validate fragment parsing because former approach using `URL`
    // led to failing to parse the fragment for some variants of the test strings below.
    func testFragment() {
        let fragmentDestinations = [
            "scheme://domain/path#fragment",
            "scheme:/path#fragment",
            "scheme:path#fragment",
            "scheme:#fragment",
        ]

        // Test successful fragment parsing
        fragmentDestinations
            .forEach { url in
                XCTAssertNotNil(ValidatedURL(parsingExact: url)?.components.fragment)
            }
    }
}
