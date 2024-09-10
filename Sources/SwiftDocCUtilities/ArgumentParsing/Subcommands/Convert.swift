/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import ArgumentParser
import SwiftDocC
import Foundation

extension Docc {
    /// Converts documentation markup, assets, and symbol information into a documentation archive.
    public struct Convert: ParsableCommand {
        public init() {}

        /// The name of the directory docc will write its build artifacts to.
        private static let buildDirectory = ".docc-build"

        /// The file handle that should be used for emitting warnings during argument validation.
        ///
        /// Provided as a static variable to allow for redirecting output in unit tests.
        static var _errorLogHandle: LogHandle = .standardError
        
        static var _diagnosticFormattingOptions: DiagnosticFormattingOptions = []
        
        public static var configuration = CommandConfiguration(
            abstract: "Convert documentation markup, assets, and symbol information into a documentation archive.",
            usage: """
            docc convert [<catalog-path>] [--additional-symbol-graph-dir <symbol-graph-dir>]
            docc convert [<catalog-path>] [--additional-symbol-graph-dir <symbol-graph-dir>] [--output-dir <output-dir>]
            docc convert [<catalog-path>] [--additional-symbol-graph-dir <symbol-graph-dir>] [--output-dir <output-dir>] [<availability-options>] [<diagnostic-options>] [<source-repository-options>] [<hosting-options>] [<info-plist-fallbacks>] [<feature-flags>] [<other-options>]
            """,
            discussion: """
            When building documentation for source code, the 'convert' command is commonly invoked by other tools as part of a build workflow. Such build workflows can perform tasks to extract symbol graph information and may infer values for 'docc' flags and options from other build configuration.
            
            When building documentation for a catalog that only contain articles or tutorial content, interacting with the 'docc convert' command directly can be a good alternative to using DocC via a build workflow.
            """
        )
        
        // Note:
        // The order of the option groups in this file is reflected in the 'docc convert --help' output.
        //
        // The flags and options in this file is defined as internal with public accessors. This allows us to reorganize flags and options
        // in the `docc` command line interface without source breaking changes.

        // MARK: - Inputs & outputs

        @OptionGroup(title: "Inputs & outputs")
        var inputsAndOutputs: InputAndOutputOptions
        struct InputAndOutputOptions: ParsableArguments {
            @OptionGroup()
            var documentationCatalog: DocumentationCatalogOption
            
            @Option(
                name: [.customLong("additional-symbol-graph-dir")],
                help: "A path to a directory of additional symbol graph files.",
                transform: URL.init(fileURLWithPath:)
            )
            var additionalSymbolGraphDirectory: URL?
            
            @Option(
                name: [.customLong("additional-symbol-graph-files")],
                parsing: ArrayParsingStrategy.upToNextOption,
                help: .hidden,
                transform: URL.init(fileURLWithPath:)
            )
            @available(*, deprecated, renamed: "additionalSymbolGraphDirectory", message: "Use 'additionalSymbolGraphDirectory' instead. This deprecated API will be removed after 6.0 is released")
            var additionalSymbolGraphFiles: [URL] = [] // Remove when other tools no longer use it. (rdar://72449411)
            
            @Option(
                name: [.customLong("output-path"), .customLong("output-dir"), .customShort("o")], // Remove "output-dir" when other tools no longer pass that option. (rdar://72449411)
                help: "The location where the documentation compiler writes the built documentation.",
                transform: URL.init(fileURLWithPath:)
            )
            var providedOutputURL: URL?
            
            func validate() throws {
                warnAboutDeprecatedOptionIfNeeded("additional-symbol-graph-files", message: "Use '--additional-symbol-graph-dir' instead.")
                
                if let outputParent = providedOutputURL?.deletingLastPathComponent() {
                    // Verify that the intermediate directories exist for the output location.
                    var isDirectory: ObjCBool = false
                    guard FileManager.default.fileExists(atPath: outputParent.path, isDirectory: &isDirectory), isDirectory.boolValue else {
                        throw ValidationError("No directory exists at '\(outputParent.path)'.")
                    }
                }
            }
        }
        
        /// The user-provided path to a `.docc` documentation catalog.
        public var documentationCatalog: DocumentationCatalogOption {
            get { inputsAndOutputs.documentationCatalog }
            set { inputsAndOutputs.documentationCatalog = newValue }
        }
        @available(*, deprecated, renamed: "documentationCatalog", message: "Use 'documentationCatalog' instead. This deprecated API will be removed after 6.0 is released")
        public var documentationBundle: DocumentationBundleOption {
            get { inputsAndOutputs.documentationCatalog }
            set { inputsAndOutputs.documentationCatalog = newValue }
        }
        
        /// A user-provided path to a directory of additional symbol graph files that the convert action will process.
        public var additionalSymbolGraphDirectory: URL? {
            get { inputsAndOutputs.additionalSymbolGraphDirectory }
            set { inputsAndOutputs.additionalSymbolGraphDirectory = newValue }
        }
        
        @available(*, deprecated, renamed: "additionalSymbolGraphDirectory", message: "Use 'additionalSymbolGraphDirectory' instead. This deprecated API will be removed after 6.0 is released")
        public var additionalSymbolGraphFiles: [URL] { // Remove when other tools no longer use it. (rdar://72449411)
            get { inputsAndOutputs.additionalSymbolGraphFiles }
            set { inputsAndOutputs.additionalSymbolGraphFiles = newValue }
        }
        
        /// A user-provided location where the convert action writes the built documentation.
        public var providedOutputURL: URL? {
            get { inputsAndOutputs.providedOutputURL }
            set { inputsAndOutputs.providedOutputURL = newValue }
        }
        
        /// The path to the directory that all build output should be placed in.
        public var outputURL: URL {
            // If an output location was passed as an argument, use it as-is.
            if let providedOutputURL {
                return providedOutputURL
            }
            
            var outputURL = documentationCatalog.urlOrFallback
            
            // Check that the output is written in a build directory sub-folder
            if outputURL.lastPathComponent != Convert.buildDirectory {
                outputURL.appendPathComponent(Convert.buildDirectory)
            }
            
            return outputURL
        }
        
        // MARK: - Availability options
        
        @OptionGroup(title: "Availability options")
        var availabilityOptions: AvailabilityOptions
        struct AvailabilityOptions: ParsableArguments {
            @Option(
                name: .customLong("platform"),
                parsing: ArrayParsingStrategy.singleValue,
                help: ArgumentHelp("Specify information about the current release of a platform.", discussion: """
                Each platform's information is specified via separate "--platform" values using the following format: "name={platform name},version={semantic version}".
                Optionally, the platform information can include a 'beta={true|false}' component. If no beta information is provided, the platform is considered not in beta.
                If the platform is set to beta, any symbol introduced in a version equal to or greater than the specified semantic version will be marked as beta.
                """)
            )
            var platforms: [String] = []
        }

        /// User-provided platform name/version pairs.
        ///
        /// Used to set the current release version of a platform. Contains an array of strings in the following format:
        /// ```
        /// name={platform name},version={semantic version}
        /// ```
        ///
        /// Optionally, the platform name/version pair can include a `beta={true|false}` component. If no beta information is provided the platform is considered not in beta.
        ///
        /// # Example
        /// ```
        /// "name=macOS,version=10.1.2"
        /// "name=macOS,version=10.1.2,beta=true"
        /// ```
        public var platforms: [String] {
            get { availabilityOptions.platforms }
            set { availabilityOptions.platforms = newValue }
        }

        /// The user-provided path to an executable that can be used to resolve links.
        ///
        /// This is an optional value and an internal link resolver is used by default.
        @OptionGroup() // This is only configured via environmental variables, so it doesn't display in the help text.
        public var outOfProcessLinkResolverOption: OutOfProcessLinkResolverOption

        // MARK: - Source repository options
        
        /// Arguments for specifying information about the source code repository that hosts the documented project's code.
        @OptionGroup(title: "Source repository options")
        public var sourceRepositoryArguments: SourceRepositoryArguments
        
        // MARK: - Hosting options
        
        @OptionGroup(title: "Hosting options")
        var hostingOptions: HostingOptions
        struct HostingOptions: ParsableArguments {
            @Option(
                name: [.customLong("hosting-base-path")],
                help: ArgumentHelp("The base path your documentation website will be hosted at.", discussion: """
                For example, if you deploy your site to 'example.com/my_name/my_project/documentation' instead of 'example.com/documentation', pass '/my_name/my_project' as the base path.
                """)
            )
            var hostingBasePath: String?

            @Flag(
                inversion: .prefixedNo,
                exclusivity: .exclusive,
                help: "Produce a DocC archive that supports static hosting environments."
            )
            var transformForStaticHosting = true
        }
        
        /// A Boolean value that is true if the DocC archive produced by this conversion will support static hosting environments.
        ///
        /// This value defaults to true but can be explicitly disabled with the `--no-transform-for-static-hosting` flag.
        public var transformForStaticHosting: Bool {
            get { hostingOptions.transformForStaticHosting }
            set { hostingOptions.transformForStaticHosting = newValue }
        }
        
        /// A user-provided relative path to be used in the archived output
        var hostingBasePath: String? {
            hostingOptions.hostingBasePath
        }
        
        /// The user-provided path to an HTML documentation template.
        @OptionGroup()
        public var templateOption: TemplateOption
        
        // MARK: Diagnostic options
        
        @OptionGroup(title: "Diagnostic options")
        var diagnosticOptions: DiagnosticOptions
        struct DiagnosticOptions: ParsableArguments {
            @Flag(help: "Include 'note'/'information' level diagnostics in addition to warnings and errors.")
            var analyze = false
            
            @Option(
                name: [.customLong("diagnostics-file"), .customLong("diagnostics-output-path")],
                help: ArgumentHelp(
                    "The location where the documentation compiler writes the diagnostics file.",
                    discussion: "Specifying a diagnostic file path implies '--ide-console-output'."
                ),
                transform: URL.init(fileURLWithPath:)
            )
            var diagnosticsOutputPath: URL?
            
            @Option(
                name: [.customLong("diagnostic-filter"), .long],
                help: ArgumentHelp("Filter diagnostics with a lower severity than this level.", discussion:
                """
                This option is ignored if `--analyze` is passed.
                
                This filter level is inclusive. If a level of 'note' is specified, diagnostics with a severity up to and including 'note' will be printed.
                \(supportedDiagnosticLevelsMessage)
                """)
            )
            var diagnosticLevel: String?
            
            @Flag(
                name: [.customLong("ide-console-output"), .customLong("emit-fixits")],
                help: "Format output to the console intended for an IDE or other tool to parse.")
            var formatConsoleOutputForTools = false
            
            @Flag(help: "Treat warnings as errors")
            var warningsAsErrors = false

            func validate() throws {
                if analyze && diagnosticLevel != nil {
                    warnAboutDiagnostic(.init(
                        severity: .information,
                        identifier: "org.swift.docc.IgnoredDiagnosticsFilter",
                        summary: "'--diagnostic-filter' is ignored when '--analyze' is set."
                    ))
                }
        
                if let level = diagnosticLevel, DiagnosticSeverity(level) == nil {
                    warnAboutDiagnostic(.init(
                        severity: .information,
                        identifier: "org.swift.docc.UnknownDiagnosticLevel",
                        summary: """
                            "\(level)" is not a valid diagnostic severity.
                            \(Self.supportedDiagnosticLevelsMessage)
                            """
                    ))
                }
            }
        
            private static let supportedDiagnosticLevelsMessage = """
                The supported diagnostic filter levels are:
                 - error
                 - warning
                 - note, info, information
                 - hint, notice
                """
        }
        
        /// Treat warning as errors.
        public var warningsAsErrors: Bool {
            get { diagnosticOptions.warningsAsErrors }
            set { diagnosticOptions.warningsAsErrors = newValue }
        }

        /// A user-provided value that is true if output to the console should be formatted for an IDE or other tool to parse.
        public var formatConsoleOutputForTools: Bool {
            get { diagnosticOptions.formatConsoleOutputForTools }
            set { diagnosticOptions.formatConsoleOutputForTools = newValue }
        }
        
        /// A user-provided location where the convert action writes the diagnostics file.
        public var diagnosticsOutputPath: URL? {
            get { diagnosticOptions.diagnosticsOutputPath }
            set { diagnosticOptions.diagnosticsOutputPath = newValue }
        }
        
        /// The diagnostic severity level to filter
        public var diagnosticLevel: String? {
            get { diagnosticOptions.diagnosticLevel }
            set { diagnosticOptions.diagnosticLevel = newValue }
        }

        /// A user-provided value that is true if additional analyzer style warnings should be outputted to the terminal.
        ///
        /// Defaults to false.
        public var analyze: Bool {
            get { diagnosticOptions.analyze }
            set { diagnosticOptions.analyze = newValue }
        }

        // MARK: - Info.plist fallback options

        @OptionGroup(title: "Info.plist fallbacks")
        var infoPlistFallbacks: InfoPlistFallbackOptions
        struct InfoPlistFallbackOptions: ParsableArguments {
            @Option(
                name: [.customLong("default-code-listing-language")],
                help: "A fallback default language for code listings if no value is provided in the documentation catalogs's Info.plist file."
            )
            var defaultCodeListingLanguage: String?
        
            @Option(
                name: [.customLong("fallback-display-name"), .customLong("display-name")], // Remove spelling without "fallback" prefix when other tools no longer use it. (rdar://72449411)
                help: ArgumentHelp("A fallback display name if no value is provided in the documentation catalogs's Info.plist file.", discussion: """
                If no display name is provided in the catalogs's Info.plist file or via the '--fallback-display-name' option, \
                DocC will infer a display name from the documentation catalog base name or from the module name from the symbol graph files provided \
                via the '--additional-symbol-graph-dir' option.
                """)
            )
            var fallbackBundleDisplayName: String?
        
            @Option(
                name: [.customLong("fallback-bundle-identifier"), .customLong("bundle-identifier")], // Remove spelling without "fallback" prefix when other tools no longer use it. (rdar://72449411)
                help: ArgumentHelp("A fallback bundle identifier if no value is provided in the documentation catalogs's Info.plist file.", discussion: """
                If no bundle identifier is provided in the catalogs's Info.plist file or via the '--fallback-bundle-identifier' option, \
                DocC will infer a bundle identifier from the display name.
                """)
            )
            var fallbackBundleIdentifier: String?
        
            @Option(
                name: [.customLong("fallback-bundle-version"), .customLong("bundle-version")], // Remove spelling without "fallback" prefix when other tools no longer use it. (rdar://72449411)
                help: .hidden
            )
            @available(*, deprecated, message: "The bundle version isn't used for anything. This deprecated API will be removed after 6.0 is released")
            var fallbackBundleVersion: String?
            
            @Option(
                help: ArgumentHelp("A fallback default module kind if no value is provided in the documentation catalogs's Info.plist file.", discussion: """
                If no module kind is provided in the catalogs's Info.plist file or via the '--fallback-default-module-kind' option, \
                DocC will display the module kind as a "Framework".
                """)
            )
            var fallbackDefaultModuleKind: String?
            
            func validate() throws {
                for deprecatedOptionName in ["display-name", "bundle-identifier", "bundle-version"] {
                    warnAboutDeprecatedOptionIfNeeded(deprecatedOptionName, message: "Use '--fallback-\(deprecatedOptionName)' instead.")
                }
            }
        }
        
        /// A user-provided fallback display name for the documentation bundle.
        ///
        /// If the documentation catalogs's Info.plist file contains a bundle display name, the documentation catalog ignores this fallback name.
        public var fallbackBundleDisplayName: String? {
            get { infoPlistFallbacks.fallbackBundleDisplayName }
            set { infoPlistFallbacks.fallbackBundleDisplayName = newValue }
        }
        
        /// A user-provided fallback identifier for the documentation bundle.
        ///
        /// If the documentation catalogs's Info.plist file contains a bundle identifier, the documentation catalog ignores this fallback identifier.
        public var fallbackBundleIdentifier: String? {
            get { infoPlistFallbacks.fallbackBundleIdentifier }
            set { infoPlistFallbacks.fallbackBundleIdentifier = newValue }
        }
        
        /// A user-provided fallback version for the documentation bundle.
        ///
        /// If the documentation catalogs's Info.plist file contains a bundle version, the documentation catalog ignores this fallback version.
        @available(*, deprecated, message: "The bundle version isn't used for anything. This deprecated API will be removed after 6.0 is released")
        public var fallbackBundleVersion: String? {
            get { infoPlistFallbacks.fallbackBundleVersion }
            set { infoPlistFallbacks.fallbackBundleVersion = newValue }
        }
        
        /// A user-provided default language for code listings.
        ///
        /// If the documentation catalogs's Info.plist file contains a default code listing language, the documentation catalog ignores this fallback language.
        public var defaultCodeListingLanguage: String? {
            get { infoPlistFallbacks.defaultCodeListingLanguage }
            set { infoPlistFallbacks.defaultCodeListingLanguage = newValue }
        }
        
        /// A user-provided default kind description for the module.
        ///
        /// If the documentation catalogs's Info.plist file contains a default module kind, the documentation catalog ignores this fallback module kind.
        public var fallbackDefaultModuleKind: String? {
            get { infoPlistFallbacks.fallbackDefaultModuleKind }
            set { infoPlistFallbacks.fallbackDefaultModuleKind = newValue }
        }
        
        // MARK: - Documentation coverage options
        
        /// A user-provided value that is true if the user wants to opt in to Experimental documentation coverage generation.
        ///
        /// Defaults to none.
        @OptionGroup(title: "Documentation coverage (Experimental)")
        public var experimentalDocumentationCoverageOptions: DocumentationCoverageOptionsArgument
        
        // MARK: - Link resolution options
        
        @OptionGroup(title: "Link resolution options (Experimental)")
        var linkResolutionOptions: LinkResolutionOptions
        
        struct LinkResolutionOptions: ParsableArguments {
            @Option(
                name: [.customLong("dependency")],
                parsing: ArrayParsingStrategy.singleValue,
                help: ArgumentHelp("A path to a documentation archive to resolve external links against.", discussion: """
                Only documentation archives built with '--enable-experimental-external-link-support' are supported as dependencies.
                """),
                transform: URL.init(fileURLWithPath:)
            )
            var dependencies: [URL] = []

            mutating func validate() throws {
                let fileManager = FileManager.default
                
                var filteredDependencies: [URL] = []
                for dependency in dependencies {
                    // Check that the dependency URL is a directory. We don't validate the extension.
                    var isDirectory: ObjCBool = false
                    guard fileManager.fileExists(atPath: dependency.path, isDirectory: &isDirectory) else {
                        Convert.warnAboutDiagnostic(.init(
                            severity: .warning,
                            identifier: "org.swift.docc.Dependency.NotFound",
                            summary: "No documentation archive exist at '\(dependency.path)'."
                        ))
                        continue
                    }
                    guard isDirectory.boolValue else {
                        Convert.warnAboutDiagnostic(.init(
                            severity: .warning,
                            identifier: "org.swift.docc.Dependency.IsNotDirectory",
                            summary: "Dependency at '\(dependency.path)' is not a directory."
                        ))
                        continue
                    }
                    // Check that the dependency contains both the expected files
                    let linkableEntitiesFile = dependency.appendingPathComponent(ConvertFileWritingConsumer.linkableEntitiesFileName, isDirectory: false)
                    let hasLinkableEntitiesFile = fileManager.fileExists(atPath: linkableEntitiesFile.path)
                    if !hasLinkableEntitiesFile {
                        Convert.warnAboutDiagnostic(.init(
                            severity: .warning,
                            identifier: "org.swift.docc.Dependency.MissingLinkableEntities",
                            summary: "Dependency at '\(dependency.path)' doesn't contain a is not a '\(linkableEntitiesFile.lastPathComponent)' file."
                        ))
                    }
                    let linkableHierarchyFile = dependency.appendingPathComponent(ConvertFileWritingConsumer.linkHierarchyFileName, isDirectory: false)
                    let hasLinkableHierarchyFile = fileManager.fileExists(atPath: linkableHierarchyFile.path)
                    if !hasLinkableHierarchyFile {
                        Convert.warnAboutDiagnostic(.init(
                            severity: .warning,
                            identifier: "org.swift.docc.Dependency.MissingLinkHierarchy",
                            summary: "Dependency at '\(dependency.path)' doesn't contain a is not a '\(linkableHierarchyFile.lastPathComponent)' file."
                        ))
                    }
                    if hasLinkableEntitiesFile && hasLinkableHierarchyFile {
                        filteredDependencies.append(dependency)
                    }
                }
                self.dependencies = filteredDependencies
            }
        }
        
        /// A list of URLs to documentation archives that the local documentation depends on.
        public var dependencies: [URL] {
            get { linkResolutionOptions.dependencies }
            set { linkResolutionOptions.dependencies = newValue }
        }
        
        // MARK: - Feature flag options
        
        @OptionGroup(title: "Feature flags")
        var featureFlags: FeatureFlagOptions
        
        struct FeatureFlagOptions: ParsableArguments {
            @Flag(help: "Allows for custom templates, like `header.html`.")
            var experimentalEnableCustomTemplates = false
            
            @Flag(help: .hidden)
            var enableExperimentalDeviceFrameSupport = false
            
            @Flag(help: "Inherit documentation for inherited symbols")
            var enableInheritedDocs = false

            @Flag(help: "Experimental: allow catalog directories without the `.docc` extension.")
            var allowArbitraryCatalogDirectories = false
            
            @Flag(
                name: .customLong("enable-experimental-external-link-support"),
                help: ArgumentHelp("Support external links to this documentation output.", discussion: """
                Write additional link metadata files to the output directory to support resolving documentation links to the documentation in that output directory.
                """)
            )
            var enableExperimentalLinkHierarchySerialization = false

            @Flag(help: .hidden)
            var experimentalModifyCatalogWithGeneratedCuration = false

            @Flag(
                name: .customLong("enable-experimental-overloaded-symbol-presentation"),
                help: ArgumentHelp("Collects all the symbols that are overloads of each other onto a new merged-symbol page.")
            )
            var enableExperimentalOverloadedSymbolPresentation = false
            
            @Flag(
                name: .customLong("enable-experimental-mentioned-in"),
                help: ArgumentHelp("Render a section on symbol documentation which links to articles that mention that symbol", discussion: """
                Validates and filters symbols' parameter and return value documentation based on the symbol's function signature in each language representation.
                """)
            )
            var enableExperimentalMentionedIn = false

            @Flag(
                name: .customLong("parameters-and-returns-validation"),
                inversion: .prefixedEnableDisable,
                help: ArgumentHelp("Validate parameter and return value documentation", discussion: """
                Validates and filters symbols' parameter and return value documentation based on the symbol's function signature in each language representation.
                """)
            )
            var enableParametersAndReturnsValidation = true
            
            // This flag only exist to allow developers to pass the previous '--enable-experimental-...' flag without errors.
            @Flag(name: .customLong("enable-experimental-parameters-and-returns-validation"), help: .hidden)
            @available(*, deprecated, message: "This deprecated API will be removed after 6.0 is released")
            var enableExperimentalParametersAndReturnsValidation = false
            
            @Flag(help: "Write additional metadata files to the output directory.")
            var emitDigest = false
        
            @Flag(
                help: ArgumentHelp(
                    "Writes an LMDB representation of the navigator index to the output directory.",
                    discussion: "A JSON representation of the navigator index is emitted by default."
                )
            )
            var emitLMDBIndex = false

            @Flag(help: .hidden)
            @available(*, deprecated, renamed: "emitLMDBIndex", message: "Use 'emitLMDBIndex' instead. This deprecated API will be removed after 6.0 is released")
            var index = false
        
            @available(*, deprecated) // This deprecation silences the access of the deprecated `index` flag.
            mutating func validate() throws {
                Convert.warnAboutDeprecatedOptionIfNeeded("enable-experimental-objective-c-support", message: "This flag has no effect. Objective-C support is enabled by default.")
                Convert.warnAboutDeprecatedOptionIfNeeded("enable-experimental-json-index", message: "This flag has no effect. The JSON render is emitted by default.")
                Convert.warnAboutDeprecatedOptionIfNeeded("experimental-parse-doxygen-commands", message: "This flag has no effect. Doxygen support is enabled by default.")
                Convert.warnAboutDeprecatedOptionIfNeeded("enable-experimental-parameters-and-returns-validation", message: "This flag has no effect. Parameter and return value validation is enabled by default.")
                Convert.warnAboutDeprecatedOptionIfNeeded("index", message: "Use '--emit-lmdb-index' indead.")
                emitLMDBIndex = emitLMDBIndex || index
            }
        }

        /// A user-provided value that is true if the user wants to provide a custom template for rendered output.
        ///
        /// Defaults to false
        public var experimentalEnableCustomTemplates: Bool {
            get { featureFlags.experimentalEnableCustomTemplates }
            set { featureFlags.experimentalEnableCustomTemplates = newValue }
            
        }

        /// A user-provided value that is true if the user enables experimental support for device frames.
        ///
        /// Defaults to false.
        public var enableExperimentalDeviceFrameSupport: Bool {
            get { featureFlags.enableExperimentalDeviceFrameSupport }
            set { featureFlags.enableExperimentalDeviceFrameSupport = newValue }
        }
        
        /// A user-provided value that is true if experimental documentation inheritance is to be enabled.
        ///
        /// Defaults to false.
        public var enableInheritedDocs: Bool {
            get { featureFlags.enableInheritedDocs }
            set { featureFlags.enableInheritedDocs = newValue }
        }
        
        /// A user-provided value that is true if additional metadata files should be produced.
        ///
        /// Defaults to false.
        public var allowArbitraryCatalogDirectories: Bool {
            get { featureFlags.allowArbitraryCatalogDirectories }
            set { featureFlags.allowArbitraryCatalogDirectories = newValue }
        }
        
        /// A user-provided value that is true if the user enables experimental serialization of the local link resolution information.
        public var enableExperimentalLinkHierarchySerialization: Bool {
            get { featureFlags.enableExperimentalLinkHierarchySerialization }
            set { featureFlags.enableExperimentalLinkHierarchySerialization = newValue }
        }

        /// A user-provided value that is true if the user wants to in-place modify the provided documentation catalog to write generated curation to documentation extension files.
        ///
        /// Defaults to false
        ///
        /// > Important: This will write new and updated files to the provided documentation catalog directory.
        public var experimentalModifyCatalogWithGeneratedCuration: Bool {
            get { featureFlags.experimentalModifyCatalogWithGeneratedCuration }
            set { featureFlags.experimentalModifyCatalogWithGeneratedCuration = newValue }
        }

        /// A user-provided value that is true if the user enables experimental serialization of the local link resolution information.
        public var enableExperimentalOverloadedSymbolPresentation: Bool {
            get { featureFlags.enableExperimentalOverloadedSymbolPresentation }
            set { featureFlags.enableExperimentalOverloadedSymbolPresentation = newValue }
        }

        /// A user-provided value that is true if the user enables experimental automatically generated "mentioned in"
        /// links on symbols.
        public var enableExperimentalMentionedIn: Bool {
            get { featureFlags.enableExperimentalMentionedIn }
            set { featureFlags.enableExperimentalMentionedIn = newValue }
        }
        
        /// A user-provided value that is true if the user enables experimental validation for parameters and return value documentation.
        public var enableParametersAndReturnsValidation: Bool {
            get { featureFlags.enableParametersAndReturnsValidation }
            set { featureFlags.enableParametersAndReturnsValidation = newValue }
        }
        
        @available(*, deprecated, renamed: "enableParametersAndReturnsValidation", message: "Use 'enableParametersAndReturnsValidation' instead. This deprecated API will be removed after 6.0 is released")
        public var enableExperimentalParametersAndReturnsValidation: Bool {
            get { enableParametersAndReturnsValidation }
            set { enableParametersAndReturnsValidation = newValue }
        }
        
        /// A user-provided value that is true if additional metadata files should be produced.
        ///
        /// Defaults to false.
        public var emitDigest: Bool {
            get { featureFlags.emitDigest }
            set { featureFlags.emitDigest = newValue }
        }

        /// A user-provided value that is true if the LMDB representation of the navigator index should be produced.
        ///
        /// Defaults to false.
        public var emitLMDBIndex: Bool {
            get { featureFlags.emitLMDBIndex }
            set { featureFlags.emitLMDBIndex = newValue }
            
        }
        /// This value is provided for backwards compatibility with existing clients but will be removed soon. Renamed to '--emit-lmdb-index'.
        @available(*, deprecated, renamed: "emitLMDBIndex", message: "Use 'emitLMDBIndex' instead. This deprecated API will be removed after 6.0 is released")
        public var index: Bool {
            get { featureFlags.emitLMDBIndex }
            set { featureFlags.emitLMDBIndex = newValue }
        }
        
        // MARK: - ParsableCommand conformance

        public mutating func validate() throws {
            if transformForStaticHosting {
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
                        DiagnosticConsoleWriter.formattedDescription(for: invalidOrMissingTemplateDiagnostic),
                        to: &Self._errorLogHandle
                    )
                    
                    transformForStaticHosting = false
                }
            }
        }

        public mutating func run() throws {
            // Initialize a `ConvertAction` from the current options in the `Convert` command.
            var convertAction = try ConvertAction(fromConvertCommand: self)

            // Perform the conversion and print any warnings or errors found
            try convertAction.performAndHandleResult()
        }
        
        // MARK: Warnings
        
        static func warnAboutDeprecatedOptionIfNeeded(_ deprecatedOption: String, message: String) {
            guard ProcessInfo.processInfo.arguments.contains("--\(deprecatedOption)") else {
                return // Only warn if the flag is used
            }
            warnAboutDiagnostic(.init(
                severity: .warning,
                identifier: "org.swift.docc.DeprecatedOption",
                summary: "'--\(deprecatedOption)' is deprecated. \(message)"
            ))
        }
        
        private static func warnAboutDiagnostic(_ diagnostic: Diagnostic) {
            print(
                DiagnosticConsoleWriter.formattedDescription(for: diagnostic, options: _diagnosticFormattingOptions),
                to: &_errorLogHandle
            )
        }
    }
}
