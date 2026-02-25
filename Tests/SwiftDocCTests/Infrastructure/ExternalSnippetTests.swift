/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import DocCCommon
import DocCTestUtilities
import SymbolKit
import XCTest

@testable import SwiftDocC

/// Tests for external source file snippet support
class ExternalSnippetTests: XCTestCase {

    func testExternalSourceFileRegionExtraction() throws {
        // Test the RegionExtractor with different comment styles
        let extractor = RegionExtractor()

        // Test C-style block comments
        let cCode = [
            "/* Some header */",
            "int main() {",
            "    /* snippet.setup */",
            "    int x = 5;",
            "    /* snippet.end */",
            "    return x;",
            "}",
        ]

        let cSlices = extractor.parseRegions(in: cCode, using: .blockComment("/*", "*/"))
        XCTAssertEqual(cSlices.count, 1)
        XCTAssertEqual(cSlices["setup"], 2..<4)

        // Test Python-style hash comments
        let pythonCode = [
            "#!/usr/bin/env python3",
            "def hello():",
            "    # snippet.greeting",
            "    print('Hello, World!')",
            "    # snippet.end",
            "    return True",
        ]

        let pythonSlices = extractor.parseRegions(in: pythonCode, using: .hashComment("#"))
        XCTAssertEqual(pythonSlices.count, 1)
        XCTAssertEqual(pythonSlices["greeting"], 2..<4)
    }

    func testLanguageRegistryConfiguration() throws {
        // Test that we can get configuration for different extensions
        XCTAssertNotNil(SnippetLanguageRegistry.configuration(forExtension: "c"))
        XCTAssertNotNil(SnippetLanguageRegistry.configuration(forExtension: "cpp"))
        XCTAssertNotNil(SnippetLanguageRegistry.configuration(forExtension: "js"))
        XCTAssertNotNil(SnippetLanguageRegistry.configuration(forExtension: "py"))
        XCTAssertNotNil(SnippetLanguageRegistry.configuration(forExtension: "rs"))

        // Test that unsupported extension returns nil
        XCTAssertNil(SnippetLanguageRegistry.configuration(forExtension: "unknown"))

        // Verify C uses block comments
        let cConfig = try XCTUnwrap(SnippetLanguageRegistry.configuration(forExtension: "c"))
        if case .blockComment = cConfig.commentStyle {
            // Expected
        } else {
            XCTFail("C should use block comments")
        }

        // Verify Python uses hash comments
        let pyConfig = try XCTUnwrap(SnippetLanguageRegistry.configuration(forExtension: "py"))
        if case .hashComment = pyConfig.commentStyle {
            // Expected
        } else {
            XCTFail("Python should use hash comments")
        }
    }

    func testMultipleRegionsInCFile() throws {
        let extractor = RegionExtractor()

        let cCode = [
            "#include <stdio.h>",
            "/* snippet.init */",
            "void init() {",
            "    printf(\"init\\n\");",
            "}",
            "/* snippet.end */",
            "",
            "/* snippet.cleanup */",
            "void cleanup() {",
            "    printf(\"cleanup\\n\");",
            "}",
            "/* snippet.end */",
            "",
            "int main() {",
            "    init();",
            "    cleanup();",
            "    return 0;",
            "}",
        ]

        let slices = extractor.parseRegions(in: cCode, using: .blockComment("/*", "*/"))

        XCTAssertEqual(slices.count, 2)
        XCTAssertEqual(slices["init"], 1..<5)
        XCTAssertEqual(slices["cleanup"], 7..<11)
    }

    func testImplicitRegionEnd() throws {
        let extractor = RegionExtractor()

        // Test that a new region implicitly ends the previous one
        let code = [
            "func first() {}",
            "// snippet.part1",
            "let x = 1",
            "// snippet.part2",
            "let y = 2",
            "// snippet.end",
            "func last() {}",
        ]

        let slices = extractor.parseRegions(in: code, using: .lineComment("//"))

        XCTAssertEqual(slices.count, 2)
        XCTAssertEqual(slices["part1"], 1..<2)
        XCTAssertEqual(slices["part2"], 2..<5)
    }
}
