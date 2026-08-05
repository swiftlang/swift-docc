/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

public import ArgumentParser
public import Foundation
import SwiftDocC

extension Docc {
    /// Indexes a documentation bundle.
    public struct Index: AsyncParsableCommand {
        public init() {}

        public static var configuration = CommandConfiguration(
            abstract: "Create an index for the documentation from compiled data.")

        /// The user-provided path to a `.doccarchive` documentation archive.
        @OptionGroup()
        public var documentationArchive: DocCArchiveOption

        /// The user-provided bundle name to use for the produced index.
        @Option(help: "The bundle name for the index.")
        public var bundleIdentifier: String

        /// A user-provided value that is true if additional index information should be outputted to the terminal.
        @Flag(help: "Print out the index information while the process runs.")
        public var verbose = false

        /// The path to the directory that all build output should be placed in.
        public var outputURL: URL {
            documentationArchive.urlOrFallback.appendingPathComponent("index", isDirectory: true)
        }

        public func run() async throws {
            Self.warnAboutDeprecation()
            
            let indexAction = IndexAction(
                archiveURL: documentationArchive.urlOrFallback,
                outputURL: outputURL,
                bundleIdentifier: bundleIdentifier
            )
            try await indexAction.performAndHandleResult()
        }
        
        /// The file handle that the index command uses to write the warning about its deprecation.
        ///
        /// Provided as a static variable to allow for redirecting output in unit tests.
        static var _errorLogHandle: LogHandle = .standardError
        static var _diagnosticFormattingOptions: DiagnosticFormattingOptions = []
        
        private static func warnAboutDeprecation() {
            let diagnostic = Diagnostic(
                severity: .warning,
                identifier: "DeprecatedIndexCommand",
                summary: "The `index` command is deprecated and scheduled to be removed after the Swift 6.6 release; pass the `--emit-lmdb-index` flag to the `convert` command instead",
                explanation: """
                The `convert` command always creates a JSON representation of the navigation hierarchy for the on-page sidebar.
                If you need an LMDB database representation of the same navigation hierarchy, \
                pass the `--emit-lmdb-index` flag to the `convert` command _instead_ of running the `index` command on the output of the `convert` command.
                
                If you're building documentation using the Swift-DocC Plugin (`swift package generate-documentation`) it passes the `--emit-lmdb-index` flag to Swift-DocC by default, \
                and requires the `--disable-indexing`/`--no-indexing` flag to opt out of that behavior. \
                If you need the LMDB database representation of the same navigation hierarchy in the documentation output, \
                don't pass the `--disable-indexing`/`--no-indexing` flag to `swift package generate-documentation`.
                """
            )
            
            print(
                DiagnosticConsoleWriter.formattedDescription(for: diagnostic, options: _diagnosticFormattingOptions),
                to: &_errorLogHandle
            )
        }
    }
    
    // This command wraps the Index command so that we can still support it as a top-level command without listing it in the help
    // text (but still list the Index command as a subcommand of the ProcessArchive command).
    struct _Index: AsyncParsableCommand {
        init() {}

        static var configuration = CommandConfiguration(
            commandName: "index",
            abstract: "Create an index for the documentation from compiled data.",
            shouldDisplay: false
        )

        @OptionGroup
        var command: Index

        public func run() async throws {
            try await command.run()
        }
    }
}
