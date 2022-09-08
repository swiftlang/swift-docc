/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import ArgumentParser
import SwiftDocC
import Foundation

extension Docc {
    /// Converts a documentation bundle.
    public struct Convert: ParsableCommand {

        public init() {}

        // MARK: - Constants

        /// The name of the directory docc will write its build artifacts to.
        private static let buildDirectory = ".docc-build"

        // MARK: - Configuration

        public static var configuration = CommandConfiguration(
            abstract: "Converts documentation from a source bundle.")

        // MARK: - Command Line Options & Arguments

        /// The user-provided path to a `.docc` documentation bundle.
        @OptionGroup()
        public var documentationBundle: DocumentationBundleOption

        /// User-provided platform name/version pairs.
        ///
        /// Used to set the current release version of a platform. Contains an array of strings in the following format:
        /// ```
        /// name={platform name},version={semantic version}
        /// ```
        ///
        /// # Example
        /// ```
        /// "name=macOS,version=10.1.2"
        /// ```
        @Option(
            name: .customLong("platform"),
            parsing: ArrayParsingStrategy.singleValue,
            help: ArgumentHelp(
                """
                Set the current release version of a platform.
                """,
                discussion: """
                    Use the following format: "name={platform name},version={semantic version}".
                    """))
        public var platforms: [String] = []

        /// The user-provided path to an HTML documentation template.
        @OptionGroup()
        public var templateOption: TemplateOption

        /// The user-provided path to an executable that can be used to resolve links.
        ///
        /// This is an optional value and an internal link resolver is used by default.
        @OptionGroup()
        public var outOfProcessLinkResolverOption: OutOfProcessLinkResolverOption

        /// A user-provided value that is true if additional analyzer style warnings should be outputted to the terminal.
        ///
        /// Defaults to false.
        @Flag(
            help: """
                Outputs additional analyzer style warnings in addition to standard warnings/errors.
                """)
        public var analyze = false

        /// A user-provided value that is true if additional metadata files should be produced.
        ///
        /// Defaults to false.
        @Flag(help: "Writes additional metadata files to the output directory.")
        public var emitDigest = false

        /// A user-provided value that is true if the LMDB representation of the
        /// navigator index should be produced.
        ///
        /// Defaults to false.
        @Flag(
            help: ArgumentHelp(
                "Writes an LMDB representation of the navigator index to the output directory.",
                discussion: "A JSON representation of the navigator index is emitted by default."
            )
        )
        public var emitLMDBIndex = false
        
        /// This value is provided for backwards compatibility with existing clients but
        /// will be removed soon. Renamed to '--emit-lmdb-index'.
        @Flag(help: .hidden)
        public var index = false
        
        /// A user-provided value that is true if fix-its should be written to output.
        ///
        /// Defaults to false.
        @Flag(inversion: .prefixedNo, help: "Outputs fixits for common issues")
        public var emitFixits = false

        /// A user-provided value that is true if the user wants to opt in to Experimental documentation coverage generation.
        ///
        /// Defaults to none.
        @OptionGroup()
        public var experimentalDocumentationCoverageOptions: DocumentationCoverageOptionsArgument

        /// A user-provided value that is true if the user wants to provide a custom template for rendered output.
        ///
        /// Defaults to false
        @Flag(help: "Allows for custom templates, like `header.html`.")
        public var experimentalEnableCustomTemplates = false
        
        /// A user-provided value that is true if the user enables experimental Objective-C language support.
        ///
        /// > Important: This flag is deprecated now that the feature is enabled by default, and will be removed in a future release.
        @Flag(help: .hidden)
        public var enableExperimentalObjectiveCSupport = false
        
        /// A user-provided value that is true if the user enables experimental support for emitting
        /// a JSON index.
        ///
        /// This property exists for backwards compatibility with existing clients but is
        /// deprecated and will be removed soon.
        @Flag(help: .hidden)
        @available(*, deprecated, message: "Render Index JSON is now emitted by default.")
        public var enableExperimentalJSONIndex = false

        /// A user-provided value that is true if experimental documentation inheritance is to be enabled.
        ///
        /// Defaults to false.
        @Flag(help: "Inherit documentation for inherited symbols")
        public var enableInheritedDocs = false
        
        
        @Flag(help: "Treat warnings as errors")
        public var warningsAsErrors = false
        
        /// Arguments for specifying information about the source code repository that hosts the documented project's code.
        @OptionGroup()
        public var sourceRepositoryArguments: SourceRepositoryArguments

        // MARK: - Info.plist fallbacks
        
        /// A user-provided fallback display name for the documentation bundle.
        ///
        /// If the documentation bundle's Info.plist file contains a bundle display name, the documentation bundle ignores this fallback name.
        @Option(
            name: [.customLong("fallback-display-name"), .customLong("display-name")], // Remove spelling without "fallback" prefix when other tools no longer use it. (rdar://72449411)
            help: "A fallback display name if no value is provided in the documentation bundle's Info.plist file."
        )
        public var fallbackBundleDisplayName: String?
        
        /// A user-provided fallback display name for the documentation bundle.
        ///
        /// If the documentation bundle's Info.plist file contains a bundle identifier, the documentation bundle ignores this fallback identifier.
        @Option(
            name: [.customLong("fallback-bundle-identifier"), .customLong("bundle-identifier")], // Remove spelling without "fallback" prefix when other tools no longer use it. (rdar://72449411)
            help: "A fallback bundle identifier if no value is provided in the documentation bundle's Info.plist file."
        )
        public var fallbackBundleIdentifier: String?
        
        /// A user-provided fallback version for the documentation bundle.
        ///
        /// If the documentation bundle's Info.plist file contains a bundle version, the documentation bundle ignores this fallback version.
        @Option(
            name: [.customLong("fallback-bundle-version"), .customLong("bundle-version")], // Remove spelling without "fallback" prefix when other tools no longer use it. (rdar://72449411)
            help: "A fallback bundle version if no value is provided in the documentation bundle's Info.plist file."
        )
        public var fallbackBundleVersion: String?
        
        /// A user-provided default language for code listings.
        ///
        /// If the documentation bundle's Info.plist file contains a default code listing language, the documentation bundle ignores this fallback language.
        @Option(
            name: [.customLong("default-code-listing-language")],
            help: "A fallback default language for code listings if no value is provided in the documentation bundle's Info.plist file."
        )
        public var defaultCodeListingLanguage: String?

        @Option(
            help: """
                A fallback default module kind if no value is provided \
                in the documentation bundle's Info.plist file.
                """
        )
        public var fallbackDefaultModuleKind: String?
        
        /// A user-provided location where the convert action writes the built documentation.
        @Option(
            name: [.customLong("output-path"), .customLong("output-dir")], // Remove "output-dir" when other tools no longer pass that option. (rdar://72449411)
            help: "The location where the documentation compiler writes the built documentation.",
            transform: URL.init(fileURLWithPath:)
        )
        var providedOutputURL: URL?
        
        // MARK: - Symbol graph files
        
        /// A user-provided path to a directory of additional symbol graph files that the convert action will process.
        @Option(
            name: [.customLong("additional-symbol-graph-dir")],
            help: "A path to a directory of additional symbol graph files.",
            transform: URL.init(fileURLWithPath:)
        )
        public var additionalSymbolGraphDirectory: URL?
        
        /// A user-provided list o path to additional symbol graph files that the convert action will process.
        @Option(
            name: [.customLong("additional-symbol-graph-files")],
            parsing: ArrayParsingStrategy.upToNextOption,
            help: .hidden,
            transform: URL.init(fileURLWithPath:)
        )
        public var additionalSymbolGraphFiles: [URL] = [] // Remove when other tools no longer use it. (rdar://72449411)

        @Option(help: ArgumentHelp("Filters diagnostics above this level from output", discussion:
        """
        This filter level is inclusive. If a level of `information` is specified, diagnostics with a severity up to and including `information` will be printed.
        This option is ignored if `--analyze` is passed.
        Must be one of "error", "warning", "information", or "hint"
        """))
        public var diagnosticLevel: String?
        
        // MARK: - Computed Properties

        /// The path to the directory that all build output should be placed in.
        public var outputURL: URL {
            // If an output location was passed as an argument, use it as-is.
            if let providedOutputURL = providedOutputURL {
                return providedOutputURL
            }
            
            var outputURL = documentationBundle.urlOrFallback

            // Check that the output is written in a build directory sub-folder
            if outputURL.lastPathComponent != Convert.buildDirectory {
                outputURL.appendPathComponent(Convert.buildDirectory)
            }

            return outputURL
        }
        
        /// A Boolean value that is true if the DocC archive produced by this conversion
        /// will support static hosting environments.
        ///
        /// This value defaults to true but can be explicitly disabled with the
        /// `--no-transform-for-static-hosting` flag.
        @Flag(
            inversion: .prefixedNo,
            exclusivity: .exclusive,
            help: "Produce a DocC archive that supports static hosting environments."
        )
        public var transformForStaticHosting = true

        /// A user-provided relative path to be used in the archived output
        @Option(
            name: [.customLong("hosting-base-path")],
            help: ArgumentHelp(
                "The base path your documentation website will be hosted at.",
                discussion: "For example, to deploy your site to 'example.com/my_name/my_project/documentation' instead of 'example.com/documentation', pass '/my_name/my_project' as the base path.")
        )
        var hostingBasePath: String?
        
        /// The file handle that should be used for emitting warnings during argument validation.
        ///
        /// Provided as a static variable to allow for redirecting output in unit tests.
        static var _errorLogHandle: LogHandle = .standardError

        // MARK: - Property Validation

        public mutating func validate() throws {
            if let level = diagnosticLevel, DiagnosticSeverity(level) == nil {
                print("""
                note: "\(level)" is not a valid diagnostic level.
                      Use one of "error", "warning", "information", or "hint"
                """)
            }
            
            if let outputParent = providedOutputURL?.deletingLastPathComponent() {
                var isDirectory: ObjCBool = false
                guard FileManager.default.fileExists(atPath: outputParent.path, isDirectory: &isDirectory), isDirectory.boolValue else {
                    throw ValidationError("No directory exists at '\(outputParent.path)'.")
                }
            }

            if transformForStaticHosting  {
                if let templateURL = templateOption.templateURL {
                    let neededFileName: String

                    if hostingBasePath != nil {
                        neededFileName = HTMLTemplate.templateFileName.rawValue
                    }else {
                        neededFileName = HTMLTemplate.indexFileName.rawValue
                    }

                    let indexTemplate = templateURL.appendingPathComponent(neededFileName, isDirectory: false)
                    if !FileManager.default.fileExists(atPath: indexTemplate.path) {
                        throw TemplateOption.invalidHTMLTemplateError(
                            path: templateURL.path,
                            expectedFile: neededFileName
                        )
                    }

                } else {
                    let invalidOrMissingTemplateDiagnostic = Diagnostic(
                        severity: .warning,
                        identifier: "org.swift.docc.MissingHTMLTemplate",
                        summary: "Invalid or missing HTML template directory",
                        explanation: """
                            Invalid or missing HTML template directory, relative to the docc \
                            executable, at: '\(templateOption.defaultTemplateURL.path)'.
                            Set the '\(TemplateOption.environmentVariableKey)' environment variable \
                            to use a custom HTML template.
                            
                            Conversion will continue, but the produced DocC archive will not be \
                            compatible with static hosting environments.
                            
                            Pass the '--no-transform-for-static-hosting' flag to silence this warning.
                            """
                    )
                    
                    print(
                        invalidOrMissingTemplateDiagnostic.localizedDescription,
                        to: &Self._errorLogHandle
                    )
                    
                    transformForStaticHosting = false
                }
            }

        }

        // MARK: - Execution

        public mutating func run() throws {
            // Initialize a `ConvertAction` from the current options in the `Convert` command.
            var convertAction = try ConvertAction(fromConvertCommand: self)

            // Perform the conversion and print any warnings or errors found
            try convertAction.performAndHandleResult()
        }
    }
}
