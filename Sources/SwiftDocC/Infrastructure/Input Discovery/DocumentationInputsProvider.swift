/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SymbolKit

extension DocumentationContext {

    /// A type that provides inputs for a unit of documentation.
    ///
    /// The inputs provider discovers documentation catalogs on the file system and creates a ``DocumentationBundle`` from the discovered catalog content.
    ///
    /// The input provider categorizes the catalog content based on corresponding ``DocumentationBundleFileTypes`` conditions:
    ///
    ///  Category                                 | Condition
    ///  ---------------------------------------- | -------------------------------------------------
    ///  ``DocumentationBundle/markupURLs``       | ``DocumentationBundleFileTypes/isMarkupFile(_:)``
    ///  ``DocumentationBundle/symbolGraphURLs``  | ``DocumentationBundleFileTypes/isSymbolGraphFile(_:)``
    ///  ``DocumentationBundle/info``             | ``DocumentationBundleFileTypes/isInfoPlistFile(_:)``
    ///  ``DocumentationBundle/themeSettings``    | ``DocumentationBundleFileTypes/isThemeSettingsFile(_:)``
    ///  ``DocumentationBundle/customHeader``     | ``DocumentationBundleFileTypes/isCustomHeader(_:)``
    ///  ``DocumentationBundle/customFooter``     | ``DocumentationBundleFileTypes/isCustomFooter(_:)``
    ///  ``DocumentationBundle/miscResourceURLs`` | Any file not already matched above.
    ///
    /// ## Topics
    ///
    /// ### Catalog discovery
    ///
    /// Discover documentation catalogs and create documentation build inputs from the discovered catalog's content.
    ///
    /// - ``findCatalog(startingPoint:allowArbitraryCatalogDirectories:)``
    /// - ``makeInputs(contentOf:options:)``
    ///
    /// ### Input discovery
    ///
    /// Discover documentation build inputs from a mix of discovered documentation catalogs and other command line options.
    ///
    /// - ``inputsAndDataProvider(startingPoint:allowArbitraryCatalogDirectories:options:)``
    ///
    /// ### Errors
    ///
    /// Errors that the inputs provider can raise while validating the discovered inputs.
    ///
    /// - ``MultipleCatalogsError``
    /// - ``NotEnoughInformationError``
    /// - ``InputsFromSymbolGraphError``
    package struct InputsProvider {
        /// The file manager that the provider uses to read file and directory contents from the file system.
        private var fileManager: FileManagerProtocol

        /// Creates a new documentation inputs provider.
        /// - Parameter fileManager: The file manager that the provider uses to read file and directory contents from the file system.
        package init(fileManager: FileManagerProtocol) {
            self.fileManager = fileManager
        }

        /// Creates a new documentation inputs provider.
        package init() {
            self.init(fileManager: FileManager.default)
        }
    }
}

// MARK: Catalog discovery

extension DocumentationContext.InputsProvider {

    private typealias FileTypes = DocumentationBundleFileTypes

    /// A discovered documentation catalog.
    struct CatalogURL {
        let url: URL
    }

    struct MultipleCatalogsError: DescribedError {
        let startingPoint: URL
        let catalogs: [URL]

        var errorDescription: String {
            """
            Found multiple documentation catalogs in \(startingPoint.standardizedFileURL.path):
            \(catalogs.map { ($0.relative(to: startingPoint) ?? $0).standardizedFileURL.path }.sorted().map { " - \($0)" }.joined(separator: "\n"))
            """
        }
    }

    /// Traverses the file system from the given starting point to find a documentation catalog.
    /// - Parameters:
    ///   - startingPoint: The top of the directory hierarchy that the provider traverses to find a documentation catalog.
    ///   - allowArbitraryCatalogDirectories: Whether to treat the starting point as a documentation catalog if the provider doesn't find an actual catalog on the file system.
    /// - Returns: The found documentation catalog.
    /// - Throws: If the directory hierarchy contains more than one documentation catalog.
    func findCatalog(
        startingPoint: URL,
        allowArbitraryCatalogDirectories: Bool = false
    ) throws -> CatalogURL? {
        var foundCatalogs: [URL] = []

        var urlsToCheck = [startingPoint]
        while !urlsToCheck.isEmpty {
            let url = urlsToCheck.removeFirst()

            guard !FileTypes.isDocumentationCatalog(url) else {
                // Don't look for catalogs inside of other catalogs.
                foundCatalogs.append(url)
                continue
            }

            urlsToCheck.append(contentsOf: try fileManager.contentsOfDirectory(at: url, options: .skipsHiddenFiles).directories)
        }

        guard foundCatalogs.count <= 1 else {
            throw MultipleCatalogsError(startingPoint: startingPoint, catalogs: foundCatalogs)
        }

        let catalogURL = foundCatalogs.first
        // If the provider didn't find a catalog, check if the root should be treated as a catalog
        ?? (allowArbitraryCatalogDirectories ? startingPoint : nil)

        return catalogURL.map(CatalogURL.init)
    }
}

// MARK: Create from catalog

extension DocumentationContext {
    package typealias Inputs = DocumentationBundle
}

extension DocumentationContext.InputsProvider {

    package typealias Options = BundleDiscoveryOptions

    /// Creates a collection of documentation inputs from the content of the given documentation catalog.
    /// 
    /// - Parameters:
    ///   - catalogURL: The location of a discovered documentation catalog.
    ///   - options: Options to configure how the provider creates the documentation inputs.
    /// - Returns: Inputs that categorize the files of the given catalog.
    func makeInputs(contentOf catalogURL: CatalogURL, options: Options) throws -> DocumentationContext.Inputs {
        let url = catalogURL.url
        let shallowContent = try fileManager.contentsOfDirectory(at: url, options: [.skipsHiddenFiles]).files
        let infoPlistData = try shallowContent
            .first(where: FileTypes.isInfoPlistFile)
            .map { try fileManager.contents(of: $0) }

        let info = try DocumentationContext.Inputs.Info(
            from: infoPlistData,
            bundleDiscoveryOptions: options,
            derivedDisplayName: url.deletingPathExtension().lastPathComponent
        )

        let foundContents = try findContents(in: url)
        return DocumentationContext.Inputs(
            info: info,
            symbolGraphURLs:  foundContents.symbolGraphs + options.additionalSymbolGraphFiles,
            markupURLs:       foundContents.markup,
            miscResourceURLs: foundContents.resources,
            customHeader:  shallowContent.first(where: FileTypes.isCustomHeader),
            customFooter:  shallowContent.first(where: FileTypes.isCustomFooter),
            themeSettings: shallowContent.first(where: FileTypes.isThemeSettingsFile)
        )
    }

    /// Finds all the markup files, resource files, and symbol graph files in the given directory.
    private func findContents(in startURL: URL) throws -> (markup: [URL], resources: [URL], symbolGraphs: [URL]) {
        // Find all the files
        var foundMarkup:       [URL] = []
        var foundResources:    [URL] = []
        var foundSymbolGraphs: [URL] = []

        var urlsToCheck = [startURL]
        while !urlsToCheck.isEmpty {
            let url = urlsToCheck.removeFirst()

            var (files, directories) = try fileManager.contentsOfDirectory(at: url, options: .skipsHiddenFiles)

            urlsToCheck.append(contentsOf: directories)

            // Group the found files by type
            let markupPartitionIndex = files.partition(by: FileTypes.isMarkupFile)
            var nonMarkupFiles = files[..<markupPartitionIndex]
            let symbolGraphPartitionIndex = nonMarkupFiles.partition(by: FileTypes.isSymbolGraphFile)

            foundMarkup.append(contentsOf:       files[markupPartitionIndex...]               )
            foundResources.append(contentsOf:    nonMarkupFiles[..<symbolGraphPartitionIndex] )
            foundSymbolGraphs.append(contentsOf: nonMarkupFiles[symbolGraphPartitionIndex...] )
        }

        return (markup: foundMarkup, resources: foundResources, symbolGraphs: foundSymbolGraphs)
    }
}

// MARK: Create without catalog

extension DocumentationContext.InputsProvider {
    /// Creates a collection of documentation inputs from the symbol graph files and other command line options.
    ///
    /// - Parameter options: Options to configure how the provider creates the documentation inputs.
    /// - Returns: Inputs that categorize the files of the given catalog.
    func makeInputsFromSymbolGraphs(options: Options) throws -> InputsAndDataProvider? {
        guard !options.additionalSymbolGraphFiles.isEmpty else {
            return nil
        }

        // Find all the unique module names from the symbol graph files and generate a top level module page for each of them.
        var moduleNames = Set<String>()
        for url in options.additionalSymbolGraphFiles {
            let data = try fileManager.contents(of: url)
            let container = try JSONDecoder().decode(SymbolGraphModuleContainer.self, from: data)
            moduleNames.insert(container.module.name)
        }
        let derivedDisplayName = moduleNames.count == 1 ? moduleNames.first : nil

        let info = try DocumentationContext.Inputs.Info(bundleDiscoveryOptions: options, derivedDisplayName: derivedDisplayName)
        
        let topLevelPages: [URL]
        let provider: DataProvider
        if moduleNames.count == 1, let moduleName = moduleNames.first, moduleName != info.displayName, let url = URL(string: "in-memory-data://\(moduleName).md") {
            let synthesizedExtensionFileData = Data("""
                # ``\(moduleName)``
                
                @Metadata {
                  @DisplayName("\(info.displayName)")
                }
                """.utf8)
            
            topLevelPages = [url]
            provider = InMemoryDataProvider(
                files: [url: synthesizedExtensionFileData],
                fallback: fileManager
            )
        } else {
            topLevelPages = []
            provider = fileManager
        }

        return (
            inputs: DocumentationBundle(
                info: info,
                symbolGraphURLs: options.additionalSymbolGraphFiles,
                markupURLs: topLevelPages,
                miscResourceURLs: []
            ),
            dataProvider: provider
        )
    }
}

/// A wrapper type that decodes only the module in the symbol graph.
private struct SymbolGraphModuleContainer: Decodable {
    /// The decoded symbol graph module.
    let module: SymbolGraph.Module

    typealias CodingKeys = SymbolGraph.CodingKeys

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.module = try container.decode(SymbolGraph.Module.self, forKey: .module)
    }
}

// MARK: Discover and create

extension DocumentationContext.InputsProvider {
    /// A pair of documentation inputs and a corresponding data provider for those input files.
    package typealias InputsAndDataProvider = (inputs: DocumentationContext.Inputs, dataProvider: DataProvider)
    
    /// Traverses the file system from the given starting point to find a documentation catalog and creates a collection of documentation inputs from that catalog.
    ///
    /// If the provider can't find a catalog, it will try to create documentation inputs from the option's symbol graph files.
    ///
    /// If the provider can't create documentation inputs it will raise an error with high level suggestions on how the caller can provide the missing information.
    ///
    /// - Parameters:
    ///   - startingPoint: The top of the directory hierarchy that the provider traverses to find a documentation catalog.
    ///   - allowArbitraryCatalogDirectories: Whether to treat the starting point as a documentation catalog if the provider doesn't find an actual catalog on the file system.
    ///   - options: Options to configure how the provider creates the documentation inputs.
    /// - Returns: A pair of documentation inputs and a corresponding data provider for those input files.
    package func inputsAndDataProvider(
        startingPoint: URL?,
        allowArbitraryCatalogDirectories: Bool = false,
        options: Options
    ) throws -> InputsAndDataProvider {
        if let startingPoint, let catalogURL = try findCatalog(startingPoint: startingPoint, allowArbitraryCatalogDirectories: allowArbitraryCatalogDirectories) {
            return (inputs: try makeInputs(contentOf: catalogURL, options: options), dataProvider: fileManager)
        }
        
        do {
            if let generated = try makeInputsFromSymbolGraphs(options: options) {
                return generated
            }
        } catch {
            throw InputsFromSymbolGraphError(underlyingError: error)
        }
        
        throw NotEnoughInformationError(startingPoint: startingPoint, additionalSymbolGraphFiles: options.additionalSymbolGraphFiles, allowArbitraryCatalogDirectories: allowArbitraryCatalogDirectories)
    }
    
    private static let insufficientInputsErrorMessageBase = "The information provided as command line arguments isn't enough to generate documentation.\n"
    
    struct InputsFromSymbolGraphError: DescribedError {
        var underlyingError: Error
        
        var errorDescription: String {
            "\(DocumentationContext.InputsProvider.insufficientInputsErrorMessageBase)\n\(underlyingError.localizedDescription)"
        }
    }
    
    struct NotEnoughInformationError: DescribedError {
        var startingPoint: URL?
        var additionalSymbolGraphFiles: [URL]
        var allowArbitraryCatalogDirectories: Bool
        
        var errorDescription: String {
            var message = DocumentationContext.InputsProvider.insufficientInputsErrorMessageBase
            if let startingPoint {
                message.append("""
                
                The `<catalog-path>` positional argument \(startingPoint.path.singleQuoted) isn't a documentation catalog (`.docc` directory) \
                and its directory sub-hierarchy doesn't contain a documentation catalog (`.docc` directory).
                
                """)
                if !allowArbitraryCatalogDirectories {
                    message.append("""
                    
                    To build documentation for the files in \(startingPoint.path.singleQuoted), \
                    either give it a `.docc` file extension to make it a documentation catalog \
                    or pass the `--allow-arbitrary-catalog-directories` flag to treat it as a documentation catalog, \
                    regardless of file extension.
                    
                    """)
                }
            }
            if additionalSymbolGraphFiles.isEmpty {
                if CommandLine.arguments.contains("--additional-symbol-graph-dir") {
                    message.append("""

                    The provided `--additional-symbol-graph-dir` directory doesn't contain any symbol graph files (with a `.symbols.json` file extension).
                    """)
                } else {
                    message.append("""
                    
                    To build documentation using only in-source documentation comments, \
                    pass a directory of symbol graph files (with a `.symbols.json` file extension) for the `--additional-symbol-graph-dir` argument.
                    """)
                }
            }
            
            return message
        }
    }
}
