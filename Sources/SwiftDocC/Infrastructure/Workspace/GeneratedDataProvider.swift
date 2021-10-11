/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A type that provides documentation bundles that it discovers by traversing the local file system.
public struct GeneratedDataProvider: DocumentationWorkspaceDataProvider {
    public var identifier: String = UUID().uuidString
    
    /// Options to configure how the provider generates documentation bundles.
    public var options: BundleDiscoveryOptions
    
    private let info: DocumentationBundle.Info
    private let topLevelPage: URL
    public typealias SymbolGraphDataLoader = (URL) -> Data?
    private let symbolGraphDataLoader: SymbolGraphDataLoader
    
    /// Creates a new provider that recursively traverses the content of the given root URL to discover documentation bundles.
    ///
    /// - Parameters:
    ///   - options: Options to configure how the converter discovers documentation bundles.
    ///   - symbolGraphDataLoader: A closure that loads the raw data for a symbol graph file at a given URL.
    public init(options: BundleDiscoveryOptions, symbolGraphDataLoader: @escaping SymbolGraphDataLoader) throws {
        self.options = options
        self.symbolGraphDataLoader = symbolGraphDataLoader
        do {
            let info = try DocumentationBundle.Info(plist: options.infoPlistFallbacks)
            self.info = info
        } catch {
            throw Error.notEnoughDataToGenerateBundle(options: options, underlyingError: error)
        }
        
        self.topLevelPage = URL(string: "\(info.displayName.replacingWhitespaceAndPunctuation(with: "-")).md")!
    }
    
    public func bundles(options: BundleDiscoveryOptions) throws -> [DocumentationBundle] {
        guard !options.additionalSymbolGraphFiles.isEmpty else {
            return []
        }
        
        return [
            DocumentationBundle(
                displayName: info.displayName,
                identifier: info.identifier,
                version: info.version,
                attributedCodeListings: [:],
                symbolGraphURLs: options.additionalSymbolGraphFiles,
                markupURLs: [topLevelPage],
                miscResourceURLs: [],
                defaultCodeListingLanguage: info.defaultCodeListingLanguage,
                defaultAvailability: nil
            )
        ]
    }
    
    enum Error: DescribedError {
        case unableToLoadSymbolGraphData(url: URL)
        case notEnoughDataToGenerateBundle(options: BundleDiscoveryOptions, underlyingError: Swift.Error?)
        
        var errorDescription: String {
            switch self {
            case .unableToLoadSymbolGraphData(let url):
                return "Unable to load data for symbol graph file at \(url.path.singleQuoted)"
            case .notEnoughDataToGenerateBundle(let options, let underlyingError):
                var symbolGraphFileList = options.additionalSymbolGraphFiles.reduce("") { $0 + "\n\t" + $1.path }
                if !symbolGraphFileList.isEmpty {
                    symbolGraphFileList += "\n"
                }
                
                var errorMessage =  """
                    The information provided as command line arguments is not enough to generate a documentation bundle:
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
        if url == topLevelPage {
            let markdown = "# ``\(info.displayName)``"
            return Data(markdown.utf8)
        } else if options.additionalSymbolGraphFiles.contains(url) {
            guard let data = symbolGraphDataLoader(url) else {
                throw Error.unableToLoadSymbolGraphData(url: url)
            }
            return data
        } else {
            preconditionFailure("Unexpected url '\(url)'.")
        }
    }
}
