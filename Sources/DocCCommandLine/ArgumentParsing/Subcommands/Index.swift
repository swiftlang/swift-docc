/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

public import ArgumentParser
public import Foundation

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
            let indexAction = IndexAction(
                archiveURL: documentationArchive.urlOrFallback,
                outputURL: outputURL,
                bundleIdentifier: bundleIdentifier
            )
            try await indexAction.performAndHandleResult()
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
