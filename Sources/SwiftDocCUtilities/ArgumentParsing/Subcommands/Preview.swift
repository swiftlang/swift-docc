/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

#if canImport(NIOHTTP1)
import ArgumentParser
import Foundation

extension Docc {
    /// Runs the ``Convert`` command and then sets up a web server that can be used to preview that documentation content.
    public struct Preview: ParsableCommand {

        public init() {}

        // MARK: - Configuration

        public static var configuration = CommandConfiguration(
            abstract: "Convert documentation inputs and preview the documentation output.",
            usage: """
            docc preview [<catalog-path>] [--host <host-name>] [--port <port-number>] [--additional-symbol-graph-dir <symbol-graph-dir>]
            docc preview [<catalog-path>] [--host <host-name>] [--port <port-number>] [--additional-symbol-graph-dir <symbol-graph-dir>] [--output-dir <output-dir>]
            docc preview [<catalog-path>] [--host <host-name>] [--port <port-number>] [--additional-symbol-graph-dir <symbol-graph-dir>] [--output-dir <output-dir>] [<availability-options>] [<diagnostic-options>] [<source-repository-options>] [<hosting-options>] [<info-plist-fallbacks>] [<feature-flags>] [<other-options>]
            """,
            discussion: """
            The 'preview' command extends the 'convert' command by running a preview server and monitoring the documentation input for modifications to rebuild the documentation.
            """
        )

        // MARK: - Command Line Options & Arguments
        
        /// The options used for configuring the preview server.
        @OptionGroup(title: "Preview options")
        public var previewOptions: PreviewOptions

        // MARK: - Property Validation
        
        public mutating func validate() throws {
            // The default template wasn't validated by the Convert command.
            // If a template was configured as an environmental variable, that would have already been validated in TemplateOption.
            if previewOptions.convertCommand.templateOption.templateURL == nil {
                throw TemplateOption.missingHTMLTemplateError(
                    path: previewOptions.convertCommand.templateOption.defaultTemplateURL.path
                )
            }
        }

        // MARK: - Execution

        public mutating func run() throws {
            // Initialize a `PreviewAction` from the current options in the `Preview` command.
            var previewAction = try PreviewAction(fromPreviewOptions: previewOptions)

            // Perform the preview and print any warnings or errors found
            try previewAction.performAndHandleResult()
        }
    }
}
#endif
