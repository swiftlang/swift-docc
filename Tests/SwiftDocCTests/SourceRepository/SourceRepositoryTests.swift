/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocC

class SourceRepositoryTests: XCTestCase {
    func testFormatReturnsNilIfSourceFilePrefixDoesNotMatchCheckout() {
        XCTAssertNil(
            SourceRepository(
                checkoutPath: "/path/to/checkout",
                sourceServiceBaseURL: URL(string: "https://example.com/source")!,
                formatLineNumber: { _ in "" }
            ).format(sourceFileURL: URL(string: "file:///not/path/to/checkout/file")!),
            """
            format(sourceFileURL:lineNumber:) unexpectedly returned non-nil result for source file that isn't in \
            source repository's local checkout folder.
            """
        )
    }
    
    func testFormatReturnsURLIfSourceFilePrefixMatchesCheckout() {
        XCTAssertEqual(
            SourceRepository(
                checkoutPath: "/path/to/checkout",
                sourceServiceBaseURL: URL(string: "https://example.com/source")!,
                formatLineNumber: { _ in "" }
            ).format(sourceFileURL: URL(string: "file:///path/to/checkout/file")!),
            URL(string: "https://example.com/source/file")!
        )
    }
    
    func testFormatReturnsURLWithLineNumber() {
        XCTAssertEqual(
            SourceRepository(
                checkoutPath: "/path/to/checkout",
                sourceServiceBaseURL: URL(string: "https://example.com/source")!,
                formatLineNumber: { lineNumber in "line-\(lineNumber)" }
            ).format(sourceFileURL: URL(string: "file:///path/to/checkout/file")!, lineNumber: 5),
            URL(string: "https://example.com/source/file#line-5")!
        )
    }
    
    func testGitHubFormatting() {
        XCTAssertEqual(
            SourceRepository
                .github(
                    checkoutPath: "/path/to/checkout",
                    sourceServiceBaseURL: URL(string: "https://example.com/source")!
                )
                .format(sourceFileURL: URL(string: "file:///path/to/checkout/file")!, lineNumber: 5),
            URL(string: "https://example.com/source/file#L5")!
        )
    }
    
    func testGitLabFormatting() {
        XCTAssertEqual(
            SourceRepository
                .gitlab(
                    checkoutPath: "/path/to/checkout",
                    sourceServiceBaseURL: URL(string: "https://example.com/source")!
                )
                .format(sourceFileURL: URL(string: "file:///path/to/checkout/file")!, lineNumber: 5),
            URL(string: "https://example.com/source/file#L5")!
        )
    }
    
    func testBitBucketFormatting() {
        XCTAssertEqual(
            SourceRepository
                .bitbucket(
                    checkoutPath: "/path/to/checkout",
                    sourceServiceBaseURL: URL(string: "https://example.com/source")!
                )
                .format(sourceFileURL: URL(string: "file:///path/to/checkout/file")!, lineNumber: 5),
            URL(string: "https://example.com/source/file#lines-5")!
        )
    }
}
