/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024-2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import XCTest
import Markdown

@testable import SwiftDocC

class MetadataAlternateRepresentationTests: XCTestCase {
    func testValidLocalLink() async throws {
        for link in ["``MyClass/property``", "MyClass/property"] {
            let (problems, metadata) = try await parseDirective(Metadata.self) {
                """
                @Metadata {
                    @AlternateRepresentation(\(link))
                }
                """
            }
            
            XCTAssertTrue(problems.isEmpty, "Unexpected problems: \(problems.joined(separator: "\n"))")
            XCTAssertEqual(metadata?.alternateRepresentations.count, 1)
            
            let alternateRepresentation = try XCTUnwrap(metadata?.alternateRepresentations.first)
            XCTAssertEqual(alternateRepresentation.reference.url, URL(string: "MyClass/property"))
        }
    }
        
    func testValidExternalLinkReference() async throws {
        let (problems, metadata) = try await parseDirective(Metadata.self) {
            """
            @Metadata {
                @AlternateRepresentation("doc://com.example/documentation/MyClass/property")
            }
            """
        }
        
        XCTAssertTrue(problems.isEmpty, "Unexpected problems: \(problems.joined(separator: "\n"))")
        XCTAssertEqual(metadata?.alternateRepresentations.count, 1)
        
        let alternateRepresentation = try XCTUnwrap(metadata?.alternateRepresentations.first)
        XCTAssertEqual(alternateRepresentation.reference.url, URL(string: "doc://com.example/documentation/MyClass/property"))
    }

    func testInvalidTopicReference() async throws {
        let (problems, _) = try await parseDirective(Metadata.self) {
            """
            @Metadata {
                @AlternateRepresentation("doc://")
            }
            """
        }
        
        XCTAssertEqual(problems.count, 2, "Unexpected number of problems: \(problems.joined(separator: "\n"))")
        XCTAssertEqual(problems, [
            "1: note – org.swift.docc.Metadata.NoConfiguration",
            "2: warning – org.swift.docc.HasArgument.unlabeled.ConversionFailed"
        ])
    }
}
