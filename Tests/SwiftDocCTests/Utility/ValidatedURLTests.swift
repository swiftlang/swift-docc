/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2025 Apple Inc. and the Swift project authors
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
        XCTAssertNil(ValidatedURL(parsingExact: "http://:domain"))

        XCTAssertNil(URL(string: "http://:domain").flatMap { ValidatedURL($0) })
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
    
    func testQueryIsPartOfPathForAuthoredLinks() throws {
        // Test return type disambiguation
        for linkText in [
            "SymbolName/memberName()->Int?",
            "doc:SymbolName/memberName()->Int?",
            "doc://com.example.test/SymbolName/memberName()->Int?",
        ] {
            let expectedPath = linkText.hasPrefix("doc://")
                ? "/SymbolName/memberName()->Int?"
                :  "SymbolName/memberName()->Int?"
            
            let validated = try XCTUnwrap(ValidatedURL(parsingAuthoredLink: linkText), "Failed to parse \(linkText.singleQuoted) as authored link")
            XCTAssertNil(validated.components.queryItems, "Authored documentation links don't include query items")
            XCTAssertEqual(validated.components.path, expectedPath)
            
            let validatedWithHeading = try XCTUnwrap(ValidatedURL(parsingAuthoredLink: linkText + "#Heading-Name"), "Failed to parse '\(linkText)#Heading-Name' as authored link")
            XCTAssertNil(validatedWithHeading.components.queryItems, "Authored documentation links don't include query items")
            XCTAssertEqual(validatedWithHeading.components.path, expectedPath)
            XCTAssertEqual(validatedWithHeading.components.fragment, "Heading-Name")
        }
        
        // Test parameter type disambiguation
        for linkText in [
            "SymbolName/memberName(with:and:)-(Int?,_)",
            "doc:SymbolName/memberName(with:and:)-(Int?,_)",
            "doc://com.example.test/SymbolName/memberName(with:and:)-(Int?,_)",
        ] {
            let expectedPath = linkText.hasPrefix("doc://")
                ? "/SymbolName/memberName(with:and:)-(Int?,_)"
                :  "SymbolName/memberName(with:and:)-(Int?,_)"
            
            let validated = try XCTUnwrap(ValidatedURL(parsingAuthoredLink: linkText), "Failed to parse \(linkText.singleQuoted) as authored link")
            XCTAssertNil(validated.components.queryItems, "Authored documentation links don't include query items")
            XCTAssertEqual(validated.components.path, expectedPath)
            
            let validatedWithHeading = try XCTUnwrap(ValidatedURL(parsingAuthoredLink: linkText + "#Heading-Name"), "Failed to parse '\(linkText)#Heading-Name' as authored link")
            XCTAssertNil(validatedWithHeading.components.queryItems, "Authored documentation links don't include query items")
            XCTAssertEqual(validatedWithHeading.components.path, expectedPath)
            XCTAssertEqual(validatedWithHeading.components.fragment, "Heading-Name")
        }
    }
    
    func testEscapedFragment() throws {
        let escapedFragment = try XCTUnwrap("💻".addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed))
        XCTAssertEqual(escapedFragment, "%F0%9F%92%BB")
        
        for linkText in [
            "SymbolName#\(escapedFragment)",
            "doc:SymbolName#\(escapedFragment)",
            "doc://com.example.test/SymbolName#\(escapedFragment)",
        ] {
            let expectedPath = linkText.hasPrefix("doc://")
                ? "/SymbolName"
                :  "SymbolName"
            
            let validated = try XCTUnwrap(ValidatedURL(parsingAuthoredLink: linkText), "Failed to parse \(linkText.singleQuoted) as authored link")
            
            XCTAssertEqual(validated.components.path, expectedPath)
            XCTAssertEqual(validated.components.fragment, "💻")
        }
    }
}
