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
class StaticHostingDeprecationMessageTests: XCTestCase {
    func testWarnsAboutDeprecationWhenRun() async throws {
        // Set up the output for the deprecation warning
        let originalErrorLogHandle = Docc.ProcessArchive.TransformForStaticHosting._errorLogHandle
        let originalDiagnosticFormattingOptions = Docc.Index._diagnosticFormattingOptions
        defer {
            Docc.ProcessArchive.TransformForStaticHosting._errorLogHandle = originalErrorLogHandle
            Docc.ProcessArchive.TransformForStaticHosting._diagnosticFormattingOptions = originalDiagnosticFormattingOptions
        }
        let logStorage = LogHandle.LogStorage()
        Docc.ProcessArchive.TransformForStaticHosting._errorLogHandle = .memory(logStorage)
        Docc.ProcessArchive.TransformForStaticHosting._diagnosticFormattingOptions = .formatConsoleOutputForTools
        
        // Create the minimal inputs to the command.
        let archiveInput = try Folder(name: "Something.doccarchive") {
            Folder(name: "data") {}
        }.write(inside: createTemporaryDirectory())
        
        let htmlTemplateDirectory = try Folder(name: "template") {
            TextFile(name: "index.html", utf8Content: "")
            TextFile(name: "index-template.html", utf8Content: "")
        }.write(inside: createTemporaryDirectory())
        
        SetEnvironmentVariable(TemplateOption.environmentVariableKey, htmlTemplateDirectory.path)
        defer {
            UnsetEnvironmentVariable(TemplateOption.environmentVariableKey)
        }
        
        // Verify that running the `index` command prints the deprecation message.
        let command = try Docc.ProcessArchive.TransformForStaticHosting.parse([
            archiveInput.path
        ])
        
        try await command.run()
        XCTAssertEqual(logStorage.text.trimmingCharacters(in: .newlines), """
        warning: The `process-archive transform-for-static-hosting` subcommand is deprecated and scheduled to be removed after the Swift 6.6 release; the `convert` command produces static hosting compatible output by default [DeprecatedStaticHostingCommand]
        The `convert` command has produced output that is compatible with static hosting environments by default since the 5.10 release in 2022.

        Calling `process-archive transform-for-static-hosting` on documentation output that's already compatible with static hosting environments is unnecessary. It is also a destructive operation that loses information about custom headers and footers and per-page content for accessing the documentation without JavaScript.

        If your documentation output isn't compatible with static hosting environments, don't pass the `--no-transform-for-static-hosting` flag to the `convert` command.
        """)
    }
}
