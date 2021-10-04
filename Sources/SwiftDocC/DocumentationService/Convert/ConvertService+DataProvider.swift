/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

extension ConvertService {
    /// Data provider for a conversion service.
    ///
    /// This data provider accepts in-memory documentation and assigns unique URLs for each document.
    struct InMemoryContentDataProvider: DocumentationWorkspaceDataProvider {
        var identifier: String = UUID().uuidString
        var bundles: [DocumentationBundle] = []
        
        var files: [URL: Data] = [:]
        
        mutating func registerBundle(
            info: DocumentationBundle.Info,
            symbolGraphs: [Data],
            markupFiles: [Data],
            miscResourceURLs: [URL]
        ) {
            let symbolGraphURLs = symbolGraphs.map { registerFile(contents: $0, isMarkupFile: false) }
            let markupFileURLs = markupFiles.map { registerFile(contents: $0, isMarkupFile: true) }
            
            bundles.append(
                DocumentationBundle(
                    info: info,
                    symbolGraphURLs: symbolGraphURLs,
                    markupURLs: markupFileURLs,
                    miscResourceURLs: miscResourceURLs
                )
            )
        }
        
        private mutating func registerFile(contents: Data, isMarkupFile: Bool) -> URL {
            let url = Self.createURL(isMarkupFile: isMarkupFile)
            files[url] = contents
            return url
        }

        /// Creates a unique URL for a resource.
        ///
        /// The URL this function generates for a resource is not derived from the resource itself, because it doesn't need to be. The
        /// ``DocumentationWorkspaceDataProvider`` model revolves around retrieving resources by their URL. In our use
        /// case, our resources are not file URLs so we generate a URL for each resource.
        static private func createURL(isMarkupFile: Bool) -> URL {
            var url = URL(string: "docc-service:/\(UUID().uuidString)")!
            
            if isMarkupFile {
                url.appendPathExtension(DocumentationBundleFileTypes.referenceFileExtension)
            }
            
            return url
        }
        
        func contentsOfURL(_ url: URL) throws -> Data {
            guard let contents = files[url] else {
                throw Error.unknownURL(url: url)
            }
            return contents
        }
        
        func bundles(options: BundleDiscoveryOptions) throws -> [DocumentationBundle] {
            return bundles
        }
        
        enum Error: DescribedError {
            case unknownURL(url: URL)
            
            var errorDescription: String {
                switch self {
                case .unknownURL(let url):
                    return """
                    Unable to retrieve contents of file at \(url.absoluteString.singleQuoted).
                    """
                }
            }
        }
    }
    
}
