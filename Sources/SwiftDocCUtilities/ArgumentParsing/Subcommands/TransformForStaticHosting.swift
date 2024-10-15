/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import ArgumentParser

extension Docc.ProcessArchive {
    /// Emits a statically hostable website from a DocC Archive.
    struct TransformForStaticHosting: ParsableCommand {
        
        static var configuration = CommandConfiguration(
            commandName: "transform-for-static-hosting",
            abstract: "Transform an existing DocC Archive into one that supports a static hosting environment.")
        
        @OptionGroup()
        var documentationArchive: DocCArchiveOption
        
        /// A user-provided location where the archive output will be put
        @Option(
            name: [.customLong("output-path")],
            help: ArgumentHelp(
                           "The location where docc writes the transformed archive.",
                           discussion: "If no output-path is provided, docc will perform an in-place transformation of the provided DocC Archive."
                       ),
            transform: URL.init(fileURLWithPath:)
        )
        var outputURL: URL?
        
        /// A user-provided relative path to be used in the archived output
        @Option(
            name: [.customLong("hosting-base-path")],
            help: ArgumentHelp(
                            "The base path your documentation website will be hosted at.",
                            discussion: "For example, to deploy your site to 'example.com/my_name/my_project/documentation' instead of 'example.com/documentation', pass '/my_name/my_project' as the base path.")
        )
        var hostingBasePath: String?
        
        /// The user-provided path to an HTML documentation template.
        @OptionGroup()
        var templateOption: TemplateOption

        mutating func validate() throws {

            if let templateURL = templateOption.templateURL {
                let indexTemplate = templateURL.appendingPathComponent(HTMLTemplate.templateFileName.rawValue)
                if !FileManager.default.fileExists(atPath: indexTemplate.path) {
                    throw TemplateOption.invalidHTMLTemplateError(
                        path: templateURL.path,
                        expectedFile: HTMLTemplate.templateFileName.rawValue
                    )
                }
            } else {
                throw TemplateOption.missingHTMLTemplateError(
                    path: templateOption.defaultTemplateURL.path
                )
            }
        }

        // MARK: - Execution
        
        mutating func run() throws {
            // Initialize an `TransformForStaticHostingAction` from the current options in the `TransformForStaticHostingAction` command.
            var action = try TransformForStaticHostingAction(fromCommand: self)
            
            // Perform the emit and print any warnings or errors found
            try action.performAndHandleResult()
        }
    }
}

