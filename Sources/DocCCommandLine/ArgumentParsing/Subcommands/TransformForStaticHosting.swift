/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import ArgumentParser
import SwiftDocC

extension Docc.ProcessArchive {
    /// Emits a statically hostable website from a DocC Archive.
    struct TransformForStaticHosting: AsyncParsableCommand {
        
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

        func run() async throws {
            Self.warnAboutDeprecation()
            
            // We perform validation here instead of in  `validate()` to avoid having to force unwrap the `templateURL` here.
            guard let templateURL = templateOption.templateURL else {
                throw TemplateOption.missingHTMLTemplate(at: TemplateOption.defaultTemplateURL)
            }
            try TemplateOption.validateRequiredFile(fileName: HTMLTemplate.templateFileName.rawValue, inHTMLTemplateAt: templateURL)
            
            let action = try TransformForStaticHostingAction(
                documentationBundleURL: documentationArchive.urlOrFallback,
                outputURL: outputURL,
                hostingBasePath: hostingBasePath,
                htmlTemplateDirectory: templateURL
            )
            try await action.performAndHandleResult()
        }
        
        /// The file handle that the transform-for-static-hosting subcommand uses to write the warning about its deprecation.
        ///
        /// Provided as a static variable to allow for redirecting output in unit tests.
        static var _errorLogHandle: LogHandle = .standardError
        static var _diagnosticFormattingOptions: DiagnosticFormattingOptions = []
        
        private static func warnAboutDeprecation() {
            let diagnostic = Diagnostic(
                severity: .warning,
                identifier: "DeprecatedStaticHostingCommand",
                summary: "The `process-archive transform-for-static-hosting` subcommand is deprecated and scheduled to be removed after the Swift 6.6 release; the `convert` command produces static hosting compatible output by default",
                explanation: """
                The `convert` command has produced output that is compatible with static hosting environments by default since the 5.10 release in 2022.
                
                Calling `process-archive transform-for-static-hosting` on documentation output that's already compatible with static hosting environments is unnecessary. \
                It is also a destructive operation that loses information about custom headers and footers and per-page content for accessing the documentation without JavaScript.
                
                If your documentation output isn't compatible with static hosting environments, don't pass the `--no-transform-for-static-hosting` flag to the `convert` command.
                """
            )
            
            print(
                DiagnosticConsoleWriter.formattedDescription(for: diagnostic, options: _diagnosticFormattingOptions),
                to: &_errorLogHandle
            )
        }
    }
}

