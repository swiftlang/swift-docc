/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
import SwiftDocC
@testable import SwiftDocCUtilities

class JSONEncodingRenderNodeWriterTests: XCTestCase {
    /// Verifies that if we fail during writing a JSON file the execution
    /// does not deadlock.
    func testThrowingDuringWritingDoesNotDeadlock() throws {
        let temporaryDirectory = try createTemporaryDirectory()
        let indexHTML = temporaryDirectory.appendingPathComponent("index.html", isDirectory: false)
        try "html".write(
            to: indexHTML,
            atomically: true,
            encoding: .utf8
        )
        
        // Setting up the URL generator with a lengthy target folder path
        // that is guaranteed to throw if we try writing a file.
        let writer = JSONEncodingRenderNodeWriter(
            targetFolder: URL(fileURLWithPath: String(repeating: "A", count: 4096)),
            fileManager: FileManager.default,
            transformForStaticHostingIndexHTML: indexHTML
        )
        
        let renderNode = RenderNode(identifier: .init(bundleIdentifier: "com.test", path: "/documentation/test", sourceLanguage: .swift), kind: .article)
        
        // We take precautions in case we deadlock to stop the execution with a failing code.
        // In case the original issue is present and we deadlock, we fatalError from a bg thread.
        var didReleaseExecution = false
        DispatchQueue.global(qos: .default).asyncAfter(deadline: .now() + 2.0) {
            guard didReleaseExecution else {
                fatalError("\(#file):\(#function) failed to release the execution.")
            }
        }
        XCTAssertThrowsError(try writer.write(renderNode), "Did not throw when writing to invalid path.") { _ in }
        didReleaseExecution = true
    }    
}
