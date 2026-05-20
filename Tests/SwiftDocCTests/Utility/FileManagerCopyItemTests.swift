/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
import Foundation
@testable import SwiftDocC
@testable import DocCTestUtilities

class FileManagerCopyItemTests: XCTestCase {

    // MARK: - Test helper: FileManager subclass that simulates partial directory copies

    /// A `FileManager` subclass that simulates the behavior observed on Linux (Swift 6.x) when
    /// `copyItem(at:to:)` is called on a root-owned directory by a non-root user.
    ///
    /// On Linux, `copyItem` creates the destination directory, copies children recursively, and
    /// calls `fchown()` to preserve source ownership. When the source is root-owned and the
    /// process is non-root, `fchown` fails. Depending on the Foundation version, this can cause
    /// `copyItem` to throw **mid-copy** — after creating the destination directory and copying
    /// only some children — rather than after completing the full copy.
    ///
    /// This subclass reproduces that behavior by:
    /// - For directory copies: creating the destination, copying only the first child, then throwing
    /// - For file copies: performing the real copy, then throwing (file exists but attributes weren't set)
    class PartialCopyFileManager: FileManager {
        override func copyItem(at srcURL: URL, to dstURL: URL) throws {
            var isDir: ObjCBool = false
            guard fileExists(atPath: srcURL.path, isDirectory: &isDir) else {
                throw CocoaError(.fileReadNoSuchFile, userInfo: [NSFilePathErrorKey: srcURL.path])
            }

            if isDir.boolValue {
                // Directory copy: create the directory, copy only the first child, then throw.
                // This simulates copyItem failing mid-way through a recursive directory copy.
                try createDirectory(at: dstURL, withIntermediateDirectories: true, attributes: nil)

                let children = try contentsOfDirectory(atPath: srcURL.path).sorted()
                if let firstChild = children.first {
                    let childSrc = srcURL.appendingPathComponent(firstChild)
                    let childDst = dstURL.appendingPathComponent(firstChild)
                    try super.copyItem(at: childSrc, to: childDst)
                }

                throw CocoaError(.fileWriteNoPermission, userInfo: [
                    NSFilePathErrorKey: srcURL.path,
                    NSURLErrorKey: srcURL,
                ])
            } else {
                // File copy: perform the real copy, then throw to simulate fchown failure.
                // The file IS successfully written — only the attribute-setting step fails.
                try super.copyItem(at: srcURL, to: dstURL)
                throw CocoaError(.fileWriteNoPermission, userInfo: [
                    NSFilePathErrorKey: srcURL.path,
                    NSURLErrorKey: srcURL,
                ])
            }
        }
    }

    // MARK: - Tests

    func testCopyItemCompletesIncompleteDirectoryCopy() throws {
        // Set up a source directory that mimics the docc HTML template structure
        let tempDir = try createTemporaryDirectory()
        let sourceDir = tempDir.appendingPathComponent("source")
        let destDir = tempDir.appendingPathComponent("dest")

        try FileManager.default.createDirectory(at: sourceDir, withIntermediateDirectories: true)

        // Create multiple files (alphabetically: css dir, favicon, index.html)
        let cssDir = sourceDir.appendingPathComponent("css")
        try FileManager.default.createDirectory(at: cssDir, withIntermediateDirectories: true)
        try Data("body {}".utf8).write(to: cssDir.appendingPathComponent("style.css"))
        try Data("<svg/>".utf8).write(to: sourceDir.appendingPathComponent("favicon.svg"))
        try Data("<html><head></head><body></body></html>".utf8)
            .write(to: sourceDir.appendingPathComponent("index.html"))
        try Data("<html>{{BASE_PATH}}</html>".utf8)
            .write(to: sourceDir.appendingPathComponent("index-template.html"))

        let fm = PartialCopyFileManager()

        // Without the fix, _copyItem would silently return after the partial copy,
        // leaving index.html, favicon.svg, and index-template.html missing.
        try fm._copyItem(at: sourceDir, to: destDir)

        // Verify ALL files were copied despite simulated fchown errors
        XCTAssertTrue(fm.directoryExists(atPath: destDir.appendingPathComponent("css").path),
                       "css directory should exist")
        XCTAssertTrue(fm.fileExists(atPath: destDir.appendingPathComponent("css/style.css").path),
                       "css/style.css should exist")
        XCTAssertTrue(fm.fileExists(atPath: destDir.appendingPathComponent("favicon.svg").path),
                       "favicon.svg should exist")
        XCTAssertTrue(fm.fileExists(atPath: destDir.appendingPathComponent("index.html").path),
                       "index.html should exist")
        XCTAssertTrue(fm.fileExists(atPath: destDir.appendingPathComponent("index-template.html").path),
                       "index-template.html should exist")

        // Verify content integrity
        let copiedHTML = try Data(contentsOf: destDir.appendingPathComponent("index.html"))
        XCTAssertEqual(String(decoding: copiedHTML, as: UTF8.self),
                       "<html><head></head><body></body></html>")
    }

    func testCopyItemHandlesNestedDirectoryPartialCopy() throws {
        // Test that _copyMissingChildren recurses into subdirectories
        let tempDir = try createTemporaryDirectory()
        let sourceDir = tempDir.appendingPathComponent("source")
        let destDir = tempDir.appendingPathComponent("dest")

        try FileManager.default.createDirectory(at: sourceDir, withIntermediateDirectories: true)

        // Create a nested structure: source/dir_a/file1.txt, source/dir_a/file2.txt, source/dir_b/file3.txt
        let dirA = sourceDir.appendingPathComponent("dir_a")
        let dirB = sourceDir.appendingPathComponent("dir_b")
        try FileManager.default.createDirectory(at: dirA, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: dirB, withIntermediateDirectories: true)
        try Data("file1".utf8).write(to: dirA.appendingPathComponent("file1.txt"))
        try Data("file2".utf8).write(to: dirA.appendingPathComponent("file2.txt"))
        try Data("file3".utf8).write(to: dirB.appendingPathComponent("file3.txt"))
        try Data("root_file".utf8).write(to: sourceDir.appendingPathComponent("root.txt"))

        let fm = PartialCopyFileManager()
        try fm._copyItem(at: sourceDir, to: destDir)

        // Verify entire tree was copied
        XCTAssertTrue(fm.fileExists(atPath: destDir.appendingPathComponent("dir_a/file1.txt").path))
        XCTAssertTrue(fm.fileExists(atPath: destDir.appendingPathComponent("dir_a/file2.txt").path))
        XCTAssertTrue(fm.fileExists(atPath: destDir.appendingPathComponent("dir_b/file3.txt").path))
        XCTAssertTrue(fm.fileExists(atPath: destDir.appendingPathComponent("root.txt").path))
    }

    func testCopyItemSingleFileWithPermissionError() throws {
        // Test that single-file copies still work when fchown fails (the original workaround case)
        let tempDir = try createTemporaryDirectory()

        let sourceFile = tempDir.appendingPathComponent("source.txt")
        let destFile = tempDir.appendingPathComponent("dest.txt")
        try Data("hello".utf8).write(to: sourceFile)

        let fm = PartialCopyFileManager()
        try fm._copyItem(at: sourceFile, to: destFile)

        XCTAssertTrue(fm.fileExists(atPath: destFile.path))
        let content = try Data(contentsOf: destFile)
        XCTAssertEqual(String(decoding: content, as: UTF8.self), "hello")
    }
}
