/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

extension ConvertService {
    /// Creates a bundle and an associated in-memory data provider from the information of a given convert request
    static func makeBundleAndInMemoryDataProvider(_ request: ConvertRequest) -> (inputs: DocumentationContext.Inputs, provider: InMemoryDataProvider) {
        var files: [URL: Data] = [:]
        files.reserveCapacity(
              request.symbolGraphs.count
            + request.markupFiles.count
            + request.tutorialFiles.count
            + request.miscResourceURLs.count
        )
        for markupFile in request.markupFiles {
            files[makeURL().appendingPathExtension(DocumentationInputFileTypes.referenceFileExtension)] = markupFile
        }
        for tutorialFile in request.tutorialFiles {
            files[makeURL().appendingPathExtension(DocumentationInputFileTypes.tutorialFileExtension)] = tutorialFile
        }
        let markupFileURL = Array(files.keys)
        
        var symbolGraphURLs: [URL] = []
        symbolGraphURLs.reserveCapacity(request.symbolGraphs.count)
        for symbolGraph in request.symbolGraphs {
            let url = makeURL()
            symbolGraphURLs.append(url)
            files[url] = symbolGraph
        }
        
        return (
            DocumentationContext.Inputs(
                info: request.bundleInfo,
                symbolGraphURLs: symbolGraphURLs,
                markupURLs: markupFileURL,
                miscResourceURLs: request.miscResourceURLs
            ),
            InMemoryDataProvider(
                files: files,
                fallback: FileManager.default
            )
        )
    }
    
    private static func makeURL() -> URL {
        URL(string: "docc-service:/\(UUID().uuidString)")!
    }
}
