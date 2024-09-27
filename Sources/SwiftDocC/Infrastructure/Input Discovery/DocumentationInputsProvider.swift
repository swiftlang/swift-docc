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
    public struct InputsProvider {
        /// The file manager that the provider uses to read file and directory contents from the file system.
        private var fileManager: FileManagerProtocol

        /// Creates a new documentation inputs provider.
        /// - Parameter fileManager: The file manager that the provider uses to read file and directory contents from the file system.
        package init(fileManager: FileManagerProtocol) {
            self.fileManager = fileManager
        }

        /// Creates a new documentation inputs provider.
        public init() {
            self.init(fileManager: FileManager.default)
        }
    }
}

// MARK: Catalog discovery

extension DocumentationContext.InputsProvider {

    private typealias FileTypes = DocumentationBundleFileTypes

    /// A discovered documentation catalog.
    public struct CatalogURL {
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
    public func findCatalog(
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

// MARK: Inputs creation

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
    package func makeInputs(contentOf catalogURL: CatalogURL, options: Options) throws -> DocumentationContext.Inputs {
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
    package func makeInputsFromSymbolGraphs(options: Options) throws -> DocumentationContext.Inputs? {
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

        var topLevelPages: [URL] = []
        if moduleNames.count == 1, let moduleName = moduleNames.first, moduleName != info.displayName {
            let tempURL = fileManager.uniqueTemporaryDirectory()
            try? fileManager.createDirectory(at: tempURL, withIntermediateDirectories: true, attributes: nil)

            let url = tempURL.appendingPathComponent("\(moduleName).md")
            topLevelPages.append(url)
            try fileManager.createFile(
                at: url,
                contents: Data("""
                # ``\(moduleName)``
                
                @Metadata {
                  @DisplayName("\(info.displayName)")
                }
                """.utf8),
                options: .atomic
            )
        }

        return DocumentationBundle(
            info: info,
            symbolGraphURLs: options.additionalSymbolGraphFiles,
            markupURLs: topLevelPages,
            miscResourceURLs: []
        )
    }
}

/// A wrapper type that decodes only the module in the symbol graph.
private struct SymbolGraphModuleContainer: Decodable {
    /// The decoded symbol graph module.
    let module: SymbolGraph.Module

    typealias CodingKeys = SymbolGraph.CodingKeys

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.module = try container.decode(SymbolGraph.Module.self, forKey: .module)
    }
}

// MARK: Discover and create

extension DocumentationContext.InputsProvider {
    /// Traverses the file system from the given starting point to find a documentation catalog and creates a collection of documentation inputs from that catalog.
    ///
    /// If the provider can't find a catalog, it will try to create documentation inputs from the option's symbol graph files.
    ///
    /// - Parameters:
    ///   - startingPoint: The top of the directory hierarchy that the provider traverses to find a documentation catalog.
    ///   - allowArbitraryCatalogDirectories: Whether to treat the starting point as a documentation catalog if the provider doesn't find an actual catalog on the file system.
    ///   - options: Options to configure how the provider creates the documentation inputs.
    /// - Returns: The documentation inputs for the found documentation catalog, or `nil` if the directory hierarchy doesn't contain a catalog.
    /// - Throws: If the directory hierarchy contains more than one documentation catalog.
    package func inputs(
        startingPoint: URL,
        allowArbitraryCatalogDirectories: Bool = false,
        options: Options
    ) throws -> DocumentationContext.Inputs? {
        if let catalogURL = try findCatalog(startingPoint: startingPoint, allowArbitraryCatalogDirectories: allowArbitraryCatalogDirectories) {
            try makeInputs(contentOf: catalogURL, options: options)
        } else {
            try makeInputsFromSymbolGraphs(options: options)
        }
    }
}
