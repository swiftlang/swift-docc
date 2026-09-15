/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

public import ArgumentParser
public import SwiftDocC
import Foundation

extension Docc {
    /// Merge a list of documentation archives into a combined archive.
    public struct Merge: AsyncParsableCommand {
        public init() {}
        
        public static var configuration = CommandConfiguration(
            abstract: "Merge a list of documentation archives into a combined archive.",
            usage: "docc merge <archive-path> ... [<synthesized-landing-page-options>] [--output-path <output-path>]"
        )
        
        private static let archivePathExtension = "doccarchive"
        private static let catalogPathExtension = "docc"
        
        // The file manager used to validate the input and output directories.
        //
        // Provided as a static variable to allow for using a different file manager in unit tests.
        static var _fileManager: any FileManagerProtocol = FileManager.default
        
        // Note:
        // The order of the option groups in this file is reflected in the 'docc merge --help' output.
        
        // MARK: - Inputs & outputs
        
        @OptionGroup(title: "Inputs & outputs")
        var inputsAndOutputs: InputAndOutputOptions
        struct InputAndOutputOptions: ParsableArguments {
            @Argument(
                help: ArgumentHelp(
                    "A list of paths to '.\(Merge.archivePathExtension)' documentation archive directories to combine into a combined archive.",
                    valueName: "archive-path"),
                transform: URL.init(fileURLWithPath:))
            var archives: [URL]
            
            @Option(
                help: ArgumentHelp(
                    "Path to a '.\(Merge.catalogPathExtension)' documentation catalog directory with content for the landing page.",
                    discussion: """
                    The documentation compiler uses this catalog content to create a landing page, and optionally additional top-level articles, for the combined archive.
                    Because the documentation compiler won't synthesize any landing page content, also passing a `--synthesized-landing-page-name` value has no effect. 
                    """,
                    valueName: "catalog-path",
                    visibility: .hidden),
                transform: URL.init(fileURLWithPath:))
            var landingPageCatalog: URL?
            
            @Option(
                name: [.customLong("output-path"), .customShort("o")],
                help: "The location where the documentation compiler writes the combined documentation archive.",
                transform: URL.init(fileURLWithPath:)
            )
            var providedOutputURL: URL?
            
            var outputURL: URL!
            
            mutating func validate() throws {
                let fileManager = Docc.Merge._fileManager
                
                guard !archives.isEmpty else {
                    throw ValidationError("Require at least one documentation archive to merge.")
                }
                // Validate that the input archives exists and have the expected path extension
                for archive in archives {
                    switch archive.pathExtension.lowercased() {
                    case Merge.archivePathExtension:
                        break // The expected path extension
                    case "":
                        throw ValidationError("Missing '\(Merge.archivePathExtension)' path extension for archive '\(archive.path)'")
                    default:
                        throw ValidationError("Path extension '\(archive.pathExtension)' is not '\(Merge.archivePathExtension)' for archive '\(archive.path)'")
                    }
                    guard fileManager.directoryExists(atPath: archive.path) else {
                        throw ValidationError("No directory exists at '\(archive.path)'")
                    }
                }
                
                // Validate that the input catalog exist and have the expected path extension
                if let catalog = landingPageCatalog {
                    switch catalog.pathExtension.lowercased() {
                    case Merge.catalogPathExtension:
                        break // The expected path extension
                    case "":
                        throw ValidationError("Missing '\(Merge.catalogPathExtension)' path extension for catalog '\(catalog.path)'")
                    default:
                        throw ValidationError("Path extension '\(catalog.pathExtension)' is not '\(Merge.catalogPathExtension)' for catalog '\(catalog.path)'")
                    }
                    guard fileManager.directoryExists(atPath: catalog.path) else {
                        throw ValidationError("No directory exists at '\(catalog.path)'")
                    }
                    
                    print("note: Using a custom landing page catalog isn't supported yet. Will synthesize a default landing page instead.")
                }
                
                // Validate that the directory above the output location exist so that the merge command doesn't need to create intermediate directories.
                if let outputParent = providedOutputURL?.deletingLastPathComponent() {
                    // Verify that the intermediate directories exist for the output location.
                    guard fileManager.directoryExists(atPath: outputParent.path) else {
                        throw ValidationError("Missing intermediate directory at '\(outputParent.path)' for output path")
                    }
                }
                outputURL = providedOutputURL ?? URL(fileURLWithPath: fileManager.currentDirectoryPath).appendingPathComponent("Combined.\(Merge.archivePathExtension)", isDirectory: true)
            }
        }
        
        @OptionGroup(title: "Synthesized landing page options")
        var synthesizedLandingPageOptions: SynthesizedLandingPageOptions
        struct SynthesizedLandingPageOptions: ParsableArguments {
            @Option(
                name: .customLong("synthesized-landing-page-name"),
                help: ArgumentHelp(
                    "A display name for the combined archive's synthesized landing page.",
                    valueName: "name"
                )
            )
            var name: String = "Documentation"
            
            @Option(
                name: .customLong("synthesized-landing-page-kind"),
                help: ArgumentHelp(
                    "A page kind that displays as a title heading for the combined archive's synthesized landing page.",
                    valueName: "kind"
                )
            )
            var kind: String = "Package"
            
            @Option(
                name: .customLong("synthesized-landing-page-topics-style"),
                help: ArgumentHelp(
                    "The visual style of the topic section for the combined archive's synthesized landing page.",
                    valueName: "style"
                )
            )
            var topicStyle: TopicsVisualStyle.Style = .detailedGrid
        }
        
        public func run() async throws {
            // Initialize a `ConvertAction` from the current options in the `Convert` command.
            let convertAction = MergeAction(
                archives: inputsAndOutputs.archives,
                landingPageInfo: .synthesize(
                    .init(
                        name: synthesizedLandingPageOptions.name,
                        kind: synthesizedLandingPageOptions.kind,
                        style: synthesizedLandingPageOptions.topicStyle
                    )
                ),
                outputURL: inputsAndOutputs.outputURL,
                fileManager: Self._fileManager
            )
            
            // Perform the conversion and print any warnings or errors found
            try await convertAction.performAndHandleResult()
        }
    }
}

extension TopicsVisualStyle.Style: ExpressibleByArgument {}
