/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2023-2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import ArgumentParser

extension Docc.ProcessCatalog {
    /// Emits documentation extension files that reflect the auto-generated curation.
    struct EmitGeneratedCuration: AsyncParsableCommand {
        
        static var configuration = CommandConfiguration(
            commandName: "emit-generated-curation",
            abstract: "Write documentation extension files with markdown representations of DocC's automatic curation.",
            discussion: """
            Pass the same '<catalog-path>' and '--additional-symbol-graph-dir <symbol-graph-dir>' as you would for `docc convert` to emit documentation extension files for your project.
            
            If you're getting started with arranging your symbols into topic groups you can pass '--depth 0' to only write topic sections for top-level symbols to a documentation extension file for your module.
            
            If you want to arrange a specific sub-hierarchy of your project into topic groups you can pass '--from-symbol <symbol-link>' to only write documentation extension files for that symbol and its descendants. \
            This can be combined with '--depth <limit>' to control how far to descend from the specified symbol.
            
            For more information on arranging symbols into topic groups, see https://www.swift.org/documentation/docc/adding-structure-to-your-documentation-pages.
            """)
        
        // Note:
        // The order of the option groups and their arguments is reflected in the 'docc process-catalog emit-generated-curation --help' output.
        
        // MARK: Inputs and outputs
        
        @OptionGroup(title: "Inputs & outputs")
        var inputsAndOutputs: InputAndOutputOptions
        struct InputAndOutputOptions: ParsableArguments {
            /// The path to an archive to be used by DocC.
            @Argument(
                help: ArgumentHelp(
                    "Path to the documentation catalog ('.docc') directory.",
                    valueName: "catalog-path"
                ),
                transform: URL.init(fileURLWithPath:))
            var documentationCatalog: URL?
            
            /// A user-provided path to a directory of additional symbol graph files that the convert action will process.
            @Option(
                name: [.customLong("additional-symbol-graph-dir")],
                help: ArgumentHelp(
                    "Path to a directory of additional symbol graph files.",
                    valueName: "symbol-graph-dir"
                ),
                transform: URL.init(fileURLWithPath:)
            )
            var additionalSymbolGraphDirectory: URL?
            
            /// A user-provided location where the command will write the updated catalog output.
            @Option(
                name: [.customLong("output-path")],
                help: ArgumentHelp(
                    "The location where docc writes the transformed catalog.",
                    discussion: "If no output-path is provided, docc will perform an in-place transformation of the provided documentation catalog."
                ),
                transform: URL.init(fileURLWithPath:)
            )
            var outputURL: URL?
            
            mutating func validate() throws {
                if let documentationCatalog {
                    guard documentationCatalog.pathExtension == "docc" else {
                        throw ValidationError("""
                        Missing documentation catalog directory configuration.
                        The directory at '\(documentationCatalog.path)' doesn't have a '.docc' extension.
                        """)
                    }
                    guard FileManager.default.fileExists(atPath: documentationCatalog.path) else {
                        throw ValidationError("""
                        Missing documentation catalog directory configuration.
                        The directory at '\(documentationCatalog.path)' does not exist.
                        """)
                    }
                }
            }
        }
        
        // MARK: Generation options
        
        @OptionGroup(title: "Generation options")
        var generationOptions: GenerationOptions
        struct GenerationOptions: ParsableArguments {
            /// A link to a symbol to start generating documentation extension files from.
            @Option(
                name: .customLong("from-symbol"),
                help: ArgumentHelp(
                    "A link to a symbol to start generating documentation extension files from.",
                    discussion: "If no symbol-link is provided, docc will generate documentation extension files starting from the module.",
                    valueName: "symbol-link"
                )
            )
            var startingPointSymbolLink: String?
            
            /// A depth limit for which pages to generate documentation extension files for.
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
        
        func run() async throws {
            let action = try EmitGeneratedCurationAction(
                documentationCatalog: inputsAndOutputs.documentationCatalog,
                additionalSymbolGraphDirectory: inputsAndOutputs.additionalSymbolGraphDirectory,
                outputURL: inputsAndOutputs.outputURL,
                depthLimit: generationOptions.depthLimit,
                startingPointSymbolLink: generationOptions.startingPointSymbolLink
            )
            try await action.performAndHandleResult()
        }
    }
}

