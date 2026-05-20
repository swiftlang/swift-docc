/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
import Foundation
@testable import DocCCommandLine
@testable import SwiftDocC
import ArgumentParser
import DocCTestUtilities

// This test uses `XCTestCase` so that it can call our `createTemporaryDirectory()` helper
class IndexSubcommandDeprecationMessageTests: XCTestCase {
    func testWarnsAboutDeprecationWhenRun() async throws {
        // Set up the output for the deprecation warning
        let originalErrorLogHandle = Docc.Index._errorLogHandle
        let originalDiagnosticFormattingOptions = Docc.Index._diagnosticFormattingOptions
        defer {
            Docc.Index._errorLogHandle = originalErrorLogHandle
            Docc.Index._diagnosticFormattingOptions = originalDiagnosticFormattingOptions
        }
        Docc.Index._diagnosticFormattingOptions = .formatConsoleOutputForTools
        
        // Create the minimal inputs to the command.
        let archiveInput = try Folder(name: "Something.doccarchive") {
            Folder(name: "data") {}
        }.write(inside: createTemporaryDirectory())
        
        // Verify that both versions of the command print the deprecation message.
        for indexCommandType in [
            Docc.Index.self  as any AsyncParsableCommand.Type, // Verify the `docc process-archive index` subcommand
            Docc._Index.self as any AsyncParsableCommand.Type, // Verify the hidden `docc index` command, previously left for backwards compatibility.
        ] {
            // Use a different log store for each command type
            let logStorage = LogHandle.LogStorage()
            Docc.Index._errorLogHandle = .memory(logStorage)
            
            // Verify that running the `` command prints the deprecation message.
            var command = try indexCommandType.parse([
                archiveInput.path,
                "--bundle-identifier", "org.swift.example",
            ])
            
            try await command.run()
            XCTAssertEqual(logStorage.text.trimmingCharacters(in: .newlines), """
            warning: The `index` command is deprecated and scheduled to be removed after the Swift 6.6 release; pass the `--emit-lmdb-index` flag to the `convert` command instead [DeprecatedIndexCommand]
            The `convert` command always creates a JSON representation of the navigation hierarchy for the on-page sidebar.
            If you need an LMDB database representation of the same navigation hierarchy, pass the `--emit-lmdb-index` flag to the `convert` command _instead_ of running the `index` command on the output of the `convert` command.

            If you're building documentation using the Swift-DocC Plugin (`swift package generate-documentation`) it passes the `--emit-lmdb-index` flag to Swift-DocC by default, and requires the `--disable-indexing`/`--no-indexing` flag to opt out of that behavior. If you need the LMDB database representation of the same navigation hierarchy in the documentation output, don't pass the `--disable-indexing`/`--no-indexing` flag to `swift package generate-documentation`.
            """)
        }
    }
}
