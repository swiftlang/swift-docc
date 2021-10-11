/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SwiftDocC

extension CoverageDataEntry {
    /// Outputs a short table summarizing the coverage statistics for a list of data entries in a file at the given URL.
    public static func generateSummary(
        ofDataAt url: URL,
        shouldGenerateBrief: Bool,
        shouldGenerateDetailed: Bool
    ) throws -> String {
        try generateSummary(
            ofDataAt: url,
            fileManager: FileManager.default,
            shouldGenerateBrief: shouldGenerateBrief,
            shouldGenerateDetailed: shouldGenerateDetailed
        )
    }
    
    /// Outputs a short table summarizing the coverage statistics for a list of data entries in a file at the given URL.
    ///
    /// This is an internal version of the function that allows for mocking with the internal
    /// 'FileManagerProtocol' type.
    static func generateSummary(
        ofDataAt url: URL,
        fileManager: FileManagerProtocol,
        shouldGenerateBrief: Bool,
        shouldGenerateDetailed: Bool
    ) throws -> String {
        let decoder = JSONDecoder()
        guard let data = fileManager.contents(atPath: url.path) else {
            throw Error.serializationError(description: "Unable to read file contents at '\(url.path)'")
        }

        let coverageInfo = try decoder.decode(
            [CoverageDataEntry].self,
            from: data
        )

        return generateSummary(
            of: coverageInfo,
            shouldGenerateBrief: shouldGenerateBrief,
            shouldGenerateDetailed: shouldGenerateDetailed
        )
    }
}
