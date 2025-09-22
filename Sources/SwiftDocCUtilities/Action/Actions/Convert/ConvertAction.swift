/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

package import Foundation

@_spi(ExternalLinks) // SPI to set `context.linkResolver.dependencyArchives`
public import SwiftDocC

/// An action that converts a source bundle into compiled documentation.
public struct ConvertAction: AsyncAction {
    private let signposter = ConvertActionConverter.signposter
    
    let rootURL: URL?
    let targetDirectory: URL
    let htmlTemplateDirectory: URL?
    
    private let emitDigest: Bool
    let treatWarningsAsErrors: Bool
    let experimentalEnableCustomTemplates: Bool
    private let experimentalModifyCatalogWithGeneratedCuration: Bool
    let buildLMDBIndex: Bool
    private let documentationCoverageOptions: DocumentationCoverageOptions
    let diagnosticEngine: DiagnosticEngine

    private let transformForStaticHosting: Bool
    private let hostingBasePath: String?
    
    let sourceRepository: SourceRepository?
    
    private var fileManager: any FileManagerProtocol
    private let temporaryDirectory: URL
    
    private let diagnosticWriterOptions: (formatting: DiagnosticFormattingOptions, baseURL: URL)

    /// Initializes the action with the given validated options.
    /// 
    /// - Parameters:
    ///   - documentationBundleURL: The root of the documentation catalog to convert.
    ///   - outOfProcessResolver: An out-of-process resolver that
    ///   - analyze: `true` if the convert action should override the provided `diagnosticLevel` with `.information`, otherwise `false`.
    ///   - targetDirectory: The location where the convert action will write the built documentation output.
    ///   - htmlTemplateDirectory: The location of the HTML template to use as a base for the built documentation output.
    ///   - emitDigest: Whether the conversion should create metadata files, such as linkable entities information.
    ///   - currentPlatforms: The current version and beta information for platforms that may be encountered while processing symbol graph files.
    ///   - buildIndex: Whether or not the convert action should emit an LMDB representation of the navigator index.
    /// 
    ///     A JSON representation is built and emitted regardless of this value.
    ///   - fileManager: The file manager that the convert action uses to create directories and write data to files.
    ///   - documentationCoverageOptions: Indicates whether or not to generate coverage output and at what level.
    ///   - bundleDiscoveryOptions: Options to configure how the converter discovers documentation bundles.
    ///   - diagnosticLevel: The level above which diagnostics will be filtered out. This filter level is inclusive, i.e. if a level of `DiagnosticSeverity.information` is specified, diagnostics with a severity up to and including `.information` will be printed.
    ///   - diagnosticEngine: The engine that will collect and emit diagnostics during this action.
    ///   - diagnosticFilePath: The path to a file where the convert action should write diagnostic information.
    ///   - formatConsoleOutputForTools: `true` if the convert action should write diagnostics to the console in a format suitable for parsing by an IDE or other tool, otherwise `false`.
    ///   - inheritDocs: `true` if the convert action should retain the original documentation content for inherited symbols, otherwise `false`.
    ///   - treatWarningsAsErrors: `true` if the convert action should treat warnings as errors, otherwise `false`.
    ///   - experimentalEnableCustomTemplates: `true` if the convert action should enable support for custom "header.html" and "footer.html" template files, otherwise `false`.
    ///   - experimentalModifyCatalogWithGeneratedCuration: `true` if the convert action should write documentation extension files containing markdown representations of DocC's automatic curation into the `documentationBundleURL`, otherwise `false`.
    ///   - transformForStaticHosting: `true` if the convert action should process the build documentation archive so that it supports a static hosting environment, otherwise `false`.
    ///   - allowArbitraryCatalogDirectories: `true` if the convert action should consider the root location as a documentation bundle if it doesn't discover another bundle, otherwise `false`.
    ///   - hostingBasePath: The base path where the built documentation archive will be hosted at.
    ///   - sourceRepository: The source repository where the documentation's sources are hosted.
    ///   - temporaryDirectory: The location where the convert action should write temporary files while converting the documentation.
    ///   - dependencies: A list of URLs to already built documentation archives that this documentation depends on.
    package init(
        documentationBundleURL: URL?,
        outOfProcessResolver: OutOfProcessReferenceResolver?,
        analyze: Bool,
        targetDirectory: URL,
        htmlTemplateDirectory: URL?,
        emitDigest: Bool,
        currentPlatforms: [String : PlatformVersion]?,
        buildIndex: Bool = false,
        fileManager: any FileManagerProtocol = FileManager.default,
        temporaryDirectory: URL,
        documentationCoverageOptions: DocumentationCoverageOptions = .noCoverage,
        bundleDiscoveryOptions: BundleDiscoveryOptions = .init(),
        diagnosticLevel: String? = nil,
        diagnosticEngine: DiagnosticEngine? = nil,
        diagnosticFilePath: URL? = nil,
        formatConsoleOutputForTools: Bool = false,
        inheritDocs: Bool = false,
        treatWarningsAsErrors: Bool = false,
        experimentalEnableCustomTemplates: Bool = false,
        experimentalModifyCatalogWithGeneratedCuration: Bool = false,
        transformForStaticHosting: Bool = false,
        allowArbitraryCatalogDirectories: Bool = false,
        hostingBasePath: String? = nil,
        sourceRepository: SourceRepository? = nil,
        dependencies: [URL] = []
    ) throws {
        self.rootURL = documentationBundleURL
        self.targetDirectory = targetDirectory
        self.htmlTemplateDirectory = htmlTemplateDirectory
        self.emitDigest = emitDigest
        self.buildLMDBIndex = buildIndex
        self.fileManager = fileManager
        self.temporaryDirectory = temporaryDirectory
        self.documentationCoverageOptions = documentationCoverageOptions
        self.transformForStaticHosting = transformForStaticHosting
        self.hostingBasePath = hostingBasePath
        self.sourceRepository = sourceRepository
        
        let filterLevel: DiagnosticSeverity
        if analyze {
            filterLevel = .information
        } else {
            filterLevel = DiagnosticSeverity(diagnosticLevel) ?? .warning
        }
        
        let formattingOptions: DiagnosticFormattingOptions
        if formatConsoleOutputForTools || diagnosticFilePath != nil {
            formattingOptions = [.formatConsoleOutputForTools]
        } else {
            formattingOptions = []
        }
        self.diagnosticWriterOptions = (
            formattingOptions,
            documentationBundleURL ?? URL(fileURLWithPath: fileManager.currentDirectoryPath)
        )
        
        self.treatWarningsAsErrors = treatWarningsAsErrors

        self.experimentalEnableCustomTemplates = experimentalEnableCustomTemplates
        self.experimentalModifyCatalogWithGeneratedCuration = experimentalModifyCatalogWithGeneratedCuration
        
        let engine = diagnosticEngine ?? DiagnosticEngine(treatWarningsAsErrors: treatWarningsAsErrors)
        engine.filterLevel = filterLevel
        if let diagnosticFilePath {
            engine.add(DiagnosticFileWriter(outputPath: diagnosticFilePath))
        }
        
        self.diagnosticEngine = engine
        
        var configuration = DocumentationContext.Configuration()
        
        configuration.externalMetadata.diagnosticLevel = filterLevel
        // Inject current platform versions if provided
        if var currentPlatforms {
            // Add missing platforms if their fallback platform is present.
            for (platform, fallbackPlatform) in DefaultAvailability.fallbackPlatforms where currentPlatforms[platform.displayName] == nil {
                currentPlatforms[platform.displayName] = currentPlatforms[fallbackPlatform.displayName]
            }
            configuration.externalMetadata.currentPlatforms = currentPlatforms
        }

        // Inject user-set flags.
        configuration.externalMetadata.inheritDocs = inheritDocs
        
        switch documentationCoverageOptions.level {
        case .detailed, .brief:
            configuration.experimentalCoverageConfiguration.shouldStoreManuallyCuratedReferences = true
        case .none:
            break
        }
        
        if let outOfProcessResolver {
            configuration.externalDocumentationConfiguration.sources[outOfProcessResolver.bundleID] = outOfProcessResolver
            configuration.externalDocumentationConfiguration.globalSymbolResolver = outOfProcessResolver
        }
        configuration.externalDocumentationConfiguration.dependencyArchives = dependencies
        
        let (inputs, dataProvider) = try signposter.withIntervalSignpost("Discover inputs", id: signposter.makeSignpostID()) {
            try DocumentationContext.InputsProvider(fileManager: fileManager)
            .inputsAndDataProvider(
                startingPoint: documentationBundleURL,
                allowArbitraryCatalogDirectories: allowArbitraryCatalogDirectories,
                options: bundleDiscoveryOptions
            )
        }

        self.configuration = configuration
        
        self.inputs = inputs
        self.dataProvider = dataProvider
    }
    
    let configuration: DocumentationContext.Configuration
    private let inputs: DocumentationContext.Inputs
    private let dataProvider: any DataProvider
    
    /// A block of extra work that tests perform to affect the time it takes to convert documentation
    var _extraTestWork: (() async -> Void)?

    /// Converts each eligible file from the source documentation bundle,
    /// saves the results in the given output alongside the template files.
    public func perform(logHandle: inout LogHandle) async throws -> ActionResult {
        try await perform(logHandle: &logHandle).0
    }
    
    func perform(logHandle: inout LogHandle) async throws -> (ActionResult, DocumentationContext) {
        // FIXME: Use `defer` again when the asynchronous defer-statement miscompilation (rdar://137774949) is fixed.
        let temporaryFolder = try createTempFolder(with: htmlTemplateDirectory)
        do {
            let result = try await _perform(logHandle: &logHandle, temporaryFolder: temporaryFolder)
            diagnosticEngine.flush()
            try? fileManager.removeItem(at: temporaryFolder)
            return result
        } catch {
            diagnosticEngine.flush()
            try? fileManager.removeItem(at: temporaryFolder)
            throw error
        }
    }
    
    private func _perform(logHandle: inout LogHandle, temporaryFolder: URL) async throws -> (ActionResult, DocumentationContext) {
        let convertSignpostHandle = signposter.beginInterval("Convert", id: signposter.makeSignpostID())
        defer {
            signposter.endInterval("Convert", convertSignpostHandle)
        }
        
        // Add the default diagnostic console writer now that we know what log handle it should write to.
        if !diagnosticEngine.hasConsumer(matching: { $0 is DiagnosticConsoleWriter }) {
            diagnosticEngine.add(
                DiagnosticConsoleWriter(
                    logHandle,
                    formattingOptions: diagnosticWriterOptions.formatting,
                    baseURL: diagnosticWriterOptions.baseURL,
                    dataProvider: dataProvider
                )
            )
        }
        
        // The converter has already emitted its problems to the diagnostic engine.
        // Track additional problems separately to avoid repeating the converter's problems.
        var postConversionProblems: [Problem] = []
        let totalTimeMetric = benchmark(begin: Benchmark.Duration(id: "convert-total-time"))
        
        // FIXME: Use `defer` here again when the miscompilation of this asynchronous defer-statement (rdar://137774949) is fixed.
//        defer {
//            diagnosticEngine.flush()
//        }
        
        // Run any extra work that the test may have injected
        await _extraTestWork?()
        
        // FIXME: Use `defer` here again when the miscompilation of this asynchronous defer-statement (rdar://137774949) is fixed.
//        let temporaryFolder = try createTempFolder(with: htmlTemplateDirectory)
//        defer {
//            try? fileManager.removeItem(at: temporaryFolder)
//        }

        let indexHTML: URL?
        if let htmlTemplateDirectory {
            let indexHTMLUrl = temporaryFolder.appendingPathComponent(
                HTMLTemplate.indexFileName.rawValue,
                isDirectory: false
            )
            indexHTML = indexHTMLUrl
            
            let customHostingBasePathProvided = !(hostingBasePath?.isEmpty ?? true)
            if customHostingBasePathProvided {
                let data = try StaticHostableTransformer.indexHTMLData(
                    in: htmlTemplateDirectory,
                    with: hostingBasePath,
                    fileManager: fileManager
                )
                
                // A hosting base path was provided which means we need to replace the standard
                // 'index.html' file with the transformed one.
                try fileManager.createFile(at: indexHTMLUrl, contents: data)
            }
            
            let indexHTMLTemplateURL = temporaryFolder.appendingPathComponent(
                HTMLTemplate.templateFileName.rawValue,
                isDirectory: false
            )
            
            // Delete any existing 'index-template.html' file that
            // was copied into the temporary output directory with the
            // HTML template.
            try? fileManager.removeItem(at: indexHTMLTemplateURL)
        } else {
            indexHTML = nil
        }
        
        let coverageAction = CoverageAction(
            documentationCoverageOptions: documentationCoverageOptions,
            workingDirectory: temporaryFolder,
            fileManager: fileManager)

        let indexer = try Indexer(outputURL: temporaryFolder, bundleID: inputs.id)

        let registerInterval = signposter.beginInterval("Register", id: signposter.makeSignpostID())
        let context = try await DocumentationContext(inputs: inputs, dataProvider: dataProvider, diagnosticEngine: diagnosticEngine, configuration: configuration)
        signposter.endInterval("Register", registerInterval)
        
        let outputConsumer = ConvertFileWritingConsumer(
            targetFolder: temporaryFolder,
            bundleRootFolder: rootURL,
            fileManager: fileManager,
            context: context,
            indexer: indexer,
            enableCustomTemplates: experimentalEnableCustomTemplates,
            transformForStaticHostingIndexHTML: transformForStaticHosting ? indexHTML : nil,
            bundleID: inputs.id
        )

        if experimentalModifyCatalogWithGeneratedCuration, let catalogURL = rootURL {
            let writer = GeneratedCurationWriter(context: context, catalogURL: catalogURL, outputURL: catalogURL)
            let curation = try writer.generateDefaultCurationContents()
            for (url, updatedContent) in curation {
                guard let data = updatedContent.data(using: .utf8) else { continue }
                try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
                try? data.write(to: url, options: .atomic)
            }
        }
        
        let analysisProblems: [Problem]
        let conversionProblems: [Problem]
        do {
            conversionProblems = try signposter.withIntervalSignpost("Process") {
                try ConvertActionConverter.convert(
                    inputs: inputs,
                    context: context,
                    outputConsumer: outputConsumer,
                    sourceRepository: sourceRepository,
                    emitDigest: emitDigest,
                    documentationCoverageOptions: documentationCoverageOptions
                )
            }
            analysisProblems = context.problems
        } catch {
            if emitDigest {
                let problem = Problem(description: (error as? (any DescribedError))?.errorDescription ?? error.localizedDescription, source: nil)
                try (_Deprecated(outputConsumer) as (any _DeprecatedConsumeProblemsAccess))._consume(problems: context.problems + [problem])
                try moveOutput(from: temporaryFolder, to: targetDirectory)
            }
            throw error
        }

        var didEncounterError = analysisProblems.containsErrors || conversionProblems.containsErrors
        let hasTutorial = context.knownPages.contains(where: {
            guard let kind = try? context.entity(with: $0).kind else { return false }
            return kind == .tutorial || kind == .tutorialArticle
        })
        // Warn the user if the catalog is a tutorial but does not contains a table of contents
        // and provide template content to fix this problem.
        if context.tutorialTableOfContentsReferences.isEmpty, hasTutorial {
            let tableOfContentsFilename = CatalogTemplateKind.tutorialTopLevelFilename
            let source = rootURL?.appendingPathComponent(tableOfContentsFilename)
            var replacements = [Replacement]()
            if let tableOfContentsTemplate = CatalogTemplateKind.tutorialTemplateFiles(inputs.displayName)[tableOfContentsFilename] {
                replacements.append(
                    Replacement(
                        range: .init(line: 1, column: 1, source: source) ..< .init(line: 1, column: 1, source: source),
                        replacement: tableOfContentsTemplate
                    )
                )
            }
            postConversionProblems.append(
                Problem(
                    diagnostic: Diagnostic(
                        source: source,
                        severity: .warning,
                        identifier: "org.swift.docc.MissingTableOfContents",
                        summary: "Missing tutorial table of contents page.",
                        explanation: "`@Tutorial` and `@Article` pages require a `@Tutorials` table of content page to define the documentation hierarchy."
                    ),
                    possibleSolutions: [
                        Solution(
                            summary: "Create a `@Tutorials` table of content page.",
                            replacements: replacements
                        )
                    ]
                )
            )
        }
        
        // If we're building a navigation index, finalize the process and collect encountered problems.
        do {
            let finalizeNavigationIndexMetric = benchmark(begin: Benchmark.Duration(id: "finalize-navigation-index"))
            
            // Always emit a JSON representation of the index but only emit the LMDB
            // index if the user has explicitly opted in with the `--emit-lmdb-index` flag.
            let indexerProblems = signposter.withIntervalSignpost("Finalize navigator index") {
                indexer.finalize(emitJSON: true, emitLMDB: buildLMDBIndex)
            }
            postConversionProblems.append(contentsOf: indexerProblems)
            
            benchmark(end: finalizeNavigationIndexMetric)
        }
        
        // Output to the user the problems encountered during the convert process
        diagnosticEngine.emit(postConversionProblems)

        // Stop the "total time" metric here. The moveOutput time isn't very interesting to include in the benchmark.
        // New tasks and computations should be added above this line so that they're included in the benchmark.
        benchmark(end: totalTimeMetric)
        
        if !didEncounterError {
            let coverageResults = try await coverageAction.perform(logHandle: &logHandle)
            postConversionProblems.append(contentsOf: coverageResults.problems)
        }
        
        didEncounterError = didEncounterError || postConversionProblems.containsErrors
        
        // We should generally only replace the current build output if we didn't encounter errors
        // during conversion. However, if the `emitDigest` flag is true,
        // we should replace the current output with our digest of problems.
        if !didEncounterError || emitDigest {
            try moveOutput(from: temporaryFolder, to: targetDirectory)
        }

        // Log the output size.
        benchmark(add: Benchmark.ArchiveOutputSize(archiveDirectory: targetDirectory))
        benchmark(
            add: Benchmark.DataDirectoryOutputSize(
                dataDirectory: targetDirectory.appendingPathComponent(
                    NodeURLGenerator.Path.dataFolderName,
                    isDirectory: true
                )
            )
        )
        benchmark(
            add: Benchmark.IndexDirectoryOutputSize(
                indexDirectory: targetDirectory.appendingPathComponent(
                    NodeURLGenerator.Path.indexFolderName,
                    isDirectory: true
                )
            )
        )
        
        if Benchmark.main.isEnabled {
            // Write the benchmark files directly in the target directory.

            let outputConsumer = ConvertFileWritingConsumer(
                targetFolder: targetDirectory,
                bundleRootFolder: rootURL,
                fileManager: fileManager,
                context: context,
                indexer: nil,
                transformForStaticHostingIndexHTML: nil,
                bundleID: inputs.id
            )

            try outputConsumer.consume(benchmarks: Benchmark.main)
        }

        return (ActionResult(didEncounterError: didEncounterError, outputs: [targetDirectory]), context)
    }
    
    func createTempFolder(with templateURL: URL?) throws -> URL {
        return try Self.createUniqueDirectory(inside: temporaryDirectory, template: templateURL, fileManager: fileManager)
    }
    
    func moveOutput(from: URL, to: URL) throws {
        try signposter.withIntervalSignpost("Move output") {
            try Self.moveOutput(from: from, to: to, fileManager: fileManager)
        }
    }
}
