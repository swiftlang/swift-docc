/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SwiftDocC

/// An action that creates documentation coverage info for a documentation bundle.
public struct CoverageAction: Action {
    internal init(
        documentationCoverageOptions: DocumentationCoverageOptions,
        workingDirectory: URL,
        fileManager: FileManagerProtocol) {
        self.documentationCoverageOptions = documentationCoverageOptions
        self.workingDirectory = workingDirectory
        self.fileManager = fileManager
    }

    public let documentationCoverageOptions: DocumentationCoverageOptions
    internal let workingDirectory: URL
    private let fileManager: FileManagerProtocol

    public mutating func perform(logHandle: LogHandle) throws -> ActionResult {
        switch documentationCoverageOptions.level {
        case .brief, .detailed:
            Swift.print("   --- Experimental coverage output enabled. ---")

            let summaryString = try CoverageDataEntry.generateSummary(
                ofDataAt: workingDirectory.appendingPathComponent(
                    ConvertFileWritingConsumer.docCoverageFileName),
                fileManager: fileManager,
                shouldGenerateBrief: true,
                shouldGenerateDetailed: (documentationCoverageOptions.level == .detailed)
            )
            print(summaryString)
        case .none:
            break
        }

        return ActionResult(didEncounterError: false, outputs: [])
    }
}

