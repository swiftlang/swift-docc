/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

#if canImport(NIOHTTP1)
public import ArgumentParser
import Foundation

extension Docc {
    /// Runs the ``Convert`` command and then sets up a web server that can be used to preview that documentation content.
    public struct Preview: AsyncParsableCommand {
        public init() {}

        public static var configuration = CommandConfiguration(
            abstract: "Convert documentation inputs and preview the documentation output.",
            usage: """
            docc preview [<catalog-path>] [--port <port-number>] [--additional-symbol-graph-dir <symbol-graph-dir>]
            docc preview [<catalog-path>] [--port <port-number>] [--additional-symbol-graph-dir <symbol-graph-dir>] [--output-dir <output-dir>]
            docc preview [<catalog-path>] [--port <port-number>] [--additional-symbol-graph-dir <symbol-graph-dir>] [--output-dir <output-dir>] [<availability-options>] [<diagnostic-options>] [<source-repository-options>] [<hosting-options>] [<info-plist-fallbacks>] [<feature-flags>] [<other-options>]
            """,
            discussion: """
            The 'preview' command extends the 'convert' command by running a preview server and monitoring the documentation input for modifications to rebuild the documentation.
            """
        )
        
        /// The options used for configuring the preview server.
        @OptionGroup(title: "Preview options")
        public var previewOptions: PreviewOptions
        
        public mutating func validate() throws {
            // The default template wasn't validated by the Convert command.
            // If a template was configured as an environmental variable, that would have already been validated in TemplateOption.
            if previewOptions.convertCommand.templateOption.templateURL == nil {
                throw TemplateOption.missingHTMLTemplate(at: TemplateOption.defaultTemplateURL)
            }
        }

        public func run() async throws {
            let previewAction = try PreviewAction(
                port: previewOptions.port,
                createConvertAction: {
                    try ConvertAction(fromConvertCommand: previewOptions.convertCommand)
                }
            )
            try await previewAction.performAndHandleResult()
        }
    }
}
#endif
