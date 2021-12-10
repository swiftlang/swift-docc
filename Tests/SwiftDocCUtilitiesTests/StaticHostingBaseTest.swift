/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
import Foundation
@testable import SwiftDocC
@testable import SwiftDocCUtilities

class StaticHostingBaseTests: XCTestCase {

    /// Checks that the content in the output URL is as expected based on any JSON files found in the inputURL and any any sub folders.
    /// Also checks any index.html files contain the expected content.
    func compareJSONFolder(fileManager: FileManager, output: URL, input: URL, indexHTML: String?) {

        do {
            let inputContents = try fileManager.contentsOfDirectory(atPath: input.path)
            let outputContents = try fileManager.contentsOfDirectory(atPath: output.path)

            for inputContent in inputContents {
                if inputContent.lowercased().hasSuffix(".json") {
                    let folderName = String(inputContent.dropLast(5))
                    XCTAssert(outputContents.contains(folderName), "Failed to find folder in output for input  \(inputContent) in \(input)")
                    do {
                        let createdFolder = output.appendingPathComponent(folderName)
                        let jsonFolderContents = try fileManager.contentsOfDirectory(atPath: createdFolder.path)
                        guard jsonFolderContents.count > 0 else {
                            XCTFail("Unexpected number of files in \(createdFolder). Expected > 0 but found \(jsonFolderContents.count) - \(jsonFolderContents)")
                            continue
                        }

                        guard jsonFolderContents.contains("index.html") else {
                            XCTFail("Expected to find index.html in \(createdFolder) but found \(jsonFolderContents)")
                            continue
                        }

                        // Only check the indexHTML if we have some.
                        guard let indexHTML = indexHTML else { continue }

                        let indexFileURL = createdFolder.appendingPathComponent("index.html")
                        let testHTMLString = try String(contentsOf: indexFileURL)
                        XCTAssertEqual(testHTMLString, indexHTML, "Unexpected content in index.html at \(indexFileURL)")
                    } catch {
                        XCTFail("Invalid contents during comparrison of \(input) and \(output) - \(error)")
                        continue
                    }
                } else {
                    compareJSONFolder(fileManager: fileManager,
                                   output: output.appendingPathComponent(inputContent),
                                   input: input.appendingPathComponent(inputContent),
                                   indexHTML: indexHTML)
                }
            }
        } catch {
            XCTFail("Invalid contents during comparrison of \(input) and \(output) - \(error)")
        }
    }
}
