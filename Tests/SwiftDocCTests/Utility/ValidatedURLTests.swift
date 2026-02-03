/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Testing
import Foundation
@testable import SwiftDocC

struct ValidatedURLTests {
    
    @Test(arguments: [
        URL(string: "http://domain")!,
        URL(string: "http://www.domain.com")!,
        URL(string: "http://www.domain.com/path")!,
        URL(string: "https://www.domain.com/path")!,
        URL(string: "ftp://www.domain.com/path/file.ext")!,
    ])
    func initializeFromURL(url: URL) {
        // Check two different initializers
        #expect(url.absoluteString == ValidatedURL(parsingExact: url.absoluteString)?.absoluteString)
        #expect(url.absoluteString == ValidatedURL(url)?.absoluteString)
    }

    @Test
    func initializeFromInvalidURL() {
        #expect(ValidatedURL(parsingExact: "http://:domain") == nil)

        #expect(URL(string: "http://:domain").flatMap { ValidatedURL($0) } == nil)
    }

    @Test(arguments: [
        URL(string: "http://domain")!,
        URL(string: "https://www.domain.com")!,
        URL(string: "ftp://www.domain.com/path")!,
    ])
    func requiringScheme(url: URL) {
        let validated = ValidatedURL(url)?.requiring(scheme: "ftp")
        if url.scheme == "ftp" {
            #expect(url.absoluteString == validated?.absoluteString)
        } else {
            #expect(validated == nil)
        }
    }
    
    // We need to validate fragment parsing because former approach using `URL`
    // led to failing to parse the fragment for some variants of the test strings below.
    @Test(arguments: [
        "scheme://domain/path#fragment",
        "scheme:/path#fragment",
        "scheme:path#fragment",
        "scheme:#fragment",
    ])
    func accessingFragment(string: String) {
        #expect(ValidatedURL(parsingExact: string)?.components.fragment != nil)
    }
    
    @Test
    func queryIsPartOfPathForAuthoredLinks() throws {
        func validate(linkText: String, expectedPath: String, expectedFragment: String? = nil, sourceLocation: SourceLocation = #_sourceLocation) throws {
            let validated = try #require(ValidatedURL(parsingAuthoredLink: linkText), "Failed to parse \(linkText.singleQuoted) as authored link")
            #expect(validated.components.queryItems == nil, "Authored documentation links don't include query items", sourceLocation: sourceLocation)
            #expect(validated.components.path == expectedPath, sourceLocation: sourceLocation)
            #expect(validated.components.fragment == expectedFragment, sourceLocation: sourceLocation)
        }
        
        // Test return type disambiguation
        for linkText in [
            "SymbolName/memberName()->Int?",
            "doc:SymbolName/memberName()->Int?",
            "doc://com.example.test/SymbolName/memberName()->Int?",
        ] {
            let expectedPath = linkText.hasPrefix("doc://")
                ? "/SymbolName/memberName()->Int?"
                :  "SymbolName/memberName()->Int?"
            
            try validate(linkText: linkText, expectedPath: expectedPath)
            try validate(linkText: linkText + "#Heading-Name", expectedPath: expectedPath, expectedFragment: "Heading-Name")
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
            
            try validate(linkText: linkText, expectedPath: expectedPath)
            try validate(linkText: linkText + "#Heading-Name", expectedPath: expectedPath, expectedFragment: "Heading-Name")
        }
        
        // Test parameter with percent encoding
        var linkText = "doc://com.example.test/docc=Whats%20New&version=DocC&Title=[Update]"
        var expectedPath = "/docc=Whats%20New&version=DocC&Title=[Update]"
        try validate(linkText: linkText, expectedPath: expectedPath)
        
        // Test parameter with percent encoding at the end of the URL
        linkText = "doc://com.example.test/docc=Whats%20New&version=DocC&Title=[Update]%20"
        expectedPath = "/docc=Whats%20New&version=DocC&Title=[Update]%20"
        try validate(linkText: linkText, expectedPath: expectedPath)
        
        // Test parameter without percent encoding
        linkText = "doc://com.example.test/docc=WhatsNew&version=DocC&Title=[Update]"
        expectedPath = "/docc=WhatsNew&version=DocC&Title=[Update]"
        try validate(linkText: linkText, expectedPath: expectedPath)
        
        // Test parameter with special characters
        linkText = "doc://com.example.test/テスト"
        expectedPath = "/テスト"
        try validate(linkText: linkText, expectedPath: expectedPath)
    }
    
    @Test(arguments: [
        "SymbolName#",
        "doc:SymbolName#",
        "doc://com.example.test/SymbolName#",
    ])
    func parsingAuthoredLinkWithEscapedFragment(baseLink: String) throws {
        let escapedFragment = try #require("💻".addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed))
        #expect(escapedFragment == "%F0%9F%92%BB")
        
        let linkText = baseLink + escapedFragment
        
        let expectedPath = linkText.hasPrefix("doc://")
            ? "/SymbolName"
            :  "SymbolName"
        
        let validated = try #require(ValidatedURL(parsingAuthoredLink: linkText), "Failed to parse \(linkText.singleQuoted) as authored link")
        
        #expect(validated.components.path == expectedPath)
        #expect(validated.components.fragment == "💻")
    }
}
