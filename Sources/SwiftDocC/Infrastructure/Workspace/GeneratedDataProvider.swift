/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SymbolKit

/// A type that provides documentation catalogs that it discovers by traversing the local file system.
public class GeneratedDataProvider: DocumentationWorkspaceDataProvider {
    public var identifier: String = UUID().uuidString
    
    public typealias SymbolGraphDataLoader = (URL) -> Data?
    private let symbolGraphDataLoader: SymbolGraphDataLoader
    private var generatedMarkdownFiles: [String: Data] = [:]
    
    /// Creates a new provider that generates documentation catalogs from the ``CatalogDiscoveryOptions`` it is passed in ``catalogs(options:)``.
    ///
    /// - Parameters:
    ///   - symbolGraphDataLoader: A closure that loads the raw data for a symbol graph file at a given URL.
    public init(symbolGraphDataLoader: @escaping SymbolGraphDataLoader) {
        self.symbolGraphDataLoader = symbolGraphDataLoader
    }
    
    public func catalogs(options: CatalogDiscoveryOptions) throws -> [DocumentationCatalog] {
        let info: DocumentationCatalog.Info
        do {
            info = try DocumentationCatalog.Info(catalogDiscoveryOptions: options)
        } catch {
            throw Error.notEnoughDataToGenerateCatalog(options: options, underlyingError: error)
        }
        
        guard !options.additionalSymbolGraphFiles.isEmpty else {
            return []
        }
        
        // Find all the unique module names from the symbol graph files and generate a top level module page for each of them.
        var moduleNames = Set<String>()
        for url in options.additionalSymbolGraphFiles {
            guard let data = symbolGraphDataLoader(url) else {
                throw Error.unableToLoadSymbolGraphData(url: url)
            }
            let container = try JSONDecoder().decode(SymbolGraphModuleContainer.self, from: data)
            moduleNames.insert(container.module.name)
        }
        
        if moduleNames.count == 1, let moduleName = moduleNames.first, moduleName != info.displayName {
            generatedMarkdownFiles[moduleName] = Data("""
                # ``\(moduleName)``

                @Metadata {
                  @DisplayName("\(info.displayName)")
                }
                """.utf8)
        } else {
            for moduleName in moduleNames {
                generatedMarkdownFiles[moduleName] = Data("# ``\(moduleName)``".utf8)
            }
        }
        
        let topLevelPages = generatedMarkdownFiles.keys.map { URL(string: $0 + ".md")! }
        
        return [
            DocumentationCatalog(
                info: info,
                attributedCodeListings: [:],
                symbolGraphURLs: options.additionalSymbolGraphFiles,
                markupURLs: topLevelPages,
                miscResourceURLs: []
            )
        ]
    }
    
    @available(*, deprecated, renamed: "catalogs(options:)")
    public func bundles(options: CatalogDiscoveryOptions) throws -> [DocumentationCatalog] {
        return try catalogs(options: options)
    }
    
    enum Error: DescribedError {
        case unableToLoadSymbolGraphData(url: URL)
        case notEnoughDataToGenerateCatalog(options: CatalogDiscoveryOptions, underlyingError: Swift.Error?)
        
        var errorDescription: String {
            switch self {
            case .unableToLoadSymbolGraphData(let url):
                return "Unable to load data for symbol graph file at \(url.path.singleQuoted)"
            case .notEnoughDataToGenerateCatalog(let options, let underlyingError):
                var symbolGraphFileList = options.additionalSymbolGraphFiles.reduce("") { $0 + "\n\t" + $1.path }
                if !symbolGraphFileList.isEmpty {
                    symbolGraphFileList += "\n"
                }
                
                var errorMessage =  """
                    The information provided as command line arguments is not enough to generate a documentation catalog:
                    """
                
                if let underlyingError = underlyingError {
                    errorMessage += """
                    \((underlyingError as? DescribedError)?.errorDescription ?? underlyingError.localizedDescription)
                    
                    """
                } else {
                    errorMessage += """
                    \(options.infoPlistFallbacks.sorted(by: { lhs, rhs in lhs.key < rhs.key }).map { "\($0.key) : '\($0.value)'" }.joined(separator: "\n"))
                    Additional symbol graph files: [\(symbolGraphFileList)]
                    
                    """
                }
                
                return errorMessage
            }
        }
    }
    
    public func contentsOfURL(_ url: URL) throws -> Data {
        if DocumentationCatalogFileTypes.isMarkupFile(url), let content = generatedMarkdownFiles[url.deletingPathExtension().lastPathComponent] {
            return content
        } else if DocumentationCatalogFileTypes.isSymbolGraphFile(url) {
            guard let data = symbolGraphDataLoader(url) else {
                throw Error.unableToLoadSymbolGraphData(url: url)
            }
            return data
        } else {
            preconditionFailure("Unexpected url '\(url)'.")
        }
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
