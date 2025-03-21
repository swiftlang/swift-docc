/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
public import SwiftDocC

/// An action that creates documentation coverage info for a documentation bundle.
public struct CoverageAction: AsyncAction {
    init(
        documentationCoverageOptions: DocumentationCoverageOptions,
        workingDirectory: URL,
        fileManager: FileManagerProtocol
    ) {
        self.documentationCoverageOptions = documentationCoverageOptions
        self.workingDirectory = workingDirectory
        self.fileManager = fileManager
    }

    public let documentationCoverageOptions: DocumentationCoverageOptions
    let workingDirectory: URL
    private let fileManager: FileManagerProtocol

    public func perform(logHandle: inout LogHandle) async throws -> ActionResult {
        switch documentationCoverageOptions.level {
        case .brief, .detailed:
            print("   --- Experimental coverage output enabled. ---", to: &logHandle)

            let summaryString = try CoverageDataEntry.generateSummary(
                ofDataAt: workingDirectory.appendingPathComponent(
                    ConvertFileWritingConsumer.docCoverageFileName,
                    isDirectory: false
                ),
                fileManager: fileManager,
                shouldGenerateBrief: true,
                shouldGenerateDetailed: (documentationCoverageOptions.level == .detailed)
            )
            print(summaryString, to: &logHandle)
        case .none:
            break
        }

        return ActionResult(didEncounterError: false, outputs: [])
    }
}

