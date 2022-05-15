/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocCUtilities
@testable import SwiftDocC
import SwiftDocCTestUtilities
import ArgumentParser

class ConvertSubcommandSourceRepositoryTests: XCTestCase {
    private let testBundleURL = Bundle.module.url(
        forResource: "TestBundle",
        withExtension: "docc",
        subdirectory: "Test Bundles"
    )!
    
    private let testTemplateURL = Bundle.module.url(
        forResource: "Test Template",
        withExtension: nil,
        subdirectory: "Test Resources"
    )!
    
    func testSourceRepositoryAllArgumentsSpecified() throws {
        for sourceService in ["github", "gitlab", "bitbucket"] {
            try assertSourceRepositoryArguments(
                checkoutPath: "checkout path",
                sourceService: sourceService,
                sourceServiceBaseURL: "example.com/path/to/base"
            ) { action in
                XCTAssertEqual(action.sourceRepository?.checkoutPath, "checkout path")
                XCTAssertEqual(action.sourceRepository?.sourceServiceBaseURL, URL(string: "example.com/path/to/base")!)
            }
        }
    }
    
    func testDoesNotSetSourceRepositoryIfBothCheckoutPathAndsourceServiceBaseURLArgumentsAreMissing() throws {
        try assertSourceRepositoryArguments(
            checkoutPath: nil,
            sourceService: nil,
            sourceServiceBaseURL: nil
        ) { action in
            XCTAssertNil(action.sourceRepository)
        }
    }
    
    func testThrowsValidationErrorWhenSourceServiceIsSpecifiedButNotSourceServiceBaseURL() throws {
        XCTAssertThrowsError(
            try assertSourceRepositoryArguments(
                checkoutPath: nil,
                sourceService: nil,
                sourceServiceBaseURL: "example.com/path/to/base"
            )
        ) { error in
            XCTAssertEqual(
                (error as? ValidationError)?.message,
                """
                Missing argument '--source-service', which is required when using '--source-service-base-url' \
                and '--checkout-path'.
                """
            )
        }
    }
    
    func testThrowsValidationErrorWhenSourceServiceBaseURLIsSpecifiedButNotSourceService() throws {
        XCTAssertThrowsError(
            try assertSourceRepositoryArguments(
                checkoutPath: nil,
                sourceService: "github",
                sourceServiceBaseURL: nil
            )
        ) { error in
            XCTAssertEqual(
                (error as? ValidationError)?.message,
                """
                Missing argument '--source-service-base-url', which is required when using '--source-service' \
                and '--checkout-path'.
                """
            )
        }
    }
    
    func testThrowsValidationErrorWhenSourceServiceBaseURLIsInvalid() throws {
        XCTAssertThrowsError(
            try assertSourceRepositoryArguments(
                checkoutPath: "checkout path",
                sourceService: "github",
                sourceServiceBaseURL: "not a valid URL"
            )
        ) { error in
            XCTAssertEqual(
                (error as? ValidationError)?.message,
                "Invalid URL 'not a valid URL' for '--source-service-base-url' argument."
            )
        }
    }
    
    func testThrowsValidationErrorWhenCheckoutPathIsNotSpecified() throws {
        XCTAssertThrowsError(
            try assertSourceRepositoryArguments(
                checkoutPath: nil,
                sourceService: "github",
                sourceServiceBaseURL: "example.com/path/to/base"
            )
        ) { error in
            XCTAssertEqual(
                (error as? ValidationError)?.message,
                """
                Missing argument '--checkout-path', which is required when using '--source-service' \
                and '--source-service-base-url'.
                """
            )
        }
    }
    
    func testThrowsValidationErrorWhenSourceServiceIsInvalid() throws {
        XCTAssertThrowsError(
            try assertSourceRepositoryArguments(
                checkoutPath: "checkout path",
                sourceService: "not a supported source service",
                sourceServiceBaseURL: "example.com/foo"
            )
        ) { error in
            XCTAssertEqual(
                (error as? ValidationError)?.message,
                "Unsupported source service 'not a supported source service'. Use 'github', 'gitlab', or 'bitbucket'."
            )
        }
    }
    
    private func assertSourceRepositoryArguments(
        checkoutPath: String?,
        sourceService: String?,
        sourceServiceBaseURL: String?,
        assertion: ((ConvertAction) throws -> Void)? = nil
    ) throws {
        setenv(TemplateOption.environmentVariableKey, testTemplateURL.path, 1)
        
        let convertOptions = try Docc.Convert.parse(
            [testBundleURL.path]
                + (checkoutPath.map { ["--checkout-path", $0] } ?? [])
                + (sourceService.map { ["--source-service", $0] } ?? [])
                + (sourceServiceBaseURL.map { ["--source-service-base-url", $0] } ?? [])
        )
        
        let result = try ConvertAction(fromConvertCommand: convertOptions)
        try assertion?(result)
    }
}
