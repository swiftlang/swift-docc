/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import ArgumentParser
import Foundation

extension Docc {
    /// Indexes a documentation bundle.
    public struct Index: ParsableCommand {

        public init() {}

        // MARK: - Configuration

        public static var configuration = CommandConfiguration(
            abstract: "Create an index for the documentation from compiled data.")

        // MARK: - Command Line Options & Arguments

        /// The user-provided path to a `.doccarchive` documentation archive.
        @OptionGroup()
        public var documentationBundle: DocCArchiveOption

        /// The user-provided bundle name to use for the produced index.
        @Option(help: "The bundle name for the index.")
        public var bundleIdentifier: String

        /// A user-provided value that is true if additional index information should be outputted to the terminal.
        @Flag(help: "Print out the index information while the process runs.")
        public var verbose = false

        // MARK: - Computed Properties

        /// The path to the directory that all build output should be placed in.
        public var outputURL: URL {
            documentationBundle.urlOrFallback.appendingPathComponent("index", isDirectory: true)
        }

        // MARK: - Execution

        public mutating func run() throws {
            // Initialize an `IndexAction` from the current options in the `Index` command.
            var indexAction = try IndexAction(fromIndexCommand: self)

            // Perform the index and print any warnings or errors found
            try indexAction.performAndHandleResult()
        }
    }
}
