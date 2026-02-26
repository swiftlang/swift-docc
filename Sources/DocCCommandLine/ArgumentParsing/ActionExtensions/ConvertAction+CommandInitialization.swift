/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

package import SwiftDocC
public import Foundation

extension ConvertAction {
    /// Creates a convert action from the options in the given convert command.
    /// - Parameters:
    ///   - convert: The convert command this `ConvertAction` will be based on.
    ///   - fallbackTemplateURL: A template URL to use if the one provided by the convert command is `nil`.
    public init(fromConvertCommand convert: Docc.Convert, withFallbackTemplate fallbackTemplateURL: URL? = nil) throws {
        var standardError = LogHandle.standardError
        let outOfProcessResolver: OutOfProcessReferenceResolver?
        FeatureFlags.current.isExperimentalCodeBlockAnnotationsEnabled = convert.featureFlags.enableExperimentalCodeBlockAnnotations
        FeatureFlags.current.isExperimentalDeviceFrameSupportEnabled = convert.featureFlags.enableExperimentalDeviceFrameSupport
        FeatureFlags.current.isExperimentalLinkHierarchySerializationEnabled = convert.featureFlags.enableExperimentalLinkHierarchySerialization
        FeatureFlags.current.isExperimentalOverloadedSymbolPresentationEnabled = convert.featureFlags.enableExperimentalOverloadedSymbolPresentation
        FeatureFlags.current.isMentionedInEnabled = convert.featureFlags.enableMentionedIn
        FeatureFlags.current.isParametersAndReturnsValidationEnabled = convert.featureFlags.enableParametersAndReturnsValidation
        FeatureFlags.current.isExperimentalMarkdownOutputEnabled = convert.featureFlags.enableExperimentalMarkdownOutput
        FeatureFlags.current.isExperimentalMarkdownOutputManifestEnabled = convert.featureFlags.enableExperimentalMarkdownOutputManifest
        
        // If the user-provided a URL for an external link resolver, attempt to
        // initialize an `OutOfProcessReferenceResolver` with the provided URL.
        if let linkResolverURL = convert.outOfProcessLinkResolverOption.linkResolverExecutableURL {
            outOfProcessResolver = try OutOfProcessReferenceResolver(
                processLocation: linkResolverURL,
                errorOutputHandler: { errorMessage in
                    // If any errors occur while initializing the reference resolver,
                    // or while the link resolver is used, output them to the terminal.
                    print(errorMessage, to: &standardError)
                })
        } else {
            outOfProcessResolver = nil
        }

        // Attempt to convert the raw strings representing platform name/version pairs
        // into a dictionary. This will throw with a descriptive error upon failure.
        let parsedPlatforms = try PlatformArgumentParser.parse(convert.availabilityOptions.platforms)

        let bundleDiscoveryOptions = convert.bundleDiscoveryOptions
        
        // The `preview` and `convert` action defaulting to the current working directory is only supported
        // when running `docc preview` and `docc convert` without any of the fallback options.
        let documentationBundleURL: URL?
        if bundleDiscoveryOptions.infoPlistFallbacks.isEmpty {
            documentationBundleURL = convert.inputsAndOutputs.documentationCatalog.urlOrFallback
        } else {
            documentationBundleURL = convert.inputsAndOutputs.documentationCatalog.url
        }

        // Initialize the ``ConvertAction`` with the options provided by the ``Convert`` command.
        try self.init(
            documentationBundleURL: documentationBundleURL,
            outOfProcessResolver: outOfProcessResolver,
            analyze: convert.diagnosticOptions.analyze,
            targetDirectory: convert.outputURL,
            htmlTemplateDirectory: convert.templateOption.templateURL ?? fallbackTemplateURL,
            emitDigest: convert.featureFlags.emitDigest,
            currentPlatforms: parsedPlatforms,
            buildIndex: convert.featureFlags.emitLMDBIndex,
            temporaryDirectory: FileManager.default.temporaryDirectory,
            documentationCoverageOptions: DocumentationCoverageOptions(
                from: convert.experimentalDocumentationCoverageOptions
            ),
            bundleDiscoveryOptions: bundleDiscoveryOptions,
            diagnosticLevel: convert.diagnosticOptions.diagnosticLevel,
            diagnosticFilePath: convert.diagnosticOptions.diagnosticsOutputPath,
            formatConsoleOutputForTools: convert.diagnosticOptions.formatConsoleOutputForTools,
            inheritDocs: convert.featureFlags.enableInheritedDocs,
            treatWarningsAsErrors: convert.diagnosticOptions.warningsAsErrors,
            experimentalEnableCustomTemplates: convert.featureFlags.experimentalEnableCustomTemplates,
            experimentalModifyCatalogWithGeneratedCuration: convert.featureFlags.experimentalModifyCatalogWithGeneratedCuration,
            transformForStaticHosting: convert.hostingOptions.transformForStaticHosting,
            includeContentInEachHTMLFile: convert.hostingOptions.experimentalTransformForStaticHostingWithContent,
            allowArbitraryCatalogDirectories: convert.featureFlags.allowArbitraryCatalogDirectories,
            hostingBasePath: convert.hostingOptions.hostingBasePath,
            sourceRepository: SourceRepository(from: convert.sourceRepositoryArguments),
            dependencies: convert.linkResolutionOptions.dependencies
        )
    }
}

package extension Docc.Convert {
    var bundleDiscoveryOptions: BundleDiscoveryOptions {
        let additionalSymbolGraphFiles = symbolGraphFiles(in: inputsAndOutputs.additionalSymbolGraphDirectory)
        
        return BundleDiscoveryOptions(
            fallbackDisplayName: infoPlistFallbacks.fallbackBundleDisplayName,
            fallbackIdentifier: infoPlistFallbacks.fallbackBundleIdentifier,
            fallbackDefaultCodeListingLanguage: infoPlistFallbacks.defaultCodeListingLanguage,
            fallbackDefaultModuleKind: infoPlistFallbacks.fallbackDefaultModuleKind,
            additionalSymbolGraphFiles: additionalSymbolGraphFiles
        )
    }
}

private func symbolGraphFiles(in directory: URL?) -> [URL] {
    guard let directory else { return [] }
    
    let subpaths = FileManager.default.subpaths(atPath: directory.path) ?? []
    return subpaths.map { directory.appendingPathComponent($0) }
        .filter { DocumentationBundleFileTypes.isSymbolGraphFile($0) }
}
