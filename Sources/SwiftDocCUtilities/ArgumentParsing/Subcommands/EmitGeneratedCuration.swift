/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2023 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import ArgumentParser

extension Docc.ProcessCatalog {
    /// Emits documentation extension files that reflect the auto-generated curation.
    struct EmitGeneratedCuration: ParsableCommand {
        
        static var configuration = CommandConfiguration(
            commandName: "emit-generated-curation",
            abstract: "Write documentation extension files into the DocC Catalog with  one that supports a static hosting environment.")
        
        /// The path to an archive to be used by DocC.
        @Argument(
            help: "Path to the DocC Catalog ('.docc') directory.",
            transform: URL.init(fileURLWithPath:))
        public var documentationCatalog: URL?
        
        /// A user-provided path to a directory of additional symbol graph files that the convert action will process.
        @Option(
            name: [.customLong("additional-symbol-graph-dir")],
            help: "Path to a directory of additional symbol graph files.",
            transform: URL.init(fileURLWithPath:)
        )
        public var additionalSymbolGraphDirectory: URL?
        
        /// A user-provided location where the command will write the updated catalog output.
        @Option(
            name: [.customLong("output-path")],
            help: ArgumentHelp(
                           "The location where docc writes the transformed catalog.",
                           discussion: "If no output-path is provided, docc will perform an in-place transformation of the provided DocC Catalog."
                       ),
            transform: URL.init(fileURLWithPath:)
        )
        var outputURL: URL?
        
        ///
        @Flag(
            help: ArgumentHelp(""))
        var shortenExistingLinks: Bool = false

        mutating func validate() throws {
            if let documentationCatalog = documentationCatalog {
                guard documentationCatalog.pathExtension == "docc" else {
                    throw ValidationError("""
                    Missing DocC catalog directory configuration.
                    The directory at '\(documentationCatalog.path)' doesn't have a '.docc' extension.
                    """)
                }
                guard FileManager.default.fileExists(atPath: documentationCatalog.path) else {
                    throw ValidationError("""
                    Missing DocC catalog directory configuration.
                    The directory at '\(documentationCatalog.path)' does not exist.
                    """)
                }
            }
        }

        // MARK: - Execution
        
        mutating func run() throws {
            // Initialize an `EmitGeneratedCurationAction` from the current options in the `EmitGeneratedCuration` command.
            var action = try EmitGeneratedCurationAction(fromCommand: self)

            // Perform the emit and print any warnings or errors found
            try action.performAndHandleResult()
        }
    }
}

