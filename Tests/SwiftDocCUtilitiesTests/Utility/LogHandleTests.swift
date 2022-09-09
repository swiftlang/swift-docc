/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocCUtilities
@testable import SwiftDocC

class LogHandleTests: XCTestCase {

    /// Test that ``LogHandle`` doesn't append extra newlines to output
    /// - Bug: rdar://73462272
    func testWriteToStandardOutput() {
        let pipe = Pipe()

        // dup stdout to restore later
        let stdoutCopy = dup(FileHandle.standardOutput.fileDescriptor)

        // dup pipe's write handle to stdout. Now the file desc for stdout is the same as the pipe,
        // so when LogHandle writes to stdout, it'll be writing to pipe's write handle as well.
        dup2(pipe.fileHandleForWriting.fileDescriptor, FileHandle.standardOutput.fileDescriptor)


        var handle = LogHandle.standardOutput
        handle.write("""
            ========================================
            Starting Local Preview Server
                Address: http://localhost:8080/documentation/my-framework
            ========================================
            """
        )

        // restore stdout since pipe will be deallocated. If this wasn't
        // called, any subsequent calls to `Swift.print` could cause
        // the test runner to crash.
        dup2(stdoutCopy, FileHandle.standardOutput.fileDescriptor)

        let text = String(data: pipe.fileHandleForReading.availableData, encoding: .utf8)

        XCTAssertEqual(text, """
            ========================================
            Starting Local Preview Server
                Address: http://localhost:8080/documentation/my-framework
            ========================================
            """
        )
    }

    func testFlushesStandardOutput() {
        let pipe = Pipe()

        // dup stdout to restore later
        let stdoutCopy = dup(FileHandle.standardOutput.fileDescriptor)
        dup2(pipe.fileHandleForWriting.fileDescriptor, FileHandle.standardOutput.fileDescriptor)

        var handle = LogHandle.standardOutput
        handle.write("No newlines here")

        dup2(stdoutCopy, FileHandle.standardOutput.fileDescriptor)
        
        let data = pipe.fileHandleForReading.availableData
        let text = String(data: data, encoding: .utf8)
        XCTAssertEqual(text, "No newlines here", "\(LogHandle.self) didn't flush stdout")
    }

    func testFlushesStandardError() {
        let pipe = Pipe()

        // dup stdout to restore later
        let stdoutCopy = dup(FileHandle.standardError.fileDescriptor)
        dup2(pipe.fileHandleForWriting.fileDescriptor, FileHandle.standardError.fileDescriptor)

        var handle = LogHandle.standardError
        handle.write("No newlines here")

        dup2(stdoutCopy, FileHandle.standardError.fileDescriptor)

        let data = pipe.fileHandleForReading.availableData
        let text = String(data: data, encoding: .utf8)
        XCTAssertEqual(text, "No newlines here", "\(LogHandle.self) didn't flush stderr")
    }
}
