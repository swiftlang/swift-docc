/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import SwiftDocC
import Foundation

extension ConvertAction {
    /// Creates a  convert action from the options in the given convert command.
    /// - Parameters:
    ///   - convert: The convert command this `ConvertAction` will be based on.
    ///   - fallbackTemplateURL: A template URL to use if the one provided by the convert command is `nil`.
    public init(fromConvertCommand convert: Docc.Convert, withFallbackTemplate fallbackTemplateURL: URL? = nil) throws {
        var standardError = LogHandle.standardError
        let outOfProcessResolver: OutOfProcessReferenceResolver?
        
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
        let parsedPlatforms = try PlatformArgumentParser.parse(convert.platforms)

        let additionalSymbolGraphFiles = convert.additionalSymbolGraphFiles + symbolGraphFiles(
            in: convert.additionalSymbolGraphDirectory
        )
        
        let bundleDiscoveryOptions = BundleDiscoveryOptions(
            fallbackDisplayName: convert.fallbackBundleDisplayName,
            fallbackIdentifier: convert.fallbackBundleIdentifier,
            fallbackVersion: convert.fallbackBundleVersion,
            fallbackDefaultCodeListingLanguage: convert.defaultCodeListingLanguage,
            fallbackDefaultModuleKind: convert.fallbackDefaultModuleKind,
            additionalSymbolGraphFiles: additionalSymbolGraphFiles
        )
        
        // The `preview` and `convert` action defaulting to the current working directory is only supported
        // when running `docc preview` and `docc convert` without any of the fallback options.
        let documentationBundleURL: URL?
        if bundleDiscoveryOptions.infoPlistFallbacks.isEmpty {
            documentationBundleURL = convert.documentationBundle.urlOrFallback
        } else {
            documentationBundleURL = convert.documentationBundle.url
        }

        // Initialize the ``ConvertAction`` with the options provided by the ``Convert`` command.
        try self.init(
            documentationBundleURL: documentationBundleURL,
            outOfProcessResolver: outOfProcessResolver,
            analyze: convert.analyze,
            targetDirectory: convert.outputURL,
            htmlTemplateDirectory: convert.templateOption.templateURL ?? fallbackTemplateURL,
            emitDigest: convert.emitDigest,
            currentPlatforms: parsedPlatforms,
            buildIndex: convert.emitLMDBIndex || convert.index,
            temporaryDirectory: FileManager.default.temporaryDirectory,
            documentationCoverageOptions: DocumentationCoverageOptions(
                from: convert.experimentalDocumentationCoverageOptions
            ),
            bundleDiscoveryOptions: bundleDiscoveryOptions,
            diagnosticLevel: convert.diagnosticLevel,
            emitFixits: convert.emitFixits,
            inheritDocs: convert.enableInheritedDocs,
            treatWarningsAsErrors: convert.warningsAsErrors,
            experimentalEnableCustomTemplates: convert.experimentalEnableCustomTemplates,
            transformForStaticHosting: convert.transformForStaticHosting,
            hostingBasePath: convert.hostingBasePath,
            sourceRepository: SourceRepository(from: convert.sourceRepositoryArguments)
        )
    }
}

private func symbolGraphFiles(in directory: URL?) -> [URL] {
    guard let directory = directory else { return [] }
    
    let subpaths = FileManager.default.subpaths(atPath: directory.path) ?? []
    return subpaths.map { directory.appendingPathComponent($0) }
        .filter { DocumentationBundleFileTypes.isSymbolGraphFile($0) }
}
