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
            abstract: "Write documentation extension files into the DocC Catalog with one that supports a static hosting environment.")
        
        // Note:
        // The order of the option groups in this file is reflected in the 'docc process-catalog emit-generated-curation --help' output.
        
        // MARK: Inputs and outputs
        
        @OptionGroup(title: "Inputs & outputs")
        var inputsAndOutputs: InputAndOutputOptions
        struct InputAndOutputOptions: ParsableArguments {
            @Argument(
                help: "Path to the DocC Catalog ('.docc') directory.",
                transform: URL.init(fileURLWithPath:))
            var documentationCatalog: URL?
            
            @Option(
                name: [.customLong("additional-symbol-graph-dir")],
                help: "Path to a directory of additional symbol graph files.",
                transform: URL.init(fileURLWithPath:)
            )
            var additionalSymbolGraphDirectory: URL?
            
            @Option(
                name: [.customLong("output-path")],
                help: ArgumentHelp(
                    "The location where docc writes the transformed catalog.",
                    discussion: "If no output-path is provided, docc will perform an in-place transformation of the provided DocC Catalog."
                ),
                transform: URL.init(fileURLWithPath:)
            )
            var outputURL: URL?
            
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
        }
        
        /// The path to an archive to be used by DocC.
        var documentationCatalog: URL? {
            get { inputsAndOutputs.documentationCatalog }
            set { inputsAndOutputs.documentationCatalog = newValue }
        }
        
        /// A user-provided path to a directory of additional symbol graph files that the convert action will process.
        var additionalSymbolGraphDirectory: URL? {
            get { inputsAndOutputs.additionalSymbolGraphDirectory }
            set { inputsAndOutputs.additionalSymbolGraphDirectory = newValue }
        }
        
        /// A user-provided location where the command will write the updated catalog output.
        var outputURL: URL? {
            get { inputsAndOutputs.outputURL }
            set { inputsAndOutputs.outputURL = newValue }
        }
        
        // MARK: Generation options
        
        @OptionGroup(title: "Generation options")
        var generationOptions: GenerationOptions
        struct GenerationOptions: ParsableArguments {
            @Option(
                name: .customLong("from-symbol"),
                help: ArgumentHelp(
                    "A link to a symbol to start generating documentation extension files from.",
                    discussion: "If no symbol-link is provided, docc will generate documentation extension files starting from the module.",
                    valueName: "symbol-link"
                )
            )
            var startingPointSymbolLink: String?
            
            @Option(
                name: .customLong("depth"),
                help: ArgumentHelp(
                    "A depth limit for which pages to generate documentation extension files for.",
                    discussion: """
                    If no depth is provided, docc will generate documentation extension files for all pages from the starting point.
                    If 0 is provided, docc will generate documentation extension files for only the starting page.
                    If a positive number is provided, docc will generate documentation extension files for the starting page and its descendants up to that depth limit (inclusive).
                    """,
                    valueName: "limit"
                )
            )
            var depthLimit: Int?
            
            mutating func validate() throws {
                if let limit = depthLimit {
                    if limit < 0 {
                        self.depthLimit = nil
                    }
                }
                if let symbolLink = startingPointSymbolLink {
                    // The only validation we can do of the symbol link at this point is to remove any wrapping double backticks.
                    if symbolLink.hasPrefix("``"), symbolLink.hasSuffix("``") {
                        self.startingPointSymbolLink = String(symbolLink.dropFirst(2).dropLast(2))
                    }
                }
            }
        }
        
        /// A depth limit for which pages to generate documentation extension files for.
        var depthLimit: Int? {
            get { generationOptions.depthLimit }
            set { generationOptions.depthLimit = newValue }
        }
        /// A link to a symbol to start generating documentation extension files from.
        var startingPointSymbolLink: String? {
            get { generationOptions.startingPointSymbolLink }
            set { generationOptions.startingPointSymbolLink = newValue }
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

